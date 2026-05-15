import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';

class WiFiSensorService extends ChangeNotifier {
  DrivoraSensorData _currentData = DrivoraSensorData();
  bool _isConnected = false;
  String _status = 'Systems Standby';
  
  final List<SafetyAlert> _activeAlerts = [];
  final List<DrivoraSensorData> _dataHistory = [];
  
  WebSocketChannel? _wsChannel;
  StreamSubscription? _subscription;

  DrivoraSensorData get currentData => _currentData;
  bool get isConnected => _isConnected;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<DrivoraSensorData> get dataHistory => _dataHistory;

  Future<void> initialize() async {
    _status = 'Drivora Core Initialized';
    notifyListeners();
  }

  void toggleSafetyShield() {
    if (_isConnected) {
      stopAllStreams();
    } else {
      connectToHardwareHub('192.168.4.1');
    }
  }

  void connectToHardwareHub(String ipAddress) {
    stopAllStreams();
    _status = 'Connecting to ADAS Brain...';
    notifyListeners();

    try {
      final wsUrl = Uri.parse('ws://$ipAddress:81');
      _wsChannel = WebSocketChannel.connect(wsUrl);

      _subscription = _wsChannel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = json.decode(message);
            _processHardwareJson(data);
            if (!_isConnected) {
              _isConnected = true;
              _status = 'ADAS Link: ACTIVE';
              notifyListeners();
            }
          } catch (e) {
            debugPrint('WS Decode Error: $e');
          }
        },
        onError: (err) => _handleError('Link Error: Check WiFi'),
        onDone: () => _handleError('ADAS Link Lost'),
      );
    } catch (e) {
      _handleError('Connection Failed');
    }
  }

  void _handleError(String msg) {
    _status = msg;
    _isConnected = false;
    _currentData = DrivoraSensorData();
    notifyListeners();
  }

  void stopAllStreams() {
    _subscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnected = false;
    _status = 'Safety Shield: STANDBY';
    _activeAlerts.clear();
    notifyListeners();
  }

  void _processHardwareJson(Map<String, dynamic> json) {
    final lean = json['lean'] ?? {};
    final front = json['front'] ?? {};
    final rear = json['rear'] ?? {};
    final lane = json['lane'] ?? {};

    _currentData = DrivoraSensorData(
      frontState: front['state'] ?? 0,
      frontStateName: front['stateName'] ?? "OFFLINE",
      frontStateColor: _parseHexColor(front['stateColor'] ?? "#1db954"),
      frontDistance: (front['filteredDistanceCm'] ?? -1.0).toDouble(),
      closingSpeed: (front['closingSpeedCmS'] ?? 0.0).toDouble(),
      frontOnline: (front['online'] ?? 0) == 1,

      leanRiskLevel: lean['riskLevel'] ?? 0,
      leanRiskName: lean['riskName'] ?? "OFFLINE",
      roll: (lean['roll'] ?? 0.0).toDouble(),
      pitch: (lean['pitch'] ?? 0.0).toDouble(),
      confidence: (lean['confidence'] ?? 1.0).toDouble(),
      leanOnline: (lean['online'] ?? 0) == 1,
      criticalRollDeg: (lean['criticalRollDeg'] ?? 30.0).toDouble(),
      criticalPitchDeg: (lean['criticalPitchDeg'] ?? 20.0).toDouble(),

      rearState: rear['state'] ?? 0,
      rearStateName: rear['stateName'] ?? "OFFLINE",
      rearStateColor: _parseHexColor(rear['stateColor'] ?? "#1db954"),
      rearDistance: (rear['filteredDistanceCm'] ?? -1.0).toDouble(),
      rearOnline: (rear['online'] ?? 0) == 1,

      laneState: lane['state'] ?? 0,
      laneStateName: lane['stateName'] ?? "OFFLINE",
      laneStateColor: _parseHexColor(lane['stateColor'] ?? "#1db954"),
      laneOnline: (lane['online'] ?? 0) == 1,

      speed: (front['closingSpeedCmS'] ?? 0.0).toDouble().abs(),
      brakeActive: (front['state'] ?? 0) == 3,
      ldwActive: (lane['state'] ?? 0) != 0,
    );

    _dataHistory.add(_currentData);
    if (_dataHistory.length > 500) _dataHistory.removeAt(0);

    _processSafetyAlerts(_currentData);
    notifyListeners();
  }

  void _processSafetyAlerts(DrivoraSensorData data) {
    _activeAlerts.clear();
    if (data.frontState == 3) {
      _activeAlerts.add(SafetyAlert(title: 'BRAKE NOW', message: 'FRONT COLLISION IMMINENT', severity: AlertSeverity.critical, unitSource: 'RADAR'));
    }
    if (data.rearState == 3) {
      _activeAlerts.add(SafetyAlert(title: 'REAR WARNING', message: 'REAR PROXIMITY CRITICAL', severity: AlertSeverity.danger, unitSource: 'REAR'));
    }
    if (data.leanRiskLevel == 2) {
      _activeAlerts.add(SafetyAlert(title: 'ROLLOVER RISK', message: 'CRITICAL VEHICLE LEAN', severity: AlertSeverity.critical, unitSource: 'COG'));
    }
    if (data.laneState != 0) {
      _activeAlerts.add(SafetyAlert(title: 'LANE DRIFT', message: data.laneStateName, severity: AlertSeverity.warning, unitSource: 'VISION'));
    }
  }

  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return const Color(0xFF1DB954);
    }
  }

  void clearAlerts() {
    _activeAlerts.clear();
    notifyListeners();
  }

  Future<void> sendCalibrationToHardware({
    required double height,
    required double width,
    String? ipAddress,
  }) async {
    final hubIP = ipAddress ?? '192.168.4.1';
    _status = 'Syncing Calibration...';
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
        debugPrint('Handshake Success');
      }
    } catch (e) {
      debugPrint('ESP32 Hub not reachable: $e');
    }
  }
}
