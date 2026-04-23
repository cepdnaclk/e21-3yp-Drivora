import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';

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
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: AppTheme.successGreen.withOpacity(0.2)),
          const SizedBox(height: 20),
          const Text('All Systems Nominal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.successGreen)),
          const Text('Safety Shield monitoring active', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

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
