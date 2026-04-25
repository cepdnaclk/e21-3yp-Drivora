<<<<<<< HEAD
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

=======
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/wifi_sensor_service.dart';
import '../services/audio_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import '../widgets/car_3d_visualization.dart';
import 'alerts_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';
import 'account_screen.dart';

// ─────────────────────────────────────────────
//  ROOT SHELL
// ─────────────────────────────────────────────
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
<<<<<<< HEAD
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  bool _showAlerts = false;
=======
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _navGlowCtrl;

  final List<Widget> _pages = const [
    DashboardContent(),
    MapScreen(),
    AnalyticsScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
=======
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _navGlowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  }

  @override
  void dispose() {
<<<<<<< HEAD
    _pulseController.dispose();
    _rotationController.dispose();
=======
    _navGlowCtrl.dispose();
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
<<<<<<< HEAD
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
=======
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: _currentIndex,
        glowAnim: _navGlowCtrl,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = i);
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        },
      ),
    );
  }
<<<<<<< HEAD

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
=======
}

// ─────────────────────────────────────────────
//  PREMIUM NAVIGATION BAR
// ─────────────────────────────────────────────
class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final AnimationController glowAnim;
  final ValueChanged<int> onTap;

  const _PremiumNavBar({
    required this.currentIndex,
    required this.glowAnim,
    required this.onTap,
  });

  static const _items = [
    _NavItem(Icons.speed_rounded, 'DRIVE'),
    _NavItem(Icons.map_rounded, 'MAP'),
    _NavItem(Icons.analytics_rounded, 'DATA'),
    _NavItem(Icons.notifications_rounded, 'ALERTS'),
    _NavItem(Icons.tune_rounded, 'SYSTEM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60 + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: AppTheme.panel,
        border: const Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: AppTheme.shadow,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final selected = i == currentIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _items[i].icon,
                    size: 20,
                    color: selected ? AppTheme.accentBlue : AppTheme.textSecondary.withOpacity(0.4),
                  ),
                  Text(
                    _items[i].label,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: selected ? AppTheme.accentBlue : AppTheme.textSecondary.withOpacity(0.4),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
                    ),
                  ),
                ],
              ),
<<<<<<< HEAD
            ),
          ],
=======
            );
          }),
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        ),
      ),
    );
  }
<<<<<<< HEAD

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
=======
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({Key? key}) : super(key: key);

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent>
    with TickerProviderStateMixin {
  final AudioService _audio = AudioService();
  OverlayEntry? _alertOverlay;
  String? _lastAlertTitle;

  @override
  void dispose() {
    _removeAlertOverlay();
    _audio.stop();
    super.dispose();
  }

  void _removeAlertOverlay() {
    _alertOverlay?.remove();
    _alertOverlay = null;
    _lastAlertTitle = null;
  }

  void _showOverlayAlert(SafetyAlert alert) {
    if (_lastAlertTitle == alert.title) return;
    _removeAlertOverlay();
    
    _lastAlertTitle = alert.title;
    _audio.playCriticalSound();

    _alertOverlay = OverlayEntry(
      builder: (context) => _BigAlertOverlay(
        alert: alert,
        onDismiss: () {
          _removeAlertOverlay();
        },
      ),
    );

    Overlay.of(context).insert(_alertOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, service, _) {
        final data = service.currentData;
        final activeAlerts = service.activeAlerts;

        // Auto-manage alert popup
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (activeAlerts.isNotEmpty) {
            _showOverlayAlert(activeAlerts.first);
          } else {
            if (_alertOverlay != null) {
              _removeAlertOverlay();
              _audio.stop();
            }
          }
        });

        return Container(
          color: AppTheme.background,
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, service),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      children: [
                        // HERO UNIT: 3D Visualization
                        Expanded(flex: 14, child: _buildHeroUnit(data)),
                        const SizedBox(height: 10),
                        // MODULE MATRIX: 4 Mini-Boxes
                        Expanded(flex: 6, child: _buildSensorMatrix(data)),
                        const SizedBox(height: 10),
                        // TELEMETRY STRIP
                        _buildTelemetryStrip(data),
                      ],
                    ),
                  ),
                ),
                _buildEngageButton(service),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WiFiSensorService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.panel,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('DRIVORA U-ADAS', 
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: service.isConnected ? AppTheme.accentGreen : AppTheme.accentAmber,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  service.isConnected ? 'ACTIVE' : 'STANDBY',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountScreen())),
                icon: const Icon(Icons.account_circle_outlined, color: AppTheme.accentBlue, size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroUnit(DrivoraSensorData data) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.shadow,
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Car3DVisualization(
          speed: data.speed,
          lanePosition: data.lanePosition,
          brakeActive: data.brakeActive,
          leftSignal: data.leftSignal,
          rightSignal: data.rightSignal,
          tiltAngle: data.tiltAngle,
        ),
      ),
    );
  }

  Widget _buildSensorMatrix(DrivoraSensorData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: (constraints.maxWidth / 2) / (constraints.maxHeight / 2),
          children: [
            _SensorBox(
              icon: Icons.radar_rounded,
              label: 'RADAR',
              value: '${data.ttc.toStringAsFixed(1)}s',
              color: data.ttc < 3.0 ? AppTheme.accentRed : AppTheme.accentGreen,
              danger: data.ttc < 3.0,
              progress: (data.ttc / 10.0).clamp(0.0, 1.0),
              type: _MeterType.arc,
            ),
            _SensorBox(
              icon: Icons.remove_road_rounded,
              label: 'VISION',
              value: '${data.lanePosition.abs().toStringAsFixed(2)}m',
              color: data.ldwActive ? AppTheme.accentAmber : AppTheme.accentBlue,
              danger: data.ldwActive,
              progress: (1.0 - data.lanePosition.abs()).clamp(0.0, 1.0),
              type: _MeterType.linear,
            ),
            _SensorBox(
              icon: Icons.balance_rounded,
              label: 'CHASSIS',
              value: '${data.tiltAngle.abs().toStringAsFixed(1)}°',
              color: data.tiltAngle.abs() > 15 ? AppTheme.accentRed : AppTheme.accentGreen,
              danger: data.tiltAngle.abs() > 15,
              progress: (data.tiltAngle.abs() / 30.0).clamp(0.0, 1.0),
              type: _MeterType.gyro,
            ),
            _SensorBox(
              icon: Icons.sensors_rounded,
              label: 'REAR',
              value: '${data.blindSpotLeftDist.toInt()}m',
              color: AppTheme.accentAmber,
              danger: data.blindSpotLeftDist < 5,
              progress: (data.blindSpotLeftDist / 15.0).clamp(0.0, 1.0),
              type: _MeterType.waves,
            ),
          ],
        );
      }
    );
  }

  Widget _buildTelemetryStrip(DrivoraSensorData data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _telemetryItem('LAT-G', data.lateralG.toStringAsFixed(2), AppTheme.accentGreen),
          _telemetryItem('SPEED', '${data.speed.toInt()}', AppTheme.accentBlue),
          _telemetryItem('SCORE', '98%', AppTheme.accentAmber),
        ],
      ),
    );
  }

  Widget _telemetryItem(String label, String val, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(val, style: TextStyle(fontFamily: 'Orbitron', fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 8, color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEngageButton(WiFiSensorService service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(color: AppTheme.panel, border: Border(top: BorderSide(color: AppTheme.border))),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: service.isConnected ? service.stopAllStreams : service.startSafetySimulation,
          style: ElevatedButton.styleFrom(
            backgroundColor: service.isConnected ? AppTheme.accentRed : AppTheme.accentBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(service.isConnected ? 'DISENGAGE SHIELD' : 'ENGAGE SAFETY SHIELD', 
            style: const TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold, fontSize: 10)),
        ),
      ),
    );
  }
}

class _BigAlertOverlay extends StatefulWidget {
  final SafetyAlert alert;
  final VoidCallback onDismiss;

  const _BigAlertOverlay({required this.alert, required this.onDismiss});

  @override
  State<_BigAlertOverlay> createState() => _BigAlertOverlayState();
}

class _BigAlertOverlayState extends State<_BigAlertOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Full screen pulse overlay
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) => Container(
              color: AppTheme.accentRed.withOpacity(0.05 + (_pulseController.value * 0.1)),
            ),
          ),
          
          // Big alert banner
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.02),
                  child: child,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.report_problem_rounded, color: Colors.white, size: 60),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.alert.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.alert.message.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MeterType { arc, linear, gyro, waves }

class _SensorBox extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool danger;
  final double progress;
  final _MeterType type;

  const _SensorBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.danger,
    required this.progress,
    required this.type,
  });

  @override
  State<_SensorBox> createState() => _SensorBoxState();
}

class _SensorBoxState extends State<_SensorBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.danger ? widget.color : widget.color.withOpacity(0.15), 
          width: widget.danger ? 2 : 1,
        ),
        boxShadow: AppTheme.shadow,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BoxMeterPainter(
                progress: widget.progress,
                color: widget.color,
                type: widget.type,
                pulse: _ctrl.value,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(widget.icon, color: widget.color.withOpacity(0.6), size: 14),
                    if (widget.danger) 
                      Icon(Icons.warning_amber_rounded, color: widget.color, size: 14),
                  ],
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.value,
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                          height: 1,
                        ),
                      ),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoxMeterPainter extends CustomPainter {
  final double progress;
  final Color color;
  final _MeterType type;
  final double pulse;

  _BoxMeterPainter({required this.progress, required this.color, required this.type, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = color.withOpacity(0.4 + (pulse * 0.2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case _MeterType.arc:
        final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height * 0.85), radius: size.width * 0.3);
        canvas.drawArc(rect, math.pi, math.pi, false, paint);
        canvas.drawArc(rect, math.pi, math.pi * progress, false, activePaint);
        break;
      case _MeterType.linear:
        final y = size.height - 10;
        canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), paint);
        canvas.drawLine(Offset(10, y), Offset(10 + (size.width - 20) * progress, y), activePaint);
        break;
      case _MeterType.gyro:
        final center = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(center, size.width * 0.18, paint);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate((progress - 0.5) * (math.pi / 2));
        canvas.drawLine(Offset(-size.width * 0.18, 0), Offset(size.width * 0.18, 0), activePaint);
        canvas.restore();
        break;
      case _MeterType.waves:
        final center = Offset(size.width / 2, size.height / 2);
        for (var i = 0; i < 2; i++) {
          final p = (pulse + i / 2.0) % 1.0;
          canvas.drawCircle(center, (10 + p * 25) * progress, paint..color = color.withOpacity(0.08 * (1.0 - p)));
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
}
