import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';

class AlertSoundsScreen extends StatefulWidget {
  const AlertSoundsScreen({super.key});

  @override
  State<AlertSoundsScreen> createState() => _AlertSoundsScreenState();
}

class _AlertSoundsScreenState extends State<AlertSoundsScreen> {
  final AudioService _audioService = AudioService();

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'ALERT SOUNDS',
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
          _buildSectionHeader('Audio Test Center'),
          const SizedBox(height: 16),
          _buildAlertTestCard(
            'Collision Alert',
            '1250 Hz - Emergency',
            Icons.car_crash,
            AppTheme.accentRed,
            _audioService.playCollisionAlert,
          ),
          const SizedBox(height: 12),
          _buildAlertTestCard(
            'Lane Departure',
            '1100 Hz - Lane Warning',
            Icons.directions,
            AppTheme.accentAmber,
            _audioService.playLaneAlert,
          ),
          const SizedBox(height: 12),
          _buildAlertTestCard(
            'Obstacle Proximity',
            'Progressive - Rear Alert',
            Icons.sensors,
            AppTheme.accentCyan,
            _audioService.playCollisionAlert,
          ),
          const SizedBox(height: 12),
          _buildAlertTestCard(
            'Drowsiness Alert',
            '980 Hz - Lean Warning',
            Icons.warning_amber,
            AppTheme.accentAmber,
            _audioService.playSystemAlert,
          ),
          const SizedBox(height: 12),
          _buildAlertTestCard(
            'Information',
            '800 Hz - General Notification',
            Icons.info_outline,
            AppTheme.accentGreen,
            _audioService.playGeneralAlert,
          ),
          const SizedBox(height: 12),
          _buildAlertTestCard(
            'System Alert',
            '700 Hz - System Health',
            Icons.settings_input_composite,
            AppTheme.accentBlue,
            _audioService.playSystemAlert,
          ),
          const SizedBox(height: 12),
          _buildAlertTestCard(
            'Calibration Success',
            'Ascending Tones',
            Icons.check_circle_outline,
            AppTheme.accentGreen,
            _audioService.playCalibrationSuccess,
          ),
          const SizedBox(height: 32),
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

  Widget _buildAlertTestCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderBlue),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.15),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.rajdhani(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.2),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
}
