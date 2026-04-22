import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../widgets/car_3d_visualization.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, sensorService, _) {
        final data = sensorService.currentData;

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            title: const Text('DRIVORA - Driver Assistant'),
            backgroundColor: AppTheme.darkSurface,
            elevation: 0,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryNeon.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('⚙️', style: TextStyle(fontSize: 20)),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: sensorService.isConnected
                      ? AppTheme.successGreen.withOpacity(0.2)
                      : AppTheme.warningYellow.withOpacity(0.2),
                  border: Border.all(
                    color: sensorService.isConnected
                        ? AppTheme.successGreen
                        : AppTheme.warningYellow,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    sensorService.isConnected ? '● Online' : '○ Offline',
                    style: TextStyle(
                      color: sensorService.isConnected
                          ? AppTheme.successGreen
                          : AppTheme.warningYellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: data != null
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 3D Car Visualization
                        Car3DVisualization(
                          speed: data.speed,
                          steeringAngle: data.steeringAngle,
                          brakeActive: data.brakeStatus,
                          leftSignal: data.leftSignal,
                          rightSignal: data.rightSignal,
                        ),
                        const SizedBox(height: 24),

                        // Quick Stats Grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            _buildStatCard(
                              context,
                              title: 'RPM',
                              value: '${data.rpm.toStringAsFixed(0)}',
                              subtitle: 'Engine Speed',
                              color: AppTheme.secondaryBlue,
                              icon: '⚡',
                            ),
                            _buildStatCard(
                              context,
                              title: 'Temperature',
                              value: '${data.temperature.toStringAsFixed(1)}°C',
                              subtitle: 'Engine Temp',
                              color: data.temperature > 100
                                  ? AppTheme.dangerRed
                                  : AppTheme.primaryNeon,
                              icon: '🌡️',
                            ),
                            _buildStatCard(
                              context,
                              title: 'Fuel',
                              value: '${data.fuelLevel.toStringAsFixed(0)}%',
                              subtitle: 'Remaining',
                              color: data.fuelLevel < 15
                                  ? AppTheme.dangerRed
                                  : AppTheme.successGreen,
                              icon: '⛽',
                            ),
                            _buildStatCard(
                              context,
                              title: 'Battery',
                              value: '${data.battery.toStringAsFixed(0)}%',
                              subtitle: 'System Power',
                              color: data.battery < 20
                                  ? AppTheme.dangerRed
                                  : AppTheme.primaryNeon,
                              icon: '🔋',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Status Panels
                        _buildStatusPanel(context, data),
                        const SizedBox(height: 24),

                        // Tire Pressures
                        _buildTirPressurePanel(context, data),
                        const SizedBox(height: 24),

                        // Connection Status
                        _buildConnectionPanel(context, sensorService),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        size: 64,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Data Available',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sensorService.connectionStatus,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => sensorService.simulateData(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Simulation'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryNeon,
                          foregroundColor: AppTheme.darkBackground,
                        ),
                      ),
                    ],
                  ),
                ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.warning),
                label: 'Alerts',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.analytics),
                label: 'Analytics',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required String icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardBackground,
            AppTheme.darkSurface,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context, SensorData data) {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vehicle Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryNeon,
                  ),
            ),
            const SizedBox(height: 12),
            _buildStatusLine(
              'Engine',
              data.engineStatus ? '✓ Running' : '✗ Off',
              data.engineStatus ? AppTheme.successGreen : AppTheme.textSecondary,
            ),
            _buildStatusLine(
              'Brake',
              data.brakeStatus ? '🛑 Applied' : '○ Released',
              data.brakeStatus ? AppTheme.dangerRed : AppTheme.successGreen,
            ),
            _buildStatusLine(
              'Signals',
              '${data.leftSignal ? 'L ' : ''}${data.rightSignal ? 'R ' : ''}${!data.leftSignal && !data.rightSignal ? 'Off' : ''}',
              AppTheme.warningYellow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLine(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            status,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTirPressurePanel(BuildContext context, SensorData data) {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tire Pressure',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryNeon,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTirePressureIndicator('FL', data.tirePressureFL),
                _buildTirePressureIndicator('FR', data.tirePressureFR),
                _buildTirePressureIndicator('RL', data.tirePressureRL),
                _buildTirePressureIndicator('RR', data.tirePressureRR),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTirePressureIndicator(String label, double pressure) {
    final color = pressure < 30 || pressure > 35
        ? AppTheme.dangerRed
        : AppTheme.successGreen;

    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              pressure.toStringAsFixed(1),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildConnectionPanel(
      BuildContext context, WiFiSensorService sensorService) {
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WiFi Sensor Connection',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.primaryNeon,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              sensorService.connectionStatus,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: sensorService.isSimulating
                  ? () => sensorService.stopSimulation()
                  : () => sensorService.simulateData(),
              style: ElevatedButton.styleFrom(
                backgroundColor: sensorService.isSimulating
                    ? AppTheme.dangerRed
                    : AppTheme.primaryNeon,
                foregroundColor: AppTheme.darkBackground,
              ),
              icon: Icon(
                sensorService.isSimulating ? Icons.stop : Icons.play_arrow,
              ),
              label: Text(
                sensorService.isSimulating ? 'Stop' : 'Start Sim',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
                ],
              ),
            ],
          ),
          _buildUnitHealthIndicators(service),
        ],
      ),
    );
  }

  Widget _buildUnitHealthIndicators(CANBusService service) {
    return Row(
      children: [
        _buildUnitIndicator('A', service.unitAHealth),
        const SizedBox(width: 8),
        _buildUnitIndicator('B', service.unitBHealth),
        const SizedBox(width: 8),
        _buildUnitIndicator('C', service.unitCHealth),
        const SizedBox(width: 8),
        _buildUnitIndicator('D', service.unitDHealth),
      ],
    );
  }

  Widget _buildUnitIndicator(String label, SystemHealth health) {
    final color = health.isConnected && health.sensorFunctional
        ? AppTheme.successGreen
        : health.isConnected
            ? AppTheme.warningYellow
            : AppTheme.dangerRed;

    return Tooltip(
      message: 'Unit $label: ${health.signalStrength}%',
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertIndicator(CANBusService service) {
    final hasCritical =
        service.activeAlerts.any((a) => a.severity == AlertSeverity.critical);

    return GestureDetector(
      onTap: () =>
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Active Safety Alerts - Review recommended'),
          )),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasCritical ? AppTheme.dangerRed : AppTheme.warningYellow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              '${service.activeAlerts.length} Active Alert${service.activeAlerts.length > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.darkSurface,
      selectedItemColor: AppTheme.primaryNeon,
      unselectedItemColor: AppTheme.primaryNeon.withOpacity(0.5),
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      onTap: (index) {
        setState(() => _selectedIndex = index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.radar),
          label: 'FCW',
          tooltip: 'Forward Collision Warning',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.visibility_off),
          label: 'Rear',
          tooltip: 'Rear Safety',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.balance),
          label: 'Dynamics',
          tooltip: 'COG & Rollover',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.timeline),
          label: 'LDW',
          tooltip: 'Lane Departure Warning',
        ),
      ],
    );
  }
}
