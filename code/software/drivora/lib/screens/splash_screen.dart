import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSplashSequence();
  }

  void _setupAnimations() {
    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Scale animation
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Glow animation (pulsing)
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _startSplashSequence() async {
    _fadeController.forward();
    _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Already logged in — check if onboarding is complete
      final prefs = await SharedPreferences.getInstance();
      final setupDone = prefs.getBool('setupComplete') ?? false;
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
            setupDone ? '/dashboard' : '/onboarding');
      }
    } else {
      if (mounted) Navigator.of(context).pushReplacementNamed('/landing');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Tech background grid
            Positioned.fill(
              child: _buildTechGrid(),
            ),

            // Center content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated logo circle with glow
                      _buildAnimatedLogo(),
                      const SizedBox(height: 48),

                      // Title
                      Text(
                        'DRIVORA',
                        style: GoogleFonts.orbitron(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: AppTheme.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        'UNIVERSAL ADVANCED DRIVER ASSISTANCE SYSTEM',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 60),

                      // Loading animation
                      _buildLoadingAnimation(),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom version info
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.accentBlue,
                              AppTheme.accentBlue.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'v1.0.0',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          letterSpacing: 1,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

  Widget _buildTechGrid() => CustomPaint(
      painter: _TechGridPainter(opacity: _fadeAnimation.value),
    );

  Widget _buildAnimatedLogo() => AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) => Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentBlue.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 40 * _glowAnimation.value,
                spreadRadius: 10 * _glowAnimation.value,
              ),
              BoxShadow(
                color: AppTheme.accentCyan.withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 60 * _glowAnimation.value,
                spreadRadius: 20 * _glowAnimation.value,
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
                  AppTheme.accentBlue.withOpacity(0.3),
                  AppTheme.accentCyan.withOpacity(0.2),
                ],
              ),
              border: Border.all(
                color: AppTheme.accentCyan,
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.directions_car_rounded,
                size: 80,
                color: AppTheme.accentCyan,
              ),
            ),
          ),
        ),
    );

  Widget _buildLoadingAnimation() => SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) => RotationTransition(
            turns: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _glowController,
                curve: Interval(index * 0.15, 1, curve: Curves.linear),
              ),
            ),
            child: Container(
              width: 40 + (index * 15).toDouble(),
              height: 40 + (index * 15).toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.accentBlue.withOpacity(0.3 - (index * 0.08)),
                  width: 2,
                ),
              ),
            ),
          )),
      ),
    );
}

// Custom painter for tech grid background
class _TechGridPainter extends CustomPainter {

  _TechGridPainter({required this.opacity});
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.05 * opacity)
      ..strokeWidth = 1;

    const gridSpacing = 60.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TechGridPainter oldDelegate) => oldDelegate.opacity != opacity;
}
