import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../widgets/car_3d_visualization.dart';
import 'map_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const DashboardContent(),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, service, _) {
        final data = service.currentData;
        
        return Column(
          children: [
            _buildHeader(context, service),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Desktop/Wide view: 3-column Layout
                  if (constraints.maxWidth > 1000) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSidePanel(
                          width: 300,
                          title: 'FORWARD SYSTEMS',
                          children: [
                            _ForwardCard(data: data),
                            _LaneCard(data: data),
                            _CanBusCard(),
                          ],
                        ),
                        Expanded(
                          child: _buildCenterDisplay(service, data),
                        ),
                        _buildSidePanel(
                          width: 300,
                          title: 'REAR & DYNAMICS',
                          children: [
                            _RearCard(data: data),
                            _DynamicsCard(data: data),
                            _SafetyScoreCard(),
                          ],
                        ),
                      ],
                    );
                  } else {
                    // Mobile view: Single Column
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildCenterDisplay(service, data, isMobile: true),
                        const SizedBox(height: 20),
                        const _PanelHeader(title: 'SYSTEM MODULES'),
                        _ForwardCard(data: data),
                        const SizedBox(height: 12),
                        _LaneCard(data: data),
                        const SizedBox(height: 12),
                        _RearCard(data: data),
                        const SizedBox(height: 12),
                        _DynamicsCard(data: data),
                        const SizedBox(height: 12),
                        _SafetyScoreCard(),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WiFiSensorService service) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: AppTheme.textPrimary, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('DRIVORA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 3)),
            ],
          ),
          Row(
            children: [
              _ShieldBadge(active: service.isConnected),
              const SizedBox(width: 20),
              const _RealTimeClock(),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())),
            icon: const Icon(Icons.map_outlined, color: AppTheme.accentBlue),
          ),
        ],
      ),
    );
  }

  Widget _buildSidePanel({required double width, required String title, required List<Widget> children}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        border: Border(
          right: title.contains('FORWARD') ? const BorderSide(color: AppTheme.border) : BorderSide.none,
          left: title.contains('REAR') ? const BorderSide(color: AppTheme.border) : BorderSide.none,
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PanelHeader(title: title),
          ...children.expand((w) => [w, const SizedBox(height: 12)]).toList(),
        ],
      ),
    );
  }

  Widget _buildCenterDisplay(WiFiSensorService service, DrivoraSensorData data, {bool isMobile = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 0 : 30),
      child: Column(
        children: [
          if (service.activeAlerts.isNotEmpty) _AlertBanner(alert: service.activeAlerts.first),
          const SizedBox(height: 10),
          Car3DVisualization(
            speed: data.speed,
            lanePosition: data.lanePosition,
            brakeActive: data.brakeActive,
            leftSignal: data.leftSignal,
            rightSignal: data.rightSignal,
            tiltAngle: data.tiltAngle,
          ),
          const SizedBox(height: 24),
          _buildTelemetryStrip(data),
          const SizedBox(height: 30),
          _SystemControls(service: service),
        ],
      ),
    );
  }

  Widget _buildTelemetryStrip(DrivoraSensorData data) {
    return Row(
      children: [
        _TelemetryTile(val: '${data.ttc.toStringAsFixed(1)}s', label: 'TTC', color: AppTheme.accentGreen),
        const SizedBox(width: 10),
        _TelemetryTile(val: '${data.lanePosition.abs().toStringAsFixed(2)}m', label: 'LANE OFFSET', color: AppTheme.accentBlue),
        const SizedBox(width: 10),
        _TelemetryTile(val: '${data.lateralG.toStringAsFixed(2)}g', label: 'LATERAL G', color: AppTheme.accentAmber),
        const SizedBox(width: 10),
        const _TelemetryTile(val: '98%', label: 'SAFETY SCORE', color: AppTheme.accentGreen),
      ],
    );
  }
}

// --- Specialized UI Components ---

class _PanelHeader extends StatelessWidget {
  final String title;
  const _PanelHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 9, letterSpacing: 2.5, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
    );
  }
}

class _ForwardCard extends StatelessWidget {
  final DrivoraSensorData data;
  const _ForwardCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final color = data.ttc < 3.0 ? AppTheme.accentRed : AppTheme.accentGreen;
    return _ArtCard(
      color: color,
      icon: Icons.radar,
      status: data.ttc < 3.0 ? 'ALERT' : 'CLEAR',
      title: 'Forward Collision Warning',
      subtitle: 'FCW · UNIT A · 24GHz DOPPLER',
      value: data.ttc.toStringAsFixed(1),
      unit: 's TTC',
      desc: 'Time-to-collision nominal',
      chips: const ['ESP32-C3', 'CDM324×2'],
    );
  }
}

class _LaneCard extends StatelessWidget {
  final DrivoraSensorData data;
  const _LaneCard({required this.data});
  @override
  Widget build(BuildContext context) {
    final color = data.ldwActive ? AppTheme.accentAmber : AppTheme.accentBlue;
    return _ArtCard(
      color: color,
      icon: Icons.add_road,
      status: data.ldwActive ? 'WARN' : 'CENTERED',
      title: 'Lane Departure Warning',
      subtitle: 'LDW · UNIT D · AI-VISION',
      value: data.lanePosition.abs().toStringAsFixed(2),
      unit: 'm offset',
      desc: 'Lane position nominal',
      customChild: Container(
        height: 48, margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.1))),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: 2, color: color.withOpacity(0.2)),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: 100 + (data.lanePosition * 50),
              child: Container(width: 18, height: 28, decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(4))),
            ),
          ],
        ),
      ),
      chips: const ['ESP32-S3', 'OV2640'],
    );
  }
}

class _RearCard extends StatelessWidget {
  final DrivoraSensorData data;
  const _RearCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return _ArtCard(
      color: AppTheme.accentAmber,
      icon: Icons.settings_input_antenna,
      status: 'ALL CLEAR',
      title: 'Side & Rear Safety',
      subtitle: 'BSM · UNIT B · ULTRASONIC',
      value: data.blindSpotLeftDist.toInt().toString(),
      unit: 'm nearest',
      desc: 'No objects in blind zone',
      chips: const ['ESP32-C3', 'JSN-SR04T'],
    );
  }
}

class _DynamicsCard extends StatelessWidget {
  final DrivoraSensorData data;
  const _DynamicsCard({required this.data});
  @override
  Widget build(BuildContext context) {
    return _ArtCard(
      color: AppTheme.accentRed,
      icon: Icons.balance,
      status: 'STABLE',
      title: 'Dynamics & Rollover',
      subtitle: 'COG · UNIT C · 9-AXIS IMU',
      value: data.tiltAngle.abs().toStringAsFixed(1),
      unit: '° tilt',
      desc: 'Lateral force nominal',
      chips: const ['ESP32-C3', 'BNO055'],
    );
  }
}

class _ArtCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String status;
  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final String desc;
  final List<String> chips;
  final Widget? customChild;

  const _ArtCard({required this.color, required this.icon, required this.status, required this.title, required this.subtitle, required this.value, required this.unit, required this.desc, required this.chips, this.customChild});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
          Text(subtitle, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: AppTheme.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (customChild != null) customChild!,
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontFamily: 'Orbitron', fontSize: 26, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: chips.map((c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.border)),
              child: Text(c, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _TelemetryTile extends StatelessWidget {
  final String val;
  final String label;
  final Color color;
  const _TelemetryTile({required this.val, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.shadow),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontFamily: 'Orbitron', fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 9, letterSpacing: 1, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  final bool active;
  const _ShieldBadge({required this.active});
  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accentGreen : AppTheme.accentAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          if (active) ...[
            const _BlinkingDot(),
            const SizedBox(width: 8),
          ],
          Text(
            active ? 'SAFETY SHIELD ACTIVE' : 'SYSTEM STANDBY',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _ctrl, child: Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)));
  }
}

class _RealTimeClock extends StatefulWidget {
  const _RealTimeClock();
  @override
  State<_RealTimeClock> createState() => _RealTimeClockState();
}

class _RealTimeClockState extends State<_RealTimeClock> {
  String _time = '';
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _time = DateTime.now().toString().substring(11, 19));
    });
  }
  @override
  void dispose() { _timer.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Text(_time, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: AppTheme.textSecondary));
  }
}

class _AlertBanner extends StatelessWidget {
  final SafetyAlert alert;
  const _AlertBanner({required this.alert});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.accentRed.withOpacity(0.06), border: Border.all(color: AppTheme.accentRed.withOpacity(0.2)), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.report_gmailerrorred_rounded, color: AppTheme.accentRed, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: const TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(alert.message, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              ],
            ),
          ),
          Text(alert.unitSource, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _CanBusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CAN-BUS BACKBONE', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('4-CORE SHIELDED · ACTIVE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: AppTheme.accentGreen)),
          const SizedBox(height: 4),
          const Text('PWR · GND · CAN_H · CAN_L', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SafetyScoreCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SAFETY SCORE', style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
              Text('98', style: TextStyle(fontFamily: 'Orbitron', fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
            ],
          ),
          SizedBox(
            width: 50, height: 50,
            child: CircularProgressIndicator(value: 0.98, strokeWidth: 5, color: AppTheme.accentGreen, backgroundColor: AppTheme.accentGreen.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

class _SystemControls extends StatelessWidget {
  final WiFiSensorService service;
  const _SystemControls({required this.service});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.border), boxShadow: AppTheme.shadow),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ControlIcon(icon: Icons.wifi, active: service.currentSource == DataSource.liveWiFi, label: 'LIVE WiFi'),
          ElevatedButton(
            onPressed: service.isConnected ? service.stopAllStreams : service.startSafetySimulation,
            style: ElevatedButton.styleFrom(
              backgroundColor: service.isConnected ? AppTheme.accentRed : AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(service.isConnected ? 'DISENGAGE' : 'ENGAGE SAFETY SHIELD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          _ControlIcon(icon: Icons.data_usage_rounded, active: service.currentSource == DataSource.rawData, label: 'DATA DEMO', onTap: service.startRawDataDemo),
        ],
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String label;
  final VoidCallback? onTap;
  const _ControlIcon({required this.icon, required this.active, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: active ? AppTheme.accentBlue : AppTheme.textSecondary.withOpacity(0.3), size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: active ? AppTheme.accentBlue : AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
