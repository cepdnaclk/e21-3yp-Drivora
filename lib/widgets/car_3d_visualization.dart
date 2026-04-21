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
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        color: const Color(0xFF02050A),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          
          // Safety Aura
          Center(
            child: Container(
              width: 220, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.brakeActive ? Colors.red.withOpacity(0.1) : AppTheme.primaryNeon.withOpacity(0.05),
                    blurRadius: 70, spreadRadius: 20,
                  )
                ],
              ),
            ),
          ),

          // 3D Car Model
          Center(
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) 
                ..rotateX(0.6) 
                ..rotateY(widget.lanePosition * 0.2)
                ..rotateZ(widget.tiltAngle * (math.pi / 180)),
              alignment: Alignment.center,
              child: CustomPaint(
                size: const Size(200, 130),
                painter: TeslaStylePainter(
                  brakeActive: widget.brakeActive,
                  leftSignal: widget.leftSignal,
                  rightSignal: widget.rightSignal,
                ),
              ),
            ),
          ),

          // Speed HUD Overlay
          Positioned(
            bottom: 30, left: 0, right: 0,
            child: Column(
              children: [
                Text('${widget.speed.toInt()}', 
                  style: const TextStyle(fontSize: 62, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -3)),
                const Text('VEHICLE SPEED (KM/H)', 
                  style: TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, letterSpacing: 4, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TeslaStylePainter extends CustomPainter {
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;

  TeslaStylePainter({required this.brakeActive, required this.leftSignal, required this.rightSignal});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Main Body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFF1E293B), Colors.black],
        begin: Alignment.topCenter, end: Alignment.bottomCenter
      ).createShader(Offset.zero & size);
    
    final body = Path()
      ..moveTo(center.dx - 45, center.dy - 65)
      ..quadraticBezierTo(center.dx, center.dy - 75, center.dx + 45, center.dy - 65)
      ..lineTo(center.dx + 58, center.dy + 65)
      ..lineTo(center.dx - 58, center.dy + 65)
      ..close();
    canvas.drawPath(body, bodyPaint);

    // Glass Canopy
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 80, height: 85), const Radius.circular(15)), 
      Paint()..color = Colors.white.withOpacity(0.08)
    );

    // Dynamic Lights
    _drawLights(canvas, center);
  }

  void _drawLights(Canvas canvas, Offset center) {
    final headlight = Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(Offset(center.dx - 38, center.dy - 65), 5, headlight);
    canvas.drawCircle(Offset(center.dx + 38, center.dy - 65), 5, headlight);

    if (leftSignal) canvas.drawCircle(Offset(center.dx - 48, center.dy - 60), 7, Paint()..color = AppTheme.warningYellow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    if (rightSignal) canvas.drawCircle(Offset(center.dx + 48, center.dy - 60), 7, Paint()..color = AppTheme.warningYellow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    if (brakeActive) {
      final brake = Paint()..color = Colors.red..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawRect(Rect.fromLTWH(center.dx - 55, center.dy + 60, 25, 10), brake);
      canvas.drawRect(Rect.fromLTWH(center.dx + 30, center.dy + 60, 25, 10), brake);
    }
  }

  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.primaryNeon.withOpacity(0.03)..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 40) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 40) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}
