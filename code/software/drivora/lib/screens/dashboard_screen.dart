import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import '../services/audio_service.dart';
import '../services/wifi_sensor_service.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

// ─── palette ──────────────────────────────────────────────────────────────────
const _kBg       = Color(0xFF080B12);
const _kSurface  = Color(0xFF0C0F1A);
const _kBorder   = Color(0xFF1C2236);
const _kBorderSoft = Color(0x33283353);
const _kGreen    = Color(0xFF34C759);
const _kAmber    = Color(0xFFFFB020);
const _kOrange   = Color(0xFFFF8A3D);
const _kRed      = Color(0xFFFF3B30);
const _kCyan     = Color(0xFF00E5FF);
const _kText1    = Color(0xFFF0F4FF);
const _kText2    = Color(0xFF6B7A99);
const _kText3    = Color(0xFF8A98B5);
const _kOffline  = Color(0xFF3A4568);  // gray used for all overlays when ADAS offline

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCAFFOLD
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _idx = 0;
  final _pages = const [
    DashboardContent(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoConnect());
  }

  // Auto-connect to the ADAS brain when a registered returning user opens the
  // app directly to the dashboard (splash → setupComplete=true path).
  // Skipped if already connected (e.g. user just finished onboarding).
  Future<void> _maybeAutoConnect() async {
    final prefs    = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool('setupComplete') ?? false;
    final email    = prefs.getString('userEmail') ?? '';
    if (!setupDone || email.isEmpty || !mounted) {
      return;
    }
    final svc = Provider.of<WiFiSensorService>(context, listen: false);
    if (!svc.isConnected) {
      unawaited(svc.connectToHardwareHub('10.42.0.1'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    body: SafeArea(
      bottom: false,
      child: IndexedStack(index: _idx, children: _pages),
    ),
    bottomNavigationBar: _NavBar(current: _idx, onTap: (i) => setState(() => _idx = i)),
  );
}

// ─── BOTTOM NAV ───────────────────────────────────────────────────────────────
class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final btm = MediaQuery.of(context).padding.bottom;
    // Do NOT specify an explicit height on the Container — let the Column's
    // intrinsic height (66 + btm) drive it.  An explicit height can be 1 px
    // off from what Scaffold reserves, producing the overflow stripe.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1322), Color(0xFF0A0E18)],
        ),
        border: Border(top: BorderSide(color: _kBorderSoft, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 66,
            child: Row(children: [
              Expanded(child: _NI(Icons.speed_rounded,     'Dashboard',  0, current, onTap)),
              Expanded(child: _NI(Icons.bar_chart_rounded, 'Statistics', 1, current, onTap)),
              Expanded(child: _NI(Icons.settings_rounded,  'Settings',   2, current, onTap)),
            ]),
          ),
          if (btm > 0) SizedBox(height: btm),
        ],
      ),
    );
  }
}

class _NI extends StatelessWidget {
  const _NI(this.icon, this.label, this.index, this.current, this.onTap);
  final IconData icon; final String label; final int index, current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Active highlight bar above the selected item.
          if (sel)
            Positioned(
              top: 0,
              child: Container(
                width: 70, height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(colors: [
                    _kCyan.withOpacity(0),
                    _kCyan.withOpacity(0.9),
                    _kCyan.withOpacity(0),
                  ]),
                  boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.6), blurRadius: 10)],
                ),
              ),
            ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: sel ? _kCyan : Colors.white30, size: 22),
            const SizedBox(width: 7),
            Text(label,
                style: GoogleFonts.inter(
                    color: sel ? _kText1 : Colors.white38,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD CONTENT
// ─────────────────────────────────────────────────────────────────────────────
class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});
  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final AudioService _audio = AudioService();
  String _vehicleName  = 'My Vehicle';
  bool   _audioEnabled = true;

  @override
  void initState() { super.initState(); _loadPrefs(); }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _vehicleName  = p.getString('vehicleModel') ?? 'My Vehicle';
      _audioEnabled = p.getBool('audioEnabled')   ?? true;
    });
  }

  @override
  Widget build(BuildContext context) => Consumer<WiFiSensorService>(
    builder: (context, svc, _) {
      final d = svc.currentData;
      // Use LayoutBuilder so the Row height is always explicitly bounded —
      // prevents any bottom overflow regardless of device screen size.
      return LayoutBuilder(builder: (ctx, constraints) {
        const topBarH = 52.0;
        const topPad  = 10.0;
        const botPad  = 6.0;
        const hPad    = 14.0;
        final contentH = (constraints.maxHeight - topBarH - topPad - botPad)
            .clamp(0.0, double.infinity);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(hPad, topPad, hPad, botPad),
            child: _TopBar(svc: svc, vehicleName: _vehicleName,
                audioEnabled: _audioEnabled, audio: _audio),
          ),
          SizedBox(
            height: contentH,
            child: Row(children: [
              Expanded(flex: 9, child: _CarView(data: d)),
              Expanded(flex: 11, child: _InfoPanel(data: d)),
            ]),
          ),
        ]);
      });
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.svc, required this.vehicleName,
      required this.audioEnabled, required this.audio});
  final WiFiSensorService svc;
  final String vehicleName;
  final bool audioEnabled;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    final d = svc.currentData;
    final leanColor = d.leanRiskLevel == 2 ? _kRed
        : d.leanRiskLevel == 1 ? _kAmber : _kGreen;

    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth;
      final showVehicle  = w >= 320;
      final showLabels   = w >= 400;
      final showUnitDots = w >= 520;

      return Container(
        height: 52,
        padding: EdgeInsets.symmetric(horizontal: (w * 0.03).clamp(10.0, 20.0)),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xff11172899), Color(0xff0c111c99)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorderSoft, width: 1),
        ),
        child: Row(children: [
          // Brand
          Text('Drivora',
              style: GoogleFonts.inter(
                  color: _kText1, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: 0.2)),

          // Vehicle name
          if (showVehicle) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 1, height: 18, color: _kBorder,
            ),
            Flexible(
              child: Text(vehicleName,
                  style: GoogleFonts.inter(
                      color: _kText3, fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],

          const Spacer(),

          // Cloud sync status
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (showLabels)
              Text(svc.internetAvailable ? 'Synced ' : 'Offline ',
                  style: GoogleFonts.inter(
                      color: svc.internetAvailable ? _kGreen : _kText3,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            Icon(
              svc.internetAvailable
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              color: svc.internetAvailable ? _kGreen : _kText3,
              size: 15,
            ),
          ]),

          const SizedBox(width: 10),

          // Audio toggle label + badge
          if (showLabels) ...[
            Text('Audio',
                style: GoogleFonts.inter(
                    color: _kText3, fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: audioEnabled ? _kGreen : _kText2, width: 1.3),
              ),
              child: Text(
                audioEnabled ? 'Enabled' : 'Muted',
                style: GoogleFonts.inter(
                    color: audioEnabled ? _kGreen : _kText2,
                    fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ] else
            Icon(
              audioEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: audioEnabled ? _kGreen : _kText2, size: 17,
            ),

          // Unit dots (tablets / landscape)
          if (showUnitDots) ...[
            const SizedBox(width: 6),
            _UnitDot('Front Unit',     d.frontOnline ? _kGreen : _kRed),
            _UnitDot('Rear Unit',      d.rearOnline  ? _kGreen : _kRed),
            _UnitDot('Stability Unit', d.leanOnline  ? leanColor : _kRed),
            _UnitDot('Camera Unit',    d.laneOnline  ? _kGreen : _kRed),
          ],
        ]),
      );
    });
  }
}

class _UnitDot extends StatelessWidget {
  const _UnitDot(this.label, this.color);
  final String label; final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withOpacity(0.7), blurRadius: 7)],
        ),
      ),
      const SizedBox(width: 6),
      Text(label,
          style: GoogleFonts.inter(
              color: _kText1, fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO PANEL (right side)
// ─────────────────────────────────────────────────────────────────────────────
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.data});
  final DrivoraSensorData data;

  _AlertInfo? _primaryAlert() {
    if (data.frontState >= 2) {
      final distM = data.frontDistance >= 0
          ? '${(data.frontDistance / 100).toStringAsFixed(1)} m' : '— m';
      final speedKmh = data.closingSpeed > 0
          ? '${(data.closingSpeed * 0.036).toStringAsFixed(0)} km/h' : '—';
      return _AlertInfo(
        source:  'front',
        title:   data.frontState == 3
            ? 'FRONT COLLISION WARNING'
            : 'OBSTACLE APPROACHING',
        message: data.frontState == 3
            ? 'Obstacle Ahead! Prepare to Brake!'
            : 'Object detected ahead. Stay alert.',
        color: _kRed,
        metrics: [
          _Metric('DISTANCE',      distM,              _kRed),
          _Metric('CLOSING SPEED', speedKmh,           _kRed),
          _Metric('STATE',         data.frontStateName, _kRed),
        ],
      );
    }
    if (data.rearState >= 2) {
      final distM = data.rearDistance >= 0
          ? '${(data.rearDistance / 100).toStringAsFixed(1)} m' : '— m';
      return _AlertInfo(
        source:  'rear',
        title:   'REAR PROXIMITY WARNING',
        message: 'Object detected behind. Check rear clearance.',
        color: _kRed,
        metrics: [
          _Metric('DISTANCE', distM,              _kRed),
          _Metric('STATE',    data.rearStateName,  _kRed),
          _Metric('ZONE',     _rearZone(),         _kRed),
        ],
      );
    }
    if (data.leanRiskLevel >= 2) {
      return _AlertInfo(
        source:  'stability',
        title:   'HIGH LEAN RISK',
        message: 'Vehicle lean angle is high. Slow down.',
        color: _kRed,
        metrics: [
          _Metric('ROLL',  '${data.roll.toStringAsFixed(1)}°',   _kRed),
          _Metric('PITCH', '${data.pitch.toStringAsFixed(1)}°',  _kRed),
          _Metric('RISK',  data.leanRiskName,                    _kRed),
        ],
      );
    }
    if (data.laneState != 0) {
      return _AlertInfo(
        source:  'lane',
        title:   data.laneState == 1
            ? 'LEFT LANE DEPARTURE'
            : 'RIGHT LANE DEPARTURE',
        message: 'Vehicle is drifting toward the lane marking.',
        color: _kAmber,
        metrics: [
          _Metric('DIRECTION', data.laneState == 1 ? 'LEFT' : 'RIGHT', _kAmber),
          _Metric('STATE',     data.laneStateName,                      _kAmber),
          const _Metric('SYSTEM', 'ACTIVE',                             _kAmber),
        ],
      );
    }
    return null;
  }

  String _rearZone() {
    if (data.rearCenterState >= 2) return 'CENTER';
    if (data.rearLeftState >= 2)   return 'LEFT';
    if (data.rearRightState >= 2)  return 'RIGHT';
    return 'MULTI';
  }

  Color get _frontColor => data.frontState >= 2 ? _kRed
      : data.frontState == 1 ? _kAmber : _kGreen;
  Color get _laneColor  => data.laneState == 0 ? _kGreen : _kAmber;
  Color get _leanColor  => data.leanRiskLevel == 2 ? _kRed
      : data.leanRiskLevel == 1 ? _kAmber : _kGreen;

  String get _laneDisplay {
    switch (data.laneState) {
      case 1:  return 'LEFT LANE';
      case 2:  return 'RIGHT LANE';
      default: return 'CENTERED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = _primaryAlert();
    return LayoutBuilder(builder: (_, c) {
      // Scale from BOTH dimensions so the panel never overflows on short devices.
      // 260 px wide / 480 px tall are the design baselines.
      final sW = c.maxWidth / 260.0;
      final sH = (c.maxHeight > 0 && c.maxHeight.isFinite) ? c.maxHeight / 480.0 : sW;
      final s  = math.min(sW, sH).clamp(0.42, 1.0);
      return Padding(
        padding: EdgeInsets.fromLTRB(26 * s, 12 * s, 18 * s, 12 * s),
        child: alert == null ? _buildClearView(s) : _buildAlertView(alert, s),
      );
    });
  }

  // ── No alert: compact header + 2×2 unit data grid ─────────────────────────
  Widget _buildClearView(double s) {
    final frontDist = data.frontOnline && data.frontDistance >= 0 && data.frontState > 0
        ? '${(data.frontDistance / 100).toStringAsFixed(1)} m' : null;
    final rearDist = data.rearOnline && data.rearDistance >= 0 && data.rearState > 0
        ? '${(data.rearDistance / 100).toStringAsFixed(1)} m' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── All-clear badge ─────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF141A28), Color(0xFF0E1320)],
            ),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(color: _kGreen.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.08), blurRadius: 24, spreadRadius: -6)],
          ),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(8 * s),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10 * s)),
              child: Icon(Icons.shield_outlined, color: _kGreen, size: 22 * s),
            ),
            SizedBox(width: 12 * s),
            Flexible(
              child: Text('ALL SYSTEMS CLEAR',
                  style: GoogleFonts.inter(
                      color: _kGreen, fontSize: 17 * s,
                      fontWeight: FontWeight.w800, letterSpacing: 0.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        SizedBox(height: 10 * s),
        // ── 2×2 unit card grid ──────────────────────────────────────────────
        Expanded(child: Row(children: [
          Expanded(child: Column(children: [
            Expanded(child: _UnitCard(
              label: 'FRONT', icon: Icons.sensors_rounded,
              primary: frontDist ?? (data.frontOnline ? 'CLEAR' : 'OFFLINE'),
              secondary: data.frontOnline ? data.frontStateName : '',
              color: data.frontOnline ? _frontColor : _kText2,
              scale: s,
            )),
            SizedBox(height: 8 * s),
            Expanded(child: _UnitCard(
              label: 'STABILITY', icon: Icons.adjust_rounded,
              primary: data.leanOnline ? data.leanRiskName : 'OFFLINE',
              secondary: data.leanOnline
                  ? 'Roll ${data.roll.toStringAsFixed(1)}°' : '',
              color: data.leanOnline ? _leanColor : _kText2,
              scale: s,
            )),
          ])),
          SizedBox(width: 8 * s),
          Expanded(child: Column(children: [
            Expanded(child: _UnitCard(
              label: 'REAR', icon: Icons.directions_car_rounded,
              primary: rearDist ?? (data.rearOnline ? 'CLEAR' : 'OFFLINE'),
              secondary: data.rearOnline ? data.rearStateName : '',
              color: data.rearOnline
                  ? (data.rearState > 0 ? _kRed : _kGreen) : _kText2,
              scale: s,
            )),
            SizedBox(height: 8 * s),
            Expanded(child: _UnitCard(
              label: 'LANE', icon: Icons.add_road_rounded,
              primary: data.laneOnline ? _laneDisplay : 'OFFLINE',
              secondary: data.laneOnline && data.laneState != 0
                  ? data.laneStateName : '',
              color: data.laneOnline ? _laneColor : _kText2,
              scale: s,
            )),
          ])),
        ])),
      ],
    );
  }

  // ── Alert active: large alert card + 3 remaining compact unit rows ─────────
  Widget _buildAlertView(_AlertInfo alert, double s) {
    final src = alert.source;

    // Build the 3 status items that are NOT the alerting unit.
    final statuses = <_StatusItem>[];
    if (src != 'front') {
      final frontDist = data.frontOnline && data.frontDistance >= 0 && data.frontState > 0
          ? '${(data.frontDistance / 100).toStringAsFixed(1)} m' : null;
      statuses.add(_StatusItem(
        icon: Icons.sensors_rounded, label: 'Front',
        value: frontDist ?? (data.frontOnline ? 'CLEAR' : 'OFFLINE'),
        color: data.frontOnline ? _frontColor : _kText2,
        scale: s,
      ));
    }
    if (src != 'rear') {
      statuses.add(_StatusItem(
        icon: Icons.directions_car_rounded, label: 'Rear',
        value: data.rearOnline ? data.rearStateName : 'OFFLINE',
        color: data.rearOnline ? (data.rearState > 0 ? _kRed : _kGreen) : _kText2,
        scale: s,
      ));
    }
    if (src != 'stability') {
      statuses.add(_StatusItem(
        icon: Icons.adjust_rounded, label: 'Stability',
        value: data.leanOnline ? data.leanRiskName : 'OFFLINE',
        color: data.leanOnline ? _leanColor : _kText2,
        scale: s,
      ));
    }
    if (src != 'lane') {
      statuses.add(_StatusItem(
        icon: Icons.add_road_rounded, label: 'Lane',
        value: data.laneOnline ? _laneDisplay : 'OFFLINE',
        color: data.laneOnline ? _laneColor : _kText2,
        scale: s,
      ));
    }

    return Column(children: [
      Expanded(
        flex: 62,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 28 * s, vertical: 22 * s),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF141A28), Color(0xFF0E1320)],
            ),
            borderRadius: BorderRadius.circular(22 * s),
            border: Border.all(color: alert.color.withOpacity(0.22), width: 1.5),
            boxShadow: [BoxShadow(
              color: alert.color.withOpacity(0.10),
              blurRadius: 40, spreadRadius: -8,
            )],
          ),
          child: _AlertContent(alert: alert, scale: s),
        ),
      ),
      SizedBox(height: 12 * s),
      Expanded(
        flex: 26,
        child: Row(children: [
          for (int i = 0; i < statuses.length; i++) ...[
            if (i > 0)
              Container(width: 1, color: _kBorder,
                  margin: EdgeInsets.symmetric(vertical: 6 * s)),
            Expanded(child: statuses[i]),
          ],
        ]),
      ),
    ]);
  }
}

// ─── DATA MODELS ──────────────────────────────────────────────────────────────
class _AlertInfo {
  const _AlertInfo({required this.title, required this.message,
      required this.color, required this.metrics, this.source = ''});
  final String title, message, source;
  final Color  color;
  final List<_Metric> metrics;
}

class _Metric {
  const _Metric(this.label, this.value, this.color);
  final String label, value; final Color color;
}

// ─── UNIT DATA CARD (shown in 2×2 grid when no alert) ────────────────────────
class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.label, required this.icon, required this.color,
    required this.primary, required this.secondary, this.scale = 1.0,
  });
  final String label, primary, secondary;
  final IconData icon;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
        horizontal: 16 * scale, vertical: 14 * scale),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF141A28), Color(0xFF0E1320)],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withOpacity(0.22), width: 1.2),
      boxShadow: [BoxShadow(
        color: color.withOpacity(0.06), blurRadius: 16, spreadRadius: -4)],
    ),
    child: LayoutBuilder(builder: (_, c) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: c.maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: color.withOpacity(0.80), size: 18 * scale),
              SizedBox(width: 7 * scale),
              Text(label,
                  style: GoogleFonts.inter(
                      color: _kText3, fontSize: 11 * scale,
                      fontWeight: FontWeight.w600, letterSpacing: 1.1)),
            ]),
            SizedBox(height: 10 * scale),
            Text(primary,
                style: GoogleFonts.inter(
                    color: color, fontSize: 26 * scale,
                    fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (secondary.isNotEmpty) ...[
              SizedBox(height: 4 * scale),
              Text(secondary,
                  style: GoogleFonts.inter(
                      color: _kText2, fontSize: 13 * scale,
                      fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    )),
  );
}

// ─── ALERT CONTENT ────────────────────────────────────────────────────────────
class _AlertContent extends StatelessWidget {
  const _AlertContent({required this.alert, this.scale = 1.0});
  final _AlertInfo alert;
  final double scale;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Icon + title + message
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, color: alert.color, size: 48 * scale),
        SizedBox(width: 14 * scale),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title,
                style: GoogleFonts.inter(
                    color: alert.color, fontSize: 28 * scale,
                    fontWeight: FontWeight.w800, height: 1.08,
                    letterSpacing: 0.2),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            SizedBox(height: 6 * scale),
            Text(alert.message,
                style: GoogleFonts.inter(
                    color: _kText1, fontSize: 16 * scale,
                    fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),

      const Spacer(),

      // Metrics row
      IntrinsicHeight(
        child: Row(children: [
          for (int i = 0; i < alert.metrics.length; i++) ...[
            if (i > 0) Container(
              width: 1, color: _kBorder,
              margin: EdgeInsets.symmetric(horizontal: 16 * scale),
            ),
            Expanded(child: _MetricBox(m: alert.metrics[i], scale: scale)),
          ],
        ]),
      ),
    ],
  );
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({required this.m, this.scale = 1.0});
  final _Metric m;
  final double scale;

  @override
  Widget build(BuildContext context) {
    // Split "2.4 m" / "12 km/h" into a big value and a small unit suffix.
    final parts = m.value.split(' ');
    final head = parts.first;
    final unit = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(m.label,
            style: GoogleFonts.inter(
                color: _kText2, fontSize: 12 * scale,
                fontWeight: FontWeight.w600, letterSpacing: 1.1)),
        SizedBox(height: 6 * scale),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: head,
              style: GoogleFonts.inter(
                  color: m.color, fontSize: 32 * scale,
                  fontWeight: FontWeight.w800, height: 1),
            ),
            if (unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: GoogleFonts.inter(
                    color: m.color, fontSize: 16 * scale,
                    fontWeight: FontWeight.w600),
              ),
          ]),
        ),
      ],
    );
  }
}

// ─── STATUS ITEM (borderless icon + label + value) ───────────────────────────
class _StatusItem extends StatelessWidget {
  const _StatusItem({required this.icon, required this.label,
      required this.value, required this.color, this.scale = 1.0});
  final IconData icon; final String label, value; final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: _kText3, size: 30 * scale),
      SizedBox(width: 10 * scale),
      Flexible(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: _kText3, fontSize: 13 * scale,
                    fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2 * scale),
            Text(value,
                style: GoogleFonts.inter(
                    color: color, fontSize: 16 * scale,
                    fontWeight: FontWeight.w800, letterSpacing: 0.3),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CAR VIEW (left panel)
// ─────────────────────────────────────────────────────────────────────────────
class _CarView extends StatefulWidget {
  const _CarView({required this.data});
  final DrivoraSensorData data;
  @override
  State<_CarView> createState() => _CarViewState();
}

class _CarViewState extends State<_CarView> with TickerProviderStateMixin {
  late AnimationController _pulse, _alert, _lane;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _alert = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true);
    _lane  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 560))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose(); _alert.dispose(); _lane.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CarView old) {
    super.didUpdateWidget(old);
    final minD = [
      if (widget.data.frontDistance >= 0) widget.data.frontDistance,
      if (widget.data.rearDistance  >= 0) widget.data.rearDistance,
    ].fold<double>(9999, math.min);
    final dur = minD < 20  ? const Duration(milliseconds: 260)
        : minD < 50  ? const Duration(milliseconds: 520)
        : minD < 100 ? const Duration(milliseconds: 850)
        :              const Duration(milliseconds: 1200);
    if (_pulse.duration != dur) { _pulse.duration = dur; _pulse.repeat(); }
  }

  @override
  Widget build(BuildContext context) => Container(
    color: _kBg,
    child: LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final carW = w * 0.76;
      final carH = (h * 0.70).clamp(0.0, h - 80.0);

      return Stack(children: [
        // Sensor / lane overlays (drawn behind car)
        AnimatedBuilder(
          animation: Listenable.merge([_pulse, _alert, _lane]),
          builder: (_, __) => CustomPaint(
            size: Size(w, h),
            painter: _OverlayPainter(
              data:       widget.data,
              pulse:      _pulse.value,
              alertFlash: _alert.value,
              lanePulse:  _lane.value,
              carW:       carW,
              carH:       carH,
            ),
          ),
        ),

        // Car PNG image
        Center(
          child: SizedBox(
            width: carW,
            height: carH,
            child: Image.asset(
              'assets/car_top.png',
              fit: BoxFit.contain,
              color: Colors.white.withOpacity(0.90),
              colorBlendMode: BlendMode.modulate,
              errorBuilder: (_, __, ___) =>
                  CustomPaint(painter: _FallbackCarPainter(), size: Size(carW, carH)),
            ),
          ),
        ),

        // Lean scope on top of car
        Positioned.fill(child: _EmbeddedLeanScope(
            data: widget.data, carW: carW, carH: carH)),
      ]);
    }),
  );
}

// ─── SENSOR OVERLAY PAINTER ───────────────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({
    required this.data, required this.pulse, required this.alertFlash,
    required this.lanePulse, required this.carW, required this.carH,
  });
  final DrivoraSensorData data;
  final double pulse, alertFlash, lanePulse, carW, carH;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;

    // Arcs/zones placed at the outer ring edge for a tight fit to the car body.
    final frontArcY = cy - carH * 0.36;
    final rearZoneY = cy + carH * 0.35;

    // ── Perspective road lane lines ───────────────────────────────────────
    _paintLaneLines(canvas, size, cx, cy);

    // ── Front sonar arcs — always draw; dim when sensor offline ─────────
    _paintFrontSonar(canvas, cx, frontArcY, size.width);
    if (data.frontOnline && data.frontDistance >= 0) {
      _distLabel(canvas,
          Offset(cx, frontArcY - 26),
          '${(data.frontDistance / 100).toStringAsFixed(1)} m',
          data.frontColor);
    }

    // ── Rear zone blocks — always draw; dim when sensor offline ──────────
    _paintRearZones(canvas, cx, cy, rearZoneY);
    if (data.rearOnline && data.rearDistance >= 0) {
      _distLabel(canvas,
          Offset(cx, rearZoneY + carH * 0.10),
          '${(data.rearDistance / 100).toStringAsFixed(1)} m',
          data.rearColor);
    }

    // ── Body glow on warning/critical ─────────────────────────────────────
    final crit = data.frontState == 3 || data.rearState == 3;
    final warn = data.frontState >= 2 || data.rearState >= 2;
    if (crit || warn) {
      final gc = crit ? _kRed : _kAmber;
      final gi = crit ? 0.18 + alertFlash * 0.22 : 0.09;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy),
              width: carW * 1.08, height: carH * 1.04),
          Radius.circular(carW * 0.28),
        ),
        Paint()
          ..color = gc.withOpacity(gi)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }
  }

  // ── Perspective road lane rails (soft gradient side bars) ──────────────────
  void _paintLaneLines(Canvas canvas, Size size, double cx, double cy) {
    // Two separate rails that converge toward — but never touch — a high point,
    // giving the brushed "side rail" look instead of a sharp apex.
    final topY    = cy - carH * 0.62;
    final startY  = cy + carH * 0.66;
    final topGap  = carW * 0.26;   // half-gap at the top (keeps rails apart)
    final botGap  = carW * 0.70;   // half-gap at the bottom (wide spread)

    final lTop = Offset(cx - topGap, topY);
    final lBot = Offset(cx - botGap, startY);
    final rTop = Offset(cx + topGap, topY);
    final rBot = Offset(cx + botGap, startY);

    final leftOn  = data.laneState == 1;
    final rightOn = data.laneState == 2;

    void rail(Offset a, Offset b, bool active) {
      // Wide soft glow behind the line.
      canvas.drawLine(a, b,
        Paint()
          ..color = (active ? _kAmber : Colors.white).withOpacity(active ? 0.35 * lanePulse : 0.08)
          ..strokeWidth = active ? 32 : 24
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

      // Bright gradient core — fades toward vanishing point and bottom.
      final rect = Rect.fromPoints(a, b);
      final base = active ? _kAmber : Colors.white;
      canvas.drawLine(a, b,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              base.withOpacity(0),
              base.withOpacity(active ? (0.75 + lanePulse * 0.25) : 0.70),
              base.withOpacity(0),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect)
          ..strokeWidth = active ? 9.0 : 7.0
          ..strokeCap = StrokeCap.round);
    }

    rail(lBot, lTop, leftOn);
    rail(rBot, rTop, rightOn);
  }

  // ── Front sonar — 3 thick arc SEGMENTS close to the car front ───────────────
  void _paintFrontSonar(Canvas canvas, double cx, double arcY, double panelW) {
    final offline = !data.frontOnline;
    final state   = offline ? 0 : data.frontState;
    final color   = offline ? _kOffline : data.frontColor;
    final strokeW = state >= 2 ? 12.0 : 9.0;

    // Arc is a 130° segment centered at 12 o'clock (top of car front).
    const sweepRad = math.pi * 130.0 / 180.0;          // 130°
    const startRad = -math.pi / 2 - sweepRad / 2;      // centered at top

    // Size bands relative to car body width (not panel width).
    final bodyW = carH * 0.78;
    final bands = [bodyW * 0.88, bodyW * 1.28, bodyW * 1.68];

    for (var i = 0; i < 3; i++) {
      final ew = bands[i];
      final eh = ew * 0.40; // arc height (depth in front of car)

      final double rawOp;
      if (offline) {
        rawOp = 0.18 - i * 0.04;
      } else if (state >= 2) {
        rawOp = (0.90 - i * 0.20) * (0.55 + alertFlash * 0.45);
      } else if (state == 1) {
        rawOp = 0.52 - i * 0.12;
      } else {
        rawOp = 0.36 - i * 0.08;
      }
      final op = rawOp.clamp(0.0, 1.0);
      if (op < 0.01) continue;

      // Glow bloom.
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, arcY), width: ew + 14, height: eh + 14),
        startRad, sweepRad, false,
        Paint()
          ..color = color.withOpacity(op * 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW + 12
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );

      // Thick arc segment.
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, arcY), width: ew, height: eh),
        startRad, sweepRad, false,
        Paint()
          ..color = color.withOpacity(op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── Rear zone fan shapes ──────────────────────────────────────────────────
  void _paintRearZones(Canvas canvas, double cx, double cy, double topY) {
    final offline = !data.rearOnline;
    // Zone height: enough to look substantial but never overflow panel.
    final zH = carH * 0.18;

    // Center — symmetric trapezoid (wider at bottom) with gentle curved bottom.
    // Top edge has a slight concave curve hugging the car's rear bumper arc.
    {
      const topHW = 0.155; // half-width at top as fraction of carW
      const botHW = 0.260; // half-width at bottom
      final path = Path()
        ..moveTo(cx - carW * topHW, topY + 4)
        ..quadraticBezierTo(cx, topY, cx + carW * topHW, topY + 4)
        ..lineTo(cx + carW * botHW, topY + zH)
        ..quadraticBezierTo(cx, topY + zH * 1.14, cx - carW * botHW, topY + zH)
        ..close();
      _applyZoneStyle(canvas, path,
          offline ? 0 : data.rearCenterState,
          offline ? _kOffline : data.rearCenterColor, offline);
    }

    // Left — quadrilateral with TWO arc edges (curved top + curved bottom).
    {
      final lTI = cx - carW * 0.170; // top-inner x
      final lTO = cx - carW * 0.340; // top-outer x
      final path = Path()
        ..moveTo(lTI, topY + 3)
        ..quadraticBezierTo((lTI + lTO) / 2, topY, lTO, topY + 3) // top arc
        ..lineTo(cx - carW * 0.490, topY + zH)                     // outer-bottom corner
        ..quadraticBezierTo(cx - carW * 0.390, topY + zH + 5,
                            cx - carW * 0.285, topY + zH)          // bottom arc
        ..close();
      _applyZoneStyle(canvas, path,
          offline ? 0 : data.rearLeftState,
          offline ? _kOffline : data.rearLeftColor, offline);
    }

    // Right — mirror of left, also TWO arc edges.
    {
      final rTI = cx + carW * 0.170;
      final rTO = cx + carW * 0.340;
      final path = Path()
        ..moveTo(rTI, topY + 3)
        ..quadraticBezierTo((rTI + rTO) / 2, topY, rTO, topY + 3) // top arc
        ..lineTo(cx + carW * 0.490, topY + zH)                     // outer-bottom corner
        ..quadraticBezierTo(cx + carW * 0.390, topY + zH + 5,
                            cx + carW * 0.285, topY + zH)          // bottom arc
        ..close();
      _applyZoneStyle(canvas, path,
          offline ? 0 : data.rearRightState,
          offline ? _kOffline : data.rearRightColor, offline);
    }
  }

  void _applyZoneStyle(Canvas canvas, Path path, int state, Color color, bool offline) {
    final fillOp   = offline ? 0.10
        : state >= 2 ? (0.35 + alertFlash * 0.25)
        : state == 1 ? 0.22 : 0.14;
    final borderOp = offline ? 0.28
        : state >= 2 ? (0.90 + alertFlash * 0.10).clamp(0.0, 1.0)
        : state == 1 ? 0.70 : 0.50;

    // Neon glow bloom.
    canvas.drawPath(path,
      Paint()
        ..color = color.withOpacity(borderOp * 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));

    // Translucent fill.
    canvas.drawPath(path,
      Paint()..color = color.withOpacity(fillOp)..style = PaintingStyle.fill);

    // Bright neon border.
    canvas.drawPath(path,
      Paint()
        ..color = color.withOpacity(borderOp)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
  }

  void _distLabel(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700,
              shadows: [Shadow(color: color.withOpacity(0.8), blurRadius: 8)])),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter old) =>
      old.pulse != pulse || old.alertFlash != alertFlash ||
      old.data != data || old.lanePulse != lanePulse;
}

// ─── FALLBACK CAR (drawn if PNG not found) ────────────────────────────────────
class _FallbackCarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;
    final carRect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, Radius.circular(w * 0.28)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2C3650), Color(0xFF141824)],
        ).createShader(carRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, Radius.circular(w * 0.28)),
      Paint()
        ..color = const Color(0xFF3A4560).withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// EMBEDDED LEAN SCOPE (stability dot overlay)
// ─────────────────────────────────────────────────────────────────────────────
class _EmbeddedLeanScope extends StatefulWidget {
  const _EmbeddedLeanScope({required this.data, required this.carW, required this.carH});
  final DrivoraSensorData data;
  final double carW, carH;
  @override
  State<_EmbeddedLeanScope> createState() => _EmbeddedLeanScopeState();
}

class _EmbeddedLeanScopeState extends State<_EmbeddedLeanScope>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _cx = 0, _cy = 0, _tx = 0, _ty = 0;
  bool _init = false;
  static const double _smooth = 0.28;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (!mounted || !_init) return;
      final nx = _cx + (_tx - _cx) * _smooth;
      final ny = _cy + (_ty - _cy) * _smooth;
      if ((nx - _cx).abs() > 0.001 || (ny - _cy).abs() > 0.001) {
        setState(() { _cx = nx; _cy = ny; });
      }
    })..start();
  }

  @override void dispose() { _ticker.dispose(); super.dispose(); }

  double _pos(double val, double crit, double r) {
    const iR = 0.78, oR = 0.90, hR = 2.85;
    final a = val.abs(), s = val >= 0 ? 1.0 : -1.0;
    final iS = math.max(crit, 0.01), oS = math.max(crit * hR, iS + 0.01);
    double mag;
    if (a <= iS) {
      mag = (a / iS) * iR;
    } else {
      final t = math.min((a - iS) / (oS - iS), 1);
      mag = iR + (oR - iR) * ((1 - math.exp(-3.2 * t)) / (1 - math.exp(-3.2)));
    }
    return s * mag * r;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
    // Dot movement radius: ~20% of carH matches innermost ring scale.
    final scopeR = widget.carH * 0.20;
    final ox = c.maxWidth / 2, oy = c.maxHeight / 2;
    final px = ox + _pos(widget.data.roll,  widget.data.criticalRollDeg,  scopeR);
    final py = oy + _pos(widget.data.pitch, widget.data.criticalPitchDeg, scopeR);
    if (!_init) { _cx = px; _cy = py; _init = true; }
    _tx = px; _ty = py;
    return CustomPaint(
      size: Size(c.maxWidth, c.maxHeight),
      painter: _ScopePainter(
        dotX: _cx, dotY: _cy,
        cx: ox, cy: oy, radius: scopeR,
        riskLevel: widget.data.leanRiskLevel,
        carW: widget.carW, carH: widget.carH,
      ),
    );
  });
}

class _ScopePainter extends CustomPainter {
  const _ScopePainter({
    required this.dotX, required this.dotY,
    required this.cx,   required this.cy,   required this.radius,
    required this.riskLevel,
    required this.carW, required this.carH,
  });
  final double dotX, dotY, cx, cy, radius;
  final int    riskLevel;
  final double carW, carH;

  @override
  void paint(Canvas canvas, Size size) {
    // ── Concentric ovals fitted to actual car body outline ────────────────
    // Scale to carH so the outermost ring bottom aligns with rearZoneY.
    // rh = rw * 0.80 gives a moderate perspective compression.
    const factors = [0.88, 0.68, 0.50, 0.32];
    for (var i = 0; i < factors.length; i++) {
      final f  = factors[i];
      final rw = carH * f;
      final rh = rw * 0.80; // perspective compression
      // Inner rings slightly brighter than outer ones.
      final op = 0.10 + (factors.length - 1 - i) * 0.055;

      // Subtle glow halo behind each ring.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rw + 6, height: rh + 6),
        Paint()
          ..color = Colors.white.withOpacity(op * 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // White/gray ring.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rw, height: rh),
        Paint()
          ..color = Colors.white.withOpacity(op * 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }

    // ── Lean position dot ─────────────────────────────────────────────────
    final dotColor = riskLevel == 2 ? _kRed
        : riskLevel == 1 ? _kAmber
        : Colors.white.withOpacity(0.85);
    final dotPos = Offset(dotX, dotY);

    // Glow halo.
    canvas.drawCircle(dotPos, 12,
      Paint()
        ..color = dotColor.withOpacity(0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));

    // Filled dot.
    canvas.drawCircle(dotPos, 5,
      Paint()..color = dotColor.withOpacity(0.92));

    // White centre pip.
    canvas.drawCircle(dotPos, 2,
      Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ScopePainter o) =>
      o.dotX != dotX || o.dotY != dotY || o.riskLevel != riskLevel ||
      o.carW != carW || o.carH != carH;
}