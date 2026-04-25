import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
=======
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

<<<<<<< HEAD
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, sensorService, _) {
        final history = sensorService.dataHistory;

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: const Text('SAFETY ANALYTICS'),
            backgroundColor: AppTheme.darkSurface,
            elevation: 0,
          ),
          body: history.isEmpty
              ? _buildEmptyState()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummarySection(history),
                      const SizedBox(height: 30),
                      const Text('REAL-TIME TELEMETRY', style: TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 2)),
                      const SizedBox(height: 20),
                      _buildChartCard('COLLISION RISK (TTC)', history, (d) => d.ttc, AppTheme.dangerRed),
                      const SizedBox(height: 20),
                      _buildChartCard('STABILITY (LAT-G)', history, (d) => d.lateralG.abs(), AppTheme.primaryNeon),
                      const SizedBox(height: 20),
                      _buildChartCard('VEHICLE SPEED (KM/H)', history, (d) => d.speed, AppTheme.secondaryBlue),
                    ],
                  ),
                ),
=======
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _reveal;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade = CurvedAnimation(parent: _reveal, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, svc, _) {
        final history = svc.dataHistory;
        final alerts = svc.activeAlerts;
        final current = svc.currentData;

        final avgSpeed = history.isEmpty
            ? 0.0
            : history.map((e) => e.speed).reduce((a, b) => a + b) /
            history.length;
        final maxSpeed = history.isEmpty
            ? 0.0
            : history.map((e) => e.speed).reduce((a, b) => a > b ? a : b);
        final avgTtc = history.isEmpty
            ? 0.0
            : history.map((e) => e.ttc).reduce((a, b) => a + b) /
            history.length;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F0F5),
          body: SafeArea(
            bottom: false,
            child: FadeTransition(
              opacity: _fade,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _AnalyticsHeader(svc: svc)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _StatsRow(
                        avgSpeed: avgSpeed,
                        maxSpeed: maxSpeed,
                        avgTtc: avgTtc,
                        threatCount: alerts.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _SectionLabel('VELOCITY HISTORY'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _SparklineCard(
                        history: history,
                        label: 'Speed (KM/H)',
                        color: AppTheme.accentBlue,
                        getValue: (d) => d.speed,
                        maxY: 120,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: _SparklineCard(
                        history: history,
                        label: 'TTC (s)',
                        color: AppTheme.accentAmber,
                        getValue: (d) => d.ttc,
                        maxY: 10,
                        dangerLine: 2.2,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _SectionLabel('SAFETY EVENT LOG'),
                    ),
                  ),
                  alerts.isEmpty
                      ? SliverToBoxAdapter(
                    child: _AnalyticsEmptyAlerts(),
                  )
                      : SliverPadding(
                    padding:
                    const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) => _AnalyticsAlertRow(
                          alert: alerts[i],
                          index: i,
                        ),
                        childCount: alerts.length,
                      ),
                    ),
                  ),
                  if (alerts.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        );
      },
    );
  }
<<<<<<< HEAD

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 20),
          const Text('WAITING FOR SYSTEM DATA...', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildSummarySection(List<DrivoraSensorData> history) {
    final avgSpeed = history.map((e) => e.speed).reduce((a, b) => a + b) / history.length;
    final maxG = history.map((e) => e.lateralG.abs()).reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(child: _summaryTile('AVG SPEED', '${avgSpeed.toInt()}', 'KM/H', AppTheme.primaryNeon)),
        const SizedBox(width: 15),
        Expanded(child: _summaryTile('MAX FORCE', maxG.toStringAsFixed(2), 'G', AppTheme.dangerRed)),
      ],
    );
  }

  Widget _summaryTile(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(width: 5),
              Text(unit, style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
=======
}

// ── HEADER ────────────────────────────────────
class _AnalyticsHeader extends StatelessWidget {
  final WiFiSensorService svc;
  const _AnalyticsHeader({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                'ANALYTICS',
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1D1D1F),
                  letterSpacing: 2,
                ),
              ),
              Text(
                svc.isConnected
                    ? '${svc.dataHistory.length} samples recorded'
                    : 'Engage shield to collect data',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73)),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: svc.isConnected
                  ? AppTheme.accentGreen.withOpacity(0.1)
                  : const Color(0xFFF0F0F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: svc.isConnected
                    ? AppTheme.accentGreen.withOpacity(0.3)
                    : const Color(0xFFD1D1D6),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: svc.isConnected
                        ? AppTheme.accentGreen
                        : const Color(0xFFAEAEB2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  svc.isConnected ? 'LIVE' : 'IDLE',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: svc.isConnected
                        ? AppTheme.accentGreen
                        : const Color(0xFFAEAEB2),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        ],
      ),
    );
  }
<<<<<<< HEAD

  Widget _buildChartCard(String title, List<DrivoraSensorData> history, double Function(DrivoraSensorData) extractor, Color color) {
    final spots = history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), extractor(e.value))).toList();
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
=======
}

// ── STATS ROW ─────────────────────────────────
class _StatsRow extends StatelessWidget {
  final double avgSpeed;
  final double maxSpeed;
  final double avgTtc;
  final int threatCount;

  const _StatsRow({
    required this.avgSpeed,
    required this.maxSpeed,
    required this.avgTtc,
    required this.threatCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'AVG SPEED',
            value: avgSpeed.toInt().toString(),
            unit: 'km/h',
            color: AppTheme.accentBlue,
            icon: Icons.speed_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'PEAK SPEED',
            value: maxSpeed.toInt().toString(),
            unit: 'km/h',
            color: AppTheme.accentAmber,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'THREATS',
            value: threatCount.toString(),
            unit: 'active',
            color: threatCount > 0 ? AppTheme.accentRed : AppTheme.accentGreen,
            icon: threatCount > 0
                ? Icons.warning_rounded
                : Icons.shield_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
<<<<<<< HEAD
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots.length > 50 ? spots.sublist(spots.length - 50) : spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withOpacity(0.1),
                    ),
                  ),
                ],
=======
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFFAEAEB2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 7,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E8E93),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── SECTION LABEL ─────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.accentBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6E6E73),
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ── SPARKLINE CARD ────────────────────────────
class _SparklineCard extends StatelessWidget {
  final List<DrivoraSensorData> history;
  final String label;
  final Color color;
  final double Function(DrivoraSensorData) getValue;
  final double maxY;
  final double? dangerLine;

  const _SparklineCard({
    required this.history,
    required this.label,
    required this.color,
    required this.getValue,
    required this.maxY,
    this.dangerLine,
  });

  @override
  Widget build(BuildContext context) {
    final samples = history.length > 80
        ? history.sublist(history.length - 80)
        : history;
    final values = samples.map(getValue).toList();
    final current = values.isEmpty ? 0.0 : values.last;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                label,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E8E93),
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                current.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 72,
            child: values.isEmpty
                ? _NoDataPlaceholder(color: color)
                : CustomPaint(
              size: const Size(double.infinity, 72),
              painter: _SparklinePainter(
                values: values,
                color: color,
                maxY: maxY,
                dangerLine: dangerLine,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
<<<<<<< HEAD
=======

class _NoDataPlaceholder extends StatelessWidget {
  final Color color;
  const _NoDataPlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'ENGAGE SHIELD TO RECORD',
        style: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 9,
          color: color.withOpacity(0.3),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double maxY;
  final double? dangerLine;

  _SparklinePainter({
    required this.values,
    required this.color,
    required this.maxY,
    this.dangerLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final w = size.width;
    final h = size.height;
    final step = w / (values.length - 1).clamp(1, double.infinity);

    // Fill path
    final fillPath = Path();
    fillPath.moveTo(0, h);
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = h - (values[i].clamp(0, maxY) / maxY) * h;
      if (i == 0) {
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * step;
        final prevY = h - (values[i - 1].clamp(0, maxY) / maxY) * h;
        final cpX = (prevX + x) / 2;
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.15), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Line path
    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * step;
      final y = h - (values[i].clamp(0, maxY) / maxY) * h;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        final prevX = (i - 1) * step;
        final prevY = h - (values[i - 1].clamp(0, maxY) / maxY) * h;
        final cpX = (prevX + x) / 2;
        linePath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Danger line
    if (dangerLine != null) {
      final dy = h - (dangerLine!.clamp(0, maxY) / maxY) * h;
      canvas.drawLine(
        Offset(0, dy),
        Offset(w, dy),
        Paint()
          ..color = AppTheme.accentRed.withOpacity(0.4)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }

    // Current value dot
    final lastX = (values.length - 1) * step;
    final lastY = h - (values.last.clamp(0, maxY) / maxY) * h;
    canvas.drawCircle(
      Offset(lastX, lastY),
      4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values;
}

// ── ALERT ROW ─────────────────────────────────
class _AnalyticsAlertRow extends StatelessWidget {
  final SafetyAlert alert;
  final int index;

  const _AnalyticsAlertRow({required this.alert, required this.index});

  @override
  Widget build(BuildContext context) {
    final color = _color(alert.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.warning_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6E6E73),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                alert.unitSource,
                style: const TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _color(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return AppTheme.accentRed;
      case AlertSeverity.danger: return AppTheme.accentAmber;
      case AlertSeverity.warning: return const Color(0xFFFF9F0A);
      case AlertSeverity.info: return AppTheme.accentBlue;
    }
  }
}

class _AnalyticsEmptyAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 44,
            color: AppTheme.accentGreen.withOpacity(0.4),
          ),
          const SizedBox(height: 12),
          const Text(
            'NO EVENTS DETECTED',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.accentGreen,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'System operating within safe parameters',
            style: TextStyle(fontSize: 12, color: Color(0xFFAEAEB2)),
          ),
        ],
      ),
    );
  }
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
