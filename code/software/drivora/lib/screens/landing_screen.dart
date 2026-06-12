import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});
  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _fade;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    body: Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Logo ────────────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _glow,
                  builder: (_, __) => Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentBlue.withOpacity(_glow.value * 0.5),
                          blurRadius: 40 * _glow.value,
                          spreadRadius: 10 * _glow.value,
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.accentBlue.withOpacity(0.25),
                            AppTheme.accentCyan.withOpacity(0.15),
                          ],
                        ),
                        border: Border.all(color: AppTheme.accentCyan, width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.shield_rounded,
                            color: AppTheme.accentCyan, size: 56),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Text('DRIVORA',
                    style: GoogleFonts.orbitron(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 10),
                Text('UNIVERSAL ADVANCED DRIVER ASSISTANCE',
                    style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        letterSpacing: 2,
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),

                const Spacer(flex: 2),

                // ── Buttons ──────────────────────────────────────────────────
                _buildRegisterBtn(context),
                const SizedBox(height: 16),
                _buildLoginBtn(context),

                const Spacer(),

                Text('v1.0.0  ·  DRIVORA U-ADAS CORE',
                    style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        letterSpacing: 1,
                        color: AppTheme.textMuted),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildRegisterBtn(BuildContext ctx) => GestureDetector(
    onTap: () => Navigator.pushNamed(ctx, '/registration'),
    child: Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppTheme.accentBlue, Color(0xFF00B0FF)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppTheme.accentBlue.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text('CREATE ACCOUNT',
            style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
      ]),
    ),
  );

  Widget _buildLoginBtn(BuildContext ctx) => GestureDetector(
    onTap: () => Navigator.pushNamed(ctx, '/login'),
    child: Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.login_rounded, color: AppTheme.accentCyan, size: 20),
        const SizedBox(width: 10),
        Text('LOGIN',
            style: GoogleFonts.orbitron(
                color: AppTheme.accentCyan,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5)),
      ]),
    ),
  );
}
