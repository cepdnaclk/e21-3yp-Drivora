import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  // --- Getters ---
  DrivoraSensorData get currentData => _currentData;
  bool get isConnected => _isConnected;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<DrivoraSensorData> get dataHistory => _dataHistory;

  // --- Initialization ---
  Future<void> initialize() async {
    _status = 'Drivora Core Initialized';
    notifyListeners();
  }

  // --- Connection Management ---
  void toggleSafetyShield() {
    if (_isConnected) {
      stopAllStreams();
    } else {
      connectToHardwareHub('192.168.4.1'); // Default ESP32 SoftAP IP
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
    _currentData = DrivoraSensorData(); // Reset data on disconnect
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

  // --- Hardware Data Processing ---
  void _processHardwareJson(Map<String, dynamic> json) {
    final lean = json['lean'] ?? {};
    final front = json['front'] ?? {};
    final rear = json['rear'] ?? {};

    // 1. Generate Virtual Lane Data (Requested as Sample Data Only)
    final double time = DateTime.now().millisecondsSinceEpoch / 1000.0;
    double simulatedLanePos = math.sin(time * 0.25) * 0.4; // Gentle drifting
    bool simulatedLdw = simulatedLanePos.abs() > 0.45;

    // 2. Map Hardware States to App Model
    final newData = DrivoraSensorData(
      // Front (Radar)
      frontState: front['state'] ?? 0,
      frontStateName: front['stateName'] ?? "OFFLINE",
      frontStateColor: _parseHexColor(front['stateColor'] ?? "#1db954"),
      frontDistance: (front['filteredDistanceCm'] ?? -1.0).toDouble(),
      closingSpeed: (front['closingSpeedCmS'] ?? 0.0).toDouble(),
      frontOnline: (front['online'] ?? 0) == 1,

      // Lean (COG)
      leanRiskLevel: lean['riskLevel'] ?? 0,
      leanRiskName: lean['riskName'] ?? "OFFLINE",
      roll: (lean['roll'] ?? 0.0).toDouble(),
      pitch: (lean['pitch'] ?? 0.0).toDouble(),
      confidence: (lean['confidence'] ?? 1.0).toDouble(),
      leanOnline: (lean['online'] ?? 0) == 1,
      leanCalibrated: (lean['calibrated'] ?? 0) == 1,

      // Rear (BSM)
      rearState: rear['state'] ?? 0,
      rearStateName: rear['stateName'] ?? "OFFLINE",
      rearStateColor: _parseHexColor(rear['stateColor'] ?? "#1db954"),
      rearDistance: (rear['filteredDistanceCm'] ?? -1.0).toDouble(),
      rearOnline: (rear['online'] ?? 0) == 1,

      // Lane (Virtual)
      ldwActive: simulatedLdw,
      lanePosition: simulatedLanePos,

      // Derived Basics
      speed: (front['closingSpeedCmS'] ?? 0.0).toDouble().abs(), // Simplified speed
      brakeActive: (front['state'] ?? 0) == 3, // WARNING level
    );

    _updateCurrentData(newData);
  }

  void _updateCurrentData(DrivoraSensorData data) {
    _currentData = data;

    // Add to history for Analytics
    _dataHistory.add(data);
    if (_dataHistory.length > 500) _dataHistory.removeAt(0);

    // Process Safety Logic for Alerts
    _processSafetyAlerts(data);

    notifyListeners();
  }

  void _processSafetyAlerts(DrivoraSensorData data) {
    _activeAlerts.clear();

    // Collision Alert
    if (data.frontState == 3) {
      _activeAlerts.add(SafetyAlert(
        title: 'BRAKE NOW',
        message: 'FRONT COLLISION IMMINENT',
        severity: AlertSeverity.critical,
        unitSource: 'RADAR',
      ));
    } else if (data.frontState == 2) {
      _activeAlerts.add(SafetyAlert(
        title: 'APPROACHING',
        message: 'REDUCE SPEED',
        severity: AlertSeverity.warning,
        unitSource: 'RADAR',
      ));
    }

    // Rear Alert
    if (data.rearState == 3) {
      _activeAlerts.add(SafetyAlert(
        title: 'REAR WARNING',
        message: 'CLOSE OBJECT DETECTED',
        severity: AlertSeverity.danger,
        unitSource: 'REAR HUB',
      ));
    }

    // Stability Alert
    if (data.leanRiskLevel == 2) {
      _activeAlerts.add(SafetyAlert(
        title: 'ROLLOVER RISK',
        message: 'EXCESSIVE VEHICLE LEAN',
        severity: AlertSeverity.critical,
        unitSource: 'COG',
      ));
    }

    // Lane Alert (Simulated)
    if (data.ldwActive) {
      _activeAlerts.add(SafetyAlert(
        title: 'LANE DRIFT',
        message: 'UNINTENDED DEPARTURE',
        severity: AlertSeverity.warning,
        unitSource: 'VISION',
      ));
    }
  }

  Color _parseHexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
    } catch (_) {
      return const Color(0xFF1DB954);
    }
  }

  // --- Actions ---
  void clearAlerts() {
    _activeAlerts.clear();
    notifyListeners();
  }

  Future<void> sendCalibrationToHardware({
    required double height,
    required double width,
  }) async {
    // Note: The ESP32 doesn't have a specific calibrate endpoint in the provided code,
    // but we'll leave this here for future implementation.
    debugPrint('Sending Calibration: H:$height W:$width');
  }

  // Backwards compatibility for the "Simulation" button in UI
  void startSafetySimulation() {
    toggleSafetyShield();
  }
}
