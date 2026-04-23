import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class Car3DVisualization extends StatefulWidget {
  final double speed;
  final double lanePosition;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;
  final double tiltAngle;

  const Car3DVisualization({
    Key? key,
    required this.speed,
    this.lanePosition = 0,
    this.brakeActive = false,
    this.leftSignal = false,
    this.rightSignal = false,
    this.tiltAngle = 0,
  }) : super(key: key);

  @override
  State<Car3DVisualization> createState() => _Car3DVisualizationState();
}

class _Car3DVisualizationState extends State<Car3DVisualization>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadowLg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Scan line animation
            const _ScanLine(),
            
            // Safety zone rings
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _SafetyEnvelopePainter(
                      pulse: _pulseController.value,
                      tilt: widget.tiltAngle,
                    ),
                    size: const Size(double.infinity, double.infinity),
                  );
                },
              ),
            ),

            // Car Model
            Center(
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(0.2)
                  ..rotateY(widget.lanePosition * 0.1)
                  ..rotateZ(widget.tiltAngle * (math.pi / 180)),
                alignment: Alignment.center,
                child: CustomPaint(
                  size: const Size(200, 300),
                  painter: _CarArtistPainter(
                    brakeActive: widget.brakeActive,
                    leftSignal: widget.leftSignal,
                    rightSignal: widget.rightSignal,
                  ),
                ),
              ),
            ),

            // Central Telemetry HUD
            Positioned(
              bottom: 40, left: 0, right: 0,
              child: Column(
                children: [
                  Text('${widget.speed.toInt()}', 
                    style: const TextStyle(
                      fontSize: 64, 
                      fontWeight: FontWeight.w700, 
                      color: AppTheme.textPrimary, 
                      fontFamily: 'Orbitron',
                      letterSpacing: -2,
                    )),
                  const Text('VEHICLE SPEED (KM/H)', 
                    style: TextStyle(
                      color: AppTheme.textSecondary, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 3, 
                      fontSize: 9
                    )),
                ],
              ),
            ),
            
            const Positioned(
              top: 15, left: 0, right: 0,
              child: Text('360° SAFETY ENVELOPE', 
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, letterSpacing: 2, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarArtistPainter extends CustomPainter {
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;

  _CarArtistPainter({required this.brakeActive, required this.leftSignal, required this.rightSignal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Main Chassis
    final bodyPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFD0D0D8)],
      ).createShader(Rect.fromCenter(center: center, width: 94, height: 158));
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 94, height: 158), const Radius.circular(10)),
      bodyPaint
    );

    // Cab
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 43, center.dy - 79, 86, 55), const Radius.circular(8)),
      Paint()..shader = const LinearGradient(colors: [Color(0xFFF0F0F5), Color(0xFFC8C8D0)]).createShader(Rect.fromLTWH(0, 0, 100, 100))
    );

    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(center.dx - 35, center.dy - 71, 70, 30), const Radius.circular(5)),
      Paint()..color = const Color(0xFF0A84FF).withOpacity(0.2)
    );

    // Dynamic Lights
    if (brakeActive) {
      final brakeGlow = Paint()..color = AppTheme.accentRed..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      canvas.drawRect(Rect.fromLTWH(center.dx - 40, center.dy + 75, 20, 5), brakeGlow);
      canvas.drawRect(Rect.fromLTWH(center.dx + 20, center.dy + 75, 20, 5), brakeGlow);
    }
    
    // Signals
    if (leftSignal) {
      canvas.drawCircle(center.translate(-45, -70), 6, Paint()..color = AppTheme.accentAmber..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    if (rightSignal) {
      canvas.drawCircle(center.translate(45, -70), 6, Paint()..color = AppTheme.accentAmber..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // Sensor Dots
    canvas.drawCircle(center.translate(0, -80), 3, Paint()..color = AppTheme.accentGreen); // FCW Unit
    canvas.drawCircle(center.translate(0, 30), 4, Paint()..color = AppTheme.accentAmber); // IMU Unit
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SafetyEnvelopePainter extends CustomPainter {
  final double pulse;
  final double tilt;
  _SafetyEnvelopePainter({required this.pulse, required this.tilt});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Forward Cone
    final conePath = Path()
      ..moveTo(center.dx, center.dy - 80)
      ..lineTo(center.dx - 100, center.dy - 220)
      ..lineTo(center.dx + 100, center.dy - 220)
      ..close();
    
    canvas.drawPath(conePath, Paint()..shader = LinearGradient(
      colors: [AppTheme.accentGreen.withOpacity(0.1), Colors.transparent],
      begin: Alignment.bottomCenter, end: Alignment.topCenter
    ).createShader(Rect.fromLTWH(0, 0, 500, 500)));

    // Pulsing Rings
    final ringPaint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.2 * (1 - pulse))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, 120 + pulse * 50, ringPaint);
    
    // Tilt Indicator
    final tiltPaint = Paint()..color = AppTheme.accentAmber.withOpacity(0.5)..strokeWidth = 1;
    canvas.drawLine(center.translate(-60, 100), center.translate(60, 100), tiltPaint);
    canvas.drawCircle(center.translate(tilt * 2, 100), 5, Paint()..color = AppTheme.accentAmber);
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) => Positioned(
        top: 400 * _ctrl.value,
        left: 0, right: 0,
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.transparent, AppTheme.accentBlue.withOpacity(0.5), Colors.transparent])
          ),
        ),
      ),
    );
  }
}
