import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            title: const Text('Safety Shield Analytics'),
            backgroundColor: AppTheme.darkSurface,
          ),
          body: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.analytics_outlined, size: 64, color: Colors.white10),
                      const SizedBox(height: 16),
                      Text('Insufficient Data', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white30)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildSummaryCard(history),
                      const SizedBox(height: 20),
                      _buildMetricCard(
                        context,
                        'Unit A: Frontal Impact Risk (TTC)',
                        history,
                        (item) => item.ttc,
                        's',
                        reverse: true, // Lower is worse
                      ),
                      const SizedBox(height: 20),
                      _buildMetricCard(
                        context,
                        'Unit C: Stability Control (Lat-G)',
                        history,
                        (item) => item.lateralG.abs(),
                        'G',
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSummaryCard(List<DrivoraSensorData> history) {
    final avgSpeed = history.map((e) => e.speed).reduce((a, b) => a + b) / history.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.primaryNeon.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primaryNeon.withOpacity(0.2))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('AVG SPEED', '${avgSpeed.toInt()} KM/H'),
          _stat('STABILITY', history.any((e) => e.tiltAngle.abs() > 10) ? 'CAUTION' : 'NOMINAL'),
          _stat('VISION', 'OPTIMAL'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNeon)),
    ]);
  }

  Widget _buildMetricCard(BuildContext context, String title, List<DrivoraSensorData> history, double Function(DrivoraSensorData) extractor, String unit, {bool reverse = false}) {
    final values = history.map(extractor).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final avg = values.fold<double>(0, (sum, val) => sum + val) / values.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white05)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metric('MAX', max, unit, max > (reverse ? 2.0 : 0.5) ? AppTheme.dangerRed : AppTheme.primaryNeon),
              _metric('AVG', avg, unit, AppTheme.secondaryBlue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, double value, String unit, Color color) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
      Text('${value.toStringAsFixed(2)}$unit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
    ]);
  }
}
