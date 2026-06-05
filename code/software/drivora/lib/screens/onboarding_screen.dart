import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wifi_sensor_service.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

// ─── PALETTE ────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF060810);
const _kSurface = Color(0xFF0C0F1A);
const _kBorder  = Color(0xFF1C2236);
const _kCyan    = Color(0xFF00E5FF);
const _kBlue    = Color(0xFF2979FF);
const _kGreen   = Color(0xFF00E676);
const _kAmber   = Color(0xFFFFAB00);
const _kRed     = Color(0xFFFF1744);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  // Step 0 = Register, Step 1 = Connect WiFi, Step 2 = Calibrate
  int _step = 0;
  bool _saving = false;
  String? _error;

  // ── Step 0 form data ──────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _vehicleType  = 'Sedan';
  String _vehicleModel = '';
  final _modelCtrl = TextEditingController();

  // ── Step 2 calibration data ───────────────────────────────────────────────
  double _trackWidth    = 1.56;
  double _wheelBase     = 2.67;
  double _vehicleHeight = 1.57;
  double _tyreDiameter  = 0.62; // metres
  int    _loadCondition = 1;    // 0 light, 1 normal, 2 heavy
  int    _vehicleTypeCode = 3;  // 1 compact, 2 passenger, 3 tall/SUV
  int    _frontPreset  = 1;     // 0 near, 1 normal, 2 far
  int    _rearPreset   = 1;

  final _twCtrl  = TextEditingController(text: '1.56');
  final _wbCtrl  = TextEditingController(text: '2.67');
  final _vhCtrl  = TextEditingController(text: '1.57');
  final _tdCtrl  = TextEditingController(text: '0.62');

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  final CloudService _cloudService = CloudService();

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose(); _emailCtrl.dispose(); _modelCtrl.dispose();
    _twCtrl.dispose(); _wbCtrl.dispose(); _vhCtrl.dispose(); _tdCtrl.dispose();
    super.dispose();
  }

  void _animateStep(int next) {
    _fadeCtrl.reverse().then((_) {
      setState(() { _step = next; _error = null; });
      _fadeCtrl.forward();
    });
  }

  // ── STEP 0: Register ──────────────────────────────────────────────────────
  Future<void> _register() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final model = _modelCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || model.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    await prefs.setString('carModel', model);
    await prefs.setString('vehicleType', _vehicleType);

    await _cloudService.saveOnboardingData(
      driverName: name,
      driverEmail: email,
      driverExperience: 'Standard',
      vehicleType: _vehicleType,
      vehicleModel: model,
      vehicleHeight: _vehicleHeight,
      vehicleWidth: _trackWidth,
      alertSensitivity: 5,
      audioVolume: 7,
    );

    setState(() => _saving = false);
    _animateStep(1);
  }

  // ── STEP 1: Connect ───────────────────────────────────────────────────────
  void _connectToHub(BuildContext context) {
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    svc.connectToHardwareHub('192.168.4.1');
    setState(() => _error = null);
  }

  void _goToCalibrate() => _animateStep(2);

  // ── STEP 2: Calibrate & Send ──────────────────────────────────────────────
  Future<void> _sendCalibration(BuildContext context) async {
    final svc = Provider.of<WiFiSensorService>(context, listen: false);

    _trackWidth    = double.tryParse(_twCtrl.text) ?? _trackWidth;
    _wheelBase     = double.tryParse(_wbCtrl.text) ?? _wheelBase;
    _vehicleHeight = double.tryParse(_vhCtrl.text) ?? _vehicleHeight;
    _tyreDiameter  = double.tryParse(_tdCtrl.text) ?? _tyreDiameter;

    setState(() { _saving = true; _error = null; });

    // Save locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vHeight', _vehicleHeight);
    await prefs.setDouble('vWidth', _trackWidth);
    await prefs.setDouble('tyreDiameter', _tyreDiameter);
    await prefs.setDouble('wheelBase', _wheelBase);
    await prefs.setInt('loadCondition', _loadCondition);
    await prefs.setInt('frontPreset', _frontPreset);
    await prefs.setInt('rearPreset', _rearPreset);
    await prefs.setBool('setupComplete', true);

    // Save to cloud
    final email = prefs.getString('userEmail') ?? '';
    if (email.isNotEmpty) {
      await _cloudService.saveOnboardingData(
        driverName: prefs.getString('userName') ?? '',
        driverEmail: email,
        driverExperience: 'Standard',
        vehicleType: _vehicleType,
        vehicleModel: prefs.getString('carModel') ?? '',
        vehicleHeight: _vehicleHeight,
        vehicleWidth: _trackWidth,
        alertSensitivity: 5,
        audioVolume: 7,
      );
    }

    // Send to hardware via WebSocket
    bool sent = false;
    if (svc.isConnected) {
      sent = await svc.sendSetupToHardware(
        vehicleType:    _vehicleTypeCode,
        trackWidthM:    _trackWidth,
        wheelBaseM:     _wheelBase,
        vehicleHeightM: _vehicleHeight,
        loadCondition:  _loadCondition,
        frontPreset:    _frontPreset,
        rearPreset:     _rearPreset,
      );
    }

    setState(() => _saving = false);

    if (!mounted) return;

    // Show success dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessDialog(sentToHardware: sent),
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          _buildTopBar(),
          Expanded(
            child: FadeTransition(
              opacity: _fade,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: _buildStepContent(context),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: const BoxDecoration(
      color: _kSurface,
      border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          colors: [_kCyan, _kBlue],
        ).createShader(r),
        child: Text('DRIVORA SETUP',
            style: GoogleFonts.orbitron(
                color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      const SizedBox(height: 12),
      _StepIndicator(step: _step),
    ]),
  );

  Widget _buildStepContent(BuildContext context) {
    switch (_step) {
      case 0: return _buildRegisterStep(context);
      case 1: return _buildConnectStep(context);
      case 2: return _buildCalibrateStep(context);
      default: return const SizedBox.shrink();
    }
  }

  // ────────────────────────── STEP 0: REGISTER ──────────────────────────────
  Widget _buildRegisterStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      _StepTitle('DRIVER PROFILE', 'Set up your account to save alerts and history to the cloud.'),
      const SizedBox(height: 24),
      if (_error != null) _ErrorBox(_error!),

      _Label('Full Name'),
      _Field(controller: _nameCtrl, hint: 'e.g. John Silva', icon: Icons.person_outline),
      const SizedBox(height: 16),

      _Label('Email Address'),
      _Field(controller: _emailCtrl, hint: 'john@example.com',
          icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
      const SizedBox(height: 16),

      _Label('Vehicle Model'),
      _Field(controller: _modelCtrl, hint: 'e.g. Toyota Vitz 2018', icon: Icons.directions_car_outlined),
      const SizedBox(height: 16),

      _Label('Vehicle Category'),
      _DropdownRow<String>(
        value: _vehicleType,
        items: const ['Compact', 'Sedan', 'SUV / Tall', 'Pickup'],
        onChanged: (v) => setState(() => _vehicleType = v!),
      ),
      const SizedBox(height: 32),
      _PrimaryBtn(
        label: _saving ? 'SAVING...' : 'CONTINUE',
        onTap: _saving ? null : () => _register(),
      ),
      const SizedBox(height: 20),
    ],
  );

  // ────────────────────────── STEP 1: CONNECT ───────────────────────────────
  Widget _buildConnectStep(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (ctx, svc, _) {
        final connected = svc.isConnected;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _StepTitle('CONNECT TO ADAS BRAIN',
                'Connect your phone to the "ADASBrain" WiFi hotspot, then tap the button below.'),
            const SizedBox(height: 24),

            // Network instruction card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kCyan.withOpacity(0.3), width: 1.5),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.wifi, color: _kCyan, size: 22),
                  const SizedBox(width: 10),
                  Text('WiFi Network', style: GoogleFonts.rajdhani(
                      color: _kCyan, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ]),
                const SizedBox(height: 12),
                _InfoRow('SSID', 'ADASBrain'),
                const SizedBox(height: 6),
                _InfoRow('Password', '12345678'),
                const SizedBox(height: 6),
                _InfoRow('Hub IP', '192.168.4.1'),
              ]),
            ),
            const SizedBox(height: 16),

            // Status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (connected ? _kGreen : _kAmber).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: (connected ? _kGreen : _kAmber).withOpacity(0.4)),
              ),
              child: Row(children: [
                Icon(connected ? Icons.check_circle_rounded : Icons.wifi_find_rounded,
                    color: connected ? _kGreen : _kAmber, size: 22),
                const SizedBox(width: 12),
                Text(connected ? 'ADAS Brain Connected!' : svc.status,
                    style: GoogleFonts.rajdhani(
                        color: connected ? _kGreen : _kAmber,
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 24),

            if (!connected)
              _PrimaryBtn(
                label: 'CONNECT TO ADAS BRAIN',
                icon: Icons.link_rounded,
                onTap: () { HapticFeedback.mediumImpact(); _connectToHub(context); },
              ),
            if (!connected) const SizedBox(height: 12),
            _SecondaryBtn(
              label: connected ? 'CONTINUE TO CALIBRATION' : 'SKIP (CALIBRATE LATER)',
              onTap: _goToCalibrate,
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  // ────────────────────────── STEP 2: CALIBRATE ─────────────────────────────
  Widget _buildCalibrateStep(BuildContext context) {
    final typeLabels = ['Compact', 'Passenger / Sedan', 'Tall / SUV'];
    final loadLabels = ['Light', 'Normal', 'Heavy'];
    final presetLabels = ['Near', 'Normal', 'Far'];

    return Consumer<WiFiSensorService>(builder: (ctx, svc, _) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _StepTitle('VEHICLE CALIBRATION',
              'Enter your vehicle dimensions. These are sent to the ADAS Brain for accurate warnings.'),
          const SizedBox(height: 24),
          if (_error != null) _ErrorBox(_error!),

          // ── Dimensions ──────────────────────────────────────────────────
          _SectionHeader('VEHICLE DIMENSIONS'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _NumField('Track Width (m)', _twCtrl, '1.56')),
            const SizedBox(width: 12),
            Expanded(child: _NumField('Wheel Base (m)', _wbCtrl, '2.67')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _NumField('Vehicle Height (m)', _vhCtrl, '1.57')),
            const SizedBox(width: 12),
            Expanded(child: _NumField('Tyre Diameter (m)', _tdCtrl, '0.62')),
          ]),
          const SizedBox(height: 20),

          // ── Vehicle type ─────────────────────────────────────────────────
          _SectionHeader('VEHICLE TYPE'),
          const SizedBox(height: 12),
          _SegmentedPicker(
            labels: typeLabels,
            selected: _vehicleTypeCode - 1,
            onTap: (i) => setState(() => _vehicleTypeCode = i + 1),
          ),
          const SizedBox(height: 20),

          // ── Load condition ────────────────────────────────────────────────
          _SectionHeader('LOAD CONDITION'),
          const SizedBox(height: 12),
          _SegmentedPicker(
            labels: loadLabels,
            selected: _loadCondition,
            onTap: (i) => setState(() => _loadCondition = i),
          ),
          const SizedBox(height: 20),

          // ── Sensitivity presets ───────────────────────────────────────────
          _SectionHeader('FRONT SENSOR SENSITIVITY'),
          const SizedBox(height: 12),
          _SegmentedPicker(
            labels: presetLabels,
            selected: _frontPreset,
            onTap: (i) => setState(() => _frontPreset = i),
          ),
          const SizedBox(height: 16),

          _SectionHeader('REAR SENSOR SENSITIVITY'),
          const SizedBox(height: 12),
          _SegmentedPicker(
            labels: presetLabels,
            selected: _rearPreset,
            onTap: (i) => setState(() => _rearPreset = i),
          ),
          const SizedBox(height: 8),

          if (!svc.isConnected)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAmber.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: _kAmber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Not connected to ADAS Brain — data will be saved locally only.',
                    style: GoogleFonts.rajdhani(color: _kAmber, fontSize: 11),
                  )),
                ]),
              ),
            ),

          const SizedBox(height: 16),
          _PrimaryBtn(
            label: _saving ? 'SAVING...' : 'FINISH SETUP',
            icon: Icons.check_rounded,
            onTap: _saving ? null : () => _sendCalibration(context),
          ),
          const SizedBox(height: 20),
        ],
      );
    });
  }
}

// ─── SUPPORTING WIDGETS ───────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final int step;
  static const _labels = ['REGISTER', 'CONNECT', 'CALIBRATE'];

  @override
  Widget build(BuildContext context) => Row(children: List.generate(3, (i) {
    final done   = i < step;
    final active = i == step;
    final color  = done ? _kGreen : active ? _kCyan : Colors.white24;
    return Expanded(
      child: Row(children: [
        Expanded(child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Center(
                child: done
                    ? Icon(Icons.check, color: _kGreen, size: 14)
                    : Text('${i + 1}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 6),
            Text(_labels[i], style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 6),
          if (i < 2)
            Container(height: 1.5,
                color: (i < step) ? _kGreen.withOpacity(0.5) : Colors.white12),
        ])),
      ]),
    );
  }));
}

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.orbitron(
        color: _kCyan, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    const SizedBox(height: 8),
    Text(subtitle, style: GoogleFonts.rajdhani(color: Colors.white54, fontSize: 13, height: 1.4)),
  ]);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: GoogleFonts.rajdhani(
      color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: GoogleFonts.rajdhani(
        color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint,
      required this.icon, this.keyboard = TextInputType.text});
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboard,
    style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.rajdhani(color: Colors.white24, fontSize: 14),
      prefixIcon: Icon(icon, color: _kCyan.withOpacity(0.7), size: 20),
      filled: true,
      fillColor: _kSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _kBorder.withOpacity(0.8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kCyan, width: 1.5),
      ),
    ),
  );
}

class _NumField extends StatelessWidget {
  const _NumField(this.label, this.controller, this.hint);
  final String label, hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.rajdhani(
          color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.orbitron(color: _kCyan, fontSize: 13, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.orbitron(color: Colors.white24, fontSize: 12),
          filled: true, fillColor: _kSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kCyan, width: 1.5)),
        ),
      ),
    ],
  );
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({required this.value, required this.items, required this.onChanged});
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      dropdownColor: _kSurface,
      style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kCyan),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Text(item.toString()),
      )).toList(),
      onChanged: onChanged,
    ),
  );
}

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker({required this.labels, required this.selected, required this.onTap});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(labels.length, (i) {
      final active = selected == i;
      return Expanded(
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onTap(i); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: EdgeInsets.only(right: i < labels.length - 1 ? 8 : 0),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: active ? _kCyan.withOpacity(0.15) : _kSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: active ? _kCyan : _kBorder, width: active ? 1.5 : 1),
            ),
            alignment: Alignment.center,
            child: Text(labels[i], style: GoogleFonts.rajdhani(
                color: active ? _kCyan : Colors.white38,
                fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ),
      );
    }),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label:  ', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 12)),
    Text(value, style: GoogleFonts.orbitron(color: _kCyan, fontSize: 12, fontWeight: FontWeight.bold)),
  ]);
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: onTap != null
            ? [const Color(0xFF2979FF), const Color(0xFF00B0FF)]
            : [Colors.white12, Colors.white12]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: onTap != null
            ? [BoxShadow(color: _kBlue.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))]
            : [],
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
        Text(label, style: GoogleFonts.orbitron(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ]),
    ),
  );
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCyan.withOpacity(0.35), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(label, style: GoogleFonts.rajdhani(
          color: _kCyan, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1)),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: _kRed.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kRed.withOpacity(0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: _kRed, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: GoogleFonts.rajdhani(color: _kRed, fontSize: 13))),
    ]),
  );
}

// ─── SUCCESS DIALOG ──────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.sentToHardware});
  final bool sentToHardware;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _kSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kGreen.withOpacity(0.15),
            border: Border.all(color: _kGreen, width: 2),
            boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.4), blurRadius: 24)],
          ),
          child: const Icon(Icons.check_rounded, color: _kGreen, size: 40),
        ),
        const SizedBox(height: 24),
        Text('SETUP COMPLETE',
            style: GoogleFonts.orbitron(
                color: _kGreen, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Text(
          sentToHardware
              ? 'Calibration data sent to ADAS Brain successfully. All systems are ready.'
              : 'Profile saved. Connect to ADAS Brain later to send calibration data.',
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(color: Colors.white54, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kGreen, Color(0xFF00C853)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.4), blurRadius: 16)],
            ),
            child: Text('GO TO DASHBOARD',
                style: GoogleFonts.orbitron(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ]),
    ),
  );
}
