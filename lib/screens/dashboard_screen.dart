import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wifi_sensor_service.dart';
import '../services/audio_service.dart';
import '../models/sensor_data.dart';
import '../theme/app_theme.dart';
import 'alerts_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'map_screen.dart';
import 'account_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardContent(),
    MapScreen(),
    AnalyticsScreen(),
    AlertsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _DashboardNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _DashboardNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _DashboardNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(top: BorderSide(color: Color(0xFF1E2535), width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(Icons.speed, 'DRIVE', 0, currentIndex, onTap),
              _NavIcon(Icons.map, 'MAP', 1, currentIndex, onTap),
              _NavIcon(Icons.analytics, 'DATA', 2, currentIndex, onTap),
              _NavIcon(Icons.notifications, 'ALERTS', 3, currentIndex, onTap),
              _NavIcon(Icons.settings, 'SETUP', 4, currentIndex, onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavIcon(this.icon, this.label, this.index, this.currentIndex, this.onTap);

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFF2979FF) : Colors.white24, size: 26),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.rajdhani(color: active ? Colors.white : Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({Key? key}) : super(key: key);

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final AudioService _audio = AudioService();
  String _userName = 'Driver';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Driver';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, svc, _) {
        final data = svc.currentData;
        final alerts = svc.activeAlerts;
        final bool speedAlert = data.speed > 100;

        return Stack(
          children: [
            Column(
              children: [
                _buildHeader(context, svc),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // --- FRONT COLLISION BOX ---
                        Expanded(
                          flex: 3,
                          child: _DashboardCard(
                            title: 'FRONT COLLISION WARNING',
                            isOnline: data.frontOnline,
                            stateName: data.frontStateName,
                            stateColor: data.frontStateColor,
                            visual: _CarTopViewVisual(direction: _ViewDir.front, pulseColor: data.frontStateColor),
                            metrics: [
                              _MetricData('DISTANCE', '${data.frontDistance >= 0 ? data.frontDistance.toStringAsFixed(1) : "--"} cm'),
                              _MetricData('SPEED', '${data.speed.toStringAsFixed(1)} cm/s'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // --- LEAN MONITOR BOX ---
                        Expanded(
                          flex: 4,
                          child: _LeanScopeCard(data: data),
                        ),
                        const SizedBox(width: 12),
                        // --- REAR BLINDSPOT BOX ---
                        Expanded(
                          flex: 3,
                          child: _DashboardCard(
                            title: 'REAR BLINDSPOT MONITOR',
                            isOnline: data.rearOnline,
                            stateName: data.rearStateName,
                            stateColor: data.rearStateColor,
                            visual: _CarTopViewVisual(direction: _ViewDir.rear, pulseColor: data.rearStateColor),
                            metrics: [
                              _MetricData('DISTANCE', '${data.rearDistance >= 0 ? data.rearDistance.toStringAsFixed(1) : "--"} cm'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SystemControlBar(svc: svc),
              ],
            ),

            // --- TOP DOCKED ALERTS ---
            if (speedAlert || alerts.isNotEmpty)
              _SafetyAlertBanner(
                title: speedAlert ? 'OVERSPEED WARNING' : alerts.first.title,
                message: speedAlert ? 'SPEED EXCEEDS 100 CM/S' : alerts.first.message.toUpperCase(),
                onDismiss: speedAlert ? null : svc.clearAlerts,
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WiFiSensorService svc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 16),
      decoration: const BoxDecoration(color: Color(0xFF0A0D14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADAS BRAIN MONITOR', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
              const SizedBox(height: 6),
              Row(
                children: [
                  _StatusLabel('AP: ADASBrain', true),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _audio.playCriticalSound(),
                    child: _StatusLabel('AUDIO ENABLED', false),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_userName.toUpperCase(), style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text('DRIVER PROFILE', style: TextStyle(color: Color(0xFF2979FF), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(width: 12),
                const CircleAvatar(radius: 20, backgroundColor: Color(0xFF1E2535), child: Icon(Icons.person, color: Color(0xFF2979FF), size: 24)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final bool isOnline;
  final String stateName;
  final Color stateColor;
  final Widget visual;
  final List<_MetricData> metrics;

  const _DashboardCard({
    required this.title,
    required this.isOnline,
    required this.stateName,
    required this.stateColor,
    required this.visual,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2535)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
              _OnlineBadge(online: isOnline),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: visual),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: stateColor.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(stateName, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: metrics.map((m) => Column(
              children: [
                Text(m.label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(m.value, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _LeanScopeCard extends StatelessWidget {
  final DrivoraSensorData data;
  const _LeanScopeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final riskColor = data.leanRiskLevel == 2
        ? const Color(0xFFFF3B30)
        : (data.leanRiskLevel == 1
        ? const Color(0xFFFFB020)
        : const Color(0xFF1DB954));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2535)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COG ATTITUDE MONITOR',
                style: GoogleFonts.rajdhani(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              _OnlineBadge(online: data.leanOnline),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1A1F2B)),
              ),
              child: _LeanDotScope(
                roll: data.roll,
                pitch: data.pitch,
                criticalRollDeg: data.criticalRollDeg,
                criticalPitchDeg: data.criticalPitchDeg,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: riskColor.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(data.leanRiskName, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MetricItem('ROLL', '${data.roll.toStringAsFixed(2)}°'),
              _MetricItem('PITCH', '${data.pitch.toStringAsFixed(2)}°'),
              _MetricItem('CONF', data.confidence.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _MetricItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _LeanDotScope extends StatefulWidget {
  final double roll;
  final double pitch;
  final double criticalRollDeg;
  final double criticalPitchDeg;

  const _LeanDotScope({
    required this.roll,
    required this.pitch,
    required this.criticalRollDeg,
    required this.criticalPitchDeg,
  });

  @override
  State<_LeanDotScope> createState() => _LeanDotScopeState();
}

class _LeanDotScopeState extends State<_LeanDotScope>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  double _currentX = 0;
  double _currentY = 0;
  double _targetX = 0;
  double _targetY = 0;
  bool _initialized = false;

  static const double _smooth = 0.35;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted || !_initialized) return;

      final nextX = _currentX + (_targetX - _currentX) * _smooth;
      final nextY = _currentY + (_targetY - _currentY) * _smooth;

      if ((nextX - _currentX).abs() > 0.01 || (nextY - _currentY).abs() > 0.01) {
        setState(() {
          _currentX = nextX;
          _currentY = nextY;
        });
      } else {
        _currentX = nextX;
        _currentY = nextY;
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double _softAxisPosition(double valueDeg, double criticalDeg, double radiusPx) {
    const innerRatio = 0.78;
    const outerRatio = 0.90;
    const headroom = 2.85;

    final absV = valueDeg.abs();
    final sign = valueDeg >= 0 ? 1.0 : -1.0;

    final innerSpan = math.max(criticalDeg, 0.01);
    final outerSpan = math.max(criticalDeg * headroom, innerSpan + 0.01);

    double magRatio;
    if (absV <= innerSpan) {
      magRatio = (absV / innerSpan) * innerRatio;
    } else {
      final t = math.min((absV - innerSpan) / (outerSpan - innerSpan), 1.0);
      final eased = 1.0 - math.exp(-3.2 * t);
      final easedNorm = eased / (1.0 - math.exp(-3.2));
      magRatio = innerRatio + (outerRatio - innerRatio) * easedNorm;
    }

    return sign * magRatio * radiusPx;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final side = math.min(width, height) * 0.92;
        final radius = side / 2 - 12;

        final px = side / 2 +
            _softAxisPosition(widget.roll, widget.criticalRollDeg, radius);
        final py = side / 2 +
            _softAxisPosition(widget.pitch, widget.criticalPitchDeg, radius);

        if (!_initialized) {
          _currentX = px;
          _currentY = py;
          _initialized = true;
        }
        _targetX = px;
        _targetY = py;

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(
              painter: _LeanScopePainter(
                dotX: _currentX,
                dotY: _currentY,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SafetyAlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;

  const _SafetyAlertBanner({required this.title, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 110,
      left: 20,
      right: 20,
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFF1744),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 30, spreadRadius: 5)],
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 40),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (onDismiss != null) const Icon(Icons.touch_app, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemControlBar extends StatelessWidget {
  final WiFiSensorService svc;
  const _SystemControlBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    final active = svc.isConnected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: GestureDetector(
        onTap: svc.toggleSafetyShield,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active ? [const Color(0xFFFF1744), const Color(0xFFD50000)] : [const Color(0xFF2979FF), const Color(0xFF1565C0)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: (active ? Colors.red : Colors.blue).withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Text(
            active ? 'TERMINATE SYSTEM LINK' : 'INITIALIZE ADAS LINK',
            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  final String label;
  final bool active;
  const _StatusLabel(this.label, this.active);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF1E2535), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: active ? const Color(0xFF00E676) : Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  final bool online;
  const _OnlineBadge({required this.online});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: online ? const Color(0xFF00E676).withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: (online ? const Color(0xFF00E676) : Colors.red).withOpacity(0.3)),
      ),
      child: Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: online ? const Color(0xFF00E676) : Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  _MetricData(this.label, this.value);
}

enum _ViewDir { front, rear }

class _CarTopViewVisual extends StatefulWidget {
  final _ViewDir direction;
  final Color pulseColor;
  const _CarTopViewVisual({required this.direction, required this.pulseColor});

  @override
  State<_CarTopViewVisual> createState() => _CarTopViewVisualState();
}

class _CarTopViewVisualState extends State<_CarTopViewVisual> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _TopViewCarPainter(direction: widget.direction, pulse: _pulse.value, color: widget.pulseColor),
      ),
    );
  }
}

class _TopViewCarPainter extends CustomPainter {
  final _ViewDir direction;
  final double pulse;
  final Color color;

  _TopViewCarPainter({required this.direction, required this.pulse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final isFront = direction == _ViewDir.front;

    // Pulse effect
    final wavePaint = Paint()..color = color.withOpacity(0.4 * (1 - pulse))..style = PaintingStyle.stroke..strokeWidth = 2;
    for (int i = 0; i < 2; i++) {
      final t = (pulse + i * 0.5) % 1.0;
      final d = isFront ? -40.0 : 40.0;
      canvas.drawArc(Rect.fromCenter(center: center.translate(0, d), width: 80 + t * 60, height: 40 + t * 30), isFront ? -math.pi : 0, math.pi, false, wavePaint);
    }

    // Car silhouette (Premium Metallic Design)
    final bodyPaint = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF2C3E50), const Color(0xFF000000)]).createShader(Rect.fromCenter(center: center, width: 80, height: 160));
    final bodyPath = Path();
    bodyPath.addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 70, height: 140), const Radius.circular(15)));
    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Windshield & Glass
    final glassPaint = Paint()..color = const Color(0xFF2979FF).withOpacity(0.15);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center.translate(0, isFront ? -15 : 15), width: 55, height: 50), const Radius.circular(8)), glassPaint);

    // Realistic LEDs
    final ledPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    if (isFront) {
      ledPaint.color = Colors.white.withOpacity(0.9);
      canvas.drawCircle(center.translate(-25, -60), 6, ledPaint);
      canvas.drawCircle(center.translate(25, -60), 6, ledPaint);
    } else {
      ledPaint.color = const Color(0xFFFF1744).withOpacity(0.9);
      canvas.drawCircle(center.translate(-25, 60), 6, ledPaint);
      canvas.drawCircle(center.translate(25, 60), 6, ledPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _LeanScopePainter extends CustomPainter {
  final double dotX;
  final double dotY;

  _LeanScopePainter({
    required this.dotX,
    required this.dotY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final ringPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xFF555555)
      ..strokeWidth = 2;

    final radii = [0.44, 0.35, 0.26, 0.17, 0.08];
    for (final r in radii) {
      canvas.drawCircle(center, size.width * r, ringPaint);
    }

    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );

    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );

    final dotOffset = Offset(dotX, dotY);

    final glowPaint = Paint()
      ..color = const Color.fromRGBO(64, 128, 255, 0.75)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final dotPaint = Paint()
      ..color = const Color.fromRGBO(64, 128, 255, 0.75);

    canvas.drawCircle(dotOffset, 8, glowPaint);
    canvas.drawCircle(dotOffset, 8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LeanScopePainter oldDelegate) {
    return oldDelegate.dotX != dotX || oldDelegate.dotY != dotY;
  }
}