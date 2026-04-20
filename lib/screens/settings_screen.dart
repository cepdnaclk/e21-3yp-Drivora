import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  double _alertSensitivity = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.darkSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // WiFi Connection Section
          _buildSectionHeader(context, 'WiFi Connection'),
          _buildSettingTile(
            context,
            'WiFi Network',
            'Connected to network',
            Icons.wifi_tethering,
            AppTheme.primaryNeon,
            () {},
          ),
          _buildSettingTile(
            context,
            'IP Address',
            '192.168.1.100',
            Icons.public,
            AppTheme.secondaryBlue,
            () {},
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(context, 'Notifications'),
          _buildSwitchTile(
            context,
            'Enable Notifications',
            _notificationsEnabled,
            (value) {
              setState(() => _notificationsEnabled = value);
            },
            Icons.notifications_active,
          ),
          _buildSwitchTile(
            context,
            'Enable Vibration',
            _vibrationEnabled,
            (value) {
              setState(() => _vibrationEnabled = value);
            },
            Icons.vibration,
          ),
          const SizedBox(height: 24),

          // Alert Settings Section
          _buildSectionHeader(context, 'Alert Settings'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alert Sensitivity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _alertSensitivity,
                  onChanged: (value) {
                    setState(() => _alertSensitivity = value);
                  },
                  activeColor: AppTheme.primaryNeon,
                  inactiveColor: AppTheme.textSecondary.withOpacity(0.3),
                  divisions: 2,
                  label: _alertSensitivity < 0.33
                      ? 'Low'
                      : _alertSensitivity < 0.66
                          ? 'Medium'
                          : 'High',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(context, 'About'),
          _buildSettingTile(
            context,
            'App Version',
            '1.0.0',
            Icons.info,
            AppTheme.primaryNeon,
            () {},
          ),
          _buildSettingTile(
            context,
            'Build Number',
            '001',
            Icons.build,
            AppTheme.secondaryBlue,
            () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: AppTheme.primaryNeon,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryNeon.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryNeon.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryNeon),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.primaryNeon,
        ),
      ),
    );
  }
}
            title: 'Notifications',
            subtitle: 'Receive alert notifications',
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
          ),
          _buildSettingTile(
            title: 'Vibration',
            subtitle: 'Vibrate on alerts',
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() => _vibrationEnabled = value);
            },
          ),

          // Display Section
          _buildSectionHeader('Display'),
          _buildSettingTile(
            title: 'Dark Mode',
            subtitle: 'Always use dark theme',
            value: _darkMode,
            onChanged: (value) {
              setState(() => _darkMode = value);
            },
          ),

          // Alert Thresholds
          _buildSectionHeader('Alert Sensitivity'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sensitivity Level',
                      style: TextStyle(
                        color: DrivoraTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(_alertSensitivity * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: DrivoraTheme.primaryNeon,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                      elevation: 4,
                    ),
                    activeTrackColor: DrivoraTheme.primaryNeon,
                    inactiveTrackColor:
                        DrivoraTheme.dividerColor,
                    thumbColor: DrivoraTheme.primaryNeon,
                  ),
                  child: Slider(
                    min: 0,
                    max: 1,
                    value: _alertSensitivity,
                    onChanged: (value) {
                      setState(() => _alertSensitivity = value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Lower = Less sensitive (fewer alerts) | Higher = Very sensitive (more alerts)',
                  style: TextStyle(
                    color: DrivoraTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Device Settings
          _buildSectionHeader('Device Settings'),
          _buildSettingButton(
            title: 'Connect to Vehicle Device',
            subtitle: 'Set WiFi device IP address',
            icon: Icons.wifi_tethering,
            onPressed: () {
              _showConnectDialog();
            },
          ),
          _buildSettingButton(
            title: 'Calibrate Sensors',
            subtitle: 'Fine-tune sensor readings',
            icon: Icons.tune,
            onPressed: () {
              // Implement calibration
            },
          ),

          // About Section
          _buildSectionHeader('About'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DrivoraTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DrivoraTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'App Version',
                  style: TextStyle(
                    color: DrivoraTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '1.0.0',
                  style: TextStyle(
                    color: DrivoraTheme.primaryNeon,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Build Number',
                  style: TextStyle(
                    color: DrivoraTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '2026.04.19',
                  style: TextStyle(
                    color: DrivoraTheme.primaryNeon,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings saved!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DrivoraTheme.primaryNeon,
              foregroundColor: DrivoraTheme.backgroundDark,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save Settings'),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: DrivoraTheme.primaryNeon,
            ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DrivoraTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DrivoraTheme.dividerColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: DrivoraTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: DrivoraTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: DrivoraTheme.primaryNeon,
            inactiveThumbColor: DrivoraTheme.textTertiary,
            inactiveTrackColor: DrivoraTheme.dividerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: DrivoraTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DrivoraTheme.dividerColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: DrivoraTheme.primaryNeon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: DrivoraTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: DrivoraTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: DrivoraTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConnectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DrivoraTheme.surfaceLight,
        title: const Text('Connect to Device'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: '192.168.1.100',
            filled: true,
            fillColor: DrivoraTheme.backgroundDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: DrivoraTheme.dividerColor,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement connection logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connecting to ${controller.text}...'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DrivoraTheme.primaryNeon,
              foregroundColor: DrivoraTheme.backgroundDark,
            ),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }
}
