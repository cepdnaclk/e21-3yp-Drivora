import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dashboard_screen.dart';
import '../theme/app_theme.dart';

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({Key? key}) : super(key: key);

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _loadingController;
  
  double _progress = 0.0;
  String _statusText = "INITIALIZING CORE...";
  final List<String> _statusMessages = [
    "BOOTING ADAS CORE...",
    "LINKING SENSOR HUB...",
    "CALIBRATING GYRO...",
    "ESTABLISHING 5G HUB...",
    "SYSTEMS READY."
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _rotationController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _loadingController = AnimationController(vsync: this, duration: const Duration(seconds: 4));

    _startInitialization();
  }

  void _startInitialization() async {
    for (int i = 0; i < _statusMessages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _statusText = _statusMessages[i];
          _progress = (i + 1) / _statusMessages.length;
        });
      }
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background HUD circles
          Center(
            child: RotationTransition(
              turns: _rotationController,
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  size: const Size(400, 400),
                  painter: _HUDRingPainter(),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Centered Logo with Pulse
                ScaleTransition(
                  scale: Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentBlue.withOpacity(0.5), width: 2),
                      boxShadow: [
                        BoxShadow(color: AppTheme.accentBlue.withOpacity(0.2), blurRadius: 40, spreadRadius: 10)
                      ],
                    ),
                    child: const Icon(Icons.shield_rounded, color: AppTheme.accentBlue, size: 80),
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'DRIVORA ADAS',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'SECURITY PROTOCOL ACTIVE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    letterSpacing: 4,
                    color: AppTheme.accentBlue.withOpacity(0.7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Loading Progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _statusText,
                            style: GoogleFonts.rajdhani(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            "${(_progress * 100).toInt()}%",
                            style: GoogleFonts.orbitron(
                              color: AppTheme.accentBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HUDRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (size.width / 8) * i, paint);
    }

    // Draw tech crosshair
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
