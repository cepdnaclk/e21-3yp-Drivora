import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
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
            title: const Text('Analytics'),
            backgroundColor: AppTheme.darkSurface,
          ),
          body: history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Data Available',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAnalyticsCard(
                        context,
                        'Speed Analysis',
                        history,
                        (item) => item.speed,
                        'km/h',
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticsCard(
                        context,
                        'Temperature Analysis',
                        history,
                        (item) => item.temperature,
                        '°C',
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildAnalyticsCard(
    BuildContext context,
    String title,
    List data,
    Function(dynamic) getValue,
    String unit,
  ) {
    final values = data.map((item) => getValue(item) as double).toList();
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    final avg = values.fold<double>(0, (sum, val) => sum + val) / values.length;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryNeon.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.primaryNeon,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatIndicator(
                  'Max',
                  '${max.toStringAsFixed(1)}$unit',
                  AppTheme.dangerRed,
                ),
                _buildStatIndicator(
                  'Avg',
                  '${avg.toStringAsFixed(1)}$unit',
                  AppTheme.primaryNeon,
                ),
                _buildStatIndicator(
                  'Min',
                  '${min.toStringAsFixed(1)}$unit',
                  AppTheme.successGreen,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
