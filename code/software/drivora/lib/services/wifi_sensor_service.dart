import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

enum DataSource { standby, simulation, rawData, liveWiFi }

class WiFiSensorService extends ChangeNotifier {
  DrivoraSensorData _currentData = DrivoraSensorData();
  bool _isConnected = false;
  DataSource _currentSource = DataSource.standby;
  String _status = 'Systems Standby';
  final List<SafetyAlert> _activeAlerts = [];
  final List<DrivoraSensorData> _dataHistory = [];
  
  StreamSubscription? _dataSubscription;
  Timer? _pollingTimer;

  DrivoraSensorData get currentData => _currentData;
  bool get isConnected => _isConnected;
  bool get isSimulating => _currentSource == DataSource.simulation;
  DataSource get currentSource => _currentSource;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<DrivoraSensorData> get dataHistory => _dataHistory;

  Future<void> initialize() async {
    _status = 'Drivora Core Initialized';
    notifyListeners();
  }

  void stopAllStreams() {
    _dataSubscription?.cancel();
    _pollingTimer?.cancel();
    _isConnected = false;
    _currentSource = DataSource.standby;
    _status = 'Safety Shield: STANDBY';
    _activeAlerts.clear();
    notifyListeners();
  }

  // --- 1. Realistic Simulation ---
  void startSafetySimulation() {
    stopAllStreams();
    _currentSource = DataSource.simulation;
    _isConnected = true;
    _status = 'Safety Shield: SIMULATING';
    
    _dataSubscription = Stream.periodic(
      const Duration(milliseconds: 100),
      (count) => count,
    ).listen((count) {
      final double time = count * 0.1;
      double ttc = 4.0 + math.sin(time * 0.4) * 3.0;
      double lanePos = math.sin(time * 0.25);
      _updateData(DrivoraSensorData(
        speed: 80.0 + math.sin(time * 0.15) * 10.0,
        ttc: ttc,
        frontDistance: ttc * 10.0,
        lanePosition: lanePos,
        ldwActive: lanePos.abs() > 0.8,
        lateralG: math.sin(time * 0.5) * 0.55,
        tiltAngle: math.sin(time * 0.5) * 11.0,
        brakeActive: ttc < 2.5,
        leftSignal: lanePos < -0.65,
        rightSignal: lanePos > 0.65,
      ));
    });
  }

  // --- 2. Raw Data Demo (From JSON) ---
  Future<void> startRawDataDemo() async {
    stopAllStreams();
    _currentSource = DataSource.rawData;
    _status = 'Safety Shield: DATA DEMO';
    
    try {
      final String response = await rootBundle.loadString('assets/raw_sensor_data.json');
      final List<dynamic> data = json.decode(response);
      int index = 0;

      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (index >= data.length) index = 0;
        final map = data[index];
        _updateData(DrivoraSensorData(
          ttc: (map['ttc'] ?? 10.0).toDouble(),
          speed: (map['speed'] ?? 0.0).toDouble(),
          lanePosition: (map['lanePosition'] ?? 0.0).toDouble(),
          ldwActive: map['ldwActive'] ?? false,
          lateralG: (map['lateralG'] ?? 0.0).toDouble(),
          tiltAngle: (map['tiltAngle'] ?? 0.0).toDouble(),
          brakeActive: map['brakeActive'] ?? false,
          leftSignal: map['leftSignal'] ?? false,
          rightSignal: map['rightSignal'] ?? false,
          frontDistance: (map['frontDistance'] ?? 100.0).toDouble(),
          blindSpotLeftDist: (map['blindSpotLeftDist'] ?? 15.0).toDouble(),
          blindSpotRightDist: (map['blindSpotRightDist'] ?? 15.0).toDouble(),
        ));
        index++;
      });
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      _status = 'Error loading demo data';
      notifyListeners();
    }
  }

  // --- 3. Live WiFi Connection (Hardware) ---
  void connectToLiveSensors(String ipAddress) {
    stopAllStreams();
    _currentSource = DataSource.liveWiFi;
    _status = 'Connecting to Hub...';
    notifyListeners();

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      try {
        final response = await http.get(Uri.parse('http://$ipAddress/data')).timeout(const Duration(milliseconds: 500));
        if (response.statusCode == 200) {
          final map = json.decode(response.body);
          _updateData(DrivoraSensorData(
            speed: (map['sp'] ?? 0.0).toDouble(),
            ttc: (map['ttc'] ?? 10.0).toDouble(),
            lanePosition: (map['lp'] ?? 0.0).toDouble(),
            ldwActive: map['ldw'] == 1,
            lateralG: (map['lg'] ?? 0.0).toDouble(),
            tiltAngle: (map['ta'] ?? 0.0).toDouble(),
            brakeActive: map['br'] == 1,
            unitAOnline: map['uA'] == 1,
            unitBOnline: map['uB'] == 1,
            unitCOnline: map['uC'] == 1,
            unitDOnline: map['uD'] == 1,
          ));
          _status = 'Live Data: ACTIVE';
          _isConnected = true;
        }
      } catch (e) {
        _status = 'Hardware Link Lost';
        _isConnected = false;
      }
      notifyListeners();
    });
  }

<<<<<<< HEAD
=======
  // --- 4. New Method: Transmit Calibration to Hardware ---
  Future<void> sendCalibrationToHardware({
    required double height,
    required double width,
    String? ipAddress,
  }) async {
    final hubIP = ipAddress ?? '192.168.4.1'; // Default IP
    _status = 'Calibrating Hardware...';
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('http://$hubIP/calibrate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vHeight': height,
          'vWidth': width,
        }),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        _status = 'Calibration Success';
      } else {
        _status = 'Calibration Error: ${response.statusCode}';
      }
    } catch (e) {
      _status = 'Hardware Link Error (Calibration)';
    }
    notifyListeners();
  }

>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  void _updateData(DrivoraSensorData data) {
    _currentData = data;
    _dataHistory.add(_currentData);
    if (_dataHistory.length > 500) _dataHistory.removeAt(0);
    _processSafetyLogic(_currentData);
    notifyListeners();
  }

  void _processSafetyLogic(DrivoraSensorData data) {
    _activeAlerts.clear();
    if (data.ttc < 2.2) {
      _activeAlerts.add(SafetyAlert(title: 'BRAKE NOW', message: 'Collision Imminent', severity: AlertSeverity.critical, unitSource: 'Unit A'));
    }
    if (data.ldwActive) {
      _activeAlerts.add(SafetyAlert(title: 'LANE DRIFT', message: 'Unintended Departure', severity: AlertSeverity.danger, unitSource: 'Unit D'));
    }
    if (data.tiltAngle.abs() > 15.0) {
      _activeAlerts.add(SafetyAlert(title: 'ROLLOVER RISK', message: 'Stability Compromised', severity: AlertSeverity.warning, unitSource: 'Unit C'));
    }
  }

  void clearAlerts() {
    _activeAlerts.clear();
    notifyListeners();
  }
}
