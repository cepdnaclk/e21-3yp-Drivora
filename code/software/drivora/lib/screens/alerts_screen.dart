import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

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

    // Load cloud alert history on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<WiFiSensorService>(context, listen: false).loadAlertHistory();
      }
    });
  }

  @override
  void dispose() {
    _emptyAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<WiFiSensorService>(
      builder: (context, svc, _) {
        // Show session history (deduped, newest first) — includes cloud fetched entries
        final all = svc.alertHistory;
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
                  hasActive: svc.activeAlerts.isNotEmpty,
                ),
                _FilterRow(
                  selected: _filterSeverity,
                  onSelect: (s) =>
                      setState(() => _filterSeverity = s == _filterSeverity ? null : s),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _EmptyState(anim: _emptyAnim, filtered: _filterSeverity != null)
                      : _AlertList(alerts: filtered),
                ),
              ],
            ),
          ),
        );
      },
    );
}

// ── TOP BAR ──────────────────────────────────────────────────────────────────
class _AlertsTopBar extends StatelessWidget {

  const _AlertsTopBar({required this.alertCount, required this.hasActive});
  final int alertCount;
  final bool hasActive;

  @override
  Widget build(BuildContext context) => Container(
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
                alertCount == 0
                    ? 'No events recorded'
                    : '$alertCount event${alertCount > 1 ? 's' : ''} · ${hasActive ? "ACTIVE" : "all clear"}',
                style: TextStyle(
                  fontSize: 12,
                  color: hasActive ? AppTheme.accentRed : const Color(0xFF6E6E73),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (hasActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accentRed,
                    boxShadow: [BoxShadow(color: AppTheme.accentRed.withOpacity(0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 6),
                const Text('ACTIVE', style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 9,
                    fontWeight: FontWeight.w900, color: AppTheme.accentRed, letterSpacing: 1)),
              ]),
            ),
        ],
      ),
    );
}

// ── FILTER ROW ────────────────────────────────────────────────────────────────
class _FilterRow extends StatelessWidget {

  const _FilterRow({required this.selected, required this.onSelect});
  final AlertSeverity? selected;
  final ValueChanged<AlertSeverity> onSelect;

  static const _filters = [
    (AlertSeverity.critical, 'CRITICAL', AppTheme.accentRed),
    (AlertSeverity.danger, 'DANGER', AppTheme.accentAmber),
    (AlertSeverity.warning, 'WARNING', Color(0xFFFF9F0A)),
    (AlertSeverity.info, 'INFO', AppTheme.accentBlue),
  ];

  @override
  Widget build(BuildContext context) => Container(
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

// ── ALERT LIST ────────────────────────────────────────────────────────────────
class _AlertList extends StatelessWidget {

  const _AlertList({required this.alerts});
  final List<SafetyAlert> alerts;

  @override
  Widget build(BuildContext context) => ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: alerts.length,
      itemBuilder: (context, i) => _AlertCard(
          key: ValueKey('${alerts[i].title}${alerts[i].timestamp.millisecondsSinceEpoch}'),
          alert: alerts[i],
          index: i,
        ),
    );
}

class _AlertCard extends StatefulWidget {

  const _AlertCard({super.key, required this.alert, required this.index});
  final SafetyAlert alert;
  final int index;

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

    Future.delayed(Duration(milliseconds: widget.index * 40), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final hm = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays > 0) return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}  $hm';
    if (diff.inHours > 0) return '${diff.inHours}h ago  $hm';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
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
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 11, color: Color(0xFFAEAEB2)),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimestamp(widget.alert.timestamp),
                                style: const TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 8,
                                  color: Color(0xFFAEAEB2),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ]),
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
      case AlertSeverity.danger:   return AppTheme.accentAmber;
      case AlertSeverity.warning:  return const Color(0xFFFF9F0A);
      case AlertSeverity.info:     return AppTheme.accentBlue;
    }
  }

  IconData _severityIcon(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return Icons.report_problem_rounded;
      case AlertSeverity.danger:   return Icons.warning_rounded;
      case AlertSeverity.warning:  return Icons.info_rounded;
      case AlertSeverity.info:     return Icons.notifications_rounded;
    }
  }

  String _severityLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return 'CRITICAL';
      case AlertSeverity.danger:   return 'DANGER';
      case AlertSeverity.warning:  return 'WARNING';
      case AlertSeverity.info:     return 'INFO';
    }
  }
}

class _AlertDetail extends StatelessWidget {

  const _AlertDetail({required this.alert, required this.color});
  final SafetyAlert alert;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
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
          _DetailChip('SEVERITY', _severityText(alert.severity),
              _severityColor(alert.severity)),
          const SizedBox(width: 12),
          _DetailChip(
            'TIME',
            '${alert.timestamp.hour.toString().padLeft(2, '0')}:'
            '${alert.timestamp.minute.toString().padLeft(2, '0')}',
            AppTheme.accentBlue,
          ),
        ],
      ),
    );

  String _severityText(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return 'CRITICAL';
      case AlertSeverity.danger:   return 'DANGER';
      case AlertSeverity.warning:  return 'WARNING';
      case AlertSeverity.info:     return 'INFO';
    }
  }

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return AppTheme.accentRed;
      case AlertSeverity.danger:   return AppTheme.accentAmber;
      case AlertSeverity.warning:  return const Color(0xFFFF9F0A);
      case AlertSeverity.info:     return AppTheme.accentBlue;
    }
  }
}

class _DetailChip extends StatelessWidget {

  const _DetailChip(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
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

// ── EMPTY STATE ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {

  const _EmptyState({required this.anim, required this.filtered});
  final AnimationController anim;
  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
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
