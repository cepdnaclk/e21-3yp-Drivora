import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _audioAlerts = true;
  double _radarSensitivity = 0.7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('System Configuration'),
        backgroundColor: AppTheme.darkSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section('Hardware Calibration'),
          _tile('Unit A: Radar Range', '2.5s TTC Threshold', Icons.radar, AppTheme.primaryNeon),
          _tile('Unit D: Camera Offset', 'Center-aligned', Icons.camera_enhance, AppTheme.secondaryBlue),
          const SizedBox(height: 24),
          
          _section('Safety Parameters'),
          _switchTile('Audio Collision Warnings', _audioAlerts, (v) => setState(() => _audioAlerts = v)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Radar Sensitivity', style: TextStyle(fontSize: 12, color: Colors.white38)),
          ),
          Slider(
            value: _radarSensitivity,
            activeColor: AppTheme.primaryNeon,
            onChanged: (v) => setState(() => _radarSensitivity = v),
          ),
          const SizedBox(height: 24),
          
          _section('Diagnostic Info'),
          _tile('Firmware', 'v2.4.1-Stable', Icons.memory, Colors.white24),
          _tile('CAN-Bus Load', '14% - Nominal', Icons.settings_input_component, AppTheme.successGreen),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Text(title, style: const TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
    );
  }

  Widget _tile(String title, String subtitle, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white05)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white38)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white12),
      ),
    );
  }

  Widget _switchTile(String title, bool val, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(15)),
      child: SwitchListTile(
        value: val,
        onChanged: onChanged,
        activeColor: AppTheme.primaryNeon,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
