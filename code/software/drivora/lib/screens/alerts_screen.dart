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
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: const Text('Alerts & Warnings'),
            backgroundColor: AppTheme.darkSurface,
            actions: [
              if (sensorService.alerts.isNotEmpty)
                TextButton(
                  onPressed: () => sensorService.clearAlerts(),
                  child: const Text('Clear All'),
                ),
            ],
          ),
          body: sensorService.alerts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 64,
                        color: AppTheme.successGreen,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'All Clear!',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No active alerts',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sensorService.alerts.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final alert = sensorService.alerts[index];
                    final color = _getAlertColor(alert.type);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.2),
                            AppTheme.cardBackground,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getAlertIcon(alert.type),
                                color: color,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alert.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: color),
                                    ),
                                    Text(
                                      alert.message,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}:${alert.timestamp.second.toString().padLeft(2, '0')}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppTheme.textTertiary),
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

  Color _getAlertColor(AlertType type) {
    switch (type) {
      case AlertType.critical:
        return AppTheme.dangerRed;
      case AlertType.danger:
        return AppTheme.dangerRed;
      case AlertType.warning:
        return AppTheme.warningYellow;
      case AlertType.info:
        return AppTheme.secondaryBlue;
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.critical:
        return Icons.error;
      case AlertType.danger:
        return Icons.warning;
      case AlertType.warning:
        return Icons.info;
      case AlertType.info:
        return Icons.info_outline;
    }
  }
}

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DrivoraTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('Safety Alerts'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: DrivoraTheme.primaryNeon,
          unselectedLabelColor: DrivoraTheme.textSecondary,
          indicatorColor: DrivoraTheme.primaryNeon,
          tabs: const [
            Tab(text: 'All Alerts'),
            Tab(text: 'Critical'),
            Tab(text: 'Warnings'),
            Tab(text: 'Info'),
          ],
        ),
      ),
      body: Consumer<WiFiSensorService>(
        builder: (context, sensorService, _) {
          final alerts = sensorService.alerts;

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAlertsList(alerts, null),
              _buildAlertsList(alerts, AlertType.danger),
              _buildAlertsList(alerts, AlertType.warning),
              _buildAlertsList(alerts, AlertType.info),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAlertsList(List<Alert> allAlerts, AlertType? filterType) {
    final filtered = filterType == null
        ? allAlerts
        : allAlerts.where((a) => a.type == filterType).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: 64,
              color: DrivoraTheme.successGreen,
            ),
            const SizedBox(height: 16),
            Text(
              filterType == null
                  ? 'No alerts'
                  : 'No ${filterType.toString().split('.').last} alerts',
              style: const TextStyle(
                color: DrivoraTheme.textSecondary,
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final alert = filtered[filtered.length - 1 - index];
        final typeStr = alert.type == AlertType.danger
            ? 'danger'
            : alert.type == AlertType.warning
                ? 'warning'
                : 'info';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AlertCard(
            title: alert.title,
            message: alert.message,
            type: typeStr,
            onDismiss: () {
              // Implement dismiss logic
            },
          ),
        );
      },
    );
  }
}
