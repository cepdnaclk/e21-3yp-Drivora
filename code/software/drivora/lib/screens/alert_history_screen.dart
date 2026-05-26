import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/wifi_sensor_service.dart';
import '../theme/app_theme.dart';

class AlertHistoryScreen extends StatefulWidget {
  const AlertHistoryScreen({super.key});

  @override
  State<AlertHistoryScreen> createState() => _AlertHistoryScreenState();
}

class _AlertHistoryScreenState extends State<AlertHistoryScreen> {
  String _filterSeverity = 'All';
  late List<SafetyAlert> _filteredAlerts = [];

  @override
  void initState() {
    super.initState();
    _updateFilteredAlerts();
  }

  void _updateFilteredAlerts() {
    final sensorService = Provider.of<WiFiSensorService>(context, listen: false);
    final alerts = sensorService.activeAlerts;

    setState(() {
      if (_filterSeverity == 'All') {
        _filteredAlerts = alerts;
      } else {
        _filteredAlerts = alerts.where((alert) {
          switch (_filterSeverity) {
            case 'Critical':
              return alert.severity == AlertSeverity.critical;
            case 'Danger':
              return alert.severity == AlertSeverity.danger;
            case 'Warning':
              return alert.severity == AlertSeverity.warning;
            case 'Info':
              return alert.severity == AlertSeverity.info;
            default:
              return true;
          }
        }).toList();
      }
    });
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return AppTheme.accentRed;
      case AlertSeverity.danger:
        return AppTheme.accentRed;
      case AlertSeverity.warning:
        return AppTheme.accentAmber;
      case AlertSeverity.info:
        return AppTheme.accentBlue;
    }
  }

  IconData _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
      case AlertSeverity.danger:
        return Icons.warning_rounded;
      case AlertSeverity.warning:
        return Icons.error_outline_rounded;
      case AlertSeverity.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'ALERT HISTORY',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        elevation: 0,
        backgroundColor: AppTheme.panel,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            color: AppTheme.panel,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Filter: ',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ...[' All', 'Critical', 'Danger', 'Warning', 'Info'].map(
                    (severity) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(severity),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Alert list
          Expanded(
            child: Consumer<WiFiSensorService>(
              builder: (context, sensorService, _) {
                final alerts = sensorService.activeAlerts;

                if (alerts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 80,
                          color: AppTheme.accentGreen.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Alerts',
                          style: GoogleFonts.orbitron(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All systems operating normally',
                          style: GoogleFonts.rajdhani(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[alerts.length - 1 - index]; // Reverse order (newest first)
                    return _buildAlertCard(alert);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );

  Widget _buildFilterChip(String severity) {
    final isActive = _filterSeverity == severity;
    return GestureDetector(
      onTap: () {
        setState(() => _filterSeverity = severity);
        _updateFilteredAlerts();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive ? AppTheme.accentCyan : AppTheme.border,
          ),
          borderRadius: BorderRadius.circular(20),
          color: isActive ? AppTheme.accentCyan.withOpacity(0.2) : Colors.transparent,
        ),
        child: Text(
          severity,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isActive ? AppTheme.accentCyan : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(SafetyAlert alert) {
    final severityColor = _getSeverityColor(alert.severity);
    final severityIcon = _getSeverityIcon(alert.severity);
    final timeString = _formatTime(alert.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: severityColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: severityColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left indicator
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: severityColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),

            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: severityColor.withOpacity(0.15),
              ),
              child: Icon(
                severityIcon,
                color: severityColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          alert.title,
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.severity.name.toUpperCase(),
                          style: GoogleFonts.rajdhani(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: severityColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    alert.message,
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.source_rounded, size: 12, color: AppTheme.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        alert.unitSource,
                        style: GoogleFonts.rajdhani(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeString,
                        style: GoogleFonts.rajdhani(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
