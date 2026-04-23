import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusCard extends StatelessWidget {
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CircularProgressCard extends StatelessWidget {
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
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  final String title;
  final String message;
  final String type; // 'danger', 'warning', 'info'
  final VoidCallback? onDismiss;

  const AlertCard({
    Key? key,
    required this.title,
    required this.message,
    required this.type,
    this.onDismiss,
  }) : super(key: key);

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
    }
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

class StatisticsChart extends StatelessWidget {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
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
                        ),
                      ),
                    ],
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }
}

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color? borderColor;

  const GlassmorphicCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 16,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
