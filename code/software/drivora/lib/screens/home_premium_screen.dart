import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/wifi_sensor_service.dart';
import '../widgets/car_3d_visualization.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'alerts_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class HomePremiumScreen extends StatefulWidget {
  const HomePremiumScreen({Key? key}) : super(key: key);

  @override
  State<HomePremiumScreen> createState() => _HomePremiumScreenState();
}

class _HomePremiumScreenState extends State<HomePremiumScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeController,
        child: CustomScrollView(
          slivers: [
            // Premium Header
            SliverAppBar(
              expandedHeight: 100,
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.panel,
              elevation: 8,
              shadowColor: Colors.black.withOpacity(0.1),
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DRIVORA',
                          style: GoogleFonts.orbitron(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            letterSpacing: 3,
                          ),
                        ),
                        Text(
                          'Advanced Driver Assistance System',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Content
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium 3D Car Visualization Card
                      _buildCar3DCard(),
                      const SizedBox(height: 40),

                      // Quick Stats
                      _buildQuickStats(),
                      const SizedBox(height: 40),

                      // Navigation Buttons Section
                      Text(
                        'NAVIGATION',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Navigation Grid
                      _buildNavigationGrid(context),
                      const SizedBox(height: 40),

                      // System Status
                      _buildSystemStatus(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCar3DCard() {
    return Consumer<WiFiSensorService>(
      builder: (context, sensorService, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.panel, AppTheme.background],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.shadowLg,
            border: Border.all(
              color: AppTheme.border,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Card Header
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
                      bottom: BorderSide(
                        color: AppTheme.border,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '3D VEHICLE STATUS',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
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

                // 3D Car Visualization
                SizedBox(
                  height: 350,
                  child: Car3DVisualization(
                    speed: sensorService.speed,
                    lanePosition: sensorService.lanePosition,
                    tiltAngle: sensorService.tiltAngle,
                    brakeActive: sensorService.brakeActive,
                    leftSignal: sensorService.leftSignal,
                    rightSignal: sensorService.rightSignal,
                  ),
                ),

                // Card Footer - Quick Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.border,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildFooterStat(
                        'SPEED',
                        '${sensorService.speed.toStringAsFixed(1)} KM/H',
                        AppTheme.accentBlue,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppTheme.border,
                      ),
                      _buildFooterStat(
                        'STATUS',
                        sensorService.systemStatus,
                        AppTheme.accentGreen,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppTheme.border,
                      ),
                      _buildFooterStat(
                        'SAFETY',
                        '${(sensorService.safetyScore * 100).toStringAsFixed(0)}%',
                        AppTheme.accentAmber,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooterStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.orbitron(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.rajdhani(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return Consumer<WiFiSensorService>(
      builder: (context, sensorService, _) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'ACTIVE ALERTS',
                '${sensorService.activeAlerts.length}',
                AppTheme.accentRed,
                Icons.warning_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'SENSORS',
                'ONLINE',
                AppTheme.accentGreen,
                Icons.sensors_rounded,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'CONNECTIVITY',
                'STABLE',
                AppTheme.accentBlue,
                Icons.cloud_done_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.1),
            color.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.orbitron(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.rajdhani(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationGrid(BuildContext context) {
    final navItems = [
      NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        color: AppTheme.accentBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        ),
      ),
      NavItem(
        icon: Icons.map_rounded,
        label: 'Navigation',
        color: AppTheme.accentGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        ),
      ),
      NavItem(
        icon: Icons.notifications_active_rounded,
        label: 'Alerts',
        color: AppTheme.accentRed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AlertsScreen()),
        ),
      ),
      NavItem(
        icon: Icons.analytics_rounded,
        label: 'Analytics',
        color: AppTheme.accentAmber,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
        ),
      ),
      NavItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        ),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: navItems.map((item) => _buildNavButton(item)).toList(),
    );
  }

  Widget _buildNavButton(NavItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              item.color.withOpacity(0.15),
              item.color.withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: item.color.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.color.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 40,
                  color: item.color,
                ),
                const SizedBox(height: 12),
                Text(
                  item.label,
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Consumer<WiFiSensorService>(
      builder: (context, sensorService, _) {
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
                    'SYSTEM STATUS',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatusItem('FCW System', sensorService.fcwActive),
                  _buildStatusItem('LDW System', sensorService.ldwActive),
                  _buildStatusItem('Data Source', sensorService.dataSource != 'None'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusItem(String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.accentGreen : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
