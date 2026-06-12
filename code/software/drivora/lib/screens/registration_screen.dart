import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _modelCtrl   = TextEditingController();
  String _vehicleCategory = 'Sedan';

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  late AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  // ── Validation & submit ───────────────────────────────────────────────────
  Future<void> _register() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;
    final model   = _modelCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Full name is required.'); return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.'); return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.'); return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.'); return;
    }
    if (model.isEmpty) {
      setState(() => _error = 'Vehicle model is required.'); return;
    }

    setState(() { _loading = true; _error = null; });

    final ok = await CloudService().registerUser(
      name:            name,
      email:           email,
      password:        pass,
      vehicleModel:    model,
      vehicleCategory: _vehicleCategory,
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    } else {
      setState(() {
        _loading = false;
        _error = 'Registration failed. Email may already be in use or check your connection.';
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Stack(children: [
      // Background tech art
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _bgCtrl,
          builder: (_, __) => CustomPaint(
            painter: _TechArtPainter(rotation: _bgCtrl.value),
          ),
        ),
      ),

      SafeArea(
        child: Column(children: [
          // Back button row
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Row(children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.accentCyan, size: 22),
                padding: EdgeInsets.zero,
              ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Header ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.textPrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppTheme.shadow,
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: AppTheme.accentGreen, size: 30),
                  ),
                  const SizedBox(height: 20),
                  Text('Create Account',
                      style: GoogleFonts.rajdhani(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.1)),
                  Text('DRIVORA U-ADAS SETUP',
                      style: GoogleFonts.orbitron(
                          fontSize: 11,
                          letterSpacing: 3,
                          color: AppTheme.accentBlue,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 28),

                  // ── Error ───────────────────────────────────────────────
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppTheme.accentRed.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppTheme.accentRed, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(
                                color: AppTheme.accentRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Vehicle info ────────────────────────────────────────
                  _sectionTitle('VEHICLE INFORMATION'),
                  const SizedBox(height: 10),
                  _inputLabel('VEHICLE MODEL'),
                  _textField(_modelCtrl, 'e.g. Toyota Vitz 2018',
                      Icons.directions_car_outlined),
                  const SizedBox(height: 14),
                  _inputLabel('VEHICLE CATEGORY'),
                  _dropdown(),
                  const SizedBox(height: 22),

                  // ── Driver info ────────────────────────────────────────
                  _sectionTitle('DRIVER INFORMATION'),
                  const SizedBox(height: 10),
                  _inputLabel('FULL NAME'),
                  _textField(_nameCtrl, 'e.g. Sachith Nirmal',
                      Icons.person_outline),
                  const SizedBox(height: 14),
                  _inputLabel('EMAIL ADDRESS'),
                  _textField(_emailCtrl, 'sachith@example.com',
                      Icons.email_outlined,
                      keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _inputLabel('PASSWORD'),
                  _passwordField(_passCtrl, '••••••••', _obscurePass,
                      () => setState(() => _obscurePass = !_obscurePass)),
                  const SizedBox(height: 14),
                  _inputLabel('CONFIRM PASSWORD'),
                  _passwordField(_confirmCtrl, '••••••••', _obscureConfirm,
                      () => setState(
                          () => _obscureConfirm = !_obscureConfirm)),
                  const SizedBox(height: 36),

                  // ── Register button ────────────────────────────────────
                  Container(
                    width: double.infinity,
                    height: 62,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                          colors: [AppTheme.accentBlue, Colors.blueAccent]),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.accentBlue.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: Colors.transparent,
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text('REGISTER',
                              style: GoogleFonts.orbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: Colors.white)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/login');
                      },
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.rajdhani(
                              color: AppTheme.textSecondary, fontSize: 14),
                          children: const [
                            TextSpan(text: 'Already registered?  '),
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                  color: AppTheme.accentCyan,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ]),
      ),
    ]),
  );

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Text(t,
      style: GoogleFonts.rajdhani(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          fontSize: 11,
          color: AppTheme.accentCyan));

  Widget _inputLabel(String t) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(t,
        style: GoogleFonts.orbitron(
            fontSize: 10,
            letterSpacing: 1.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold)),
  );

  Widget _textField(TextEditingController ctrl, String hint, IconData icon,
          {TextInputType keyboard = TextInputType.text}) =>
      Container(
        decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.shadow),
        child: TextField(
          controller: ctrl,
          keyboardType: keyboard,
          style: GoogleFonts.rajdhani(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppTheme.textSecondary.withOpacity(0.3)),
            prefixIcon: Icon(icon, color: AppTheme.accentBlue, size: 22),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      );

  Widget _passwordField(TextEditingController ctrl, String hint, bool obscure,
          VoidCallback toggle) =>
      Container(
        decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.shadow),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: GoogleFonts.rajdhani(
              fontSize: 16,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppTheme.textSecondary.withOpacity(0.3)),
            prefixIcon: const Icon(Icons.lock_outline,
                color: AppTheme.accentBlue, size: 22),
            suffixIcon: IconButton(
              icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppTheme.textSecondary,
                  size: 20),
              onPressed: toggle,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          ),
        ),
      );

  Widget _dropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow),
    child: DropdownButton<String>(
      value: _vehicleCategory,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      dropdownColor: AppTheme.panel,
      style: GoogleFonts.rajdhani(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppTheme.accentBlue),
      items: const ['Compact', 'Sedan', 'SUV / Tall', 'Pickup / Van']
          .map((v) => DropdownMenuItem(value: v, child: Text(v)))
          .toList(),
      onChanged: (v) { if (v != null) setState(() => _vehicleCategory = v); },
    ),
  );
}

// ─── Background painter ────────────────────────────────────────────────────────
class _TechArtPainter extends CustomPainter {
  const _TechArtPainter({required this.rotation});
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * 0.8, size.height * 0.15);
    for (var i = 0; i < 3; i++) {
      final radius = 100.0 + i * 45.0;
      canvas.drawCircle(center, radius, paint);
      final angle = rotation * 2 * math.pi + i * math.pi / 4;
      canvas.drawCircle(
          center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          4,
          Paint()..color = AppTheme.accentBlue.withOpacity(0.08));
    }
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.01)
      ..strokeWidth = 0.5;
    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_TechArtPainter old) => old.rotation != rotation;
}
