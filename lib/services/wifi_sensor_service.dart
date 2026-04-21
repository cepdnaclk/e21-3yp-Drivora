import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';

class WiFiSensorService extends ChangeNotifier {
  DrivoraSensorData _currentData = DrivoraSensorData();
  bool _isConnected = false;
  bool _isSimulating = false;
  String _status = 'Systems Standby';
  final List<SafetyAlert> _activeAlerts = [];
  final List<DrivoraSensorData> _dataHistory = [];
  
  StreamSubscription? _simSubscription;

  DrivoraSensorData get currentData => _currentData;
  bool get isConnected => _isConnected;
  bool get isSimulating => _isSimulating;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<DrivoraSensorData> get dataHistory => _dataHistory;

  Future<void> initialize() async {
    _status = 'Drivora Core Initialized';
    notifyListeners();
  }

  void startSafetySimulation() {
    _isSimulating = true;
    _isConnected = true;
    _status = 'Safety Shield: ACTIVE';
    notifyListeners();

    _simSubscription?.cancel();
    _simSubscription = Stream.periodic(
      const Duration(milliseconds: 100),
      (count) => count,
    ).listen((count) {
      final double time = count * 0.1;
      
      // Unit A: Radar TTC (Forward Collision)
      double ttc = 4.0 + math.sin(time * 0.4) * 3.0;
      
      // Unit D: AI Vision Lane Drift
      double lanePos = math.sin(time * 0.25);
      bool ldw = lanePos.abs() > 0.8;

      // Unit C: COG Stability
      double latG = math.sin(time * 0.5) * 0.55;
      double tilt = latG * 20.0;

      // Unit B: Side Detection
      double bsL = 8.0 + math.sin(time * 0.6) * 7.0;
      double bsR = 8.0 + math.cos(time * 0.6) * 7.0;

      _currentData = DrivoraSensorData(
        speed: 80.0 + math.sin(time * 0.15) * 10.0,
        ttc: ttc,
        frontDistance: ttc * 10.0,
        lanePosition: lanePos,
        ldwActive: ldw,
        lateralG: latG,
        tiltAngle: tilt,
        blindSpotLeftDist: bsL,
        blindSpotRightDist: bsR,
        brakeActive: ttc < 2.5,
        leftSignal: lanePos < -0.65,
        rightSignal: lanePos > 0.65,
        unitAOnline: true,
        unitBOnline: true,
        unitCOnline: true,
        unitDOnline: true,
      );

      _dataHistory.add(_currentData);
      if (_dataHistory.length > 500) _dataHistory.removeAt(0);

      _processSafetyLogic(_currentData);
      notifyListeners();
    });
  }

  void _processSafetyLogic(DrivoraSensorData data) {
    _activeAlerts.clear();
    if (data.ttc < 2.2) {
      _activeAlerts.add(SafetyAlert(
        title: 'BRAKE NOW', message: 'Forward Collision Imminent', severity: AlertSeverity.critical, unitSource: 'Unit A'
      ));
    }
    if (data.ldwActive) {
      _activeAlerts.add(SafetyAlert(
        title: 'LANE DRIFT', message: 'Vehicle leaving lane', severity: AlertSeverity.danger, unitSource: 'Unit D'
      ));
    }
    if (data.tiltAngle.abs() > 15.0) {
      _activeAlerts.add(SafetyAlert(
        title: 'ROLLOVER RISK', message: 'High Lateral Force', severity: AlertSeverity.warning, unitSource: 'Unit C'
      ));
    }
  }

  void clearAlerts() {
    _activeAlerts.clear();
    notifyListeners();
  }

  void stopSimulation() {
    _simSubscription?.cancel();
    _isSimulating = false;
    _isConnected = false;
    _status = 'Safety Shield: STANDBY';
    _activeAlerts.clear();
    notifyListeners();
  }
}
