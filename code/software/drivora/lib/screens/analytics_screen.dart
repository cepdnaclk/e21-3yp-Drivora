import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';

// ─── palette (mirrors dashboard) ─────────────────────────────────────────────
const _kBg      = Color(0xFF080B12);
const _kSurface = Color(0xFF0C0F1A);
const _kBorder  = Color(0xFF1C2236);
const _kGreen   = Color(0xFF34C759);
const _kAmber   = Color(0xFFFFB020);
const _kRed     = Color(0xFFFF3B30);
const _kText1   = Color(0xFFF0F4FF);
const _kText2   = Color(0xFF6B7A99);

// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // null = all time; 7 = last 7 days; 30 = last 30 days
  int? _filterDays = 7;

  static const _filterOptions = [
    _FilterOption('Last 7 Days',  7),
    _FilterOption('Last 30 Days', 30),
    _FilterOption('All Time',     null),
  ];

  @override
  Widget build(BuildContext context) => Consumer<WiFiSensorService>(
    builder: (context, svc, _) {
      final score    = svc.driverScore(_filterDays);
      final total    = svc.totalEventCount(_filterDays);
      final front    = svc.frontEventCount(_filterDays);
      final rear     = svc.rearEventCount(_filterDays);
      final stab     = svc.stabilityEventCount(_filterDays);
      final lane     = svc.laneEventCount(_filterDays);
      final incidents = svc.incidentsForRange(_filterDays);

      return Scaffold(
        backgroundColor: _kBg,
        body: SafeArea(
          bottom: false,
          child: Row(children: [
            // ── LEFT: Score gauge — 25% of screen width ─────────────────────
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.25,
              child: _ScorePanel(score: score, total: total),
            ),
            Container(width: 1, color: _kBorder),
            // ── RIGHT: Counters + history ────────────────────────────────────
            Expanded(
              child: Column(children: [
                // Counter row
                _CounterRow(
                  total: total, front: front,
                  rear: rear, stab: stab, lane: lane,
                ),
                Container(height: 1, color: _kBorder),
                // History header + filter
                _HistoryHeader(
                  filterDays: _filterDays,
                  options: _filterOptions,
                  onChanged: (v) => setState(() => _filterDays = v),
                  count: incidents.length,
                ),
                // Scrollable event list
                Expanded(
                  child: incidents.isEmpty
                      ? _EmptyHistory()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                          itemCount: incidents.length,
                          itemBuilder: (ctx, i) =>
                              _IncidentCard(record: incidents[i]),
                        ),
                ),
              ]),
            ),
          ]),
        ),
      );
    },
  );
}

class _FilterOption {
  const _FilterOption(this.label, this.days);
  final String label;
  final int?   days;
}

// ─────────────────────────────────────────────────────────────────────────────
// LEFT PANEL — Score gauge
// ─────────────────────────────────────────────────────────────────────────────
class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.score, required this.total});
  final int score;
  final int total;

  Color get _scoreColor {
    if (score >= 80) return _kGreen;
    if (score >= 50) return _kAmber;
    return _kRed;
  }

  String get _scoreBand {
    if (score >= 80) return 'GOOD';
    if (score >= 50) return 'WARNING';
    return 'POOR';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    // Reserve ~117px for the labels/badge around the gauge; gauge fills the rest.
    final availH    = (c.maxHeight.isFinite && c.maxHeight > 0) ? c.maxHeight : 400.0;
    final gaugeSize = (availH - 117.0).clamp(60.0, 200.0);
    final gap1      = (availH * 0.04).clamp(4.0, 20.0);
    final gap2      = (availH * 0.03).clamp(4.0, 16.0);
    final gap3      = (availH * 0.03).clamp(4.0, 18.0);
    final scoreFsz  = (gaugeSize * 0.26).clamp(18.0, 52.0);
    final pctFsz    = (gaugeSize * 0.09).clamp(10.0, 18.0);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Overall Score',
            style: GoogleFonts.inter(
                color: _kText2, fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        SizedBox(height: gap1),
        SizedBox(
          width: gaugeSize,
          height: gaugeSize,
          child: CustomPaint(
            painter: _GaugePainter(score: score, color: _scoreColor),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$score',
                      style: GoogleFonts.inter(
                          color: _scoreColor, fontSize: scoreFsz,
                          fontWeight: FontWeight.w800, height: 1)),
                  Text('%',
                      style: GoogleFonts.inter(
                          color: _scoreColor.withOpacity(0.7),
                          fontSize: pctFsz, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: gap2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: _scoreColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _scoreColor.withOpacity(0.35)),
          ),
          child: Text(_scoreBand,
              style: GoogleFonts.inter(
                  color: _scoreColor, fontSize: 15,
                  fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        SizedBox(height: gap3),
        Text('$total Total Events',
            style: GoogleFonts.inter(
                color: _kText2, fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  });
}

// ─── Circular gauge painter ────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.score, required this.color});
  final int   score;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width  / 2;
    final cy     = size.height / 2;
    final radius = math.min(cx, cy) - 10;

    const startAngle = math.pi * 0.75;   // 135°
    const sweepFull  = math.pi * 1.50;   // 270° total sweep

    // Track (background arc)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepFull, false,
      Paint()
        ..color = _kBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    // Score arc
    final sweepScore = sweepFull * score.clamp(0, 100) / 100;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startAngle, sweepScore, false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );

    // Glow on score arc tip
    if (sweepScore > 0.05) {
      final tipAngle = startAngle + sweepScore;
      final tipX = cx + radius * math.cos(tipAngle);
      final tipY = cy + radius * math.sin(tipAngle);
      canvas.drawCircle(
        Offset(tipX, tipY), 7,
        Paint()
          ..color = color.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.score != score || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNTER ROW — 5 stat boxes
// ─────────────────────────────────────────────────────────────────────────────
class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.total, required this.front, required this.rear,
    required this.stab,  required this.lane,
  });
  final int total, front, rear, stab, lane;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 72,
    child: Row(children: [
      _CounterBox(count: total, label: 'Total Events',          color: _kText1),
      _CounterBox(count: front, label: 'Front Collision',       color: _kRed),
      _CounterBox(count: rear,  label: 'Rear Blindspot',        color: _kAmber),
      _CounterBox(count: stab,  label: 'Stability',             color: _kAmber),
      _CounterBox(count: lane,  label: 'Lane Departure',        color: _kGreen, last: true),
    ]),
  );
}

class _CounterBox extends StatelessWidget {
  const _CounterBox({
    required this.count, required this.label, required this.color,
    this.last = false,
  });
  final int    count;
  final String label;
  final Color  color;
  final bool   last;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      decoration: BoxDecoration(
        border: Border(
          right: last ? BorderSide.none : const BorderSide(color: _kBorder),
        ),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(count.toString().padLeft(2, '0'),
            style: GoogleFonts.inter(
                color: color, fontSize: 26,
                fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: _kText2, fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3),
            maxLines: 2),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY HEADER with filter dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.filterDays, required this.options,
    required this.onChanged, required this.count,
  });
  final int? filterDays;
  final List<_FilterOption> options;
  final ValueChanged<int?> onChanged;
  final int count;

  String get _currentLabel => options
      .firstWhere((o) => o.days == filterDays,
          orElse: () => options.last)
      .label;

  @override
  Widget build(BuildContext context) => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(children: [
      Text('Critical Event History',
          style: GoogleFonts.inter(
              color: _kText1, fontSize: 13,
              fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _kRed.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kRed.withOpacity(0.30)),
        ),
        child: Text('$count',
            style: GoogleFonts.inter(
                color: _kRed, fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
      const Spacer(),
      // Filter dropdown
      GestureDetector(
        onTapDown: (d) async {
          final result = await showMenu<int?>(
            context: context,
            position: RelativeRect.fromLTRB(
                d.globalPosition.dx - 120,
                d.globalPosition.dy + 8,
                d.globalPosition.dx,
                d.globalPosition.dy + 100),
            color: const Color(0xFF141826),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: _kBorder)),
            items: options.map((o) => PopupMenuItem<int?>(
              value: o.days,
              child: Text(o.label,
                  style: GoogleFonts.inter(
                      color: o.days == filterDays ? _kGreen : _kText1,
                      fontSize: 12, fontWeight: FontWeight.w500)),
            )).toList(),
          );
          if (result != filterDays) onChanged(result ?? (filterDays == null ? 7 : null));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_currentLabel,
                style: GoogleFonts.inter(
                    color: _kText2, fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: _kText2, size: 16),
          ]),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INCIDENT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.record});
  final Map<String, dynamic> record;

  Color _severityColor(int sev) {
    if (sev >= 3) return _kRed;
    if (sev == 2) return _kAmber;
    return _kText2;
  }

  String _severityLabel(int sev) {
    if (sev >= 3) return 'CRITICAL';
    if (sev == 2) return 'WARNING';
    return 'INFO';
  }

  IconData _sourceIcon(String src) {
    switch (src) {
      case 'front':    return Icons.arrow_upward_rounded;
      case 'rear':     return Icons.arrow_downward_rounded;
      case 'center':   return Icons.radio_button_checked_outlined;
      case 'lane':     return Icons.edit_road_rounded;
      default:         return Icons.warning_amber_rounded;
    }
  }

  String _sourceLabel(String src) {
    switch (src) {
      case 'front':    return 'Front';
      case 'rear':     return 'Rear';
      case 'center':   return 'Stability';
      case 'lane':     return 'Lane';
      default:         return 'Multiple';
    }
  }

  String _timeAgo(int tsMs) {
    final dt   = DateTime.fromMillisecondsSinceEpoch(tsMs);
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0)    return '${diff.inDays}d ago';
    if (diff.inHours > 0)   return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  String _formatDate(int tsMs) {
    final dt = DateTime.fromMillisecondsSinceEpoch(tsMs);
    final h  = dt.hour.toString().padLeft(2, '0');
    final m  = dt.minute.toString().padLeft(2, '0');
    final d  = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo  $h:$m';
  }

  String _detail() {
    final src = record['sourceUnit'] as String? ?? '';
    switch (src) {
      case 'front':
        final dist = (record['frontDistanceCm'] as num?)?.toDouble();
        final spd  = (record['frontSpeedCmS']   as num?)?.toDouble();
        if (dist != null && dist > 0) {
          final dm = (dist / 100).toStringAsFixed(1);
          if (spd != null && spd > 0) {
            final sk = (spd * 0.036).toStringAsFixed(0);
            return '${dm}m  ·  $sk km/h';
          }
          return '${dm}m';
        }
        return '';
      case 'rear':
        final dist = (record['rearNearestDistanceCm'] as num?)?.toDouble();
        final zone = record['rearZone'] as String?;
        if (dist != null && dist > 0) {
          final dm = (dist / 100).toStringAsFixed(1);
          return zone != null ? '${dm}m  ·  $zone zone' : '${dm}m';
        }
        return '';
      case 'center':
        final roll  = (record['leanRollDeg']  as num?)?.toDouble();
        final pitch = (record['leanPitchDeg'] as num?)?.toDouble();
        if (roll != null || pitch != null) {
          return 'Roll ${roll?.toStringAsFixed(1) ?? '—'}°  ·  Pitch ${pitch?.toStringAsFixed(1) ?? '—'}°';
        }
        return '';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sev    = (record['severity'] as int?) ?? 2;
    final src    = record['sourceUnit'] as String? ?? 'multiple';
    final title  = record['title']     as String? ?? 'Safety Event';
    final msg    = record['message']   as String? ?? '';
    final tsMs   = (record['realTimeMs'] as int?) ?? (record['receivedAtMs'] as int?) ?? 0;
    final color  = _severityColor(sev);
    final detail = _detail();

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(children: [
        // Source icon
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(_sourceIcon(src), color: color, size: 18),
        ),
        const SizedBox(width: 10),

        // Title + message + detail
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.inter(
                      color: color, fontSize: 12,
                      fontWeight: FontWeight.w700),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (msg.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(msg,
                    style: GoogleFonts.inter(
                        color: _kText2, fontSize: 10,
                        fontWeight: FontWeight.w400),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (detail.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(detail,
                    style: GoogleFonts.inter(
                        color: _kText1.withOpacity(0.6), fontSize: 10,
                        fontWeight: FontWeight.w500)),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Right: source badge + time
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.30)),
            ),
            child: Text(_severityLabel(sev),
                style: GoogleFonts.inter(
                    color: color, fontSize: 8,
                    fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          const SizedBox(height: 3),
          Text(_sourceLabel(src),
              style: GoogleFonts.inter(
                  color: _kText2, fontSize: 9,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(tsMs > 0 ? _timeAgo(tsMs) : '—',
              style: GoogleFonts.inter(
                  color: _kText2, fontSize: 9)),
          if (tsMs > 0)
            Text(_formatDate(tsMs),
                style: GoogleFonts.inter(
                    color: _kText2.withOpacity(0.6), fontSize: 8)),
        ]),
      ]),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.shield_outlined, color: _kGreen.withOpacity(0.35), size: 40),
      const SizedBox(height: 10),
      Text('No Events Recorded',
          style: GoogleFonts.inter(
              color: _kGreen, fontSize: 13,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('Drive with Drivora connected to log events.',
          style: GoogleFonts.inter(
              color: _kText2, fontSize: 11)),
    ]),
  );
}
