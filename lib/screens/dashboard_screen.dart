import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../widgets/car_3d_visualization.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: Consumer<WiFiSensorService>(
        builder: (context, service, _) {
          final data = service.currentData;
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(service),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        // 3D CAR VISUALIZATION (Tesla Style)
                        Car3DVisualization(
                          speed: data.speed,
                          lanePosition: data.lanePosition,
                          brakeActive: data.brakeActive,
                          leftSignal: data.leftSignal,
                          rightSignal: data.rightSignal,
                          tiltAngle: data.tiltAngle,
                        ),
                        const SizedBox(height: 24),
                        
                        // SAFETY SHIELD CORE (Units A, B, C, D)
                        _buildSafetyShieldGrid(data),
                        const SizedBox(height: 24),
                        
                        // REAL-TIME ALERT CENTER
                        if (service.activeAlerts.isNotEmpty) _buildAlertCenter(service.activeAlerts),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildSafetyControlBar(service),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(WiFiSensorService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DRIVORA U-ADAS', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              Text(service.isSimulating ? 'SAFETY SHIELD ACTIVE' : 'SYSTEMS STANDBY',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: service.isSimulating ? AppTheme.primaryNeon : Colors.white24, letterSpacing: 2)),
            ],
          ),
          Row(
            children: [
              _unitIndicator('A', service.currentData.unitAOnline),
              _unitIndicator('B', service.currentData.unitBOnline),
              _unitIndicator('C', service.currentData.unitCOnline),
              _unitIndicator('D', service.currentData.unitDOnline),
            ],
          )
        ],
      ),
    );
  }

  Widget _unitIndicator(String label, bool online) {
    final color = online ? AppTheme.primaryNeon : Colors.red;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      width: 24, height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.5), width: 1),
        color: color.withOpacity(0.05),
      ),
      child: Center(child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
    );
  }

  Widget _buildSafetyShieldGrid(DrivoraSensorData data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _safetyPanel('Unit A: Front Radar', 'TTC: ${data.ttc.toStringAsFixed(1)}s', 
            data.ttc < 3.0 ? AppTheme.dangerRed : AppTheme.primaryNeon, 'Collision Warning'),
        _safetyPanel('Unit D: AI Vision', 'POS: ${data.lanePosition > 0 ? "R" : "L"} ${data.lanePosition.abs().toStringAsFixed(2)}', 
            data.ldwActive ? AppTheme.warningYellow : AppTheme.secondaryBlue, 'Lane Departure'),
        _safetyPanel('Unit C: Dynamics', 'LAT-G: ${data.lateralG.toStringAsFixed(2)}', 
            data.tiltAngle.abs() > 15 ? AppTheme.dangerRed : AppTheme.successGreen, 'Stability Monitor'),
        _safetyPanel('Unit B: Rear Hub', 'SIDE: ${data.blindSpotLeftDist.toInt()}m | ${data.blindSpotRightDist.toInt()}m', 
            AppTheme.primaryNeon, 'Blind Spot Safety'),
      ],
    );
  }

  Widget _safetyPanel(String unit, String val, Color color, String feature) {
    return GlassmorphicContainer(
      width: double.infinity, height: double.infinity, borderRadius: 24, blur: 20, alignment: Alignment.center, border: 1,
      linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)]),
      borderGradient: LinearGradient(colors: [color.withOpacity(0.3), Colors.transparent]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(unit, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
            Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFamily: 'RobotoMono')),
            Text(feature, style: const TextStyle(fontSize: 9, color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCenter(List<SafetyAlert> alerts) {
    return Column(
      children: alerts.map((a) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed, size: 28),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
            Text(a.message, style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
            child: Text(a.unitSource, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
        ]),
      )).toList(),
    );
  }

  Widget _buildSafetyControlBar(WiFiSensorService service) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.security, color: Colors.white24),
          ElevatedButton(
            onPressed: service.isSimulating ? service.stopSimulation : service.startSafetySimulation,
            style: ElevatedButton.styleFrom(
              backgroundColor: service.isSimulating ? AppTheme.dangerRed : AppTheme.primaryNeon,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18)
            ),
            child: Text(service.isSimulating ? 'DISENGAGE SHIELD' : 'ENGAGE SAFETY SHIELD', 
              style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
          ),
          const Icon(Icons.wifi, color: Colors.white24),
        ],
      ),
    );
  }
}
