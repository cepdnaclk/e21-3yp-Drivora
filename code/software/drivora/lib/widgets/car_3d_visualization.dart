import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class Car3DVisualization extends StatefulWidget {
  final double speed;
  final double lanePosition;
<<<<<<< HEAD
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
=======
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
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  }) : super(key: key);

  @override
  State<Car3DVisualization> createState() => _Car3DVisualizationState();
}

class _Car3DVisualizationState extends State<Car3DVisualization>
    with TickerProviderStateMixin {
<<<<<<< HEAD
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
=======
  late AnimationController _roadCtrl;
  late AnimationController _pulseCtrl;
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
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
=======
    _roadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    )..repeat();
  }

  @override
  void dispose() {
<<<<<<< HEAD
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
=======
    _roadCtrl.dispose();
    _pulseCtrl.dispose();
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
<<<<<<< HEAD
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
=======
      height: double.infinity,
      color: const Color(0xFF02050A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Perspective Road Path Simulation (DRAMATIC DEPARTURE)
          AnimatedBuilder(
            animation: _roadCtrl,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _PerspectiveRoadPainter(
                progress: _roadCtrl.value,
                laneOffset: widget.lanePosition,
              ),
            ),
          ),

          // 2. Safety Aura / Pulse
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _SafetyFieldPainter(
                pulse: _pulseCtrl.value,
                isDanger: widget.brakeActive || widget.lanePosition.abs() > 0.6,
              ),
            ),
          ),

          // 3. ENLARGED 3D Car Model (EXTREME COG TILT)
          Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(0.2)
              ..rotateZ(widget.tiltAngle * (math.pi / 180) * 1.5), // Even more exaggerated tilt
            alignment: Alignment.center,
            child: SizedBox(
              width: 280, // Larger car
              height: 420,
              child: CustomPaint(
                painter: _AdvancedCarPainter(
                  brakeActive: widget.brakeActive,
                  leftSignal: widget.leftSignal,
                  rightSignal: widget.rightSignal,
                ),
              ),
            ),
          ),

          // 4. Scanning Grid Lines
          const _TacticalOverlay(),
        ],
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
    );
  }
}

<<<<<<< HEAD
class _CarArtistPainter extends CustomPainter {
=======
class _PerspectiveRoadPainter extends CustomPainter {
  final double progress;
  final double laneOffset;
  _PerspectiveRoadPainter({required this.progress, required this.laneOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // EXTREME LANE DEPARTURE: Even more dramatic shift
    final cx = w / 2 - (laneOffset * 280);

    final roadPaint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Road Body
    final path = Path()
      ..moveTo(cx - 50, h * 0.1)
      ..lineTo(cx + 50, h * 0.1)
      ..lineTo(cx + 700, h)
      ..lineTo(cx - 700, h)
      ..close();
    canvas.drawPath(path, roadPaint);

    // Lateral Perspective Lines (Road Edges)
    final edgePaint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.18)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx - 50, h * 0.1), Offset(cx - 700, h), edgePaint);
    canvas.drawLine(Offset(cx + 50, h * 0.1), Offset(cx + 700, h), edgePaint);

    // Moving Lane Markings
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 10;

    const dashCount = 8;
    for (var i = 0; i < dashCount; i++) {
      final t = (progress + i) / dashCount;
      final y = h * 0.1 + (h * 0.9) * t;
      final scale = 0.1 + (t * 0.9);
      final dw = 50.0 * scale;

      // Center Dash
      canvas.drawLine(Offset(cx, y), Offset(cx, y + dw), dashPaint);
    }
  }

  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

class _AdvancedCarPainter extends CustomPainter {
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;

<<<<<<< HEAD
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
=======
  _AdvancedCarPainter({required this.brakeActive, required this.leftSignal, required this.rightSignal});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Chassis Base
    final chassisRect = Rect.fromCenter(center: Offset(cx, cy), width: 120, height: 250);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chassisRect, const Radius.circular(22)),
      Paint()..shader = const LinearGradient(
        colors: [Color(0xFF2C3E50), Color(0xFF000000)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter
      ).createShader(chassisRect),
    );

    // Cabin Glass
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 50, cy - 90, 100, 110), const Radius.circular(16)),
      Paint()..color = Colors.white.withOpacity(0.08)
    );

    // Front Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 42, cy - 80, 84, 40), const Radius.circular(8)),
      Paint()..color = const Color(0xFF00B0FF).withOpacity(0.18)
    );

    // Interactive Lights
    if (brakeActive) {
      final brake = Paint()..color = AppTheme.accentRed..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
      canvas.drawRect(Rect.fromLTWH(cx - 55, cy + 110, 35, 10), brake);
      canvas.drawRect(Rect.fromLTWH(cx + 20, cy + 110, 35, 10), brake);
    }

    if (DateTime.now().millisecond % 1000 > 500) {
      final sigColor = AppTheme.accentAmber;
      if (leftSignal) canvas.drawCircle(Offset(cx - 60, cy - 100), 12, Paint()..color = sigColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
      if (rightSignal) canvas.drawCircle(Offset(cx + 60, cy - 100), 12, Paint()..color = sigColor..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));
    }

    // Detail: Headlights
    final head = Paint()..color = Colors.white.withOpacity(0.95)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(Offset(cx - 45, cy - 115), 7, head);
    canvas.drawCircle(Offset(cx + 45, cy - 115), 7, head);
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

class _SafetyFieldPainter extends CustomPainter {
  final double pulse;
  final bool isDanger;
  _SafetyFieldPainter({required this.pulse, required this.isDanger});
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
<<<<<<< HEAD
    
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
=======
    final color = isDanger ? AppTheme.accentRed : AppTheme.accentCyan;

    canvas.drawCircle(
      center,
      160 + (pulse * 70),
      Paint()
        ..color = color.withOpacity(0.15 * (1 - pulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

class _TacticalOverlay extends StatelessWidget {
  const _TacticalOverlay();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _GridOverlayPainter(),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
    );
  }
}
<<<<<<< HEAD
=======

class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 40) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 40) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override bool shouldRepaint(_) => false;
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
