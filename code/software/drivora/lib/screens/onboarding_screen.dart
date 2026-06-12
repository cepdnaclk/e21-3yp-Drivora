import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wifi_sensor_service.dart';

// ─── PALETTE ─────────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF060810);
const _kSurface = Color(0xFF0C0F1A);
const _kBorder  = Color(0xFF1C2236);
const _kCyan    = Color(0xFF00E5FF);
const _kBlue    = Color(0xFF2979FF);
const _kGreen   = Color(0xFF00E676);
const _kAmber   = Color(0xFFFFAB00);
const _kRed     = Color(0xFFFF1744);
const _kPurple  = Color(0xFFAA00FF);

// Steps: 0=connect, 1=vehicle-profile, 2=dimensions,
//        3=front-preset, 4=rear-preset, 5=sound, 6=calibrate
const int _kTotalSetupSteps = 6;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  bool _saving = false;
  String? _error;

  // ── Connect step (step 0) ─────────────────────────────────────────────────
  final _newSsidCtrl    = TextEditingController(text: 'ADASBrain');
  final _newPassCtrl    = TextEditingController(text: '12345678');
  final _confirmPassCtrl = TextEditingController();
  bool _wifiChangeSent  = false;

  // ── Vehicle profile (step 2) ──────────────────────────────────────────────
  int _vehicleTypeCode = 3; // 1=compact, 2=passenger, 3=SUV/tall
  int _loadCondition   = 1; // 0=light, 1=normal, 2=heavy

  // ── Dimensions (step 3) ───────────────────────────────────────────────────
  final _twCtrl = TextEditingController(text: '1.56');
  final _wbCtrl = TextEditingController(text: '2.67');
  final _vhCtrl = TextEditingController(text: '1.57');
  bool _vehicleSent = false;

  // ── Sensitivity presets (steps 4 & 5) ────────────────────────────────────
  int _frontPreset = 1; // 0=near, 1=normal, 2=far
  bool _frontSent  = false;
  int _rearPreset  = 1;
  bool _rearSent   = false;

  // ── Sound settings (step 6) ───────────────────────────────────────────────
  // Index: 0=front, 1=rear, 2=lane, 3=lean
  // Defaults from main.cpp: front→0, rear→1, lane→2, lean→3
  final List<int> _soundPatterns = [0, 1, 2, 3];
  final List<int> _soundVolumes  = [100, 100, 100, 100];
  bool _soundSent = false;

  // ── Calibration (step 7) ─────────────────────────────────────────────────
  bool _calSent = false;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _newSsidCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _twCtrl.dispose();
    _wbCtrl.dispose();
    _vhCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    _fadeCtrl.reverse().then((_) {
      setState(() { _step++; _error = null; _saving = false; });
      _fadeCtrl.forward();
    });
  }

  // ── STEP 0: Connect ───────────────────────────────────────────────────────
  void _connectToHub(BuildContext ctx) {
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    unawaited(svc.connectToHardwareHub('10.42.0.1'));
    setState(() => _error = null);
  }

  Future<void> _sendWifiChange(BuildContext ctx) async {
    final ssid    = _newSsidCtrl.text.trim();
    final pass    = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (ssid.isEmpty) {
      setState(() => _error = 'SSID cannot be empty.'); return;
    }
    if (pass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.'); return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.'); return;
    }
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    setState(() { _saving = true; _error = null; });
    final sent = await svc.sendWifiSetupToHardware(ssid: ssid, password: pass);
    setState(() { _saving = false; _wifiChangeSent = sent; });
    if (!sent) setState(() => _error = 'Not connected — connect to ADAS Brain first.');
  }

  // ── STEP 3: Dimensions → saveVehicle ─────────────────────────────────────
  Future<void> _sendVehicle(BuildContext ctx) async {
    final tw = double.tryParse(_twCtrl.text) ?? 1.56;
    final wb = double.tryParse(_wbCtrl.text) ?? 2.67;
    final vh = double.tryParse(_vhCtrl.text) ?? 1.57;
    setState(() { _saving = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('vWidth', tw);
    await prefs.setDouble('wheelBase', wb);
    await prefs.setDouble('vHeight', vh);
    await prefs.setInt('vehicleTypeCode', _vehicleTypeCode);
    await prefs.setInt('loadCondition', _loadCondition);

    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    var sent = false;
    if (svc.isConnected) {
      sent = await svc.sendVehicleToHardware(
        vehicleType:    _vehicleTypeCode,
        loadCondition:  _loadCondition,
        trackWidthM:    tw,
        wheelBaseM:     wb,
        vehicleHeightM: vh,
      );
    }
    // Mark success whether sent to HW or saved locally when not connected
    setState(() { _saving = false; _vehicleSent = sent || !svc.isConnected; });
    if (!sent && svc.isConnected) {
      setState(() => _error = 'Failed to send. Tap to retry.');
    }
  }

  // ── STEP 4: Front preset ──────────────────────────────────────────────────
  Future<void> _sendFrontPreset(BuildContext ctx) async {
    setState(() { _saving = true; _error = null; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('frontPreset', _frontPreset);
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    var sent = false;
    if (svc.isConnected) sent = await svc.sendFrontPresetToHardware(_frontPreset);
    setState(() { _saving = false; _frontSent = sent || !svc.isConnected; });
    if (!sent && svc.isConnected) setState(() => _error = 'Failed to send.');
  }

  // ── STEP 5: Rear preset ───────────────────────────────────────────────────
  Future<void> _sendRearPreset(BuildContext ctx) async {
    setState(() { _saving = true; _error = null; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rearPreset', _rearPreset);
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    var sent = false;
    if (svc.isConnected) sent = await svc.sendRearPresetToHardware(_rearPreset);
    setState(() { _saving = false; _rearSent = sent || !svc.isConnected; });
    if (!sent && svc.isConnected) setState(() => _error = 'Failed to send.');
  }

  // ── STEP 6: Sound settings ────────────────────────────────────────────────
  // Auto-swap patterns so all 4 remain unique when user picks a new one.
  void _setSoundPattern(int unitIdx, int newPattern) {
    final existingIdx = _soundPatterns.indexOf(newPattern);
    if (existingIdx != -1 && existingIdx != unitIdx) {
      final prev = _soundPatterns[unitIdx];
      setState(() {
        _soundPatterns[existingIdx] = prev;
        _soundPatterns[unitIdx]     = newPattern;
        _soundSent = false;
      });
    } else {
      setState(() { _soundPatterns[unitIdx] = newPattern; _soundSent = false; });
    }
  }

  Future<void> _sendSoundSettings(BuildContext ctx) async {
    setState(() { _saving = true; _error = null; });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('soundPatterns', _soundPatterns.join(','));
    await prefs.setString('soundVolumes',  _soundVolumes.join(','));
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    var sent = false;
    if (svc.isConnected) {
      sent = await svc.sendSoundSettingsToHardware(
        frontPattern: _soundPatterns[0], rearPattern: _soundPatterns[1],
        lanePattern:  _soundPatterns[2], leanPattern: _soundPatterns[3],
        frontVolume:  _soundVolumes[0],  rearVolume:  _soundVolumes[1],
        laneVolume:   _soundVolumes[2],  leanVolume:  _soundVolumes[3],
      );
    }
    setState(() { _saving = false; _soundSent = sent || !svc.isConnected; });
    if (!sent && svc.isConnected) setState(() => _error = 'Failed to send.');
  }

  // ── STEP 7: Center calibration ────────────────────────────────────────────
  Future<void> _sendCenterCal(BuildContext ctx) async {
    setState(() { _saving = true; _error = null; });
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(ctx, listen: false);
    if (svc.isConnected) {
      await svc.sendCenterCalibration();
      await Future.delayed(const Duration(seconds: 2));
    }
    setState(() { _saving = false; _calSent = true; });
  }

  Future<void> _finishSetup(BuildContext ctx) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setupComplete', true);
    if (!mounted) return;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const _CompletionDialog(),
    );
    if (!mounted) return;
    unawaited(Navigator.of(ctx).pushReplacementNamed('/dashboard'));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    body: SafeArea(
      child: Column(children: [
        _buildTopBar(),
        Expanded(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: _buildStepContent(context),
            ),
          ),
        ),
        _PhaseIndicator(step: _step),
      ]),
    ),
  );

  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: const BoxDecoration(
      color: _kSurface,
      border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ShaderMask(
        shaderCallback: (r) =>
            const LinearGradient(colors: [_kCyan, _kBlue]).createShader(r),
        child: Text('DRIVORA SETUP',
            style: GoogleFonts.orbitron(
                color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      const SizedBox(height: 12),
      _StepProgressBar(step: _step, total: _kTotalSetupSteps),
    ]),
  );

  Widget _buildStepContent(BuildContext ctx) {
    switch (_step) {
      case 0: return _buildConnectStep(ctx);
      case 1: return _buildVehicleProfileStep(ctx);
      case 2: return _buildDimensionsStep(ctx);
      case 3: return _buildFrontPresetStep(ctx);
      case 4: return _buildRearPresetStep(ctx);
      case 5: return _buildSoundStep(ctx);
      case 6: return _buildCalibrateStep(ctx);
      default: return const SizedBox.shrink();
    }
  }

  // ────────────────── STEP 0: CONNECT ──────────────────────────────────────
  Widget _buildConnectStep(BuildContext ctx) =>
      Consumer<WiFiSensorService>(builder: (_, svc, __) {
        final connected = svc.isConnected;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          const _StepTitle('CONNECT TO ADAS BRAIN',
              'Connect your phone to the "ADASBrain" hotspot, then set your WiFi credentials.'),
          const SizedBox(height: 16),

          // ── Connection status + connect button ────────────────────────────
          _StatusBadge(
            connected: connected,
            label: connected ? 'ADAS Brain Connected!' : svc.status,
          ),
          const SizedBox(height: 10),
          if (!connected)
            _PrimaryBtn(
              label: 'CONNECT TO ADAS BRAIN',
              icon: Icons.link_rounded,
              onTap: () { HapticFeedback.mediumImpact(); _connectToHub(ctx); },
            ),

          const SizedBox(height: 20),

          // ── WiFi credentials form ─────────────────────────────────────────
          Text('NEW WIFI CREDENTIALS',
              style: GoogleFonts.rajdhani(
                  color: Colors.white38, fontSize: 10,
                  fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 10),

          _CompactField('New WiFi SSID', _newSsidCtrl, Icons.wifi_tethering),
          const SizedBox(height: 10),
          _CompactField('New WiFi Password (min 8 chars)', _newPassCtrl,
              Icons.lock_outline, obscure: true),
          const SizedBox(height: 10),
          _CompactField('Confirm Password', _confirmPassCtrl,
              Icons.lock_reset_rounded, obscure: true),
          const SizedBox(height: 16),

          // ── Error / success feedback ──────────────────────────────────────
          if (_error != null) ...[_ErrorBox(_error!), const SizedBox(height: 10)],

          if (_wifiChangeSent) ...[
            const _SuccessBadge(
                'WiFi config sent! ADAS Brain is restarting.\n'
                'Reconnect your phone to the new SSID, then tap Reconnect below.'),
            const SizedBox(height: 12),
            _PrimaryBtn(
              label: 'RECONNECT TO NEW NETWORK',
              icon: Icons.wifi_rounded,
              onTap: () {
                setState(() => _wifiChangeSent = false);
                _connectToHub(ctx);
              },
            ),
          ] else ...[
            _SendBtn(
              saving: _saving,
              label: 'SAVE & RECONNECT',
              icon: Icons.send_rounded,
              onTap: connected ? () => _sendWifiChange(ctx) : null,
            ),
          ],

          const SizedBox(height: 12),
          _SecondaryBtn(
            label: connected ? 'SKIP  →' : 'SKIP (CONNECT LATER)',
            onTap: _nextStep,
          ),
          const SizedBox(height: 8),
        ]);
      });

  // ────────────────── STEP 2: VEHICLE PROFILE ──────────────────────────────
  Widget _buildVehicleProfileStep(BuildContext ctx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 24),
      const _StepTitle('VEHICLE PROFILE',
          'Select your vehicle type and current load condition.'),
      const SizedBox(height: 24),

      const _SectionHeader('VEHICLE TYPE'),
      const SizedBox(height: 12),
      _SegmentedPicker(
        labels: const ['Compact', 'Passenger', 'SUV / Tall'],
        selected: _vehicleTypeCode - 1,
        onTap: (i) => setState(() => _vehicleTypeCode = i + 1),
      ),
      const SizedBox(height: 6),
      _VehicleTypeHint(_vehicleTypeCode),
      const SizedBox(height: 24),

      const _SectionHeader('LOAD CONDITION'),
      const SizedBox(height: 12),
      _SegmentedPicker(
        labels: const ['Light', 'Normal', 'Heavy'],
        selected: _loadCondition,
        onTap: (i) => setState(() => _loadCondition = i),
      ),
      const SizedBox(height: 6),
      _LoadHint(_loadCondition),
      const SizedBox(height: 32),

      _PrimaryBtn(
        label: 'NEXT: ENTER DIMENSIONS',
        icon: Icons.arrow_forward_rounded,
        onTap: _nextStep,
      ),
    ],
  );

  // ────────────────── STEP 3: DIMENSIONS ───────────────────────────────────
  Widget _buildDimensionsStep(BuildContext ctx) =>
      Consumer<WiFiSensorService>(builder: (_, svc, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const _StepTitle('VEHICLE DIMENSIONS',
              'Enter dimensions in metres. These calibrate distance thresholds.'),
          const SizedBox(height: 24),
          if (_error != null) ...[_ErrorBox(_error!), const SizedBox(height: 8)],

          Row(children: [
            Expanded(child: _NumField('Track Width (m)', _twCtrl, '1.56')),
            const SizedBox(width: 12),
            Expanded(child: _NumField('Wheel Base (m)', _wbCtrl, '2.67')),
          ]),
          const SizedBox(height: 12),
          _NumField('Vehicle Height (m)', _vhCtrl, '1.57'),
          const SizedBox(height: 20),

          _NotConnectedWarning(svc.isConnected),

          if (_vehicleSent) ...[
            _SuccessBadge(svc.isConnected
                ? 'Vehicle dimensions sent to ADAS Brain.'
                : 'Vehicle dimensions saved locally.'),
            const SizedBox(height: 12),
            _PrimaryBtn(
                label: 'NEXT: FRONT SENSITIVITY →',
                icon: Icons.arrow_forward_rounded,
                onTap: _nextStep),
          ] else ...[
            _SendBtn(saving: _saving, label: 'SEND TO ADAS BRAIN',
                onTap: () => _sendVehicle(ctx)),
            const SizedBox(height: 12),
            _SecondaryBtn(label: 'SKIP THIS STEP', onTap: _nextStep),
          ],
        ],
      ));

  // ────────────────── STEP 4: FRONT SENSITIVITY ────────────────────────────
  Widget _buildFrontPresetStep(BuildContext ctx) =>
      Consumer<WiFiSensorService>(builder: (_, svc, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const _StepTitle('FRONT SENSOR SENSITIVITY',
              'Sets how close objects must be before front collision warnings trigger.'),
          const SizedBox(height: 24),

          _SegmentedPicker(
            labels: const ['Near', 'Normal', 'Far'],
            selected: _frontPreset,
            onTap: (i) => setState(() { _frontPreset = i; _frontSent = false; }),
          ),
          const SizedBox(height: 6),
          _PresetHint(_frontPreset),
          const SizedBox(height: 20),

          _NotConnectedWarning(svc.isConnected),

          if (_frontSent) ...[
            _SuccessBadge(svc.isConnected
                ? 'Front sensitivity sent to ADAS Brain.'
                : 'Front sensitivity saved locally.'),
            const SizedBox(height: 12),
            _PrimaryBtn(label: 'NEXT: REAR SENSITIVITY →',
                icon: Icons.arrow_forward_rounded, onTap: _nextStep),
          ] else ...[
            _SendBtn(saving: _saving, label: 'SEND TO ADAS BRAIN',
                onTap: () => _sendFrontPreset(ctx)),
            const SizedBox(height: 12),
            _SecondaryBtn(label: 'SKIP THIS STEP', onTap: _nextStep),
          ],
        ],
      ));

  // ────────────────── STEP 5: REAR SENSITIVITY ─────────────────────────────
  Widget _buildRearPresetStep(BuildContext ctx) =>
      Consumer<WiFiSensorService>(builder: (_, svc, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const _StepTitle('REAR SENSOR SENSITIVITY',
              'Sets the detection range for the 4 rear blind-spot sensors.'),
          const SizedBox(height: 24),

          _SegmentedPicker(
            labels: const ['Near', 'Normal', 'Far'],
            selected: _rearPreset,
            onTap: (i) => setState(() { _rearPreset = i; _rearSent = false; }),
          ),
          const SizedBox(height: 6),
          _PresetHint(_rearPreset),
          const SizedBox(height: 20),

          _NotConnectedWarning(svc.isConnected),

          if (_rearSent) ...[
            _SuccessBadge(svc.isConnected
                ? 'Rear sensitivity sent to ADAS Brain.'
                : 'Rear sensitivity saved locally.'),
            const SizedBox(height: 12),
            _PrimaryBtn(label: 'NEXT: SOUND SETTINGS →',
                icon: Icons.arrow_forward_rounded, onTap: _nextStep),
          ] else ...[
            _SendBtn(saving: _saving, label: 'SEND TO ADAS BRAIN',
                onTap: () => _sendRearPreset(ctx)),
            const SizedBox(height: 12),
            _SecondaryBtn(label: 'SKIP THIS STEP', onTap: _nextStep),
          ],
        ],
      ));

  // ────────────────── STEP 6: SOUND SETTINGS ───────────────────────────────
  Widget _buildSoundStep(BuildContext ctx) {
    const patternNames = [
      'Urgent Triple Pulse',
      'Wide Double Pulse',
      'Quick Double Tap',
      'Two-Tone Stability',
    ];
    const unitNames  = ['FRONT COLLISION', 'REAR BLINDSPOT', 'LANE DEPARTURE', 'LEAN / CENTER'];
    const unitIcons  = [
      Icons.arrow_upward_rounded, Icons.arrow_downward_rounded,
      Icons.swap_horiz_rounded, Icons.rotate_right_rounded,
    ];
    const unitColors = [_kRed, _kAmber, _kBlue, _kPurple];

    return Consumer<WiFiSensorService>(builder: (_, svc, __) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const _StepTitle('BUZZER SOUND SETTINGS',
            'Assign a unique pattern and volume level for each alert unit.'),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.info_outline_rounded, color: _kAmber, size: 14),
          const SizedBox(width: 6),
          Text('Patterns auto-swap to stay unique.',
              style: GoogleFonts.rajdhani(color: _kAmber, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 20),

        // One card per alert unit
        for (int i = 0; i < 4; i++) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: unitColors[i].withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Icon(unitIcons[i], color: unitColors[i], size: 18),
                const SizedBox(width: 8),
                Text(unitNames[i], style: GoogleFonts.orbitron(
                    color: unitColors[i], fontSize: 11,
                    fontWeight: FontWeight.w900, letterSpacing: 1)),
                const Spacer(),
                // Test button
                GestureDetector(
                  onTap: () => svc.testSoundOnHardware(_soundPatterns[i], _soundVolumes[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: unitColors[i].withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: unitColors[i].withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.volume_up_rounded, color: unitColors[i], size: 14),
                      const SizedBox(width: 4),
                      Text('TEST', style: GoogleFonts.rajdhani(
                          color: unitColors[i], fontSize: 11, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // Pattern picker
              Text('PATTERN', style: GoogleFonts.rajdhani(
                  color: Colors.white30, fontSize: 10,
                  letterSpacing: 1.5, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: DropdownButton<int>(
                  value: _soundPatterns[i],
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: _kSurface,
                  style: GoogleFonts.rajdhani(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w700),
                  icon: const Icon(Icons.keyboard_arrow_down, color: _kCyan, size: 18),
                  items: List.generate(4, (p) => DropdownMenuItem<int>(
                    value: p,
                    child: Text('${p + 1}. ${patternNames[p]}'),
                  )),
                  onChanged: (p) { if (p != null) _setSoundPattern(i, p); },
                ),
              ),
              const SizedBox(height: 12),

              // Volume
              Row(children: [
                Text('VOLUME', style: GoogleFonts.rajdhani(
                    color: Colors.white30, fontSize: 10,
                    letterSpacing: 1.5, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${_soundVolumes[i]}%', style: GoogleFonts.orbitron(
                    color: unitColors[i], fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
              SliderTheme(
                data: SliderTheme.of(ctx).copyWith(
                  activeTrackColor: unitColors[i],
                  thumbColor: unitColors[i],
                  inactiveTrackColor: _kBorder,
                  overlayColor: unitColors[i].withOpacity(0.15),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _soundVolumes[i].toDouble(),
                  min: 30, max: 100, divisions: 14,
                  onChanged: (v) =>
                      setState(() { _soundVolumes[i] = v.round(); _soundSent = false; }),
                ),
              ),
            ]),
          ),
        ],

        _NotConnectedWarning(svc.isConnected),

        if (_soundSent) ...[
          _SuccessBadge(svc.isConnected
              ? 'Sound settings sent to ADAS Brain.'
              : 'Sound settings saved locally.'),
          const SizedBox(height: 12),
          _PrimaryBtn(label: 'NEXT: CALIBRATE →',
              icon: Icons.arrow_forward_rounded, onTap: _nextStep),
        ] else ...[
          _SendBtn(saving: _saving, label: 'SEND SOUND SETTINGS',
              onTap: () => _sendSoundSettings(ctx)),
          const SizedBox(height: 12),
          _SecondaryBtn(label: 'SKIP THIS STEP', onTap: _nextStep),
        ],
      ],
    ));
  }

  // ────────────────── STEP 7: CENTER CALIBRATION ───────────────────────────
  Widget _buildCalibrateStep(BuildContext ctx) =>
      Consumer<WiFiSensorService>(builder: (_, svc, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const _StepTitle('CENTER IMU CALIBRATION',
              'Park on a level surface and press Calibrate to set the neutral lean reference.'),
          const SizedBox(height: 24),

          _InfoCard(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, color: _kCyan, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Before calibrating:', style: GoogleFonts.rajdhani(
                    color: _kCyan, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '• Park vehicle on flat, level ground\n'
                  '• Engine off, vehicle stationary\n'
                  '• ADAS Brain must be connected',
                  style: GoogleFonts.rajdhani(
                      color: Colors.white60, fontSize: 12, height: 1.5)),
              ])),
            ]),
          ]),
          const SizedBox(height: 20),

          _NotConnectedWarning(svc.isConnected),

          if (_calSent) ...[
            const _SuccessBadge('Center calibration complete!'),
            const SizedBox(height: 20),
            _PrimaryBtn(
              label: 'FINISH SETUP',
              icon: Icons.check_circle_rounded,
              color: _kGreen,
              onTap: () => _finishSetup(ctx),
            ),
          ] else ...[
            _SendBtn(
              saving: _saving,
              label: _saving ? 'CALIBRATING...' : 'CALIBRATE CENTER UNIT',
              icon: Icons.gps_fixed_rounded,
              onTap: svc.isConnected ? () => _sendCenterCal(ctx) : null,
            ),
            const SizedBox(height: 12),
            _SecondaryBtn(label: 'SKIP (CALIBRATE LATER)',
                onTap: () => _finishSetup(ctx)),
          ],
        ],
      ));
}

// ─── STEP PROGRESS BAR ───────────────────────────────────────────────────────

class _StepProgressBar extends StatelessWidget {
  const _StepProgressBar({required this.step, required this.total});
  final int step, total;

  static const _stepLabels = [
    'CONNECT', 'VEHICLE', 'DIMENSIONS',
    'FRONT', 'REAR', 'SOUND', 'CALIBRATE',
  ];

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / (total + 1);
    final label = step < _stepLabels.length ? _stepLabels[step] : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('STEP $step / $total',
            style: GoogleFonts.rajdhani(
                color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Text('─  $label',
            style: GoogleFonts.rajdhani(
                color: _kCyan, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: _kBorder,
          valueColor: const AlwaysStoppedAnimation<Color>(_kCyan),
          minHeight: 3,
        ),
      ),
    ]);
  }
}

// ─── REUSABLE WIDGETS ─────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  const _StepTitle(this.title, this.subtitle);
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: GoogleFonts.orbitron(
        color: _kCyan, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
    const SizedBox(height: 8),
    Text(subtitle, style: GoogleFonts.rajdhani(
        color: Colors.white54, fontSize: 13, height: 1.4)),
  ]);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.rajdhani(
          color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kCyan.withOpacity(0.25), width: 1.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.connected, required this.label});
  final bool connected;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: (connected ? _kGreen : _kAmber).withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: (connected ? _kGreen : _kAmber).withOpacity(0.4)),
    ),
    child: Row(children: [
      Icon(connected ? Icons.check_circle_rounded : Icons.wifi_find_rounded,
          color: connected ? _kGreen : _kAmber, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.rajdhani(
          color: connected ? _kGreen : _kAmber,
          fontSize: 13, fontWeight: FontWeight.w800))),
    ]),
  );
}

// ─── PHASE INDICATOR ──────────────────────────────────────────────────────────
// "01 Register | 02 Connect | 03 Setup" — shown at the bottom of all steps.

class _PhaseIndicator extends StatelessWidget {
  const _PhaseIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    // step 0 = Connect phase; steps 1-6 = Setup phase
    final activePhase = step == 0 ? 1 : 2; // 0=Register(done), 1=Connect, 2=Setup

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PhaseChip(label: '01  Register', index: 0, active: activePhase == 0, done: true),
          _PhaseDivider(),
          _PhaseChip(label: '02  Connect',  index: 1, active: activePhase == 1, done: activePhase > 1),
          _PhaseDivider(),
          _PhaseChip(label: '03  Setup',    index: 2, active: activePhase == 2, done: false),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.index,
      required this.active, required this.done});
  final String label;
  final int    index;
  final bool   active, done;

  @override
  Widget build(BuildContext context) {
    final color = active ? _kCyan : done ? _kGreen : Colors.white24;
    return Text(label,
        style: GoogleFonts.rajdhani(
            color: color, fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.5));
  }
}

class _PhaseDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text('|',
        style: GoogleFonts.rajdhani(
            color: Colors.white12, fontSize: 14)),
  );
}

class _CompactField extends StatelessWidget {
  const _CompactField(this.hint, this.ctrl, this.icon, {this.obscure = false});
  final String hint;
  final TextEditingController ctrl;
  final IconData icon;
  final bool obscure;
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.rajdhani(color: Colors.white24, fontSize: 13),
      prefixIcon: Icon(icon, color: _kCyan.withOpacity(0.7), size: 18),
      filled: true, fillColor: _kBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kCyan, width: 1.5)),
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
          color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
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

class _SegmentedPicker extends StatelessWidget {
  const _SegmentedPicker(
      {required this.labels, required this.selected, required this.onTap});
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
              border: Border.all(
                  color: active ? _kCyan : _kBorder, width: active ? 1.5 : 1),
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

class _VehicleTypeHint extends StatelessWidget {
  const _VehicleTypeHint(this.code);
  final int code;
  static const _hints = [
    'Short wheelbase, low center of gravity. (e.g. Suzuki Alto, Wagon R)',
    'Standard sedan or hatchback. (e.g. Toyota Vitz, Honda Civic)',
    'Tall or high-COG vehicle. (e.g. SUV, Van, Pickup)',
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, left: 4),
    child: Text(_hints[(code - 1).clamp(0, 2)],
        style: GoogleFonts.rajdhani(color: Colors.white30, fontSize: 11, height: 1.3)),
  );
}

class _LoadHint extends StatelessWidget {
  const _LoadHint(this.load);
  final int load;
  static const _hints = [
    'Driver only or very little cargo.',
    'Normal occupancy with moderate cargo.',
    'Full load or maximum cargo weight.',
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, left: 4),
    child: Text(_hints[load.clamp(0, 2)],
        style: GoogleFonts.rajdhani(color: Colors.white30, fontSize: 11, height: 1.3)),
  );
}

class _PresetHint extends StatelessWidget {
  const _PresetHint(this.preset);
  final int preset;
  static const _hints = [
    'Near – Warns at short range. Best for city / tight spaces.',
    'Normal – Balanced warning distance for everyday driving.',
    'Far – Warns early. Best for highway / high-speed driving.',
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, left: 4),
    child: Text(_hints[preset.clamp(0, 2)],
        style: GoogleFonts.rajdhani(color: Colors.white30, fontSize: 11, height: 1.3)),
  );
}

class _NotConnectedWarning extends StatelessWidget {
  const _NotConnectedWarning(this.connected);
  final bool connected;
  @override
  Widget build(BuildContext context) {
    if (connected) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _kAmber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kAmber.withOpacity(0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: _kAmber, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'Not connected to ADAS Brain — settings will be saved locally only.',
            style: GoogleFonts.rajdhani(color: _kAmber, fontSize: 12),
          )),
        ]),
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: _kGreen.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kGreen.withOpacity(0.4)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.check_circle_rounded, color: _kGreen, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: GoogleFonts.rajdhani(color: _kGreen, fontSize: 13, height: 1.4))),
    ]),
  );
}

class _SendBtn extends StatelessWidget {
  const _SendBtn({required this.saving, required this.label, this.icon, this.onTap});
  final bool saving;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: saving ? null : onTap,
    child: Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: (onTap != null && !saving)
              ? [const Color(0xFF2979FF), const Color(0xFF00B0FF)]
              : [Colors.white12, Colors.white12],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: (onTap != null && !saving)
            ? [BoxShadow(color: _kBlue.withOpacity(0.4), blurRadius: 16,
                offset: const Offset(0, 5))]
            : [],
      ),
      alignment: Alignment.center,
      child: saving
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
              Text(label, style: GoogleFonts.orbitron(
                  color: Colors.white, fontSize: 12,
                  fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ]),
    ),
  );
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, this.icon, this.onTap, this.color});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c1 = color ?? const Color(0xFF2979FF);
    final c2 = color != null ? color!.withOpacity(0.65) : const Color(0xFF00B0FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: onTap != null ? [c1, c2] : [Colors.white12, Colors.white12]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null
              ? [BoxShadow(color: c1.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))]
              : [],
        ),
        alignment: Alignment.center,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
          Text(label, style: GoogleFonts.orbitron(
              color: Colors.white, fontSize: 13,
              fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ]),
      ),
    );
  }
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
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: _kRed.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kRed.withOpacity(0.4)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: _kRed, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: GoogleFonts.rajdhani(color: _kRed, fontSize: 13))),
    ]),
  );
}

// ─── COMPLETION DIALOG ────────────────────────────────────────────────────────

class _CompletionDialog extends StatelessWidget {
  const _CompletionDialog();
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
                color: _kGreen, fontSize: 18,
                fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Text(
          'ADAS Brain configured and ready.\nAll systems are active.',
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
                    color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ]),
    ),
  );
}
