import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../theme/app_theme.dart';

class StatusCard extends StatelessWidget {
=======
import 'dart:math' as math;
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  STATUS CARD  – glowing metric tile
// ─────────────────────────────────────────────────────────────────────────────
class StatusCard extends StatefulWidget {
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color? backgroundColor;
  final Color? accentColor;

  const StatusCard({
    Key? key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    this.backgroundColor,
    this.accentColor,
  }) : super(key: key);

  @override
<<<<<<< HEAD
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? DrivoraTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor?.withOpacity(0.3) ?? DrivoraTheme.dividerColor,
          width: 1,
        ),
        boxShadow: DrivoraTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: DrivoraTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                icon,
                color: accentColor ?? DrivoraTheme.primaryNeon,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accentColor ?? DrivoraTheme.primaryNeon,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: DrivoraTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
=======
  State<StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<StatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppTheme.accentCyan;

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withOpacity(0.15 + _shimmer.value * 0.1),
              width: 1,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.06 + _shimmer.value * 0.02),
                AppTheme.surfaceElevated,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: accent.withOpacity(0.08 + _shimmer.value * 0.05),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      fontFamily: 'Rajdhani',
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, color: accent, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.value,
                    style: TextStyle(
                      color: accent,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      shadows: [
                        Shadow(color: accent.withOpacity(0.5), blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.unit,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Thin neon accent line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0)],
                  ),
                  borderRadius: BorderRadius.circular(1),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
                ),
              ),
            ],
          ),
<<<<<<< HEAD
        ],
      ),
=======
        );
      },
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    );
  }
}

<<<<<<< HEAD
class CircularProgressCard extends StatelessWidget {
=======
// ─────────────────────────────────────────────────────────────────────────────
//  CIRCULAR PROGRESS CARD  – arc gauge
// ─────────────────────────────────────────────────────────────────────────────
class CircularProgressCard extends StatefulWidget {
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  final String title;
  final double value;
  final double maxValue;
  final String unit;
  final Color? progressColor;

  const CircularProgressCard({
    Key? key,
    required this.title,
    required this.value,
    required this.maxValue,
    required this.unit,
    this.progressColor,
  }) : super(key: key);

  @override
<<<<<<< HEAD
  Widget build(BuildContext context) {
    final percentage = (value / maxValue).clamp(0.0, 1.0);
    final color = progressColor ?? DrivoraTheme.primaryNeon;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DrivoraTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DrivoraTheme.dividerColor,
          width: 1,
        ),
        boxShadow: DrivoraTheme.softShadow,
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: color.withOpacity(0.2),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${value.toStringAsFixed(1)}$unit',
                    style: const TextStyle(
                      color: DrivoraTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: DrivoraTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
=======
  State<CircularProgressCard> createState() => _CircularProgressCardState();
}

class _CircularProgressCardState extends State<CircularProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.value / widget.maxValue).clamp(0.0, 1.0);
    final color = widget.progressColor ?? AppTheme.accentCyan;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadow,
      ),
      child: Column(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating dashed outer ring
                AnimatedBuilder(
                  animation: _rotateCtrl,
                  builder: (_, __) => Transform.rotate(
                    angle: _rotateCtrl.value * 2 * math.pi,
                    child: CustomPaint(
                      size: const Size(110, 110),
                      painter: _DashedRingPainter(color: color.withOpacity(0.2)),
                    ),
                  ),
                ),
                // Arc progress
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _ArcProgressPainter(
                    progress: percentage,
                    color: color,
                    trackColor: color.withOpacity(0.1),
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(percentage * 100).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        shadows: [
                          Shadow(color: color.withOpacity(0.6), blurRadius: 10),
                        ],
                      ),
                    ),
                    Text(
                      '%',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${widget.value.toStringAsFixed(1)}${widget.unit}',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

<<<<<<< HEAD
class AlertCard extends StatelessWidget {
  final String title;
  final String message;
  final String type; // 'danger', 'warning', 'info'
=======
class _ArcProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ArcProgressPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = -math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress
    if (progress > 0) {
      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle * progress,
        colors: [color.withOpacity(0.6), color],
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        Paint()
          ..shader = gradient.createShader(
              Rect.fromCircle(center: center, radius: radius))
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Glow dot at tip
      final tipAngle = startAngle + sweepAngle * progress;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY),
        5,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(Offset(tipX, tipY), 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcProgressPainter old) =>
      old.progress != progress;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  _DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    const dashCount = 32;
    const dashLength = math.pi * 2 / dashCount;

    for (var i = 0; i < dashCount; i++) {
      final startAngle = i * dashLength;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLength * 0.5,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ALERT CARD  – severity-aware notification tile
// ─────────────────────────────────────────────────────────────────────────────
class AlertCard extends StatefulWidget {
  final String title;
  final String message;
  final String type; // 'danger' | 'warning' | 'info'
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  final VoidCallback? onDismiss;

  const AlertCard({
    Key? key,
    required this.title,
    required this.message,
    required this.type,
    this.onDismiss,
  }) : super(key: key);

<<<<<<< HEAD
  Color _getAlertColor() {
    switch (type) {
      case 'danger':
        return DrivoraTheme.dangerRed;
      case 'warning':
        return DrivoraTheme.warningYellow;
      default:
        return DrivoraTheme.primaryNeon;
    }
  }

  IconData _getAlertIcon() {
    switch (type) {
      case 'danger':
        return Icons.error_outline;
      case 'warning':
        return Icons.warning_amber;
      default:
        return Icons.info_outline;
=======
  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.type == 'danger') _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color get _alertColor {
    switch (widget.type) {
      case 'danger':  return AppTheme.accentRed;
      case 'warning': return AppTheme.accentAmber;
      default:        return AppTheme.accentCyan;
    }
  }

  IconData get _alertIcon {
    switch (widget.type) {
      case 'danger':  return Icons.warning_rounded;
      case 'warning': return Icons.info_rounded;
      default:        return Icons.check_circle_rounded;
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    }
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final alertColor = _getAlertColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getAlertIcon(),
            color: alertColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: alertColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: DrivoraTheme.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                color: alertColor,
                size: 16,
              ),
            ),
        ],
      ),
=======
    final color = _alertColor;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.06 + _pulse.value * 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.25 + _pulse.value * 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1 + _pulse.value * 0.08),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_alertIcon, color: color, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.message,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.onDismiss != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.close_rounded, color: color, size: 14),
                  ),
                ),
              ],
            ],
          ),
        );
      },
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    );
  }
}

<<<<<<< HEAD
class StatisticsChart extends StatelessWidget {
=======
// ─────────────────────────────────────────────────────────────────────────────
//  STATISTICS CHART  – animated bar chart
// ─────────────────────────────────────────────────────────────────────────────
class StatisticsChart extends StatefulWidget {
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  final String label;
  final List<double> values;
  final Color? barColor;

  const StatisticsChart({
    Key? key,
    required this.label,
    required this.values,
    this.barColor,
  }) : super(key: key);

  @override
<<<<<<< HEAD
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final color = barColor ?? DrivoraTheme.primaryNeon;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DrivoraTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DrivoraTheme.dividerColor,
          width: 1,
        ),
=======
  State<StatisticsChart> createState() => _StatisticsChartState();
}

class _StatisticsChartState extends State<StatisticsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _grow;

  @override
  void initState() {
    super.initState();
    _grow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _grow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.isEmpty) return const SizedBox.shrink();

    final maxValue = widget.values.reduce((a, b) => a > b ? a : b);
    final color = widget.barColor ?? AppTheme.accentCyan;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
<<<<<<< HEAD
            label,
            style: const TextStyle(
              color: DrivoraTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: values
                .map((value) {
                  final heightPercent = maxValue > 0 ? (value / maxValue) : 0;
=======
            widget.label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _grow,
            builder: (_, __) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: widget.values.asMap().entries.map((entry) {
                  final ratio = maxValue > 0 ? entry.value / maxValue : 0.0;
                  final barH = 48.0 * ratio * _grow.value;
                  final isMax = entry.value == maxValue;

>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
<<<<<<< HEAD
                        width: 6,
                        height: 40 * heightPercent,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
=======
                        width: 8,
                        height: barH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isMax
                                ? [color, color.withOpacity(0.6)]
                                : [color.withOpacity(0.6), color.withOpacity(0.3)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: isMax
                              ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]
                              : null,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
                        ),
                      ),
                    ],
                  );
<<<<<<< HEAD
                })
                .toList(),
=======
                }).toList(),
              );
            },
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
          ),
        ],
      ),
    );
  }
}

<<<<<<< HEAD
=======
// ─────────────────────────────────────────────────────────────────────────────
//  GLASSMORPHIC CARD  – dark-glass container
// ─────────────────────────────────────────────────────────────────────────────
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? borderColor;

  const GlassmorphicCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
<<<<<<< HEAD
    this.borderRadius = 16,
=======
    this.borderRadius = 20,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
<<<<<<< HEAD
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.1),
=======
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.08),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
<<<<<<< HEAD
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
=======
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
<<<<<<< HEAD
=======

// ─────────────────────────────────────────────────────────────────────────────
//  NEON DIVIDER
// ─────────────────────────────────────────────────────────────────────────────
class NeonDivider extends StatelessWidget {
  final Color color;
  final double height;

  const NeonDivider({
    Key? key,
    this.color = AppTheme.accentBlue,
    this.height = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withOpacity(0.6),
            color,
            color.withOpacity(0.6),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HUD BADGE  – small status label
// ─────────────────────────────────────────────────────────────────────────────
class HudBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool pulsing;

  const HudBadge({
    Key? key,
    required this.text,
    required this.color,
    this.pulsing = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.2), blurRadius: 8),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
