import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wifi_sensor_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _audioAlerts = true;
  int _alertSensitivity = 5;
  int _audioVolume = 7;
  final double _radarSensitivity = 0.7;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alertSensitivity = prefs.getInt('alertSensitivity') ?? 5;
      _audioVolume = prefs.getInt('audioVolume') ?? 7;
      _audioAlerts = prefs.getBool('audioEnabled') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alertSensitivity', _alertSensitivity);
    await prefs.setInt('audioVolume', _audioVolume);
    await prefs.setBool('audioEnabled', _audioAlerts);
    
    // Update audio service
    if (mounted) {
      final wifiService = Provider.of<WiFiSensorService>(context, listen: false);
      wifiService.setAudioEnabled(_audioAlerts);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'SYSTEM SETTINGS',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppTheme.panel,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio & Alert Settings Section
          _buildSectionHeader('Audio & Alerts'),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              _buildSwitchTile(
                'Audio Alerts',
                'Enable sound notifications',
                _audioAlerts,
                (value) {
                  setState(() => _audioAlerts = value);
                  _saveSettings();
                },
              ),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 12),
              _buildSliderTile(
                'Alert Sensitivity',
                'How aggressive should alerts be',
                _alertSensitivity,
                1,
                10,
                (value) {
                  setState(() => _alertSensitivity = value.toInt());
                  _saveSettings();
                },
              ),
              const SizedBox(height: 16),
              const Divider(color: AppTheme.border, height: 1),
              const SizedBox(height: 12),
              _buildSliderTile(
                'Audio Volume',
                'Adjust alert sound volume',
                _audioVolume,
                0,
                10,
                (value) {
                  setState(() => _audioVolume = value.toInt());
                  _saveSettings();
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Hardware Calibration Section
          _buildSectionHeader('Hardware Configuration'),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              _buildInfoTile(
                'Front Unit (Radar)',
                'Range: 0-200m, Frequency: 77GHz',
                Icons.radar,
                AppTheme.accentBlue,
              ),
              const Divider(color: AppTheme.border, height: 1),
              _buildInfoTile(
                'Center Unit (Lean)',
                'Monitors vehicle lean angle',
                Icons.balance_rounded,
                AppTheme.accentCyan,
              ),
              const Divider(color: AppTheme.border, height: 1),
              _buildInfoTile(
                'Rear Unit (Blindspot)',
                'Proximity warning system',
                Icons.sensors,
                AppTheme.accentAmber,
              ),
              const Divider(color: AppTheme.border, height: 1),
              _buildInfoTile(
                'Lane Unit (Camera)',
                'Lane departure detection',
                Icons.videocam_rounded,
                AppTheme.accentGreen,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // System Information Section
          _buildSectionHeader('System Information'),
          const SizedBox(height: 8),
          _buildSettingsCard(
            children: [
              _buildInfoTile(
                'App Version',
                '1.0.0',
                Icons.info_outline,
                AppTheme.textMuted,
              ),
              const Divider(color: AppTheme.border, height: 1),
              _buildInfoTile(
                'Framework',
                'Flutter 3.0+',
                Icons.build_rounded,
                AppTheme.textMuted,
              ),
              const Divider(color: AppTheme.border, height: 1),
              _buildInfoTile(
                'Hardware Protocol',
                'CAN-Bus + WebSocket',
                Icons.settings_input_component,
                AppTheme.textMuted,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Action Buttons
          _buildSectionHeader('Maintenance'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderBlue),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surface,
            ),
            child: Column(
              children: [
                _buildActionButton(
                  'Recalibrate Hardware',
                  'Send calibration data to all units',
                  Icons.settings_backup_restore_rounded,
                  _showRecalibrateDialog,
                ),
                const Divider(color: AppTheme.border, height: 1),
                _buildActionButton(
                  'Test Audio Alerts',
                  'Play sample alert sounds',
                  Icons.volume_up_rounded,
                  _testAudioAlerts,
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );

  Widget _buildSectionHeader(String title) => Text(
      title,
      style: GoogleFonts.orbitron(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppTheme.accentCyan,
        letterSpacing: 2,
      ),
    );

  Widget _buildSettingsCard({required List<Widget> children}) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderBlue),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
      ),
      child: Column(children: children),
    );

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.accentCyan,
            inactiveThumbColor: AppTheme.textMuted,
          ),
        ],
      ),
    );

  Widget _buildSliderTile(
    String title,
    String subtitle,
    int value,
    int min,
    int max,
    Function(double) onChanged,
  ) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.rajdhani(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$value',
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: value.toString(),
            activeColor: AppTheme.accentCyan,
            inactiveColor: AppTheme.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );

  Widget _buildInfoTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.rajdhani(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) => Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentBlue.withOpacity(0.15),
                ),
                child: Icon(icon, color: AppTheme.accentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppTheme.accentBlue,
              ),
            ],
          ),
        ),
      ),
    );

  void _showRecalibrateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Recalibrate Hardware',
          style: GoogleFonts.rajdhani(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Text(
          'Park on level ground and keep the vehicle still. This will recalibrate all sensor units.',
          style: GoogleFonts.rajdhani(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: GoogleFonts.rajdhani(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performCalibration();
            },
            child: Text(
              'RECALIBRATE',
              style: GoogleFonts.rajdhani(
                color: AppTheme.accentCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _performCalibration() async {
    final wifiService = Provider.of<WiFiSensorService>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();

    final height = prefs.getDouble('vehicleHeight') ?? 1.57;
    final width = prefs.getDouble('vehicleWidth') ?? 1.56;

    await wifiService.sendCalibrationToHardware(height: height, width: width);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calibration command sent to hardware units',
            style: GoogleFonts.rajdhani(color: Colors.white),
          ),
          backgroundColor: AppTheme.accentGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _testAudioAlerts() {
    final wifiService = Provider.of<WiFiSensorService>(context, listen: false);
    if (!_audioAlerts) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Audio alerts are disabled. Enable them in settings.',
            style: GoogleFonts.rajdhani(color: Colors.white),
          ),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      return;
    }

    // Play test sequence
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Playing test audio sequence...',
          style: GoogleFonts.rajdhani(color: Colors.white),
        ),
        backgroundColor: AppTheme.accentBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _section(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Text(title, style: const TextStyle(color: AppTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
    );

  Widget _tile(String title, String subtitle, IconData icon, Color color) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white38)),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white12),
      ),
    );

  Widget _switchTile(String title, bool val, Function(bool) onChanged) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppTheme.cardBackground, borderRadius: BorderRadius.circular(15)),
      child: SwitchListTile(
        value: val,
        onChanged: onChanged,
        activeThumbColor: AppTheme.primaryNeon,
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
}
