import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class Car3DVisualization extends StatefulWidget {
  final double speed;
  final double steeringAngle;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;

  const Car3DVisualization({
    Key? key,
    required this.speed,
    this.steeringAngle = 0,
    this.brakeActive = false,
    this.leftSignal = false,
    this.rightSignal = false,
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
      duration: const Duration(milliseconds: 1500),
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
      height: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.darkBackground,
            AppTheme.cardBackground,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryNeon.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background grid
          CustomPaint(
            painter: GridPainter(),
            child: Container(),
          ),
          // 3D Car Visualization
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.05)
                      .animate(_glowController),
                  child: CustomPaint(
                    size: const Size(200, 150),
                    painter: Car3DPainter(
                      steeringAngle: widget.steeringAngle,
                      brakeActive: widget.brakeActive,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Speed and Status Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.leftSignal)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningYellow.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.warningYellow),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppTheme.warningYellow,
                            size: 16,
                          ),
                        ),
                      const Spacer(),
                      Column(
                        children: [
                          Text(
                            '${widget.speed.toStringAsFixed(0)} km/h',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppTheme.primaryNeon,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (widget.brakeActive)
                            Text(
                              '🛑 BRAKE ACTIVE',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.dangerRed,
                                  ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      if (widget.rightSignal)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningYellow.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.warningYellow),
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: AppTheme.warningYellow,
                            size: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Car3DPainter extends CustomPainter {
  final double steeringAngle;
  final bool brakeActive;

  Car3DPainter({
    required this.steeringAngle,
    required this.brakeActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final bodyPaint = Paint()
      ..color = brakeActive ? AppTheme.dangerRed : AppTheme.primaryNeon
      ..style = PaintingStyle.fill;

    final windowPaint = Paint()
      ..color = AppTheme.secondaryBlue.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final brakeLightPaint = Paint()
      ..color = brakeActive ? AppTheme.dangerRed : Colors.grey.shade700
      ..style = PaintingStyle.fill;

    // Main car body (top view with perspective)
    final bodyPath = Path()
      ..moveTo(center.dx - 60, center.dy - 30)
      ..lineTo(center.dx - 50, center.dy - 50)
      ..lineTo(center.dx + 50, center.dy - 50)
      ..lineTo(center.dx + 60, center.dy - 30)
      ..lineTo(center.dx + 55, center.dy + 50)
      ..lineTo(center.dx - 55, center.dy + 50)
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);

    // Front windshield
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 40,
        center.dy - 45,
        80,
        15,
      ),
      windowPaint,
    );

    // Rear window
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - 35,
        center.dy + 10,
        70,
        15,
      ),
      windowPaint,
    );

    // Front wheels with steering angle
    _drawWheel(
      canvas,
      Offset(center.dx - 35, center.dy - 25),
      steeringAngle,
      2,
    );
    _drawWheel(
      canvas,
      Offset(center.dx + 35, center.dy - 25),
      steeringAngle,
      2,
    );

    // Rear wheels (fixed)
    _drawWheel(
      canvas,
      Offset(center.dx - 35, center.dy + 40),
      0,
      1.5,
    );
    _drawWheel(
      canvas,
      Offset(center.dx + 35, center.dy + 40),
      0,
      1.5,
    );

    // Headlights
    canvas.drawCircle(
      Offset(center.dx - 20, center.dy - 55),
      4,
      Paint()..color = AppTheme.warningYellow,
    );
    canvas.drawCircle(
      Offset(center.dx + 20, center.dy - 55),
      4,
      Paint()..color = AppTheme.warningYellow,
    );

    // Brake lights (rear)
    canvas.drawCircle(
      Offset(center.dx - 20, center.dy + 58),
      4,
      brakeLightPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + 20, center.dy + 58),
      4,
      brakeLightPaint,
    );
  }

  void _drawWheel(
    Canvas canvas,
    Offset center,
    double rotationAngle,
    double scale,
  ) {
    final radius = 8.0 * scale;

    // Wheel rim
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade700
        ..style = PaintingStyle.fill,
    );

    // Wheel treads (rotated)
    const treadCount = 6;
    for (int i = 0; i < treadCount; i++) {
      final angle = (i / treadCount * 2 * math.pi) + (rotationAngle * 0.05);
      final x = center.dx + (radius - 2) * math.cos(angle);
      final y = center.dy + (radius - 2) * math.sin(angle);

      canvas.drawCircle(
        Offset(x, y),
        1 * scale,
        Paint()..color = Colors.grey.shade500,
      );
    }

    // Center hub
    canvas.drawCircle(
      center,
      3 * scale,
      Paint()..color = AppTheme.primaryNeon,
    );
  }

  @override
  bool shouldRepaint(Car3DPainter oldDelegate) {
    return oldDelegate.steeringAngle != steeringAngle ||
        oldDelegate.brakeActive != brakeActive;
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryNeon.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const spacing = 20.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i, size.height),
        paint,
      );
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(size.width, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

  @override
  State<Car3DVisualization> createState() => _Car3DVisualizationState();
}

class _Car3DVisualizationState extends State<Car3DVisualization>
    with TickerProviderStateMixin {
  late AnimationController _wheelController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _wheelController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Color _getCarColor() {
    if (!widget.engineStatus) return Colors.grey.shade700;
    if (widget.temperature > 100) return DrivoraTheme.dangerRed;
    if (widget.battery < 20) return DrivoraTheme.warningYellow;
    return DrivoraTheme.primaryNeon;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating glow effect
        ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.2)
              .animate(_glowController),
          child: Container(
            width: 320,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getCarColor().withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
          ),
        ),
        // 3D Car Drawing
        Transform.rotate(
          angle: widget.heading * math.pi / 180,
          child: CustomPaint(
            size: const Size(240, 320),
            painter: Car3DPainter(
              color: _getCarColor(),
              wheelRotation: _wheelController.value,
              speed: widget.speed,
              temperature: widget.temperature,
            ),
          ),
        ),
        // Status badges
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DrivoraTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: DrivoraTheme.primaryNeon, width: 1),
            ),
            child: Text(
              'Speed: ${widget.speed.toStringAsFixed(1)} km/h',
              style: const TextStyle(
                color: DrivoraTheme.primaryNeon,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Battery indicator
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            width: 40,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.battery > 20
                    ? DrivoraTheme.successGreen
                    : DrivoraTheme.dangerRed,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                Container(
                  width: (widget.battery / 100) * 36,
                  height: 20,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: widget.battery > 20
                        ? DrivoraTheme.successGreen
                        : DrivoraTheme.dangerRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class Car3DPainter extends CustomPainter {
  final Color color;
  final double wheelRotation;
  final double speed;
  final double temperature;

  Car3DPainter({
    required this.color,
    required this.wheelRotation,
    required this.speed,
    required this.temperature,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint mainBodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Paint windowPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final Paint wheelPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;

    final Paint headlightPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final Paint glarePaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);

    // Draw shadow under car
    canvas.drawEllipse(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 20),
        width: 180,
        height: 30,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Draw main body (with 3D effect)
    final bodyPath = Path()
      ..moveTo(center.dx - 70, center.dy + 40)
      ..lineTo(center.dx - 80, center.dy - 20)
      ..lineTo(center.dx - 60, center.dy - 60)
      ..lineTo(center.dx + 60, center.dy - 60)
      ..lineTo(center.dx + 80, center.dy - 20)
      ..lineTo(center.dx + 70, center.dy + 40)
      ..close();

    canvas.drawPath(bodyPath, mainBodyPaint);

    // Draw rear bumper
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 50),
        width: 140,
        height: 20,
      ),
      Paint()..color = color.withOpacity(0.8),
    );

    // Draw front windshield
    final windshieldPath = Path()
      ..moveTo(center.dx - 50, center.dy - 45)
      ..lineTo(center.dx - 45, center.dy - 70)
      ..lineTo(center.dx + 45, center.dy - 70)
      ..lineTo(center.dx + 50, center.dy - 45)
      ..close();

    canvas.drawPath(windshieldPath, windowPaint);

    // Draw rear window
    final rearWindowPath = Path()
      ..moveTo(center.dx - 60, center.dy - 30)
      ..lineTo(center.dx - 55, center.dy - 50)
      ..lineTo(center.dx + 55, center.dy - 50)
      ..lineTo(center.dx + 60, center.dy - 30)
      ..close();

    canvas.drawPath(rearWindowPath, windowPaint);

    // Draw headlights
    canvas.drawCircle(
      Offset(center.dx - 35, center.dy - 65),
      12,
      headlightPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + 35, center.dy - 65),
      12,
      headlightPaint,
    );

    // Draw headlight glare
    canvas.drawCircle(
      Offset(center.dx - 35, center.dy - 65),
      8,
      glarePaint,
    );
    canvas.drawCircle(
      Offset(center.dx + 35, center.dy - 65),
      8,
      glarePaint,
    );

    // Draw front wheels (left and right)
    _drawWheel(canvas, Offset(center.dx - 55, center.dy + 35), wheelPaint);
    _drawWheel(canvas, Offset(center.dx + 55, center.dy + 35), wheelPaint);

    // Draw middle accent line
    canvas.drawLine(
      Offset(center.dx - 70, center.dy + 10),
      Offset(center.dx + 70, center.dy + 10),
      Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 2,
    );

    // Draw temperature indicator (warning glow if hot)
    if (temperature > 100) {
      canvas.drawPath(
        bodyPath,
        Paint()
          ..color = Colors.red.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawWheel(Canvas canvas, Offset center, Paint paint) {
    // Outer rim
    canvas.drawCircle(center, 18, paint);

    // Tire tread (rotated)
    const int treads = 8;
    for (int i = 0; i < treads; i++) {
      final angle = (i / treads * 2 * math.pi) + wheelRotation * 2 * math.pi;
      final x = center.dx + 12 * math.cos(angle);
      final y = center.dy + 12 * math.sin(angle);

      canvas.drawCircle(
        Offset(x, y),
        2,
        Paint()..color = Colors.grey.shade600,
      );
    }

    // Center hub
    canvas.drawCircle(
      center,
      6,
      Paint()..color = Colors.grey.shade400,
    );
  }

  @override
  bool shouldRepaint(Car3DPainter oldDelegate) {
    return oldDelegate.wheelRotation != wheelRotation ||
        oldDelegate.color != color ||
        oldDelegate.temperature != temperature;
  }
}
