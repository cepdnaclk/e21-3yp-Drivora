import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

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
        );
      },
    );
  }

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
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, List<DrivoraSensorData> history, double Function(DrivoraSensorData) extractor, Color color) {
    final spots = history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), extractor(e.value))).toList();
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
