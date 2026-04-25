import 'package:flutter/material.dart';
<<<<<<< HEAD
=======
import 'package:flutter/services.dart';
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

<<<<<<< HEAD
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, sensorService, _) {
        final alerts = sensorService.activeAlerts;
        
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: const Text('Safety Event Log'),
            backgroundColor: AppTheme.darkSurface,
            actions: [
              if (alerts.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  onPressed: () => sensorService.clearAlerts(),
                ),
            ],
          ),
          body: alerts.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final color = _getAlertColor(alert.severity);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                            child: Icon(_getAlertIcon(alert.severity), color: color, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(alert.title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                                    Text(alert.unitSource, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(alert.message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
=======
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen>
    with SingleTickerProviderStateMixin {
  AlertSeverity? _filterSeverity;
  late AnimationController _emptyAnim;

  @override
  void initState() {
    super.initState();
    _emptyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emptyAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, svc, _) {
        final all = svc.activeAlerts;
        final filtered = _filterSeverity == null
            ? all
            : all.where((a) => a.severity == _filterSeverity).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF0F0F5),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _AlertsTopBar(
                  alertCount: all.length,
                  onClear: all.isEmpty
                      ? null
                      : () {
                    HapticFeedback.mediumImpact();
                    svc.clearAlerts();
                  },
                ),
                _FilterRow(
                  selected: _filterSeverity,
                  onSelect: (s) =>
                      setState(() => _filterSeverity = s == _filterSeverity ? null : s),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyState(anim: _emptyAnim, filtered: _filterSeverity != null)
                      : _AlertList(alerts: filtered, onDismiss: (alert) {
                    HapticFeedback.lightImpact();
                    // Individual dismiss — just clear all for now since model only has clearAll
                    svc.clearAlerts();
                  }),
                ),
              ],
            ),
          ),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        );
      },
    );
  }
<<<<<<< HEAD

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: AppTheme.successGreen.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text('All Systems Nominal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
          const Text('Safety Shield monitoring active', style: TextStyle(color: Colors.white38)),
=======
}

// ── TOP BAR ──────────────────────────────────
class _AlertsTopBar extends StatelessWidget {
  final int alertCount;
  final VoidCallback? onClear;

  const _AlertsTopBar({required this.alertCount, this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0x0A000000))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SAFETY LOG',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D1D1F),
                  letterSpacing: 2,
                ),
              ),
              Text(
                alertCount == 0 ? 'No active events' : '$alertCount event${alertCount > 1 ? 's' : ''} detected',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6E6E73),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (onClear != null)
            _ActionButton(
              icon: Icons.delete_sweep_rounded,
              label: 'CLEAR ALL',
              color: AppTheme.accentRed,
              onTap: onClear!,
            ),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        ],
      ),
    );
  }
<<<<<<< HEAD

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical: return AppTheme.dangerRed;
      case AlertSeverity.danger: return Colors.orange;
      case AlertSeverity.warning: return AppTheme.warningYellow;
      case AlertSeverity.info: return AppTheme.secondaryBlue;
    }
  }

  IconData _getAlertIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical: return Icons.report_problem;
      case AlertSeverity.danger: return Icons.warning_rounded;
      case AlertSeverity.warning: return Icons.info_outline;
      case AlertSeverity.info: return Icons.notifications_none;
    }
  }
}
=======
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FILTER ROW ────────────────────────────────
class _FilterRow extends StatelessWidget {
  final AlertSeverity? selected;
  final ValueChanged<AlertSeverity> onSelect;

  const _FilterRow({required this.selected, required this.onSelect});

  static const _filters = [
    (AlertSeverity.critical, 'CRITICAL', AppTheme.accentRed),
    (AlertSeverity.danger, 'DANGER', AppTheme.accentAmber),
    (AlertSeverity.warning, 'WARNING', Color(0xFFFF9F0A)),
    (AlertSeverity.info, 'INFO', AppTheme.accentBlue),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final (severity, label, color) = f;
            final isSelected = selected == severity;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(severity);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? color : color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? color : color.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : color,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── ALERT LIST ────────────────────────────────
class _AlertList extends StatelessWidget {
  final List<SafetyAlert> alerts;
  final ValueChanged<SafetyAlert> onDismiss;

  const _AlertList({required this.alerts, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: alerts.length,
      itemBuilder: (context, i) {
        return _AlertCard(
          key: ValueKey(alerts[i].title + alerts[i].message),
          alert: alerts[i],
          index: i,
        );
      },
    );
  }
}

class _AlertCard extends StatefulWidget {
  final SafetyAlert alert;
  final int index;

  const _AlertCard({Key? key, required this.alert, required this.index})
      : super(key: key);

  @override
  State<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<_AlertCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entrance;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(widget.alert.severity);
    final icon = _severityIcon(widget.alert.severity);
    final label = _severityLabel(widget.alert.severity);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _expanded = !_expanded);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Severity icon bubble
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withOpacity(0.2)),
                        ),
                        child: Icon(icon, color: color, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.alert.title,
                                    style: TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.alert.message,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFFAEAEB2),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                // Expanded detail panel
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _expanded
                      ? _AlertDetail(alert: widget.alert, color: color)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return AppTheme.accentRed;
      case AlertSeverity.danger: return AppTheme.accentAmber;
      case AlertSeverity.warning: return const Color(0xFFFF9F0A);
      case AlertSeverity.info: return AppTheme.accentBlue;
    }
  }

  IconData _severityIcon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return Icons.report_problem_rounded;
      case AlertSeverity.danger: return Icons.warning_rounded;
      case AlertSeverity.warning: return Icons.info_rounded;
      case AlertSeverity.info: return Icons.notifications_rounded;
    }
  }

  String _severityLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return 'CRITICAL';
      case AlertSeverity.danger: return 'DANGER';
      case AlertSeverity.warning: return 'WARNING';
      case AlertSeverity.info: return 'INFO';
    }
  }
}

class _AlertDetail extends StatelessWidget {
  final SafetyAlert alert;
  final Color color;

  const _AlertDetail({required this.alert, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _DetailChip('SOURCE', alert.unitSource, color),
          const SizedBox(width: 12),
          _DetailChip('STATUS', 'ACTIVE', AppTheme.accentRed),
          const SizedBox(width: 12),
          _DetailChip('RESPONSE', 'REQUIRED', AppTheme.accentAmber),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 8,
            color: Color(0xFF8E8E93),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── EMPTY STATE ───────────────────────────────
class _EmptyState extends StatelessWidget {
  final AnimationController anim;
  final bool filtered;

  const _EmptyState({required this.anim, required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: anim,
            builder: (context, _) => Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen
                    .withOpacity(0.05 + anim.value * 0.05),
                border: Border.all(
                  color: AppTheme.accentGreen.withOpacity(0.2 + anim.value * 0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.shield_rounded,
                size: 48,
                color: AppTheme.accentGreen.withOpacity(0.5 + anim.value * 0.3),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            filtered ? 'NO EVENTS IN THIS CATEGORY' : 'ALL SYSTEMS NOMINAL',
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.accentGreen,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Try a different severity filter'
                : 'Safety Shield monitoring active',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFAEAEB2),
            ),
          ),
        ],
      ),
    );
  }
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
