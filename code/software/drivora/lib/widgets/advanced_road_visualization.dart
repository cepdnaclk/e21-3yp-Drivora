import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class AdvancedRoadVisualization extends StatefulWidget {
  final double speed;
  final double lanePosition;
  final bool ldwActive;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;

  const AdvancedRoadVisualization({
    Key? key,
    this.speed = 0,
    this.lanePosition = 0,
    this.ldwActive = false,
    this.brakeActive = false,
    this.leftSignal = false,
    this.rightSignal = false,
  }) : super(key: key);

  @override
  State<AdvancedRoadVisualization> createState() =>
      _AdvancedRoadVisualizationState();
}

class _AdvancedRoadVisualizationState extends State<AdvancedRoadVisualization>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _roadScrollController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _roadScrollController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _roadScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation:
          Listenable.merge([_scanController, _roadScrollController]),
      builder: (context, child) {
        return CustomPaint(
          painter: AdvancedRoadPainter(
            speed: widget.speed,
            lanePosition: widget.lanePosition,
            ldwActive: widget.ldwActive,
            brakeActive: widget.brakeActive,
            leftSignal: widget.leftSignal,
            rightSignal: widget.rightSignal,
            scanProgress: _scanController.value,
            roadScrollProgress: _roadScrollController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class AdvancedRoadPainter extends CustomPainter {
  final double speed;
  final double lanePosition;
  final bool ldwActive;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;
  final double scanProgress;
  final double roadScrollProgress;

  AdvancedRoadPainter({
    required this.speed,
    required this.lanePosition,
    required this.ldwActive,
    required this.brakeActive,
    required this.leftSignal,
    required this.rightSignal,
    required this.scanProgress,
    required this.roadScrollProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw premium gradient background (sky)
    _drawGradientSky(canvas, size);

    // Draw road with perspective
    _drawRoadWithPerspective(canvas, size);

    // Draw lane markings with movement
    _drawLaneMarkings(canvas, size);

    // Draw vehicle
    _drawVehicle(canvas, size);

    // Draw lane departure warnings
    if (ldwActive) {
      _drawLaneDepartureWarning(canvas, size);
    }

    // Draw scan line effect
    _drawScanEffect(canvas, size);

    // Draw speed and info overlay
    _drawInfoOverlay(canvas, size);
  }

  void _drawGradientSky(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF87CEEB).withOpacity(0.8), // Sky blue
            const Color(0xFFE0E0E0).withOpacity(0.6), // Road gray
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawRoadWithPerspective(Canvas canvas, Size size) {
    final roadWidth = size.width * 0.6;
    final roadX = (size.width - roadWidth) / 2;

    // Road background
    final roadPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.fill;

    // Perspective road shape (trapezoid getting wider toward camera)
    final roadPath = Path()
      ..moveTo(size.width * 0.3, 20) // Top left
      ..lineTo(size.width * 0.7, 20) // Top right
      ..lineTo(size.width, size.height) // Bottom right
      ..lineTo(0, size.height) // Bottom left
      ..close();

    canvas.drawPath(roadPath, roadPaint);

    // Road texture/details
    final texturePaint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 30; i++) {
      final y = size.height - (i * size.height / 30);
      final progress = (i / 30) * 2 - 1;
      final xOffset = progress * size.width * 0.2;
      canvas.drawLine(
        Offset(xOffset, y),
        Offset(size.width - xOffset, y),
        texturePaint,
      );
    }
  }

  void _drawLaneMarkings(Canvas canvas, Size size) {
    final markingPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = Colors.yellow.withOpacity(0.7)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Left lane line (solid white)
    final leftPath = Path();
    leftPath.moveTo(size.width * 0.25, 0);
    leftPath.quadraticBezierTo(
      size.width * 0.2 + (lanePosition * 20),
      size.height * 0.5,
      size.width * 0.05,
      size.height,
    );
    canvas.drawPath(leftPath, markingPaint);

    // Right lane line (solid white)
    final rightPath = Path();
    rightPath.moveTo(size.width * 0.75, 0);
    rightPath.quadraticBezierTo(
      size.width * 0.8 + (lanePosition * 20),
      size.height * 0.5,
      size.width * 0.95,
      size.height,
    );
    canvas.drawPath(rightPath, markingPaint);

    // Center lane marking (dashed yellow - if two-lane road)
    for (int i = 0; i < 15; i++) {
      final y = (i * size.height / 15) + (roadScrollProgress * size.height / 15);
      final normalizedY = y % size.height;
      final xLerp = normalizedY / size.height;
      final centerX = size.width * 0.5 + (lanePosition * 30 * xLerp);

      canvas.drawLine(
        Offset(centerX, normalizedY),
        Offset(centerX, normalizedY + size.height / 30),
        dashPaint,
      );
    }
  }

  void _drawVehicle(Canvas canvas, Size size) {
    final vehicleX = size.width / 2 + (lanePosition * 50);
    final vehicleY = size.height * 0.65;

    canvas.save();
    canvas.translate(vehicleX, vehicleY);

    // Vehicle shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(2, 35), width: 80, height: 50),
        const Radius.circular(10),
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );

    // Main vehicle body
    final bodyGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.red[300]!,
        Colors.red[600]!,
        Colors.red[800]!,
      ],
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 80, height: 45),
        const Radius.circular(12),
      ),
      Paint()
        ..shader = bodyGradient.createShader(
          Rect.fromCenter(center: Offset.zero, width: 80, height: 45),
        ),
    );

    // Windshield
    canvas.drawPath(
      Path()
        ..moveTo(-28, -15)
        ..lineTo(-20, -30)
        ..lineTo(20, -30)
        ..lineTo(28, -15),
      Paint()
        ..color = Colors.blue.withOpacity(0.6)
        ..style = PaintingStyle.fill,
    );

    // Headlights
    canvas.drawCircle(Offset(-20, -18), 4, Paint()..color = Colors.yellow[300]!);
    canvas.drawCircle(Offset(20, -18), 4, Paint()..color = Colors.yellow[300]!);

    // Brake lights
    if (brakeActive) {
      canvas.drawCircle(Offset(-30, 5), 5, Paint()..color = Colors.red);
      canvas.drawCircle(Offset(30, 5), 5, Paint()..color = Colors.red);

      // Glow
      canvas.drawCircle(
        Offset(-30, 5),
        8,
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(30, 5),
        8,
        Paint()
          ..color = Colors.red.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Turn signals
    if (leftSignal) {
      canvas.drawCircle(
        Offset(-40, -5),
        4,
        Paint()..color = Colors.amber,
      );
    }
    if (rightSignal) {
      canvas.drawCircle(
        Offset(40, -5),
        4,
        Paint()..color = Colors.amber,
      );
    }

    // Wheels
    _drawWheelAdvanced(canvas, Offset(-24, 24), brakeActive);
    _drawWheelAdvanced(canvas, Offset(24, 24), brakeActive);

    canvas.restore();
  }

  void _drawWheelAdvanced(Canvas canvas, Offset position, bool braking) {
    // Tire
    canvas.drawCircle(position, 9, Paint()..color = Colors.black);

    // Rim
    final rimGradient = RadialGradient(
      colors: [Colors.grey[300]!, Colors.grey[600]!],
    );
    canvas.drawCircle(
      position,
      5,
      Paint()
        ..shader =
            rimGradient.createShader(Rect.fromCircle(center: position, radius: 5)),
    );

    if (braking) {
      canvas.drawCircle(
        position,
        12,
        Paint()
          ..color = Colors.red.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _drawLaneDepartureWarning(Canvas canvas, Size size) {
    final vehicleX = size.width / 2 + (lanePosition * 50);

    // Check lane boundaries
    final leftBoundary = size.width * 0.25;
    final rightBoundary = size.width * 0.75;

    if (vehicleX < leftBoundary + 30 || vehicleX > rightBoundary - 30) {
      // Draw warning zone
      final warningPaint = Paint()
        ..color = Colors.amber.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        warningPaint,
      );

      // Draw pulsing border
      final borderPaint = Paint()
        ..color = Colors.amber.withOpacity(0.6 + (scanProgress * 0.3))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        borderPaint,
      );
    }
  }

  void _drawScanEffect(Canvas canvas, Size size) {
    final y = size.height * scanProgress;

    // Glow
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppTheme.accentGreen.withOpacity(0.15)
        ..strokeWidth = 12,
    );

    // Main line
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = AppTheme.accentGreen.withOpacity(0.7)
        ..strokeWidth = 2,
    );
  }

  void _drawInfoOverlay(Canvas canvas, Size size) {
    // Speed info
    final speedText = TextPainter(
      text: TextSpan(
        text: '${speed.toStringAsFixed(1)} KM/H',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    speedText.layout();
    speedText.paint(canvas, Offset(size.width - 180, 20));

    // Lane position info
    final laneText = TextPainter(
      text: TextSpan(
        text: lanePosition > 0.2
            ? 'RIGHT LANE'
            : lanePosition < -0.2
                ? 'LEFT LANE'
                : 'CENTER',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    laneText.layout();
    laneText.paint(canvas, Offset(20, 20));
  }

  @override
  bool shouldRepaint(AdvancedRoadPainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.lanePosition != lanePosition ||
        oldDelegate.ldwActive != ldwActive ||
        oldDelegate.brakeActive != brakeActive ||
        oldDelegate.leftSignal != leftSignal ||
        oldDelegate.rightSignal != rightSignal ||
        oldDelegate.scanProgress != scanProgress ||
        oldDelegate.roadScrollProgress != roadScrollProgress;
  }
}
