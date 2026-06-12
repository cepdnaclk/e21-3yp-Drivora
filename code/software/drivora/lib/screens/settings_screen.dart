import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_service.dart';
import '../services/wifi_sensor_service.dart';
import '../theme/app_theme.dart';

// ─── section indices ──────────────────────────────────────────────────────────
const _kAccount      = 0;
const _kVehicle      = 1;
const _kSensitivity  = 2;
const _kSound        = 3;
const _kConnectivity = 4;
const _kWizard       = 5;
const _kReset        = 6;

const _kPatternNames = [
  'Urgent Triple Pulse',
  'Wide Double Pulse',
  'Quick Double Tap',
  'Two Tone Stability',
];

// ─── palette shortcuts ────────────────────────────────────────────────────────
const _kBg      = AppTheme.background;
const _kPanel   = AppTheme.panel;
const _kBlue    = AppTheme.accentBlue;
const _kCyan    = AppTheme.accentCyan;
const _kRed     = AppTheme.accentRed;
const _kPrimary = AppTheme.textPrimary;
const _kSecond  = AppTheme.textSecondary;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int     _section = _kAccount;
  bool    _saving  = false;
  String? _error;
  String? _success;

  // ── Account ────────────────────────────────────────────────────────────────
  final _nameCtrl         = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  String _vehicleCategory = 'Sedan';
  String _userEmail       = '';
  final _currentPassCtrl  = TextEditingController();
  final _newPassCtrl      = TextEditingController();
  final _confirmPassCtrl  = TextEditingController();
  bool _obscureCur  = true;
  bool _obscureNew  = true;
  bool _obscureCon  = true;

  // ── Vehicle Profile ────────────────────────────────────────────────────────
  int _vehicleType   = 2;   // 1 compact, 2 passenger, 3 tall/SUV
  int _loadCondition = 1;   // 0 light, 1 normal, 2 heavy
  final _trackWidthCtrl    = TextEditingController();
  final _wheelbaseCtrl     = TextEditingController();
  final _vehicleHeightCtrl = TextEditingController();

  // ── Sensitivity ────────────────────────────────────────────────────────────
  int _frontPreset = 1;   // 0 near, 1 normal, 2 far
  int _rearPreset  = 1;

  // ── Sound ──────────────────────────────────────────────────────────────────
  bool _audioEnabled = true;
  int  _frontPattern = 0;
  int  _rearPattern  = 1;
  int  _lanePattern  = 2;   // Camera/Lane unit
  int  _leanPattern  = 3;   // Stability/Lean unit
  int  _frontVolume  = 80;
  int  _rearVolume   = 30;
  int  _laneVolume   = 30;
  int  _leanVolume   = 30;

  // ── Connectivity ──────────────────────────────────────────────────────────
  final _ssidCtrl           = TextEditingController();
  final _wifiNewPassCtrl    = TextEditingController();
  final _wifiConfirmPassCtrl = TextEditingController();
  bool _obscureWifiNew  = true;
  bool _obscureWifiCon  = true;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _vehicleModelCtrl, _currentPassCtrl, _newPassCtrl,
      _confirmPassCtrl, _trackWidthCtrl, _wheelbaseCtrl, _vehicleHeightCtrl,
      _ssidCtrl, _wifiNewPassCtrl, _wifiConfirmPassCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadAll() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text          = p.getString('userName')        ?? '';
      _vehicleModelCtrl.text  = p.getString('vehicleModel')    ?? '';
      _vehicleCategory        = p.getString('vehicleCategory') ?? 'Sedan';
      _userEmail              = p.getString('userEmail')       ?? '';

      _vehicleType   = p.getInt('vehicleType')    ?? 2;
      _loadCondition = p.getInt('loadCondition')  ?? 1;
      _trackWidthCtrl.text    = (p.getDouble('trackWidth_m')    ?? 1.56).toStringAsFixed(2);
      _wheelbaseCtrl.text     = (p.getDouble('wheelBase_m')     ?? 2.67).toStringAsFixed(2);
      _vehicleHeightCtrl.text = (p.getDouble('vehicleHeight_m') ?? 1.57).toStringAsFixed(2);

      _frontPreset = p.getInt('frontPreset') ?? 1;
      _rearPreset  = p.getInt('rearPreset')  ?? 1;

      _audioEnabled = p.getBool('audioEnabled') ?? true;
      _frontPattern = p.getInt('frontPattern')  ?? 0;
      _rearPattern  = p.getInt('rearPattern')   ?? 1;
      _lanePattern  = p.getInt('lanePattern')   ?? 2;
      _leanPattern  = p.getInt('leanPattern')   ?? 3;
      _frontVolume  = p.getInt('frontVolume')   ?? 80;
      _rearVolume   = p.getInt('rearVolume')    ?? 30;
      _laneVolume   = p.getInt('laneVolume')    ?? 30;
      _leanVolume   = p.getInt('leanVolume')    ?? 30;

      _ssidCtrl.text = p.getString('wifiSsid') ?? 'ADASBrain';
    });
  }

  void _switchSection(int s) => setState(() {
    _section = s;
    _error   = null;
    _success = null;
  });

  void _msg({String? error, String? success}) {
    setState(() { _error = error; _success = success; });
    if (success != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _success = null);
      });
    }
  }

  // ── Saves ──────────────────────────────────────────────────────────────────

  Future<void> _saveAccount() async {
    final name  = _nameCtrl.text.trim();
    final model = _vehicleModelCtrl.text.trim();
    if (name.isEmpty)  { _msg(error: 'Full name is required.');      return; }
    if (model.isEmpty) { _msg(error: 'Vehicle model is required.'); return; }

    // Password change only if current-pass field is filled
    final curPass = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final conPass = _confirmPassCtrl.text;
    final changingPass = curPass.isNotEmpty || newPass.isNotEmpty || conPass.isNotEmpty;
    if (changingPass) {
      if (curPass.isEmpty)       { _msg(error: 'Enter your current password.');         return; }
      if (newPass.length < 6)    { _msg(error: 'New password must be ≥ 6 characters.'); return; }
      if (newPass != conPass)    { _msg(error: 'Passwords do not match.');              return; }
    }

    setState(() => _saving = true);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('userName',        name);
      await p.setString('vehicleModel',    model);
      await p.setString('vehicleCategory', _vehicleCategory);

      await CloudService().updateUserProfile(
        name: name, vehicleModel: model,
        vehicleCategory: _vehicleCategory, email: _userEmail,
      );

      if (changingPass) {
        final user = FirebaseAuth.instance.currentUser!;
        final cred = EmailAuthProvider.credential(email: user.email!, password: curPass);
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newPass);
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
      _msg(success: 'Account details saved.');
    } on FirebaseAuthException catch (e) {
      _msg(error: e.code == 'wrong-password'
          ? 'Current password is incorrect.' : 'Auth error: ${e.message}');
    } catch (e) {
      _msg(error: 'Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveVehicleProfile() async {
    final tw = double.tryParse(_trackWidthCtrl.text);
    final wb = double.tryParse(_wheelbaseCtrl.text);
    final vh = double.tryParse(_vehicleHeightCtrl.text);
    if (tw == null || wb == null || vh == null) {
      _msg(error: 'Enter valid numeric values.'); return;
    }
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setInt('vehicleType',       _vehicleType);
    await p.setInt('loadCondition',     _loadCondition);
    await p.setDouble('trackWidth_m',    tw);
    await p.setDouble('wheelBase_m',     wb);
    await p.setDouble('vehicleHeight_m', vh);
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    final sent = await svc.sendVehicleToHardware(
      vehicleType: _vehicleType, loadCondition: _loadCondition,
      trackWidthM: tw, wheelBaseM: wb, vehicleHeightM: vh,
    );
    if (mounted) setState(() => _saving = false);
    _msg(success: sent
        ? 'Vehicle profile saved & sent to hardware.'
        : 'Saved locally (hardware not connected).');
  }

  Future<void> _saveSensitivity() async {
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setInt('frontPreset', _frontPreset);
    await p.setInt('rearPreset',  _rearPreset);
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    await svc.sendFrontPresetToHardware(_frontPreset);
    await svc.sendRearPresetToHardware(_rearPreset);
    if (mounted) setState(() => _saving = false);
    _msg(success: 'Sensitivity settings sent to hardware.');
  }

  Future<void> _calibrate() async {
    setState(() => _saving = true);
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    final sent = await svc.sendCenterCalibration();
    if (mounted) setState(() => _saving = false);
    _msg(success: sent
        ? 'Calibration command sent. Keep vehicle stationary.'
        : 'Not connected to hardware.');
  }

  Future<void> _saveSound() async {
    final patterns = [_frontPattern, _rearPattern, _lanePattern, _leanPattern];
    if (patterns.toSet().length != 4) {
      _msg(error: 'Each unit must use a different sound pattern.'); return;
    }
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setBool('audioEnabled', _audioEnabled);
    await p.setInt('frontPattern',  _frontPattern);
    await p.setInt('rearPattern',   _rearPattern);
    await p.setInt('lanePattern',   _lanePattern);
    await p.setInt('leanPattern',   _leanPattern);
    await p.setInt('frontVolume',   _frontVolume);
    await p.setInt('rearVolume',    _rearVolume);
    await p.setInt('laneVolume',    _laneVolume);
    await p.setInt('leanVolume',    _leanVolume);
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    svc.setAudioEnabled(_audioEnabled);
    await svc.sendSoundSettingsToHardware(
      frontPattern: _frontPattern, rearPattern: _rearPattern,
      lanePattern:  _lanePattern,  leanPattern: _leanPattern,
      frontVolume:  _frontVolume,  rearVolume:  _rearVolume,
      laneVolume:   _laneVolume,   leanVolume:  _leanVolume,
    );
    if (mounted) setState(() => _saving = false);
    _msg(success: 'Sound settings saved & sent to hardware.');
  }

  Future<void> _testSound(int pattern, int volume) async {
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    await svc.testSoundOnHardware(pattern, volume);
  }

  Future<void> _saveConnectivity() async {
    final ssid    = _ssidCtrl.text.trim();
    final newPass = _wifiNewPassCtrl.text;
    final conPass = _wifiConfirmPassCtrl.text;
    if (ssid.isEmpty)        { _msg(error: 'SSID cannot be empty.');                      return; }
    if (newPass.length < 8)  { _msg(error: 'Password must be at least 8 characters.');   return; }
    if (newPass != conPass)  { _msg(error: 'Passwords do not match.');                   return; }
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    await p.setString('wifiSsid', ssid);
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    final sent = await svc.sendWifiSetupToHardware(ssid: ssid, password: newPass);
    _wifiNewPassCtrl.clear();
    _wifiConfirmPassCtrl.clear();
    if (mounted) setState(() => _saving = false);
    _msg(success: sent
        ? 'WiFi settings sent to hardware.'
        : 'Saved (hardware not connected).');
  }

  Future<void> _resetSystem() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset System?',
            style: GoogleFonts.rajdhani(
                color: _kPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        content: Text(
          'Vehicle dimensions, sensitivity presets, sound settings, and '
          'connectivity settings will be cleared. Your account data is not affected.',
          style: GoogleFonts.rajdhani(color: _kSecond, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.rajdhani(color: _kSecond)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('RESET', style: GoogleFonts.rajdhani(
                color: _kRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    final p = await SharedPreferences.getInstance();
    for (final k in [
      'vehicleType','loadCondition','trackWidth_m','wheelBase_m','vehicleHeight_m',
      'frontPreset','rearPreset','audioEnabled','frontPattern','rearPattern',
      'lanePattern','leanPattern','frontVolume','rearVolume','laneVolume','leanVolume',
      'wifiSsid','setupComplete',
    ]) { await p.remove(k); }
    if (!mounted) return;
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    await svc.sendResetDefaults();
    await _loadAll();
    if (mounted) setState(() => _saving = false);
    _msg(success: 'System reset complete. Run the Setup Wizard to reconfigure.');
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    body: SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Sidebar(selected: _section, onSelect: _switchSection),
          Container(width: 1, color: AppTheme.border),
          Expanded(child: _buildContent()),
        ],
      ),
    ),
  );

  Widget _buildContent() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── status banners ──────────────────────────────────────────────────
      if (_error != null) ...[
        _Banner(text: _error!, isError: true),
        const SizedBox(height: 16),
      ],
      if (_success != null) ...[
        _Banner(text: _success!, isError: false),
        const SizedBox(height: 16),
      ],
      // ── panel content ───────────────────────────────────────────────────
      switch (_section) {
        _kAccount      => _buildAccountPanel(),
        _kVehicle      => _buildVehiclePanel(),
        _kSensitivity  => _buildSensitivityPanel(),
        _kSound        => _buildSoundPanel(),
        _kConnectivity => _buildConnectivityPanel(),
        _kWizard       => _buildWizardPanel(),
        _kReset        => _buildResetPanel(),
        _              => const SizedBox.shrink(),
      },
    ]),
  );

  // ── ACCOUNT ────────────────────────────────────────────────────────────────
  Widget _buildAccountPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('ACCOUNT SETTINGS', 'Update your profile and change your password.'),
      const SizedBox(height: 24),

      _label('VEHICLE MODEL'),
      _field(_vehicleModelCtrl, 'e.g. Toyota Vitz 2018', Icons.directions_car_outlined),
      const SizedBox(height: 14),

      _label('VEHICLE CATEGORY'),
      _dropdown(
        value: _vehicleCategory,
        items: const ['Compact', 'Sedan', 'SUV / Tall', 'Pickup / Van'],
        onChanged: (v) { if (v != null) setState(() => _vehicleCategory = v); },
      ),
      const SizedBox(height: 14),

      _label('FULL NAME'),
      _field(_nameCtrl, 'Your full name', Icons.person_outline),
      const SizedBox(height: 14),

      _label('EMAIL ADDRESS'),
      _readOnlyField(_userEmail, Icons.email_outlined),
      const SizedBox(height: 24),

      _dividerLine(),
      const SizedBox(height: 20),
      _label('CURRENT PASSWORD'),
      _passField(_currentPassCtrl, '••••••••', _obscureCur,
          () => setState(() => _obscureCur = !_obscureCur)),
      const SizedBox(height: 14),

      _label('NEW PASSWORD'),
      _passField(_newPassCtrl, '••••••••', _obscureNew,
          () => setState(() => _obscureNew = !_obscureNew)),
      const SizedBox(height: 14),

      _label('CONFIRM PASSWORD'),
      _passField(_confirmPassCtrl, '••••••••', _obscureCon,
          () => setState(() => _obscureCon = !_obscureCon)),
      const SizedBox(height: 32),

      Align(
        alignment: Alignment.centerRight,
        child: _saveBtn('Save', _saving ? null : _saveAccount),
      ),
    ],
  );

  // ── VEHICLE PROFILE ────────────────────────────────────────────────────────
  Widget _buildVehiclePanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('VEHICLE PROFILE', 'Physical parameters sent to the ADAS Brain hardware.'),
      const SizedBox(height: 24),

      _label('VEHICLE TYPE'),
      _dropdown(
        value: _vehicleType,
        items: const [1, 2, 3],
        labels: const ['Compact', 'Passenger', 'Tall / SUV'],
        onChanged: (v) { if (v != null) setState(() => _vehicleType = v); },
      ),
      const SizedBox(height: 14),

      _label('LOAD CONDITION'),
      _dropdown(
        value: _loadCondition,
        items: const [0, 1, 2],
        labels: const ['Light', 'Normal', 'Heavy'],
        onChanged: (v) { if (v != null) setState(() => _loadCondition = v); },
      ),
      const SizedBox(height: 14),

      _label('TRACK WIDTH (m)'),
      _numField(_trackWidthCtrl, '1.56'),
      const SizedBox(height: 14),

      _label('WHEELBASE (m)'),
      _numField(_wheelbaseCtrl, '2.67'),
      const SizedBox(height: 14),

      _label('VEHICLE HEIGHT (m)'),
      _numField(_vehicleHeightCtrl, '1.57'),
      const SizedBox(height: 32),

      Align(
        alignment: Alignment.centerRight,
        child: _saveBtn('Save', _saving ? null : _saveVehicleProfile),
      ),
    ],
  );

  // ── SENSITIVITY & CALIBRATION ──────────────────────────────────────────────
  Widget _buildSensitivityPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('SENSITIVITY & CALIBRATION', 'Detection range presets and IMU center calibration.'),
      const SizedBox(height: 24),

      _label('FRONT UNIT SENSITIVITY'),
      _dropdown(
        value: _frontPreset,
        items: const [0, 1, 2],
        labels: const ['Near  (aggressive)', 'Normal', 'Far  (relaxed)'],
        onChanged: (v) { if (v != null) setState(() => _frontPreset = v); },
      ),
      const SizedBox(height: 14),

      _label('REAR UNIT SENSITIVITY'),
      _dropdown(
        value: _rearPreset,
        items: const [0, 1, 2],
        labels: const ['Near  (aggressive)', 'Normal', 'Far  (relaxed)'],
        onChanged: (v) { if (v != null) setState(() => _rearPreset = v); },
      ),
      const SizedBox(height: 28),

      Align(
        alignment: Alignment.centerRight,
        child: _saveBtn('Save Sensitivity', _saving ? null : _saveSensitivity),
      ),
      const SizedBox(height: 32),

      _dividerLine(),
      const SizedBox(height: 24),

      Text('CENTER UNIT CALIBRATION',
          style: GoogleFonts.orbitron(
              fontSize: 11, letterSpacing: 2,
              color: _kCyan, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(
        'Park on level ground and keep the vehicle completely stationary. '
        'The stability sensor will recalibrate its zero reference.',
        style: GoogleFonts.rajdhani(
            fontSize: 13, color: _kSecond, height: 1.5),
      ),
      const SizedBox(height: 20),
      _outlineBtn(
        label: 'Calibrate Center Unit',
        icon: Icons.tune_rounded,
        onTap: _saving ? null : _calibrate,
      ),
    ],
  );

  // ── SOUND ──────────────────────────────────────────────────────────────────
  Widget _buildSoundPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('SOUND SETTINGS', 'Assign a unique buzz pattern and volume to each alert unit.'),
      const SizedBox(height: 20),

      // Audio master toggle
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kPanel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(children: [
          const Icon(Icons.volume_up_rounded, color: _kBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text('Sound',
              style: GoogleFonts.rajdhani(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kPrimary))),
          Switch(
            value: _audioEnabled,
            onChanged: (v) => setState(() => _audioEnabled = v),
            activeThumbColor: _kCyan,
            inactiveThumbColor: _kSecond,
          ),
          const SizedBox(width: 4),
          Text(_audioEnabled ? 'Enabled' : 'Disabled',
              style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  color: _audioEnabled ? _kCyan : _kSecond,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
      const SizedBox(height: 20),

      _soundUnit(
        label:      'Front Unit',
        pattern:    _frontPattern,
        volume:     _frontVolume,
        onPattern:  (v) => setState(() => _frontPattern = v),
        onVolume:   (v) => setState(() => _frontVolume = v),
      ),
      const SizedBox(height: 14),
      _soundUnit(
        label:      'Rear Unit',
        pattern:    _rearPattern,
        volume:     _rearVolume,
        onPattern:  (v) => setState(() => _rearPattern = v),
        onVolume:   (v) => setState(() => _rearVolume = v),
      ),
      const SizedBox(height: 14),
      _soundUnit(
        label:      'Stability Unit',
        pattern:    _leanPattern,
        volume:     _leanVolume,
        onPattern:  (v) => setState(() => _leanPattern = v),
        onVolume:   (v) => setState(() => _leanVolume = v),
      ),
      const SizedBox(height: 14),
      _soundUnit(
        label:      'Camera Unit',
        pattern:    _lanePattern,
        volume:     _laneVolume,
        onPattern:  (v) => setState(() => _lanePattern = v),
        onVolume:   (v) => setState(() => _laneVolume = v),
      ),
      const SizedBox(height: 32),

      Align(
        alignment: Alignment.centerRight,
        child: _saveBtn('Save', _saving ? null : _saveSound),
      ),
    ],
  );

  // ── CONNECTIVITY ───────────────────────────────────────────────────────────
  Widget _buildConnectivityPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('CONNECTIVITY SETTINGS', 'Change the ADAS Brain access-point name and password.'),
      const SizedBox(height: 24),

      _label('WIFI SSID'),
      _field(_ssidCtrl, 'ADAS Brain network name', Icons.wifi_rounded),
      const SizedBox(height: 14),

      _label('NEW PASSWORD'),
      _passField(_wifiNewPassCtrl, '••••••••', _obscureWifiNew,
          () => setState(() => _obscureWifiNew = !_obscureWifiNew)),
      const SizedBox(height: 14),

      _label('CONFIRM PASSWORD'),
      _passField(_wifiConfirmPassCtrl, '••••••••', _obscureWifiCon,
          () => setState(() => _obscureWifiCon = !_obscureWifiCon)),
      const SizedBox(height: 32),

      Align(
        alignment: Alignment.centerRight,
        child: _saveBtn('Change Password', _saving ? null : _saveConnectivity),
      ),
    ],
  );

  // ── GUIDED SETUP WIZARD ────────────────────────────────────────────────────
  Widget _buildWizardPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('GUIDED SETUP WIZARD', ''),
      const SizedBox(height: 48),

      Center(
        child: Column(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pushNamed('/onboarding'),
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderBlue),
              ),
              alignment: Alignment.center,
              child: Text('Open Setup Wizard',
                  style: GoogleFonts.rajdhani(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: _kPrimary)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Run the full setup again after reinstalling, remounting,\nor moving the system to another vehicle',
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
                fontSize: 14, color: _kSecond, height: 1.5),
          ),
        ]),
      ),
    ],
  );

  // ── SYSTEM RESET ───────────────────────────────────────────────────────────
  Widget _buildResetPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PanelTitle('SYSTEM RESET', ''),
      const SizedBox(height: 48),

      Center(
        child: Column(children: [
          GestureDetector(
            onTap: _saving ? null : _resetSystem,
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kRed.withOpacity(0.4)),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(color: _kRed, strokeWidth: 2))
                  : Text('Reset System',
                      style: GoogleFonts.rajdhani(
                          fontSize: 18, fontWeight: FontWeight.w700,
                          color: _kRed)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Reset returns connectivity settings, vehicle dimensions,\n'
            'sensitivity presets and sound setting preferences to defaults.\n'
            'Setup must be completed again afterwards.',
            textAlign: TextAlign.center,
            style: GoogleFonts.rajdhani(
                fontSize: 14, color: _kSecond, height: 1.5),
          ),
        ]),
      ),
    ],
  );

  // ── Widget helpers ──────────────────────────────────────────────────────────

  Widget _soundUnit({
    required String label,
    required int pattern,
    required int volume,
    required ValueChanged<int> onPattern,
    required ValueChanged<int> onVolume,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kPanel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.rajdhani(
              fontSize: 15, fontWeight: FontWeight.w700, color: _kPrimary)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButton<int>(
              value: pattern,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              dropdownColor: const Color(0xFF0D1018),
              style: GoogleFonts.rajdhani(
                  color: _kPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kBlue),
              items: List.generate(4, (i) =>
                  DropdownMenuItem(value: i, child: Text(_kPatternNames[i]))),
              onChanged: (v) { if (v != null) onPattern(v); },
            ),
          ),
        ),
        const SizedBox(width: 10),
        _testButton(pattern, volume),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _kBlue.withOpacity(0.6),
              inactiveTrackColor: AppTheme.border,
              thumbColor: _kPrimary,
              overlayColor: _kBlue.withOpacity(0.1),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: volume.toDouble(),
              min: 30, max: 100, divisions: 14,
              onChanged: (v) => onVolume(v.toInt()),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text('$volume%',
              style: GoogleFonts.rajdhani(
                  fontSize: 13, color: _kSecond, fontWeight: FontWeight.w600)),
        ),
      ]),
    ]),
  );

  Widget _testButton(int pattern, int volume) => GestureDetector(
    onTap: () => _testSound(pattern, volume),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderBlue),
      ),
      child: Text('Test',
          style: GoogleFonts.rajdhani(
              fontSize: 14, fontWeight: FontWeight.w700, color: _kPrimary)),
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(t,
        style: GoogleFonts.orbitron(
            fontSize: 10, letterSpacing: 1.5,
            color: _kSecond, fontWeight: FontWeight.bold)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon) =>
      Container(
        decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: TextField(
          controller: ctrl,
          style: GoogleFonts.rajdhani(
              fontSize: 16, color: _kPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _kSecond.withOpacity(0.4)),
            prefixIcon: Icon(icon, color: _kBlue, size: 20),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      );

  Widget _readOnlyField(String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border)),
    child: Row(children: [
      Icon(icon, color: _kSecond, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(value.isEmpty ? '—' : value,
          style: GoogleFonts.rajdhani(
              fontSize: 16, color: _kSecond, fontWeight: FontWeight.w600))),
    ]),
  );

  Widget _numField(TextEditingController ctrl, String hint) => Container(
    decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border)),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
      ],
      style: GoogleFonts.rajdhani(
          fontSize: 16, color: _kPrimary, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: _kSecond.withOpacity(0.4)),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    ),
  );

  Widget _passField(TextEditingController ctrl, String hint,
          bool obscure, VoidCallback toggle) =>
      Container(
        decoration: BoxDecoration(
            color: _kPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: GoogleFonts.rajdhani(
              fontSize: 16, color: _kPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: _kSecond.withOpacity(0.4)),
            prefixIcon:
                const Icon(Icons.lock_outline, color: _kBlue, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                  color: _kSecond, size: 18),
              onPressed: toggle,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      );

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged, List<String>? labels,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
        color: _kPanel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border)),
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      dropdownColor: const Color(0xFF0D1018),
      style: GoogleFonts.rajdhani(
          color: _kPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kBlue),
      items: items.asMap().entries.map((e) => DropdownMenuItem(
          value: e.value,
          child: Text(labels != null ? labels[e.key] : '${e.value}'))).toList(),
      onChanged: onChanged,
    ),
  );

  Widget _saveBtn(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: BoxDecoration(
        color: onTap == null
            ? const Color(0xFF1A1F2E)
            : const Color(0xFF1E2535),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: onTap == null
                ? AppTheme.border
                : AppTheme.borderBlue),
      ),
      child: _saving
          ? const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _kPrimary))
          : Text(label,
              style: GoogleFonts.rajdhani(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: onTap == null ? _kSecond : _kPrimary)),
    ),
  );

  Widget _outlineBtn({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _kCyan.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kCyan.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: _kCyan, size: 20),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.rajdhani(
                fontSize: 15, fontWeight: FontWeight.w700, color: _kCyan)),
      ]),
    ),
  );

  Widget _dividerLine() => Container(
    height: 1,
    color: AppTheme.border,
  );
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelect});
  final int selected;
  final ValueChanged<int> onSelect;

  static const _items = [
    (label: 'Account Settings',    icon: Icons.account_circle_outlined),
    (label: 'Vehicle Profile',     icon: Icons.directions_car_outlined),
    (label: 'Sensitivity & Calibration', icon: Icons.tune_rounded),
    (label: 'Sound Settings',      icon: Icons.volume_up_outlined),
    (label: 'Connectivity Settings', icon: Icons.wifi_rounded),
    (label: 'Guided Setup Wizard', icon: Icons.auto_fix_high_rounded),
    (label: 'System Reset',        icon: Icons.restart_alt_rounded),
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    color: const Color(0xFF0A0D16),
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final isSelected = i == selected;
        return GestureDetector(
          onTap: () => onSelect(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? _kBlue.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isSelected
                      ? _kBlue.withOpacity(0.25)
                      : Colors.transparent),
            ),
            child: Text(
              _items[i].label,
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _kPrimary : _kSecond,
              ),
            ),
          ),
        );
      },
    ),
  );
}

// ─── Reusable sub-widgets ─────────────────────────────────────────────────────
class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.title, this.subtitle);
  final String title, subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title,
          style: GoogleFonts.rajdhani(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: _kPrimary, height: 1.1)),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.rajdhani(
                fontSize: 13, color: _kSecond, height: 1.4)),
      ],
    ],
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? _kRed : _kCyan;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
            style: TextStyle(color: color,
                fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
