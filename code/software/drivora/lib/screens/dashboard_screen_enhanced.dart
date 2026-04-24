import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/wifi_sensor_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../widgets/car_3d_visualization.dart';
import 'map_screen.dart';
import '../widgets/advanced_road_visualization.dart';

class DashboardScreenEnhanced extends StatefulWidget {
  const DashboardScreenEnhanced({Key? key}) : super(key: key);

  @override
  State<DashboardScreenEnhanced> createState() => _DashboardScreenEnhancedState();
}

class _DashboardScreenEnhancedState extends State<DashboardScreenEnhanced>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  bool _showAlerts = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<WiFiSensorService>(
        builder: (context, service, _) {
          return CustomScrollView(
            slivers: [
              // Premium Header
              _buildEnhancedHeader(context, service),

              // Main Content - 4 Box Grid System
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Real-time Road Visualization with Lane Departure
                      _buildRoadVisualization(service),
                      const SizedBox(height: 32),

                      // Alert Section (Collapsible)
                      if (service.activeAlerts.isNotEmpty)
                        _buildAlertSection(service),

                      const SizedBox(height: 32),

                      // 4-Box Grid Layout with 3D Animations
                      GridView.count(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 1200 ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 20,
                        crossAxisSpacing: 20,
                        childAspectRatio: 1.1,
                        children: [
                          _build3DMetricBox(
                            context,
                            icon: Icons.speed_rounded,
                            title: 'SPEED',
                            value: '${service.speed.toStringAsFixed(1)}',
                            unit: 'KM/H',
                            color: AppTheme.accentBlue,
                            animationValue: _pulseController.value,
                            animationType: 'pulse',
                          ),
                          _build3DMetricBox(
                            context,
                            icon: Icons.warning_amber_rounded,
                            title: 'FCW SYSTEM',
                            value: service.fcwActive ? 'ACTIVE' : 'READY',
                            unit: 'FORWARD COLLISION',
                            color: service.fcwActive
                                ? AppTheme.accentRed
                                : AppTheme.accentGreen,
                            animationValue: _pulseController.value,
                            animationType: 'scale',
                          ),
                          _build3DMetricBox(
                            context,
                            icon: Icons.road_rounded,
                            title: 'LDW SYSTEM',
                            value: service.ldwActive ? 'ACTIVE' : 'READY',
                            unit: 'LANE DEPARTURE',
                            color: service.ldwActive
                                ? AppTheme.accentAmber
                                : AppTheme.accentGreen,
                            animationValue: _pulseController.value,
                            animationType: 'rotate',
                          ),
                          _build3DMetricBox(
                            context,
                            icon: Icons.shield_rounded,
                            title: 'SAFETY SCORE',
                            value:
                                '${(service.safetyScore * 100).toStringAsFixed(0)}',
                            unit: '%',
                            color: AppTheme.accentGreen,
                            animationValue: _rotationController.value,
                            animationType: 'rotate3d',
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // System Status Panel
                      _buildSystemStatusPanel(service),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEnhancedHeader(BuildContext context, WiFiSensorService service) {
    return SliverAppBar(
      expandedHeight: 80,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.panel,
      elevation: 8,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.accentBlue.withOpacity(0.1),
                AppTheme.accentGreen.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DRIVORA DASHBOARD',
                      style: GoogleFonts.orbitron(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: 2,
                      ),
                    ),
                    Text(
                      service.status,
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        color: AppTheme.accentGreen,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: service.isConnected
                            ? AppTheme.accentGreen
                            : AppTheme.accentRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        service.isConnected ? 'CONNECTED' : 'DISCONNECTED',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('MAP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        elevation: 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoadVisualization(WiFiSensorService service) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.panel, AppTheme.background],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadowLg,
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.topRight,
                  colors: [
                    AppTheme.accentBlue.withOpacity(0.1),
                    AppTheme.accentGreen.withOpacity(0.1),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REAL-TIME VEHICLE TRACKING',
                    style: GoogleFonts.orbitron(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentGreen,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentGreen,
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Road Visualization with Lane Lines
            SizedBox(
              height: 300,
              child: AdvancedRoadVisualization(
                speed: service.speed,
                lanePosition: service.lanePosition,
                ldwActive: service.ldwActive,
                brakeActive: service.brakeActive,
                leftSignal: service.leftSignal,
                rightSignal: service.rightSignal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertSection(WiFiSensorService service) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentRed.withOpacity(0.15),
            AppTheme.accentRed.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: AppTheme.accentRed.withOpacity(0.5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Alert Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.accentRed.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: AppTheme.accentRed,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'ACTIVE ALERTS (${service.activeAlerts.length})',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _showAlerts = !_showAlerts),
                  child: Icon(
                    _showAlerts
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppTheme.accentRed,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          // Alerts List
          if (_showAlerts)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: service.activeAlerts
                    .map(
                      (alert) => _buildAlertItem(alert),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(SafetyAlert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          border: Border.all(
            color: AppTheme.accentRed.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentRed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.description,
                    style: GoogleFonts.rajdhani(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DMetricBox(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String unit,
    required Color color,
    required double animationValue,
    required String animationType,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background Animation
              _buildBoxAnimation(animationType, animationValue, color),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon with animation
                    Transform.scale(
                      scale: animationType == 'scale'
                          ? 1.0 + (animationValue * 0.2)
                          : 1.0,
                      child: Transform.rotate(
                        angle: animationType == 'rotate'
                            ? animationValue * 2 * math.pi
                            : 0,
                        child: Icon(
                          icon,
                          size: 48,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      title,
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Main Value - Large Text
                    Text(
                      value,
                      style: GoogleFonts.rajdhani(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: color,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Unit
                    Text(
                      unit,
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoxAnimation(
    String type,
    double value,
    Color color,
  ) {
    switch (type) {
      case 'pulse':
        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.1 + (value * 0.1)),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );

      case 'rotate':
        return Positioned.fill(
          child: Transform.rotate(
            angle: value * 2 * math.pi,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 2,
                ),
              ),
            ),
          ),
        );

      case 'rotate3d':
        return Positioned.fill(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * 2 * math.pi),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
        );

      default:
        return SizedBox.expand(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
    }
  }

  Widget _buildSystemStatusPanel(WiFiSensorService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentGreen.withOpacity(0.1),
            AppTheme.accentBlue.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: AppTheme.accentGreen.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM DIAGNOSTICS',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OPERATIONAL',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDiagnosticItem('FCW', service.fcwActive),
              _buildDiagnosticItem('LDW', service.ldwActive),
              _buildDiagnosticItem('BSM', true),
              _buildDiagnosticItem('Connected', service.isConnected),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.accentGreen : AppTheme.textSecondary,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.accentGreen,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
