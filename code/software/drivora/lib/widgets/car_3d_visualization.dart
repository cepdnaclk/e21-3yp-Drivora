import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class Car3DVisualization extends StatefulWidget {
  final double speed;
  final double lanePosition;
  final double tiltAngle;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;

  const Car3DVisualization({
    Key? key,
    this.speed = 0,
    this.lanePosition = 0,
    this.tiltAngle = 0,
    this.brakeActive = false,
    this.leftSignal = false,
    this.rightSignal = false,
  }) : super(key: key);

  @override
  State<Car3DVisualization> createState() => _Car3DVisualizationState();
}

class _Car3DVisualizationState extends State<Car3DVisualization>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [_scanController, _pulseController, _rotationController],
      ),
      builder: (context, child) {
        return CustomPaint(
          painter: Car3DPainter(
            speed: speed,
            lanePosition: lanePosition,
            tiltAngle: tiltAngle,
            brakeActive: brakeActive,
            leftSignal: leftSignal,
            rightSignal: rightSignal,
            scanProgress: _scanController.value,
            pulseValue: _pulseController.value,
            rotationValue: _rotationController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Car3DPainter extends CustomPainter {
  final double speed;
  final double lanePosition;
  final double tiltAngle;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;
  final double scanProgress;
  final double pulseValue;
  final double rotationValue;

  Car3DPainter({
    required this.speed,
    required this.lanePosition,
    required this.tiltAngle,
    required this.brakeActive,
    required this.leftSignal,
    required this.rightSignal,
    required this.scanProgress,
    required this.pulseValue,
    required this.rotationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw premium gradient background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentBlue.withOpacity(0.08),
            AppTheme.accentGreen.withOpacity(0.04),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final center = Offset(size.width / 2, size.height / 2);

    // Draw advanced safety visualization
    _drawAdvancedSafetyZone(canvas, size, center);

    // Draw 3D car with depth
    _drawCar3DAdvanced(canvas, size, center);

    // Draw scan line
    _drawScanLine(canvas, size);

    // Draw tilt indicator
    _drawTiltIndicator(canvas, size, center);

    // Draw speed display
    _drawSpeedDisplay(canvas, size, center);

    // Draw sensor data visualization
    _drawSensorVisualization(canvas, size, center);
  }

  void _drawAdvancedSafetyZone(Canvas canvas, Size size, Offset center) {
    // Forward detection zone with gradient
    final conePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.accentGreen.withOpacity(0.25),
          AppTheme.accentGreen.withOpacity(0.05),
        ],
      ).createShader(Rect.fromLTWH(center.dx - 80, center.dy - 40, 160, 200));

    final conePath = Path()
      ..moveTo(center.dx, center.dy - 40)
      ..lineTo(center.dx - 80, size.height - 30)
      ..lineTo(center.dx + 80, size.height - 30)
      ..close();

    canvas.drawPath(conePath, conePaint);

    // Animated zone border
    final coneBorder = Paint()
      ..color = AppTheme.accentGreen.withOpacity(0.6 + (pulseValue * 0.3))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(conePath, coneBorder);

    // Concentric safety rings with pulsing effect
    final maxRings = 4;
    for (int i = 0; i < maxRings; i++) {
      final radius = 50.0 + (i * 50.0) + (pulseValue * 25);
      final opacity = (1 - (pulseValue * 0.6)) * (0.4 - (i * 0.08)).clamp(0.0, 0.4);

      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = AppTheme.accentBlue.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawCar3DAdvanced(Canvas canvas, Size size, Offset center) {
    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Smooth rotation
    canvas.rotate(tiltAngle * 0.025 + (rotationValue * 0.1));

    // Shadow effect for depth
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(3, 35), width: 95, height: 55),
        const Radius.circular(14),
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..style = PaintingStyle.fill,
    );

    // Main car body with metallic gradient
    final bodyGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.red[300]!,
        Colors.red[600]!,
        Colors.red[800]!,
      ],
    );

    final bodyPaint = Paint()
      ..shader = bodyGradient.createShader(
        Rect.fromCenter(center: Offset.zero, width: 90, height: 50),
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 90, height: 50),
        const Radius.circular(14),
      ),
      bodyPaint,
    );

    // Windshield with reflection effect
    final windshieldPaint = Paint()
      ..color = Colors.blue.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path()
        ..moveTo(-30, -18)
        ..lineTo(-22, -38)
        ..lineTo(22, -38)
        ..lineTo(30, -18),
      windshieldPaint,
    );

    // Windshield highlight
    canvas.drawPath(
      Path()
        ..moveTo(-25, -35)
        ..lineTo(-20, -28)
        ..lineTo(20, -28)
        ..lineTo(25, -35),
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    // Car hood/top detail
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(0, -15),
          width: 70,
          height: 25,
        ),
        const Radius.circular(10),
      ),
      Paint()
        ..color = Colors.red[700]!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Wheels with better styling
    _drawWheel3D(canvas, Offset(-28, 28), brakeActive);
    _drawWheel3D(canvas, Offset(28, 28), brakeActive);

    // Tail lights
    if (brakeActive) {
      canvas.drawCircle(Offset(-38, 5), 6, Paint()..color = Colors.red);
      canvas.drawCircle(Offset(38, 5), 6, Paint()..color = Colors.red);
      
      // Glow effect
      canvas.drawCircle(
        Offset(-38, 5),
        9,
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(38, 5),
        9,
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Headlights
    canvas.drawCircle(Offset(-25, -22), 5, Paint()..color = Colors.yellow[300]!);
    canvas.drawCircle(Offset(25, -22), 5, Paint()..color = Colors.yellow[300]!);

    // Signal lights with animation
    if (leftSignal) {
      canvas.drawCircle(
        Offset(-45, -10),
        4,
        Paint()..color = Colors.amber.withOpacity(0.6 + (pulseValue * 0.4)),
      );
    }

    if (rightSignal) {
      canvas.drawCircle(
        Offset(45, -10),
        4,
        Paint()..color = Colors.amber.withOpacity(0.6 + (pulseValue * 0.4)),
      );
    }

    // Sensor positions with glow
    _drawSensorDot(canvas, Offset(0, -35), AppTheme.accentGreen); // FCW
    _drawSensorDot(canvas, Offset(-35, 15), AppTheme.accentAmber); // IMU
    _drawSensorDot(canvas, Offset(35, 15), AppTheme.accentAmber); // Rear sensors

    canvas.restore();
  }

  void _drawWheel3D(Canvas canvas, Offset position, bool braking) {
    // Tire with shine
    canvas.drawCircle(
      position,
      10,
      Paint()..color = Colors.black,
    );

    // Rim gradient
    final rimGradient = RadialGradient(
      colors: [Colors.grey[300]!, Colors.grey[600]!],
    );

    canvas.drawCircle(
      position,
      6,
      Paint()
        ..shader = rimGradient.createShader(Rect.fromCircle(center: position, radius: 6)),
    );

    // Tire shine
    canvas.drawArc(
      Rect.fromCircle(center: position, radius: 10),
      math.pi * 1.5,
      math.pi * 0.8,
      false,
      Paint()
        ..color = Colors.grey[400]!.withOpacity(0.4)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    if (braking) {
      canvas.drawCircle(
        position,
        13,
        Paint()
          ..color = Colors.red.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawSensorDot(Canvas canvas, Offset position, Color color) {
    // Main dot
    canvas.drawCircle(position, 3.5, Paint()..color = color);

    // Glow effect
    canvas.drawCircle(
      position,
      6,
      Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawScanLine(Canvas canvas, Size size) {
    final y = size.height * scanProgress;

    // Glow effect
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppTheme.accentGreen.withOpacity(0.2)
        ..strokeWidth = 8,
    );

    // Main line
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppTheme.accentGreen.withOpacity(0.7)
        ..strokeWidth = 2.5,
    );
  }

  void _drawTiltIndicator(Canvas canvas, Size size, Offset center) {
    final indicatorY = size.height - 50;
    final indicatorWidth = 120.0;
    final indicatorX = (size.width - indicatorWidth) / 2;

    // Background panel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX, indicatorY, indicatorWidth, 40),
        const Radius.circular(10),
      ),
      Paint()
        ..color = Colors.grey.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    // Tilt bar
    final barWidth = (indicatorWidth - 4) * ((lanePosition + 1) / 2).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX + 2, indicatorY + 2, barWidth, 36),
        const Radius.circular(8),
      ),
      Paint()
        ..color = AppTheme.accentAmber
        ..style = PaintingStyle.fill,
    );

    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX, indicatorY, indicatorWidth, 40),
        const Radius.circular(10),
      ),
      Paint()
        ..color = AppTheme.accentAmber.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawSpeedDisplay(Canvas canvas, Size size, Offset center) {
    // Background for speed display
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + 15),
          width: 180,
          height: 80,
        ),
        const Radius.circular(15),
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.1)
        ..style = PaintingStyle.fill,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: '${speed.toStringAsFixed(0)}',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 48,
          fontWeight: FontWeight.w900,
          fontFamily: 'Courier',
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.width / 2 - textPainter.width / 2,
        center.dy - 10,
      ),
    );

    final unitPainter = TextPainter(
      text: const TextSpan(
        text: 'KM/H',
        style: TextStyle(
          color: Colors.black54,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    unitPainter.layout();
    unitPainter.paint(
      canvas,
      Offset(
        size.width / 2 - unitPainter.width / 2,
        center.dy + 35,
      ),
    );
  }

  void _drawSensorVisualization(Canvas canvas, Size size, Offset center) {
    // Front distance indicator
    final frontDist = 50 + (pulseValue * 30);
    canvas.drawLine(
      Offset(center.dx - 15, center.dy - 50),
      Offset(center.dx - 15, center.dy - 50 - frontDist),
      Paint()
        ..color = AppTheme.accentGreen.withOpacity(0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawLine(
      Offset(center.dx + 15, center.dy - 50),
      Offset(center.dx + 15, center.dy - 50 - frontDist),
      Paint()
        ..color = AppTheme.accentGreen.withOpacity(0.5)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(Car3DPainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.lanePosition != lanePosition ||
        oldDelegate.tiltAngle != tiltAngle ||
        oldDelegate.brakeActive != brakeActive ||
        oldDelegate.leftSignal != leftSignal ||
        oldDelegate.rightSignal != rightSignal ||
        oldDelegate.scanProgress != scanProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.rotationValue != rotationValue;
  }
}
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
