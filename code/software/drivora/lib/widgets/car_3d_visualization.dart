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
    with TickerProviderStateMixin {
  late AnimationController _roadCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _signalCtrl;
  late AnimationController _ldwCtrl;
  late AnimationController _cogCtrl;

  @override
  void initState() {
    super.initState();
    _roadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _signalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _ldwCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
    _cogCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _roadCtrl.dispose();
    _pulseCtrl.dispose();
    _signalCtrl.dispose();
    _ldwCtrl.dispose();
    _cogCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLaneDeparting = widget.lanePosition.abs() > 0.45;
    final bool isDanger = widget.brakeActive || isLaneDeparting;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF060910),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── LAYER 1: Road with perspective lane markings ──
            AnimatedBuilder(
              animation: _roadCtrl,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _TopViewRoadPainter(
                  progress: _roadCtrl.value,
                  laneOffset: widget.lanePosition,
                  speed: widget.speed,
                ),
              ),
            ),

            // ── LAYER 2: Lane Departure Warning Overlay ──
            if (isLaneDeparting)
              AnimatedBuilder(
                animation: _ldwCtrl,
                builder: (context, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _LaneDepartureWarningPainter(
                    laneOffset: widget.lanePosition,
                    pulse: _ldwCtrl.value,
                  ),
                ),
              ),

            // ── LAYER 3: Safety Aura Pulse ──
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _SafetyAuraPainter(
                  pulse: _pulseCtrl.value,
                  isDanger: isDanger,
                  laneOffset: widget.lanePosition,
                ),
              ),
            ),

            // ── LAYER 4: TOP-VIEW CAR + COG ──
            AnimatedBuilder(
              animation: _signalCtrl,
              builder: (context, signal) {
                return AnimatedBuilder(
                  animation: _cogCtrl,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _TopViewCarPainter(
                      tiltAngle: widget.tiltAngle,
                      brakeActive: widget.brakeActive,
                      leftSignal: widget.leftSignal,
                      rightSignal: widget.rightSignal,
                      signalBlink: _signalCtrl.value > 0.5,
                      laneOffset: widget.lanePosition,
                      speed: widget.speed,
                      cogPulse: _cogCtrl.value,
                    ),
                  ),
                );
              },
            ),

            // ── LAYER 5: LDW Text Banner ──
            if (isLaneDeparting)
              AnimatedBuilder(
                animation: _ldwCtrl,
                builder: (context, _) => Positioned(
                  bottom: 20,
                  child: AnimatedOpacity(
                    opacity: _ldwCtrl.value,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentAmber.withOpacity(0.5),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.warning_amber_rounded, color: Colors.black, size: 13),
                          SizedBox(width: 6),
                          Text(
                            'LANE DEPARTURE',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── LAYER 6: Speed Readout ──
            Positioned(
              top: 14,
              child: Column(
                children: [
                  Text(
                    widget.speed.toInt().toString(),
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      color: widget.speed > 80
                          ? AppTheme.accentRed
                          : AppTheme.accentCyan,
                      shadows: [
                        Shadow(
                          color: (widget.speed > 80
                              ? AppTheme.accentRed
                              : AppTheme.accentCyan)
                              .withOpacity(0.65),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'KM/H',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 7,
                      letterSpacing: 3.5,
                      color: AppTheme.textSecondary.withOpacity(0.55),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // ── LAYER 7: COG Tilt Tag ──
            Positioned(
              bottom: 14,
              left: 14,
              child: _HudTag(
                label: 'COG TILT',
                value: '${widget.tiltAngle.abs().toStringAsFixed(1)}°',
                color: widget.tiltAngle.abs() > 15
                    ? AppTheme.accentRed
                    : AppTheme.accentGreen,
              ),
            ),

            // ── LAYER 8: Lane Offset Tag ──
            Positioned(
              bottom: 14,
              right: 14,
              child: _HudTag(
                label: 'LANE Δ',
                value: '${widget.lanePosition.toStringAsFixed(2)}m',
                color: isLaneDeparting
                    ? AppTheme.accentAmber
                    : AppTheme.accentGreen,
              ),
            ),

            // ── LAYER 9: Subtle grid overlay ──
            CustomPaint(
              size: Size.infinite,
              painter: _GridOverlayPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  TOP-VIEW ROAD PAINTER
// ─────────────────────────────────────────────────────────────
class _TopViewRoadPainter extends CustomPainter {
  final double progress;
  final double laneOffset;
  final double speed;

  _TopViewRoadPainter({
    required this.progress,
    required this.laneOffset,
    required this.speed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    const laneWidth = 80.0;
    const totalRoadWidth = laneWidth * 3;

    // Road surface gradient
    final roadRect = Rect.fromLTWH(cx - totalRoadWidth / 2, 0, totalRoadWidth, h);
    final roadGrad = const LinearGradient(
      colors: [Color(0xFF0A1520), Color(0xFF0F1C2E), Color(0xFF0A1520)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
    canvas.drawRect(roadRect, Paint()..shader = roadGrad.createShader(roadRect));

    // Road edge lines
    final edgePaint = Paint()
      ..color = Colors.white.withOpacity(0.50)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx - totalRoadWidth / 2, 0), Offset(cx - totalRoadWidth / 2, h), edgePaint);
    canvas.drawLine(Offset(cx + totalRoadWidth / 2, 0), Offset(cx + totalRoadWidth / 2, h), edgePaint);

    // Lane dividers (dashed amber/gold)
    final dashPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.40)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final speedFactor = (speed / 60).clamp(0.3, 2.5);
    const dashLen = 28.0;
    const gapLen = 20.0;
    const period = dashLen + gapLen;

    for (final xOff in [-laneWidth, laneWidth]) {
      final x = cx + xOff;
      double y = -(progress * period * speedFactor);
      while (y < h) {
        canvas.drawLine(Offset(x, y), Offset(x, y + dashLen), dashPaint);
        y += period;
      }
    }

    // Center lane (dashed subtle white)
    final centerDashPaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1.0;

    double cy2 = -(progress * period * speedFactor * 0.8);
    while (cy2 < h) {
      canvas.drawLine(Offset(cx, cy2), Offset(cx, cy2 + dashLen * 0.6), centerDashPaint);
      cy2 += period;
    }

    // Road shoulder glow
    final curbPaint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.05)
      ..strokeWidth = 10
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawLine(Offset(cx - totalRoadWidth / 2 - 5, 0), Offset(cx - totalRoadWidth / 2 - 5, h), curbPaint);
    canvas.drawLine(Offset(cx + totalRoadWidth / 2 + 5, 0), Offset(cx + totalRoadWidth / 2 + 5, h), curbPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  LANE DEPARTURE WARNING PAINTER
// ─────────────────────────────────────────────────────────────
class _LaneDepartureWarningPainter extends CustomPainter {
  final double laneOffset;
  final double pulse;

  _LaneDepartureWarningPainter({required this.laneOffset, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    const laneWidth = 80.0;
    final isLeft = laneOffset < 0;
    final edgeX = isLeft ? cx - laneWidth * 1.5 : cx + laneWidth * 1.5;

    // Flashing edge
    final warnPaint = Paint()
      ..color = AppTheme.accentAmber.withOpacity(0.28 + pulse * 0.55)
      ..strokeWidth = 4 + pulse * 4
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + pulse * 5);

    canvas.drawLine(Offset(edgeX, 0), Offset(edgeX, h), warnPaint);

    // Diagonal hatching
    final hatchPaint = Paint()
      ..color = AppTheme.accentAmber.withOpacity(0.07 + pulse * 0.09)
      ..strokeWidth = 1.5;

    final hatchX1 = isLeft ? 0.0 : edgeX;
    final hatchX2 = isLeft ? edgeX : w;

    for (double y = -w; y < h + w; y += 22) {
      canvas.drawLine(
        Offset(hatchX1, y),
        Offset(hatchX2, y + (hatchX2 - hatchX1)),
        hatchPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  SAFETY AURA PAINTER
// ─────────────────────────────────────────────────────────────
class _SafetyAuraPainter extends CustomPainter {
  final double pulse;
  final bool isDanger;
  final double laneOffset;

  _SafetyAuraPainter({required this.pulse, required this.isDanger, required this.laneOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final color = isDanger ? AppTheme.accentRed : AppTheme.accentCyan;

    for (int i = 0; i < 2; i++) {
      final t = (pulse + i * 0.5) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: 130 + t * 110,
          height: 220 + t * 140,
        ),
        Paint()
          ..color = color.withOpacity(0.16 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  TOP-VIEW CAR PAINTER
// ─────────────────────────────────────────────────────────────
class _TopViewCarPainter extends CustomPainter {
  final double tiltAngle;
  final bool brakeActive;
  final bool leftSignal;
  final bool rightSignal;
  final bool signalBlink;
  final double laneOffset;
  final double speed;
  final double cogPulse;

  _TopViewCarPainter({
    required this.tiltAngle,
    required this.brakeActive,
    required this.leftSignal,
    required this.rightSignal,
    required this.signalBlink,
    required this.laneOffset,
    required this.speed,
    required this.cogPulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final carCX = w / 2 + (laneOffset * 70.0);
    final carCY = h * 0.54;

    canvas.save();
    canvas.translate(carCX, carCY);
    canvas.rotate(tiltAngle * (math.pi / 180) * 0.55);

    const carW = 68.0;
    const carH = 140.0;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 8), width: carW + 22, height: carH * 0.55),
      Paint()
        ..color = Colors.black.withOpacity(0.50)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
    );

    // Car Body
    final bodyPath = _buildCarBodyPath(carW, carH);
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1C2B3F), Color(0xFF0A1320), Color(0xFF162030)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromCenter(center: Offset.zero, width: carW, height: carH)),
    );

    // Body outline glow
    canvas.drawPath(
      bodyPath,
      Paint()
        ..color = AppTheme.accentBlue.withOpacity(0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Roof Glass
    final roofPath = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromCenter(center: const Offset(0, -10), width: carW * 0.62, height: carH * 0.38),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ));
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = const Color(0xFF00B4D8).withOpacity(0.10)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      roofPath,
      Paint()
        ..color = AppTheme.accentCyan.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Wheels
    _drawWheel(canvas, -carW * 0.46, -carH * 0.34);
    _drawWheel(canvas, carW * 0.46, -carH * 0.34);
    _drawWheel(canvas, -carW * 0.46, carH * 0.34);
    _drawWheel(canvas, carW * 0.46, carH * 0.34);

    // Headlights
    _drawHeadlight(canvas, -carW * 0.35, -carH * 0.47);
    _drawHeadlight(canvas, carW * 0.35, -carH * 0.47);

    // Brake / Tail lights
    if (brakeActive) {
      _drawBrakeLight(canvas, -carW * 0.35, carH * 0.47);
      _drawBrakeLight(canvas, carW * 0.35, carH * 0.47);
    } else {
      _drawTailLight(canvas, -carW * 0.35, carH * 0.47);
      _drawTailLight(canvas, carW * 0.35, carH * 0.47);
    }

    // Turn signals
    if (signalBlink) {
      if (leftSignal) {
        _drawSignal(canvas, -carW * 0.46, -carH * 0.44);
        _drawSignal(canvas, -carW * 0.46, carH * 0.44);
      }
      if (rightSignal) {
        _drawSignal(canvas, carW * 0.46, -carH * 0.44);
        _drawSignal(canvas, carW * 0.46, carH * 0.44);
      }
    }

    // Hood line
    canvas.drawLine(
      Offset(-carW * 0.38, -carH * 0.32),
      Offset(carW * 0.38, -carH * 0.32),
      Paint()
        ..color = AppTheme.accentBlue.withOpacity(0.18)
        ..strokeWidth = 1.2,
    );

    // Trunk line
    canvas.drawLine(
      Offset(-carW * 0.36, carH * 0.32),
      Offset(carW * 0.36, carH * 0.32),
      Paint()
        ..color = AppTheme.accentBlue.withOpacity(0.14)
        ..strokeWidth = 1.0,
    );

    // COG Point
    _drawCOGPoint(canvas, carW, carH);

    canvas.restore();

    // Velocity vector
    _drawVelocityVector(canvas, carCX, carCY, carH);
  }

  Path _buildCarBodyPath(double w, double h) {
    final halfW = w / 2;
    final halfH = h / 2;
    return Path()
      ..moveTo(0, -halfH)
      ..cubicTo(-halfW * 0.3, -halfH, -halfW, -halfH + 22, -halfW, -halfH + 38)
      ..lineTo(-halfW, halfH - 22)
      ..cubicTo(-halfW, halfH, -halfW * 0.5, halfH, 0, halfH)
      ..cubicTo(halfW * 0.5, halfH, halfW, halfH, halfW, halfH - 22)
      ..lineTo(halfW, -halfH + 38)
      ..cubicTo(halfW, -halfH + 22, halfW * 0.3, -halfH, 0, -halfH)
      ..close();
  }

  void _drawWheel(Canvas canvas, double x, double y) {
    const ww = 11.0;
    const wh = 20.0;
    final wheelRect = Rect.fromCenter(center: Offset(x, y), width: ww, height: wh);
    canvas.drawRRect(RRect.fromRectAndRadius(wheelRect, const Radius.circular(3)),
        Paint()..color = const Color(0xFF080E14));
    canvas.drawRRect(
      RRect.fromRectAndRadius(wheelRect, const Radius.circular(3)),
      Paint()
        ..color = const Color(0xFF243045)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = const Color(0xFF354A60));
  }

  void _drawHeadlight(Canvas canvas, double x, double y) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 16, height: 5),
          const Radius.circular(2)),
      Paint()
        ..color = Colors.white.withOpacity(0.92)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  void _drawBrakeLight(Canvas canvas, double x, double y) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 16, height: 5),
          const Radius.circular(2)),
      Paint()
        ..color = AppTheme.accentRed
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  void _drawTailLight(Canvas canvas, double x, double y) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 14, height: 4),
          const Radius.circular(2)),
      Paint()..color = const Color(0xFF8B0000).withOpacity(0.65),
    );
  }

  void _drawSignal(Canvas canvas, double x, double y) {
    canvas.drawCircle(
      Offset(x, y),
      5,
      Paint()
        ..color = AppTheme.accentAmber
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  void _drawCOGPoint(Canvas canvas, double carW, double carH) {
    final cogY = -carH * 0.05 + (tiltAngle * 0.5);
    final cogX = tiltAngle * 0.4;

    // Crosshair
    final cogLinePaint = Paint()
      ..color = AppTheme.accentCyan.withOpacity(0.50)
      ..strokeWidth = 0.9;
    canvas.drawLine(Offset(cogX - 18, cogY), Offset(cogX + 18, cogY), cogLinePaint);
    canvas.drawLine(Offset(cogX, cogY - 18), Offset(cogX, cogY + 18), cogLinePaint);

    // Pulsing ring
    canvas.drawCircle(
      Offset(cogX, cogY),
      8 + cogPulse * 5,
      Paint()
        ..color = AppTheme.accentCyan.withOpacity(0.18 * (1 - cogPulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // COG dot
    canvas.drawCircle(
      Offset(cogX, cogY),
      5.5,
      Paint()
        ..color = AppTheme.accentCyan
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(Offset(cogX, cogY), 3.5, Paint()..color = Colors.white);

    // Label
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'COG',
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 6.5,
          color: AppTheme.accentCyan.withOpacity(0.75),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cogX + 9, cogY - 14));
  }

  void _drawVelocityVector(Canvas canvas, double cx, double cy, double carH) {
    if (speed < 2) return;
    final arrowLen = (speed / 120.0).clamp(0.0, 1.0) * 50 + 20;
    final arrowPaint = Paint()
      ..color = AppTheme.accentGreen.withOpacity(0.65)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final tipY = cy - carH * 0.5 - arrowLen;
    canvas.drawLine(Offset(cx, cy - carH * 0.5), Offset(cx, tipY), arrowPaint);

    final path = Path()
      ..moveTo(cx, tipY - 8)
      ..lineTo(cx - 5, tipY + 2)
      ..lineTo(cx + 5, tipY + 2)
      ..close();
    canvas.drawPath(path, Paint()..color = AppTheme.accentGreen.withOpacity(0.65));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────
//  GRID OVERLAY
// ─────────────────────────────────────────────────────────────
class _GridOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.010)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 36) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────
//  HUD TAG
// ─────────────────────────────────────────────────────────────
class _HudTag extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HudTag({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.60),
        border: Border.all(color: color.withOpacity(0.40), width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 6.5,
              color: AppTheme.textSecondary.withOpacity(0.65),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}