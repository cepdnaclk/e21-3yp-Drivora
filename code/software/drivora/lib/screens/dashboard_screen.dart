import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/wifi_sensor_service.dart';
import '../services/audio_service.dart';
import '../models/sensor_data.dart';
import 'alerts_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'account_screen.dart';

// ─── PALETTE ─────────────────────────────────────────────────────────────────
const _kBg        = Color(0xFF060810);
const _kSurface   = Color(0xFF0C0F1A);
const _kSurface2  = Color(0xFF111526);
const _kBorder    = Color(0xFF1C2236);
const _kBlue      = Color(0xFF2979FF);
const _kCyan      = Color(0xFF00E5FF);
const _kGreen     = Color(0xFF00E676);
const _kAmber     = Color(0xFFFFAB00);
const _kRed       = Color(0xFFFF1744);
const _kPurple    = Color(0xFF7C4DFF);

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
    AlertsScreen(),
    AccountScreen(),
    SettingsScreen(),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _kBg,
    body: IndexedStack(index: _idx, children: _pages),
    bottomNavigationBar: _NavBar(current: _idx, onTap: (i) => setState(() => _idx = i)),
  );
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _kSurface,
      border: Border(top: BorderSide(color: _kBorder, width: 1)),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NI(Icons.speed_rounded,                  'DRIVE',   0, current, onTap),
            _NI(Icons.analytics_rounded,              'DATA',    1, current, onTap),
            _NI(Icons.notifications_active_rounded,   'ALERTS',  2, current, onTap),
            _NI(Icons.person_rounded,                 'ACCOUNT', 3, current, onTap),
            _NI(Icons.tune_rounded,                   'SETUP',   4, current, onTap),
          ],
        ),
      ),
    ),
  );
}

class _NI extends StatelessWidget {
  const _NI(this.icon, this.label, this.index, this.current, this.onTap);
  final IconData icon; final String label; final int index, current;
  final ValueChanged<int> onTap;
  @override
  Widget build(BuildContext context) {
    final a = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: a ? _kCyan : Colors.white24, size: 26),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.rajdhani(
            color: a ? _kCyan : Colors.white24, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ]),
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
  String _userName = 'DRIVER';

  @override
  void initState() { super.initState(); _loadUser(); }

  Future<void> _loadUser() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _userName = (p.getString('userName') ?? 'DRIVER').toUpperCase());
  }

  @override
  Widget build(BuildContext context) => Consumer<WiFiSensorService>(
      builder: (context, svc, _) {
        final d     = svc.currentData;
        final alerts = svc.activeAlerts;
        final speedAlert = d.speed > 100;

        return Stack(children: [
          Column(children: [
            _Header(svc: svc, userName: _userName, audio: _audio),
            Expanded(child: _Body(data: d)),
            _CmdBtn(svc: svc),
          ]),

          // Floating alert banner
          if (speedAlert || alerts.isNotEmpty)
            Positioned(
              top: 118, left: 0, right: 0,
              child: Center(child: _AlertBanner(
                title:   speedAlert ? 'OVERSPEED DETECTED'          : alerts.first.title.toUpperCase(),
                message: speedAlert ? 'REDUCE VELOCITY BELOW 100 CM/S' : alerts.first.message.toUpperCase(),
                onDismiss: speedAlert ? null : svc.clearAlerts,
              )),
            ),
        ]);
      },
    );
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({required this.svc, required this.userName, required this.audio});
  final WiFiSensorService svc;
  final String userName;
  final AudioService audio;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 14),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorder, width: 1.5)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _kSurface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kCyan.withOpacity(0.3), width: 1.5),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(radius: 18, backgroundColor: _kBlue,
                  child: Icon(Icons.person, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(userName, style: GoogleFonts.rajdhani(
                    color: _kCyan, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                const Text('PROFILE', style: TextStyle(
                    color: Colors.white54, fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ]),
            ]),
          ),
        ),
        const Spacer(),
        Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [_kCyan, _kBlue, _kPurple],
            ).createShader(r),
            child: Text('ADAS BRAIN HUB',
                style: GoogleFonts.orbitron(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w900, letterSpacing: 2.5)),
          ),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _Pill(
              label: 'LINK: ${svc.isConnected ? "ACTIVE" : "STANDBY"}',
              active: svc.isConnected,
              dotColor: svc.isConnected ? _kGreen : _kRed,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: audio.playSystemAlert,
              child: const _Pill(label: '♪  AUDIO', active: false, dotColor: _kAmber),
            ),
          ]),
        ]),
        const Spacer(),
      ]),
    );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active, required this.dotColor});
  final String label; final bool active; final Color dotColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: _kSurface2,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: dotColor.withOpacity(0.3), width: 1),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor,
              boxShadow: [BoxShadow(color: dotColor.withOpacity(0.7), blurRadius: 5)])),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
          color: active ? dotColor : Colors.white54, fontSize: 10,
          fontWeight: FontWeight.w900, letterSpacing: 0.8)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY
// ─────────────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  const _Body({required this.data});
  final DrivoraSensorData data;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(width: 200, child: _LeftPanel(data: data)),
      const SizedBox(width: 12),
      Expanded(flex: 2, child: _CarCanvas(data: data)),
      const SizedBox(width: 12),
      SizedBox(width: 200, child: _RightPanel(data: data)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// LEFT PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.data});
  final DrivoraSensorData data;

  @override
  Widget build(BuildContext context) {
    final fc = data.frontStateColor;
    final lc = data.leanRiskLevel == 2 ? _kRed : data.leanRiskLevel == 1 ? _kAmber : _kGreen;

    return Column(children: [
      Expanded(flex: 50, child: _Card(
        accent: fc,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader('FRONT COLLISION', data.frontOnline, fc),
          const SizedBox(height: 10),
          _SensorRing(color: fc, icon: Icons.sensors, online: data.frontOnline),
          const SizedBox(height: 10),
          _BigMetricRow('DISTANCE', data.frontDistance >= 0
              ? data.frontDistance.toStringAsFixed(1) : '– –', 'CM', fc),
          const SizedBox(height: 8),
          _StateBar(data.frontStateName, fc),
          const Spacer(),
          _SubGrid([
            _SMini('STATUS', data.frontOnline ? 'ONLINE' : 'OFFLINE', data.frontOnline ? _kGreen : _kRed),
          ]),
        ]),
      )),
      const SizedBox(height: 12),
      Expanded(flex: 50, child: _Card(
        accent: lc,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader('COG ATTITUDE', data.leanOnline, lc),
          const SizedBox(height: 10),
          _StateBar(data.leanRiskName, lc),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniMetric('ROLL',  '${data.roll.toStringAsFixed(1)}°',   lc)),
            const SizedBox(width: 8),
            Expanded(child: _MiniMetric('PITCH', '${data.pitch.toStringAsFixed(1)}°',  lc)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _MiniMetric('CONF',  data.confidence.toStringAsFixed(2), Colors.white54)),
            const SizedBox(width: 8),
            Expanded(child: _MiniMetric('RISK',  ['LOW', 'MED', 'HIGH'][data.leanRiskLevel.clamp(0, 2)],
                [_kGreen, _kAmber, _kRed][data.leanRiskLevel.clamp(0, 2)])),
          ]),
          const Spacer(),
          _LeanBar(roll: data.roll, critical: data.criticalRollDeg, color: lc),
        ]),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.data});
  final DrivoraSensorData data;

  @override
  Widget build(BuildContext context) {
    final rc = data.rearStateColor;
    final laneColor = data.laneState == 0 ? _kGreen : data.laneState == 1 ? _kAmber : _kRed;

    return Column(children: [
      Expanded(flex: 50, child: _Card(
        accent: rc,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader('REAR COLLISION', data.rearOnline, rc),
          const SizedBox(height: 10),
          _SensorRing(color: rc, icon: Icons.sensors, online: data.rearOnline),
          const SizedBox(height: 10),
          _BigMetricRow('DISTANCE', data.rearDistance >= 0
              ? data.rearDistance.toStringAsFixed(1) : '– –', 'CM', rc),
          const SizedBox(height: 8),
          _StateBar(data.rearStateName, rc),
          const Spacer(),
          _SubGrid([
            _SMini('STATUS', data.rearOnline ? 'ONLINE' : 'OFFLINE', data.rearOnline ? _kGreen : _kRed),
          ]),
        ]),
      )),
      const SizedBox(height: 12),
      Expanded(flex: 50, child: _Card(
        accent: laneColor,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardHeader('LANE ASSIST', data.laneOnline, laneColor),
          const SizedBox(height: 10),
          _StateBar(data.laneStateName, laneColor),
          const SizedBox(height: 10),
          _LaneSideRow('LEFT  LANE',  data.laneState == 1, 'CROSSING', 'CLEAR'),
          const SizedBox(height: 8),
          _LaneSideRow('RIGHT LANE',  data.laneState == 2, 'CROSSING', 'CLEAR'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _MiniMetric('SYSTEM', 'ACTIVE', data.laneOnline ? _kCyan : Colors.white38)),
            const SizedBox(width: 8),
            const Expanded(child: _MiniMetric('MODE',   'AUTO',   Colors.white60)),
          ]),
          const Spacer(),
          _LanePositionBar(laneState: data.laneState),
        ]),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.accent});
  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withOpacity(0.25), width: 1.5),
      boxShadow: [BoxShadow(color: accent.withOpacity(0.06), blurRadius: 18, spreadRadius: 1)],
    ),
    child: child,
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader(this.title, this.online, this.color);
  final String title; final bool online; final Color color;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: GoogleFonts.rajdhani(
          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: (online ? _kGreen : _kRed).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: (online ? _kGreen : _kRed).withOpacity(0.4)),
        ),
        child: Text(online ? '● ON' : '● OFF',
            style: TextStyle(color: online ? _kGreen : _kRed, fontSize: 8, fontWeight: FontWeight.w900)),
      ),
    ],
  );
}

class _SensorRing extends StatelessWidget {
  const _SensorRing({required this.color, required this.icon, required this.online});
  final Color color; final IconData icon; final bool online;
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 62, height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(online ? 0.7 : 0.25), width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(online ? 0.3 : 0.0), blurRadius: 16)],
      ),
      child: Icon(icon, color: color.withOpacity(online ? 1 : 0.3), size: 28),
    ),
  );
}

class _BigMetricRow extends StatelessWidget {
  const _BigMetricRow(this.label, this.value, this.unit, this.color);
  final String label, value, unit; final Color color;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    const SizedBox(height: 3),
    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
      Text(value, style: GoogleFonts.orbitron(color: color, fontSize: 26, fontWeight: FontWeight.w900)),
      const SizedBox(width: 4),
      Text(unit, style: TextStyle(color: color.withOpacity(0.55), fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  ]);
}

class _StateBar extends StatelessWidget {
  const _StateBar(this.label, this.color);
  final String label; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.4), width: 1),
    ),
    alignment: Alignment.center,
    child: Text(label, style: GoogleFonts.rajdhani(
        color: color, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
  );
}

class _MG { const _MG(this.l, this.v, this.c); final String l, v; final Color c; }
class _MetricGrid extends StatelessWidget {
  const _MetricGrid(this.items);
  final List<_MG> items;
  @override
  Widget build(BuildContext context) => Row(children: items.map((m) => Expanded(
    child: Container(
      margin: EdgeInsets.only(right: m == items.last ? 0 : 6),
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(m.l, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(m.v, style: GoogleFonts.orbitron(color: m.c, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    ),
  )).toList());
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.label, this.value, this.color);
  final String label, value; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.orbitron(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  );
}

class _SMini { const _SMini(this.l, this.v, this.c); final String l, v; final Color c; }
class _SubGrid extends StatelessWidget {
  const _SubGrid(this.items);
  final List<_SMini> items;
  @override
  Widget build(BuildContext context) => Row(children: items.map((m) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: BoxDecoration(
        color: m.c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: m.c.withOpacity(0.25)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(m.l, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.8)),
        Text(m.v, style: TextStyle(color: m.c, fontSize: 9, fontWeight: FontWeight.w900)),
      ]),
    ),
  )).toList());
}

class _LeanBar extends StatelessWidget {
  const _LeanBar({required this.roll, required this.critical, required this.color});
  final double roll, critical; final Color color;
  @override
  Widget build(BuildContext context) {
    final pct = (roll / math.max(critical * 3, 1)).clamp(-1.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ROLL INDICATOR', style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 1)),
      const SizedBox(height: 4),
      Container(
        height: 6, width: double.infinity,
        decoration: BoxDecoration(color: _kSurface2, borderRadius: BorderRadius.circular(3)),
        child: FractionallySizedBox(
          alignment: pct >= 0 ? Alignment.centerLeft : Alignment.centerRight,
          widthFactor: pct.abs() * 0.5,
          child: Container(
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]),
          ),
        ),
      ),
    ]);
  }
}

class _LanePositionBar extends StatelessWidget {
  const _LanePositionBar({required this.laneState});
  final int laneState;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('LANE POSITION', style: TextStyle(color: Colors.white30, fontSize: 8, letterSpacing: 1)),
    const SizedBox(height: 4),
    Container(
      height: 22, width: double.infinity,
      decoration: BoxDecoration(color: _kSurface2, borderRadius: BorderRadius.circular(5),
          border: Border.all(color: _kBorder)),
      child: Row(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(
            color: laneState == 1 ? _kAmber.withOpacity(0.3) : Colors.transparent,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
            border: laneState == 1 ? Border.all(color: _kAmber.withOpacity(0.6)) : null,
          ),
          alignment: Alignment.center,
          child: Text('LEFT', style: TextStyle(
              color: laneState == 1 ? _kAmber : Colors.white24, fontSize: 8, fontWeight: FontWeight.w900)),
        )),
        Container(width: 1, color: _kBorder),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(width: 8, height: 14,
              decoration: BoxDecoration(
                color: laneState == 0 ? _kGreen.withOpacity(0.4) : _kAmber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: laneState == 0 ? _kGreen : _kAmber, width: 1),
              )),
        ),
        Container(width: 1, color: _kBorder),
        Expanded(child: Container(
          decoration: BoxDecoration(
            color: laneState == 2 ? _kAmber.withOpacity(0.3) : Colors.transparent,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
            border: laneState == 2 ? Border.all(color: _kAmber.withOpacity(0.6)) : null,
          ),
          alignment: Alignment.center,
          child: Text('RIGHT', style: TextStyle(
              color: laneState == 2 ? _kAmber : Colors.white24, fontSize: 8, fontWeight: FontWeight.w900)),
        )),
      ]),
    ),
  ]);
}

class _LaneSideRow extends StatelessWidget {
  const _LaneSideRow(this.label, this.active, this.alertTxt, this.clearTxt);
  final String label, alertTxt, clearTxt; final bool active;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.8)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (active ? _kAmber : _kGreen).withOpacity(0.12),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: (active ? _kAmber : _kGreen).withOpacity(0.4)),
        ),
        child: Text(active ? alertTxt : clearTxt,
            style: TextStyle(color: active ? _kAmber : _kGreen, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CAR CANVAS — lean scope now rendered ON TOP of car body, car enlarged
// ─────────────────────────────────────────────────────────────────────────────
class _CarCanvas extends StatefulWidget {
  const _CarCanvas({required this.data});
  final DrivoraSensorData data;
  @override
  State<_CarCanvas> createState() => _CarCanvasState();
}

class _CarCanvasState extends State<_CarCanvas> with TickerProviderStateMixin {
  late AnimationController _pulse, _alert, _signal, _lane;

  @override
  void initState() {
    super.initState();
    _pulse  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _alert  = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..repeat(reverse: true);
    _signal = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))..repeat();
    _lane   = AnimationController(vsync: this, duration: const Duration(milliseconds: 550))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); _alert.dispose(); _signal.dispose(); _lane.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(covariant _CarCanvas old) {
    super.didUpdateWidget(old);
    final minD = [
      if (widget.data.frontDistance >= 0) widget.data.frontDistance,
      if (widget.data.rearDistance  >= 0) widget.data.rearDistance,
    ].fold<double>(9999, math.min);
    final dur = minD < 20  ? const Duration(milliseconds: 280)
        : minD < 50  ? const Duration(milliseconds: 560)
        : minD < 100 ? const Duration(milliseconds: 880)
        :              const Duration(milliseconds: 1300);
    if (_pulse.duration != dur) { _pulse.duration = dur; _pulse.repeat(); }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: const RadialGradient(
        center: Alignment.center, radius: 0.85,
        colors: [Color(0xFF0D1220), _kBg],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _kBorder, width: 1.5),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(23),
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _alert, _signal, _lane]),
        builder: (context, _) => Stack(children: [
          // Road grid backdrop
          CustomPaint(size: Size.infinite, painter: _RoadGridPainter()),
          // Main car + sensors + lane lines (road layer)
          CustomPaint(size: Size.infinite, painter: _CarPainter(
            pulse: _pulse.value, alertFlash: _alert.value,
            signal: _signal.value, lanePulse: _lane.value,
            data: widget.data,
          )),
          // ── LEAN SCOPE rendered ON TOP of the car body ──────────────
          Positioned.fill(child: _EmbeddedLeanScope(data: widget.data)),
        ]),
      ),
    ),
  );
}

// ─── ROAD GRID BACKDROP ───────────────────────────────────────────────────────
class _RoadGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF0F1525)..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─── EMBEDDED LEAN SCOPE — draws on top of car body ──────────────────────────
class _EmbeddedLeanScope extends StatefulWidget {
  const _EmbeddedLeanScope({required this.data});
  final DrivoraSensorData data;
  @override
  State<_EmbeddedLeanScope> createState() => _EmbeddedLeanScopeState();
}

class _EmbeddedLeanScopeState extends State<_EmbeddedLeanScope> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _cx = 0, _cy = 0, _tx = 0, _ty = 0;
  bool _init = false;
  static const double _smooth = 0.30;

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
  @override
  void dispose() { _ticker.dispose(); super.dispose(); }

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
    // ── Scope radius sized to fit inside the enlarged car cabin ──────────
    // Car height = h * 0.65, cabin = carH * 0.42 ≈ h * 0.273
    // Use ~48% of min(w,h) so the scope fills the cabin area visually
    final scopeR = math.min(c.maxWidth, c.maxHeight) * 0.155;
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
      ),
    );
  });
}

class _ScopePainter extends CustomPainter {
  _ScopePainter({required this.dotX, required this.dotY,
    required this.cx, required this.cy, required this.radius, required this.riskLevel});
  final double dotX, dotY, cx, cy, radius;
  final int riskLevel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(cx, cy);
    final dotColor = riskLevel == 2 ? _kRed : riskLevel == 1 ? _kAmber : _kCyan;

    // Slight dark backing so scope is legible over car body
    canvas.drawCircle(center, radius,
        Paint()..color = const Color(0xAA060810));

    // Rings
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4.0),
          Paint()..color = const Color(0xFF1A2540)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    // Cross-hairs
    final lp = Paint()..color = const Color(0xFF1A2540)..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx - radius, cy), Offset(cx + radius, cy), lp);
    canvas.drawLine(Offset(cx, cy - radius), Offset(cx, cy + radius), lp);

    // Risk zone rings
    canvas.drawCircle(center, radius * 0.6,
        Paint()..color = _kAmber.withOpacity(0.10)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(center, radius * 0.85,
        Paint()..color = _kRed.withOpacity(0.10)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Scope outer border
    canvas.drawCircle(center, radius,
        Paint()..color = dotColor.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Dot
    final dotPos = Offset(dotX, dotY);
    canvas.drawCircle(dotPos, 14,
        Paint()..color = dotColor.withOpacity(0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(dotPos, 8,
        Paint()..color = dotColor.withOpacity(0.85));
    canvas.drawCircle(dotPos, 3.5,
        Paint()..color = Colors.white);
    // Cross-hair on dot
    final cp = Paint()..color = dotColor.withOpacity(0.6)..strokeWidth = 1.5;
    canvas.drawLine(dotPos.translate(-14, 0), dotPos.translate(14, 0), cp);
    canvas.drawLine(dotPos.translate(0, -14), dotPos.translate(0, 14), cp);
  }
  @override
  bool shouldRepaint(covariant _ScopePainter o) =>
      o.dotX != dotX || o.dotY != dotY || o.riskLevel != riskLevel;
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN CAR PAINTER — enlarged car (65% height, 0.52 aspect), corrected lane lines
// ─────────────────────────────────────────────────────────────────────────────
class _CarPainter extends CustomPainter {

  _CarPainter({required this.pulse, required this.alertFlash,
    required this.signal, required this.lanePulse, required this.data});
  final double pulse, alertFlash, signal, lanePulse;
  final DrivoraSensorData data;

  int    _waves(int s)  => s == 2 ? 6 : s == 1 ? 5 : 3;
  double _sw(int s)     => s == 2 ? 5.0 : s == 1 ? 3.5 : 2.0;
  double _spread(int s) => s == 2 ? 200 : s == 1 ? 165 : 130;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;

    // ── ENLARGED car: 65% height, wider aspect 0.52 ──────────────────────
    final carH = h * 0.65;
    final carW = carH * 0.52;
    final carRect = Rect.fromCenter(center: Offset(cx, cy), width: carW, height: carH);

    final fSensorY = cy - carH / 2 - 18;
    final rSensorY = cy + carH / 2 + 18;

    // ── LANE LINES — positioned flush to car sides, accounting for new carW ─
    _paintLaneLines(canvas, size, cx, cy, carW, carH);

    // ── FRONT SONAR ──────────────────────────────────────────────────────
    if (data.frontOnline) {
      _paintSonar(canvas, cx, fSensorY, data.frontState, data.frontColor, true);
      if (data.frontDistance >= 0) {
        _distLabel(canvas, Offset(cx, fSensorY - 28), '${data.frontDistance.toStringAsFixed(1)} CM', data.frontColor);
      }
    }

    // ── REAR SONAR (3 sectors: L / C / R) ────────────────────────────────
    if (data.rearOnline) {
      _paintRearSonar(canvas, cx, rSensorY);
      if (data.rearDistance >= 0) {
        _distLabel(canvas, Offset(cx, rSensorY + 28), '${data.rearDistance.toStringAsFixed(1)} CM', data.rearColor);
      }
    }

    // ── BODY GLOW ─────────────────────────────────────────────────────────
    final crit = data.frontState == 2 || data.rearState == 2;
    final warn = data.frontState == 1 || data.rearState == 1;
    if (crit || warn) {
      final gc = crit ? _kRed : _kAmber;
      final gi = crit ? 0.28 + alertFlash * 0.32 : 0.14;
      canvas.drawRRect(
        RRect.fromRectAndRadius(carRect.inflate(18), Radius.circular(carW * 0.35)),
        Paint()..color = gc.withOpacity(gi)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
      );
    }

    // ── ROAD SURFACE BENEATH CAR ──────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect.inflate(6), Radius.circular(carW * 0.32)),
      Paint()..color = const Color(0xFF080C18),
    );

    // ── CAR BODY ──────────────────────────────────────────────────────────
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + carH * 0.08), width: carW * 1.1, height: carH * 0.18),
      Paint()..color = Colors.black.withOpacity(0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, Radius.circular(carW * 0.28)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2C3650), Color(0xFF141824), Color(0xFF1E2840), Color(0xFF0C1018)],
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(carRect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(carRect, Radius.circular(carW * 0.28)),
      Paint()..color = const Color(0xFF3A4560).withOpacity(0.9)..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // ── ROOF / CABIN ──────────────────────────────────────────────────────
    final roofRect = Rect.fromCenter(
      center: Offset(cx, cy - carH * 0.07),
      width: carW * 0.78, height: carH * 0.42,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(roofRect, Radius.circular(carW * 0.18)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF1A2A50), Color(0xFF0A1228)],
        ).createShader(roofRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(roofRect, Radius.circular(carW * 0.18)),
      Paint()..color = _kBlue.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );

    // ── WINDSHIELD ────────────────────────────────────────────────────────
    final windshieldRect = Rect.fromCenter(
      center: Offset(cx, cy - carH * 0.23),
      width: carW * 0.68, height: carH * 0.14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(windshieldRect, const Radius.circular(8)),
      Paint()..color = _kBlue.withOpacity(0.18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(windshieldRect, const Radius.circular(8)),
      Paint()..color = _kCyan.withOpacity(0.12)..style = PaintingStyle.stroke..strokeWidth = 1,
    );

    // ── REAR WINDOW ───────────────────────────────────────────────────────
    final rearWinRect = Rect.fromCenter(
      center: Offset(cx, cy + carH * 0.17),
      width: carW * 0.62, height: carH * 0.12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rearWinRect, const Radius.circular(6)),
      Paint()..color = const Color(0xFF1A2035).withOpacity(0.7),
    );

    // ── HOOD LINE ─────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(cx - carW * 0.38, cy - carH * 0.16),
      Offset(cx + carW * 0.38, cy - carH * 0.16),
      Paint()..color = const Color(0xFF2A3550).withOpacity(0.8)..strokeWidth = 1.2,
    );

    // ── TRUNK LINE ────────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(cx - carW * 0.35, cy + carH * 0.28),
      Offset(cx + carW * 0.35, cy + carH * 0.28),
      Paint()..color = const Color(0xFF2A3550).withOpacity(0.8)..strokeWidth = 1.2,
    );

    // ── CENTER CONSOLE STRIP ──────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: carW * 0.06, height: carH * 0.28),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF0A0E18),
    );

    // ── HEADLIGHTS ────────────────────────────────────────────────────────
    final fTop = cy - carH / 2;
    final fLedColor = data.frontOnline ? data.frontColor : Colors.white30;
    final fGlow = data.frontState == 2 ? 0.55 + alertFlash * 0.45 : 0.85;
    _paintHeadlight(canvas, Offset(cx - carW * 0.30, fTop + carH * 0.04), fLedColor, fGlow, data.frontState == 2);
    _paintHeadlight(canvas, Offset(cx + carW * 0.30, fTop + carH * 0.04), fLedColor, fGlow, data.frontState == 2);
    _paintDRLStrip(canvas, cx, fTop + carH * 0.03, carW * 0.55, fLedColor.withOpacity(0.3));

    // ── TAIL LIGHTS ───────────────────────────────────────────────────────
    final rTop = cy + carH / 2;
    final rLedColor = data.rearOnline ? data.rearColor : _kRed.withOpacity(0.5);
    final rGlow = data.rearState == 2 ? 0.55 + alertFlash * 0.45 : 0.85;
    _paintTailLight(canvas, Offset(cx - carW * 0.30, rTop - carH * 0.04), rLedColor, rGlow, data.rearState == 2);
    _paintTailLight(canvas, Offset(cx + carW * 0.30, rTop - carH * 0.04), rLedColor, rGlow, data.rearState == 2);
    _paintDRLStrip(canvas, cx, rTop - carH * 0.03, carW * 0.50, rLedColor.withOpacity(0.25));

    // ── WHEELS ────────────────────────────────────────────────────────────
    final wheelW = carW * 0.18, wheelH = carH * 0.14;
    for (final p in [
      Offset(cx - carW * 0.50, cy - carH * 0.28),
      Offset(cx + carW * 0.50, cy - carH * 0.28),
      Offset(cx - carW * 0.50, cy + carH * 0.28),
      Offset(cx + carW * 0.50, cy + carH * 0.28),
    ]) {
      _paintWheel(canvas, p, wheelW, wheelH);
    }

    // ── SIGNAL WAVES ──────────────────────────────────────────────────────
    if (data.frontOnline) {
      _signalWaves(canvas, Offset(cx - carW * 0.30, fTop + carH * 0.04), data.frontColor, left: true);
      _signalWaves(canvas, Offset(cx + carW * 0.30, fTop + carH * 0.04), data.frontColor, left: false);
    }
    if (data.rearOnline) {
      _signalWaves(canvas, Offset(cx - carW * 0.30, rTop - carH * 0.04), data.rearColor, left: true);
      _signalWaves(canvas, Offset(cx + carW * 0.30, rTop - carH * 0.04), data.rearColor, left: false);
    }
  }

  void _paintHeadlight(Canvas canvas, Offset pos, Color color, double opacity, bool crit) {
    if (crit) {
      canvas.drawCircle(pos, 16,
          Paint()..color = color.withOpacity(opacity * 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 22, height: 10), const Radius.circular(4)),
      Paint()..color = color.withOpacity(opacity)..maskFilter = MaskFilter.blur(BlurStyle.normal, crit ? 10 : 6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 22, height: 10), const Radius.circular(4)),
      Paint()..color = color.withOpacity(0.9),
    );
  }

  void _paintTailLight(Canvas canvas, Offset pos, Color color, double opacity, bool crit) {
    if (crit) {
      canvas.drawCircle(pos, 16,
          Paint()..color = color.withOpacity(opacity * 0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 20, height: 9), const Radius.circular(3)),
      Paint()..color = color.withOpacity(opacity)..maskFilter = MaskFilter.blur(BlurStyle.normal, crit ? 10 : 5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: pos, width: 20, height: 9), const Radius.circular(3)),
      Paint()..color = color.withOpacity(0.85),
    );
  }

  void _paintDRLStrip(Canvas canvas, double cx, double y, double w, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, y), width: w, height: 3), const Radius.circular(2)),
      Paint()..color = color,
    );
  }

  void _paintWheel(Canvas canvas, Offset pos, double w, double h) {
    canvas.drawOval(Rect.fromCenter(center: pos, width: w, height: h),
        Paint()..color = const Color(0xFF1A1E2A));
    canvas.drawOval(Rect.fromCenter(center: pos, width: w, height: h),
        Paint()..color = const Color(0xFF3A4055)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawOval(Rect.fromCenter(center: pos, width: w * 0.55, height: h * 0.55),
        Paint()..color = const Color(0xFF2A3045));
    for (var i = 0; i < 4; i++) {
      final angle = math.pi / 4 * i;
      canvas.drawLine(
        pos + Offset(math.cos(angle) * w * 0.1, math.sin(angle) * h * 0.1),
        pos + Offset(math.cos(angle) * w * 0.25, math.sin(angle) * h * 0.25),
        Paint()..color = const Color(0xFF4A5570)..strokeWidth = 1.5,
      );
    }
  }

  // ── LANE LINES — recalculated to sit just outside enlarged car edges ────
  // Car half-width = carW/2 = (carH*0.52)/2. Lane lines get +26 px gap.
  // Stroke width bumped to ~3.8 px (≈ 0.5 cm equivalent on screen).
  void _paintLaneLines(Canvas canvas, Size size, double cx, double cy, double carW, double carH) {
    // carW is passed in so positions always track the actual car width
    final lx = cx - carW / 2 - 26;
    final rx = cx + carW / 2 + 26;
    final top    = cy - carH / 2 - 40;
    final bottom = cy + carH / 2 + 40;

    final leftOn  = data.laneState == 1;
    final rightOn = data.laneState == 2;

    // Increased dash stroke width: active = 6.0, idle = 3.8
    _drawDash(canvas, lx, top, bottom, leftOn  ? _kAmber : Colors.white.withOpacity(0.1), leftOn  ? 6.0 : 3.8, leftOn  ? (0.6 + lanePulse * 0.4) : 1.0);
    _drawDash(canvas, rx, top, bottom, rightOn ? _kAmber : Colors.white.withOpacity(0.1), rightOn ? 6.0 : 3.8, rightOn ? (0.6 + lanePulse * 0.4) : 1.0);

    // Lane glow bloom
    if (leftOn) {
      canvas.drawLine(Offset(lx, top), Offset(lx, bottom),
          Paint()..color = _kAmber.withOpacity(0.18 * lanePulse)..strokeWidth = 24..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    if (rightOn) {
      canvas.drawLine(Offset(rx, top), Offset(rx, bottom),
          Paint()..color = _kAmber.withOpacity(0.18 * lanePulse)..strokeWidth = 24..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    // Crossing arrows
    if (leftOn)  _crossArrow(canvas, Offset(lx - 28, cy), false, _kAmber.withOpacity(0.7 + lanePulse * 0.3));
    if (rightOn) _crossArrow(canvas, Offset(rx + 28, cy), true,  _kAmber.withOpacity(0.7 + lanePulse * 0.3));
  }

  void _drawDash(Canvas canvas, double x, double top, double bottom, Color color, double sw, double opacity) {
    final p = Paint()..color = color.withOpacity(opacity)..strokeWidth = sw..strokeCap = StrokeCap.round;
    const dash = 16.0, gap = 12.0;
    var y = top;
    while (y < bottom) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + dash, bottom)), p);
      y += dash + gap;
    }
  }

  void _crossArrow(Canvas canvas, Offset pos, bool right, Color color) {
    final d = right ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(pos.dx - d * 10, pos.dy - 10)
      ..lineTo(pos.dx + d * 10, pos.dy)
      ..lineTo(pos.dx - d * 10, pos.dy + 10);
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  void _paintSonar(Canvas canvas, double cx, double focusY, int state, Color color, bool front) {
    final wc = _waves(state), sp = _spread(state), sw = _sw(state);
    for (var i = 0; i < wc; i++) {
      final t = (pulse + i / wc) % 1.0;
      final op = (state == 2 ? (0.9 - t * 0.65) * (0.55 + alertFlash * 0.45) : (0.8 - t * 0.70)).clamp(0.0, 1.0);
      final ew = 60 + t * sp, eh = 28 + t * (sp * 0.45);

      if (state == 2) {
        canvas.drawArc(Rect.fromCenter(center: Offset(cx, focusY), width: ew + 10, height: eh + 10),
            front ? -math.pi : 0, math.pi, false,
            Paint()..color = color.withOpacity(op * 0.3)..style = PaintingStyle.stroke..strokeWidth = sw + 7..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      }
      canvas.drawArc(Rect.fromCenter(center: Offset(cx, focusY), width: ew, height: eh),
          front ? -math.pi : 0, math.pi, false,
          Paint()..color = color.withOpacity(op)..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.round);
    }
  }

  // ── REAR SONAR — 3 separate 60° sector arcs (right / center / left) ────────
  // Angles in Flutter canvas: 0=3-o'clock, pi/2=6-o'clock (down), pi=9-o'clock.
  // For the rear arc (faces downward): sectors span 0→pi going clockwise.
  //   Sector 0 (car-right):  0      → pi/3
  //   Sector 1 (center):     pi/3   → 2*pi/3
  //   Sector 2 (car-left):   2*pi/3 → pi
  void _paintRearSonar(Canvas canvas, double cx, double focusY) {
    _paintSonarSector(canvas, cx, focusY,
        data.rearRightState, data.rearRightColor, 0, math.pi / 3);
    _paintSonarSector(canvas, cx, focusY,
        data.rearCenterState, data.rearCenterColor, math.pi / 3, math.pi / 3);
    _paintSonarSector(canvas, cx, focusY,
        data.rearLeftState, data.rearLeftColor, 2 * math.pi / 3, math.pi / 3);
  }

  void _paintSonarSector(Canvas canvas, double cx, double focusY,
      int state, Color color, double startAngle, double sweepAngle) {
    final wc = _waves(state), sp = _spread(state), sw = _sw(state);
    for (var i = 0; i < wc; i++) {
      final t = (pulse + i / wc) % 1.0;
      final op = (state == 2
              ? (0.9 - t * 0.65) * (0.55 + alertFlash * 0.45)
              : (0.8 - t * 0.70))
          .clamp(0.0, 1.0);
      final ew = 60 + t * sp, eh = 28 + t * (sp * 0.45);
      if (state == 2) {
        canvas.drawArc(
          Rect.fromCenter(center: Offset(cx, focusY), width: ew + 10, height: eh + 10),
          startAngle, sweepAngle, false,
          Paint()
            ..color = color.withOpacity(op * 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw + 7
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
      }
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, focusY), width: ew, height: eh),
        startAngle, sweepAngle, false,
        Paint()
          ..color = color.withOpacity(op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _signalWaves(Canvas canvas, Offset o, Color color, {required bool left}) {
    final dir = left ? -1.0 : 1.0;
    for (var i = 0; i < 3; i++) {
      final phase = (signal + i * 0.33) % 1.0;
      final x = o.dx + dir * phase * 26;
      final op = (1.0 - phase) * 0.75;
      final path = Path()
        ..moveTo(x, o.dy - 6)
        ..quadraticBezierTo(x + dir * 5, o.dy, x, o.dy + 6);
      canvas.drawPath(path, Paint()..color = color.withOpacity(op)..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    }
  }

  void _distLabel(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
        color: color, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1,
        shadows: [Shadow(color: color.withOpacity(0.85), blurRadius: 8)],
      )),
      textDirection: TextDirection.ltr, textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMAND BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _CmdBtn extends StatelessWidget {
  const _CmdBtn({required this.svc});
  final WiFiSensorService svc;

  @override
  Widget build(BuildContext context) {
    final active = svc.isConnected;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: GestureDetector(
        onTap: svc.toggleSafetyShield,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: active
                ? [const Color(0xFFFF1744), const Color(0xFFB71C1C)]
                : [const Color(0xFF2979FF), const Color(0xFF1A237E)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: (active ? _kRed : _kBlue).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(active ? Icons.power_settings_new : Icons.link, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(active ? 'TERMINATE HUB CONNECTION' : 'ESTABLISH ADAS BRAIN LINK',
                style: GoogleFonts.orbitron(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  const _AlertBanner({required this.title, required this.message, this.onDismiss});
  final String title, message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => Container(
    width: 460,
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    decoration: BoxDecoration(
      color: _kRed,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white24, width: 1.5),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 40, spreadRadius: 4)],
    ),
    child: Row(children: [
      const Icon(Icons.warning_rounded, color: Colors.white, size: 42),
      const SizedBox(width: 18),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ])),
      if (onDismiss != null)
        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26), onPressed: onDismiss),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// KEPT FOR EXTERNAL COMPATIBILITY
// ─────────────────────────────────────────────────────────────────────────────
class _StatusLight extends StatelessWidget {
  const _StatusLight({required this.online});
  final bool online;
  @override
  Widget build(BuildContext context) {
    final c = online ? _kGreen : _kRed;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c,
          boxShadow: [BoxShadow(color: c.withOpacity(0.6), blurRadius: 6)])),
      const SizedBox(width: 6),
      Text(online ? 'ONLINE' : 'OFFLINE', style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900)),
    ]);
  }
}

class _MetricData {
  _MetricData(this.label, this.value);
  final String label, value;
}