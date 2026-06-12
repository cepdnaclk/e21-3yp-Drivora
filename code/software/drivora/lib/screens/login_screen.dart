import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.'); return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.'); return;
    }

    setState(() { _loading = true; _error = null; });

    final errCode = await CloudService().loginUser(email: email, password: pass);

    if (!mounted) return;

    if (errCode == null) {
      // Mark setup as complete so returning users go straight to dashboard
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setupComplete', true);
      if (mounted) Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      setState(() {
        _loading = false;
        _error = _friendlyError(errCode);
      });
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':     return 'No account found with this email.';
      case 'wrong-password':     return 'Incorrect password. Try again.';
      case 'invalid-credential': return 'Email or password is incorrect.';
      case 'too-many-requests':  return 'Too many attempts. Try later.';
      case 'user-disabled':      return 'This account has been disabled.';
      default:                   return 'Login failed. Check your connection.';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: AppTheme.accentCyan, size: 22),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),

              // ── Header ─────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                ),
                child: const Icon(Icons.login_rounded,
                    color: AppTheme.accentCyan, size: 32),
              ),
              const SizedBox(height: 24),
              Text('Welcome Back',
                  style: GoogleFonts.rajdhani(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      height: 1.1)),
              Text('DRIVER LOGIN',
                  style: GoogleFonts.orbitron(
                      fontSize: 12,
                      letterSpacing: 3,
                      color: AppTheme.accentBlue,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 36),

              // ── Error ───────────────────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.accentRed, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(
                            color: AppTheme.accentRed,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Fields ──────────────────────────────────────────────────────
              _label('EMAIL ADDRESS'),
              _field(_emailCtrl, 'driver@example.com',
                  Icons.email_outlined, TextInputType.emailAddress),
              const SizedBox(height: 16),

              _label('PASSWORD'),
              _passField(),
              const SizedBox(height: 40),

              // ── Login button ────────────────────────────────────────────────
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                      colors: [AppTheme.accentBlue, Color(0xFF00B0FF)]),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.accentBlue.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
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
                      : Text('LOGIN',
                          style: GoogleFonts.orbitron(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 28),
              Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/registration');
                  },
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.rajdhani(
                          color: AppTheme.textSecondary, fontSize: 14),
                      children: const [
                        TextSpan(text: 'New user?  '),
                        TextSpan(
                          text: 'Create Account',
                          style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(text,
        style: GoogleFonts.orbitron(
            fontSize: 10,
            letterSpacing: 1.5,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold)),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      TextInputType kb) =>
      Container(
        decoration: BoxDecoration(
            color: AppTheme.panel,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.shadow),
        child: TextField(
          controller: ctrl,
          keyboardType: kb,
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
                const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          ),
        ),
      );

  Widget _passField() => Container(
    decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow),
    child: TextField(
      controller: _passCtrl,
      obscureText: _obscure,
      style: GoogleFonts.rajdhani(
          fontSize: 16,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: '••••••••',
        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.3)),
        prefixIcon:
            const Icon(Icons.lock_outline, color: AppTheme.accentBlue, size: 22),
        suffixIcon: IconButton(
          icon: Icon(
              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppTheme.textSecondary,
              size: 20),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      ),
    ),
  );
}
