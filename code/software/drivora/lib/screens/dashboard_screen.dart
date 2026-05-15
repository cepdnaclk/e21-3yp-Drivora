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
      backgroundColor: const Color(0xFF030508),
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavIcon(Icons.speed_rounded, 'DRIVE', 0, currentIndex, onTap),
              _NavIcon(Icons.map_rounded, 'MAP', 1, currentIndex, onTap),
              _NavIcon(Icons.analytics_rounded, 'DATA', 2, currentIndex, onTap),
              _NavIcon(Icons.notifications_active_rounded, 'ALERTS', 3, currentIndex, onTap),
              _NavIcon(Icons.tune_rounded, 'SETUP', 4, currentIndex, onTap),
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
          Icon(icon, color: active ? const Color(0xFF2979FF) : Colors.white24, size: 28),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.rajdhani(color: active ? Colors.white : Colors.white24, fontSize: 13, fontWeight: FontWeight.bold)),
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
  String _userName = 'DRIVER';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = (prefs.getString('userName') ?? 'DRIVER').toUpperCase();
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
                _buildHeader(context, svc, data.speed),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // --- MERGED COLLISION HUB (LEFT) ---
                        Expanded(
                          flex: 3,
                          child: _PremiumMonitorCard(
                            title: 'COLLISION HUB',
                            isOnline: data.frontOnline && data.rearOnline,
                            visual: _Merged3DCarVisual(
                              frontState: data.frontState,
                              frontColor: data.frontStateColor,
                              rearState: data.rearState,
                              rearColor: data.rearStateColor,
                              frontActive: data.frontOnline,
                              rearActive: data.rearOnline,
                              frontDistance: data.frontDistance,
                              rearDistance: data.rearDistance,
                            ),
                            metrics: [
                              _MetricData('FRONT', '${data.frontDistance >= 0 ? data.frontDistance.toStringAsFixed(1) : "--"} CM'),
                              _MetricData('REAR', '${data.rearDistance >= 0 ? data.rearDistance.toStringAsFixed(1) : "--"} CM'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // --- LEAN MONITOR BOX (CENTER) - INCREASED SIZE ---
                        Expanded(
                          flex: 5,
                          child: _LeanScopeCard(data: data),
                        ),
                        const SizedBox(width: 16),
                        // --- LANE ASSIST (RIGHT) - INCREASED SIZE ---
                        Expanded(
                          flex: 4,
                          child: _PremiumMonitorCard(
                            title: 'LANE ASSIST',
                            isOnline: data.laneOnline,
                            stateName: data.laneStateName,
                            stateColor: data.laneStateColor,
                            visual: _LaneVisual(laneState: data.laneState),
                            metrics: [
                              _MetricData('SYSTEM', 'MONITORING'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _CommandCenter(svc: svc),
              ],
            ),

            // --- TOP DOCKED SAFETY ALERTS ---
            if (speedAlert || alerts.isNotEmpty)
              Positioned(
                top: 135,
                left: 0,
                right: 0,
                child: Center(
                  child: _FloatingAlertBanner(
                    title: speedAlert ? 'OVERSPEED DETECTED' : alerts.first.title.toUpperCase(),
                    message: speedAlert ? 'REDUCE VELOCITY BELOW 100 CM/S' : alerts.first.message.toUpperCase(),
                    onDismiss: speedAlert ? null : svc.clearAlerts,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WiFiSensorService svc, double speed) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0D14),
        border: Border(bottom: BorderSide(color: Color(0xFF1E2535), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADAS BRAIN HUB', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _HeaderStatusPill('LINK: ${svc.isConnected ? "ACTIVE" : "STANDBY"}', svc.isConnected),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _audio.playCriticalSound(),
                    child: _HeaderStatusPill('AUDIO FEEDBACK', false, isTappable: true),
                  ),
                ],
              ),
            ],
          ),

          // --- TOP CENTERED SPEED DISPLAY ---
          //Container(
            //padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
            //decoration: BoxDecoration(
              //color: Colors.black.withOpacity(0.5),
              //borderRadius: BorderRadius.circular(22),
              //border: Border.all(color: speed > 100 ? Colors.red : const Color(0xFF2979FF).withOpacity(0.5), width: 2),
            //),
            //child: Column(
              //children: [
                //Text(
                  //speed.toInt().toString(),
                  //style: GoogleFonts.orbitron(color: speed > 100 ? Colors.red : Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                //),
                //Text('CM/S', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              //],
            //),
          //),

          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_userName, style: GoogleFonts.rajdhani(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('SYSTEM OPERATOR', style: TextStyle(color: Color(0xFF2979FF), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ],
                ),
                const SizedBox(width: 12),
                const CircleAvatar(radius: 20, backgroundColor: Color(0xFF1E2535), child: Icon(Icons.person, color: Colors.white, size: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM MONITOR CARD — REDUCED TEXT SIZE FOR SAFE STATES
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumMonitorCard extends StatelessWidget {
  final String title;
  final bool isOnline;
  final String? stateName;
  final Color? stateColor;
  final Widget visual;
  final List<_MetricData> metrics;

  const _PremiumMonitorCard({
    required this.title,
    required this.isOnline,
    this.stateName,
    this.stateColor,
    required this.visual,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E2535), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1)),
              _StatusLight(online: isOnline),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: visual),
          if (stateName != null && stateColor != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: stateColor!.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: stateColor!.withOpacity(0.3), blurRadius: 15)],
              ),
              alignment: Alignment.center,
              child: Text(stateName!, textAlign: TextAlign.center, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: metrics.map((m) => Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(m.label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(m.value, textAlign: TextAlign.center, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            )).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAN SCOPE CARD — REDUCED TEXT SIZE FOR SAFE STATE
// ─────────────────────────────────────────────────────────────────────────────
class _LeanScopeCard extends StatelessWidget {
  final DrivoraSensorData data;
  const _LeanScopeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final riskColor = data.leanRiskLevel == 2 ? const Color(0xFFFF1744) : (data.leanRiskLevel == 1 ? const Color(0xFFFFAB00) : const Color(0xFF00E676));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D14),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1E2535), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COG ATTITUDE MONITOR', style: GoogleFonts.rajdhani(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              _StatusLight(online: data.leanOnline),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1A1F2B), width: 2),
              ),
              child: _LeanDotScope(
                roll: data.roll,
                pitch: data.pitch,
                criticalRollDeg: data.criticalRollDeg,
                criticalPitchDeg: data.criticalPitchDeg,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: riskColor.withOpacity(0.85),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: riskColor.withOpacity(0.3), blurRadius: 15)],
            ),
            alignment: Alignment.center,
            child: Text(data.leanRiskName, textAlign: TextAlign.center, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ScopeMetric('ROLL', '${data.roll.toStringAsFixed(2)}°'),
              _ScopeMetric('PITCH', '${data.pitch.toStringAsFixed(2)}°'),
              _ScopeMetric('CONF', data.confidence.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ScopeMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(value, textAlign: TextAlign.center, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAN DOT SCOPE (unchanged logic, same as before)
// ─────────────────────────────────────────────────────────────────────────────
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

class _LeanDotScopeState extends State<_LeanDotScope> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _currentX = 0, _currentY = 0, _targetX = 0, _targetY = 0;
  bool _initialized = false;
  static const double _smooth = 0.35;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted || !_initialized) return;
      final nextX = _currentX + (_targetX - _currentX) * _smooth;
      final nextY = _currentY + (_targetY - _currentY) * _smooth;
      if ((nextX - _currentX).abs() > 0.001 || (nextY - _currentY).abs() > 0.001) {
        setState(() { _currentX = nextX; _currentY = nextY; });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() { _ticker.dispose(); super.dispose(); }

  double _softAxisPosition(double val, double crit, double rad) {
    const iR = 0.78; const oR = 0.90; const hR = 2.85;
    final absV = val.abs(); final sign = val >= 0 ? 1.0 : -1.0;
    final iS = math.max(crit, 0.01); final oS = math.max(crit * hR, iS + 0.01);
    double mag;
    if (absV <= iS) { mag = (absV / iS) * iR; }
    else {
      final t = math.min((absV - iS) / (oS - iS), 1.0);
      final e = 1.0 - math.exp(-3.2 * t);
      mag = iR + (oR - iR) * (e / (1.0 - math.exp(-3.2)));
    }
    return sign * mag * rad;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight) * 0.92;
      final radius = side / 2 - 12;
      final px = side / 2 + _softAxisPosition(widget.roll, widget.criticalRollDeg, radius);
      final py = side / 2 + _softAxisPosition(widget.pitch, widget.criticalPitchDeg, radius);
      if (!_initialized) { _currentX = px; _currentY = py; _initialized = true; }
      _targetX = px; _targetY = py;
      return Center(child: SizedBox(width: side, height: side, child: CustomPaint(painter: _LeanScopePainter(dotX: _currentX, dotY: _currentY))));
    });
  }
}

class _LeanScopePainter extends CustomPainter {
  final double dotX, dotY;
  _LeanScopePainter({required this.dotX, required this.dotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()..color = const Color(0xFF555555)..style = PaintingStyle.stroke..strokeWidth = 1;
    final linePaint = Paint()..color = const Color(0xFF555555)..strokeWidth = 2;
    final radii = [0.44, 0.35, 0.26, 0.17, 0.08];
    for (final r in radii) { canvas.drawCircle(center, size.width * r, ringPaint); }
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), linePaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), linePaint);

    final dotPos = Offset(dotX, dotY);
    final glow = Paint()..color = const Color.fromRGBO(64, 128, 255, 0.75)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final dotP = Paint()..color = const Color.fromRGBO(64, 128, 255, 0.75);
    canvas.drawCircle(dotPos, 8, glow);
    canvas.drawCircle(dotPos, 8, dotP);
  }
  @override
  bool shouldRepaint(covariant _LeanScopePainter old) => old.dotX != dotX || old.dotY != dotY;
}

// ─────────────────────────────────────────────────────────────────────────────
// FLOATING ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingAlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onDismiss;

  const _FloatingAlertBanner({required this.title, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFF1744),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, spreadRadius: 5)],
        border: Border.all(color: Colors.white30, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.white, size: 48),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          if (onDismiss != null) IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30), onPressed: onDismiss),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMAND CENTER
// ─────────────────────────────────────────────────────────────────────────────
class _CommandCenter extends StatelessWidget {
  final WiFiSensorService svc;
  const _CommandCenter({required this.svc});

  @override
  Widget build(BuildContext context) {
    final active = svc.isConnected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: GestureDetector(
        onTap: svc.toggleSafetyShield,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: active ? [const Color(0xFFFF1744), const Color(0xFFD50000)] : [const Color(0xFF2979FF), const Color(0xFF1565C0)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: (active ? Colors.red : Colors.blue).withOpacity(0.25), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          alignment: Alignment.center,
          child: Text(
            active ? 'TERMINATE HUB CONNECTION' : 'ESTABLISH ADAS BRAIN LINK',
            style: GoogleFonts.orbitron(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER STATUS PILL
// ─────────────────────────────────────────────────────────────────────────────
class _HeaderStatusPill extends StatelessWidget {
  final String label;
  final bool active;
  final bool isTappable;
  const _HeaderStatusPill(this.label, this.active, {this.isTappable = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF1E2535), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Text(label, style: TextStyle(color: active ? const Color(0xFF00E676) : Colors.white60, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS LIGHT
// ─────────────────────────────────────────────────────────────────────────────
class _StatusLight extends StatelessWidget {
  final bool online;
  const _StatusLight({required this.online});

  @override
  Widget build(BuildContext context) {
    final color = online ? const Color(0xFF00E676) : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9, height: 9,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 6)]),
        ),
        const SizedBox(width: 8),
        Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC DATA
// ─────────────────────────────────────────────────────────────────────────────
class _MetricData {
  final String label;
  final String value;
  _MetricData(this.label, this.value);
}

// ─────────────────────────────────────────────────────────────────────────────
// MERGED 3D CAR VISUAL — NOW WITH ANIMATED SIGNAL WAVES INSTEAD OF STATE CHIPS
// ─────────────────────────────────────────────────────────────────────────────
class _Merged3DCarVisual extends StatefulWidget {
  final int frontState, rearState;
  final Color frontColor, rearColor;
  final bool frontActive, rearActive;
  final double frontDistance, rearDistance;

  const _Merged3DCarVisual({
    required this.frontState,
    required this.rearState,
    required this.frontColor,
    required this.rearColor,
    required this.frontActive,
    required this.rearActive,
    required this.frontDistance,
    required this.rearDistance,
  });

  @override
  State<_Merged3DCarVisual> createState() => _Merged3DCarVisualState();
}

class _Merged3DCarVisualState extends State<_Merged3DCarVisual>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _alertCtrl;
  late AnimationController _signalCtrl;

  @override
  void initState() {
    super.initState();
    // Primary radar pulse — speed adapts to proximity
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    // Alert flash for critical state
    _alertCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
    // Signal wave animation
    _signalCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _alertCtrl.dispose();
    _signalCtrl.dispose();
    super.dispose();
  }

  /// Map distance to pulse speed: closer = faster pulses
  Duration _pulseDuration(double dist) {
    if (dist < 0) return const Duration(milliseconds: 1200);
    if (dist < 20) return const Duration(milliseconds: 300);
    if (dist < 50) return const Duration(milliseconds: 600);
    if (dist < 100) return const Duration(milliseconds: 900);
    return const Duration(milliseconds: 1400);
  }

  @override
  void didUpdateWidget(covariant _Merged3DCarVisual old) {
    super.didUpdateWidget(old);
    // Dynamically adjust pulse speed based on closest threat
    final minDist = [
      if (widget.frontDistance >= 0) widget.frontDistance,
      if (widget.rearDistance >= 0) widget.rearDistance,
    ].fold<double>(9999, (a, b) => a < b ? a : b);
    final dur = _pulseDuration(minDist);
    if (_pulseCtrl.duration != dur) {
      _pulseCtrl.duration = dur;
      _pulseCtrl.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _alertCtrl, _signalCtrl]),
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _MergedCarRadarPainter(
          pulse: _pulseCtrl.value,
          alertFlash: _alertCtrl.value,
          signal: _signalCtrl.value,
          fColor: widget.frontColor,
          rColor: widget.rearColor,
          fActive: widget.frontActive,
          rActive: widget.rearActive,
          fState: widget.frontState,
          rState: widget.rearState,
          fDist: widget.frontDistance,
          rDist: widget.rearDistance,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MERGED CAR RADAR PAINTER — WITH ANIMATED SIGNAL WAVES
// ─────────────────────────────────────────────────────────────────────────────
class _MergedCarRadarPainter extends CustomPainter {
  final double pulse;
  final double alertFlash;
  final double signal;
  final Color fColor, rColor;
  final bool fActive, rActive;
  final int fState, rState;
  final double fDist, rDist;

  _MergedCarRadarPainter({
    required this.pulse,
    required this.alertFlash,
    required this.signal,
    required this.fColor,
    required this.rColor,
    required this.fActive,
    required this.rActive,
    required this.fState,
    required this.rState,
    required this.fDist,
    required this.rDist,
  });

  /// Number of wave rings — more rings for closer/danger states
  int _waveCount(int state) {
    if (state == 2) return 5; // CRITICAL
    if (state == 1) return 4; // WARNING
    return 3;                 // SAFE / IDLE
  }

  /// Wave thickness — danger gets bolder waves
  double _strokeWidth(int state) {
    if (state == 2) return 4.5;
    if (state == 1) return 3.0;
    return 2.0;
  }

  /// Max spread of waves — larger spread for critical
  double _maxSpread(int state) {
    if (state == 2) return 160;
    if (state == 1) return 130;
    return 110;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // ── FRONT SONAR WAVES ────────────────────────────────────────────────────
    if (fActive) {
      final wCount = _waveCount(fState);
      final spread = _maxSpread(fState);
      final sw = _strokeWidth(fState);
      final focusY = cy - 72; // front sensor focal point above car

      for (int i = 0; i < wCount; i++) {
        final t = (pulse + i / wCount) % 1.0;
        final baseOpacity = fState == 2
            ? (0.9 - t * 0.7) * (0.6 + alertFlash * 0.4)
            : (0.75 - t * 0.65);
        final opacity = baseOpacity.clamp(0.0, 1.0);
        final w = 50 + t * spread;
        final h = 24 + t * (spread * 0.5);

        final wavePaint = Paint()
          ..color = fColor.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round;

        // Add glow for critical state
        if (fState == 2) {
          final glowPaint = Paint()
            ..color = fColor.withOpacity(opacity * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw + 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawArc(
            Rect.fromCenter(center: Offset(cx, focusY), width: w, height: h),
            -math.pi, math.pi, false, glowPaint,
          );
        }

        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, focusY), width: w, height: h),
          -math.pi, math.pi, false, wavePaint,
        );
      }

      // Distance label above waves
      if (fDist >= 0) {
        _drawDistLabel(canvas, Offset(cx, focusY - 18), '${fDist.toStringAsFixed(1)} CM', fColor);
      }
    }

    // ── REAR SONAR WAVES ─────────────────────────────────────────────────────
    if (rActive) {
      final wCount = _waveCount(rState);
      final spread = _maxSpread(rState);
      final sw = _strokeWidth(rState);
      final focusY = cy + 72; // rear sensor focal point below car

      for (int i = 0; i < wCount; i++) {
        final t = (pulse + i / wCount) % 1.0;
        final baseOpacity = rState == 2
            ? (0.9 - t * 0.7) * (0.6 + alertFlash * 0.4)
            : (0.75 - t * 0.65);
        final opacity = baseOpacity.clamp(0.0, 1.0);
        final w = 50 + t * spread;
        final h = 24 + t * (spread * 0.5);

        final wavePaint = Paint()
          ..color = rColor.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round;

        if (rState == 2) {
          final glowPaint = Paint()
            ..color = rColor.withOpacity(opacity * 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw + 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawArc(
            Rect.fromCenter(center: Offset(cx, focusY), width: w, height: h),
            0, math.pi, false, glowPaint,
          );
        }

        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, focusY), width: w, height: h),
          0, math.pi, false, wavePaint,
        );
      }

      // Distance label below waves
      if (rDist >= 0) {
        _drawDistLabel(canvas, Offset(cx, focusY + 18), '${rDist.toStringAsFixed(1)} CM', rColor);
      }
    }

    // ── CAR BODY — with alert glow overlay if any sensor is critical ─────────
    final isCritical = fState == 2 || rState == 2;
    final isWarning = fState == 1 || rState == 1;
    final bodyGlowColor = isCritical
        ? const Color(0xFFFF1744)
        : isWarning
        ? const Color(0xFFFFAB00)
        : Colors.transparent;

    // Outer alert glow on body
    if (isCritical || isWarning) {
      final glowIntensity = isCritical ? (0.3 + alertFlash * 0.35) : 0.18;
      final bodyGlowPaint = Paint()
        ..color = bodyGlowColor.withOpacity(glowIntensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 92, height: 170), const Radius.circular(26)),
        bodyGlowPaint,
      );
    }

    // Metallic car body
    final bP = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF34495E), Colors.black, const Color(0xFF34495E)],
      ).createShader(Rect.fromCenter(center: center, width: 100, height: 200));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 80, height: 160), const Radius.circular(22)),
      bP,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 80, height: 160), const Radius.circular(22)),
      Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // Glass windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center.translate(0, -20), width: 65, height: 55), const Radius.circular(12)),
      Paint()..color = const Color(0xFF2979FF).withOpacity(0.2),
    );

    // Front headlights — color-coded to front sensor state
    final fLedColor = fActive ? fColor : Colors.white38;
    final fLed = Paint()
      ..color = fLedColor.withOpacity(fState == 2 ? (0.6 + alertFlash * 0.4) : 0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, fState == 2 ? 14 : 8);
    canvas.drawCircle(center.translate(-30, -75), fState == 2 ? 13 : 10, fLed);
    canvas.drawCircle(center.translate(30, -75), fState == 2 ? 13 : 10, fLed);

    // Rear tail lights — color-coded to rear sensor state
    final rLedColor = rActive ? rColor : Colors.red.withOpacity(0.6);
    final rLed = Paint()
      ..color = rLedColor.withOpacity(rState == 2 ? (0.6 + alertFlash * 0.4) : 0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rState == 2 ? 14 : 8);
    canvas.drawCircle(center.translate(-30, 75), rState == 2 ? 13 : 10, rLed);
    canvas.drawCircle(center.translate(30, 75), rState == 2 ? 13 : 10, rLed);

    // ── ANIMATED SIGNAL WAVES (FRONT) ────────────────────────────────────────
    if (fActive) {
      _drawSignalWaves(canvas, Offset(cx - 30, cy - 75), fColor, signal, left: true);
      _drawSignalWaves(canvas, Offset(cx + 30, cy - 75), fColor, signal, left: false);
    }

    // ── ANIMATED SIGNAL WAVES (REAR) ─────────────────────────────────────────
    if (rActive) {
      _drawSignalWaves(canvas, Offset(cx - 30, cy + 75), rColor, signal, left: true);
      _drawSignalWaves(canvas, Offset(cx + 30, cy + 75), rColor, signal, left: false);
    }
  }

  void _drawSignalWaves(Canvas canvas, Offset origin, Color color, double t, {required bool left}) {
    final direction = left ? -1.0 : 1.0;

    for (int i = 0; i < 3; i++) {
      final phase = (t + i * 0.33) % 1.0;
      final x = origin.dx + direction * phase * 25;
      final y = origin.dy;
      final opacity = (1.0 - phase) * 0.8;

      final wavePaint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      // Draw curved signal wave
      final path = Path();
      path.moveTo(x, y - 6);
      path.quadraticBezierTo(x + direction * 4, y, x, y + 6);
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawDistLabel(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// LANE VISUAL (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _LaneVisual extends StatefulWidget {
  final int laneState;
  const _LaneVisual({required this.laneState});
  @override
  State<_LaneVisual> createState() => _LaneVisualState();
}

class _LaneVisualState extends State<_LaneVisual> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  @override
  void initState() { super.initState(); _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _LanePainter(state: widget.laneState, pulse: _pulse.value),
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  final int state;
  final double pulse;
  _LanePainter({required this.state, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final lP = Paint()..strokeWidth = 12..strokeCap = StrokeCap.round;
    final rP = Paint()..strokeWidth = 12..strokeCap = StrokeCap.round;

    if (state == 1) {
      lP.color = const Color(0xFFFFAB00).withOpacity(0.6 + pulse * 0.4);
      lP.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    } else {
      lP.color = Colors.white12;
    }
    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.05), Offset(size.width * 0.3, size.height * 0.95), lP);

    if (state == 2) {
      rP.color = const Color(0xFFFFAB00).withOpacity(0.6 + pulse * 0.4);
      rP.maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    } else {
      rP.color = Colors.white12;
    }
    canvas.drawLine(Offset(size.width * 0.7, size.height * 0.05), Offset(size.width * 0.7, size.height * 0.95), rP);

    final bodyPaint = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF2C3E50), Colors.black])
          .createShader(Rect.fromCenter(center: center, width: 40, height: 80));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 35, height: 75), const Radius.circular(8)), bodyPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 35, height: 75), const Radius.circular(8)),
        Paint()..color = Colors.white10..style = PaintingStyle.stroke..strokeWidth = 1);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center.translate(0, -10), width: 30, height: 25), const Radius.circular(4)),
        Paint()..color = const Color(0xFF2979FF).withOpacity(0.1));
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _TacticalScopePainter extends CustomPainter {
  final double dotX, dotY;
  _TacticalScopePainter({required this.dotX, required this.dotY});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rad = math.min(size.width, size.height) / 2;
    final gP = Paint()..color = Colors.white.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1;

    for (int i = 1; i <= 5; i++) { canvas.drawCircle(center, (rad / 5) * i, gP); }
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gP);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gP);

    // Zones
    canvas.drawCircle(center, rad * 0.78, Paint()..color = const Color(0xFFFFAB00).withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 2);
    canvas.drawCircle(center, rad * 0.90, Paint()..color = const Color(0xFFFF1744).withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 2);

    final dot = Offset(dotX, dotY);
    const dotColor = Color(0xFF00E5FF);
    canvas.drawCircle(dot, 16, Paint()..color = dotColor.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(dot, 9, Paint()..color = dotColor);
    canvas.drawCircle(dot, 5, Paint()..color = Colors.white);

    final ret = Paint()..color = dotColor.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawLine(dot.translate(-20, 0), dot.translate(20, 0), ret);
    canvas.drawLine(dot.translate(0, -20), dot.translate(0, 20), ret);
  }
  @override
  bool shouldRepaint(covariant _TacticalScopePainter old) => old.dotX != dotX || old.dotY != dotY;
}