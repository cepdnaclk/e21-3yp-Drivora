import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';
import 'audio_service.dart';
import 'cloud_service.dart';

class WiFiSensorService extends ChangeNotifier {
  DrivoraSensorData _currentData = DrivoraSensorData();
  bool _isConnected = false;
  String _status = 'Systems Standby';
  
  final List<SafetyAlert> _activeAlerts = [];
  final List<DrivoraSensorData> _dataHistory = [];
  
  WebSocketChannel? _wsChannel;
  StreamSubscription? _subscription;
  
  late AudioService _audioService;
  final CloudService _cloudService = CloudService();
  AlertType? _lastAudioAlert;
  bool _audioEnabled = true;

  DrivoraSensorData get currentData => _currentData;
  bool get isConnected => _isConnected;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<DrivoraSensorData> get dataHistory => _dataHistory;

  Future<void> initialize() async {
    _audioService = AudioService();
    _status = 'Drivora Core Initialized';
    notifyListeners();
  }
  
  /// Enable/disable audio alerts
  void setAudioEnabled(bool enabled) {
    _audioEnabled = enabled;
    _audioService.setEnabled(enabled);
    notifyListeners();
  }
  
  bool get audioEnabled => _audioEnabled;

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
    _audioService.stopAll();
    _lastAudioAlert = null;
    notifyListeners();
  }

  void _processHardwareJson(Map<String, dynamic> json) {
    final lean = json['lean'] ?? {};
    final front = json['front'] ?? {};
    final rear = json['rear'] ?? {};
    final lane = json['lane'] ?? {};

    _currentData = DrivoraSensorData(
      frontState: front['state'] ?? 0,
      frontStateName: front['stateName'] ?? 'OFFLINE',
      frontStateColor: _parseHexColor(front['stateColor'] ?? '#1db954'),
      frontDistance: (front['filteredDistanceCm'] ?? -1.0).toDouble(),
      closingSpeed: (front['closingSpeedCmS'] ?? 0.0).toDouble(),
      frontOnline: (front['online'] ?? 0) == 1,

      leanRiskLevel: lean['riskLevel'] ?? 0,
      leanRiskName: lean['riskName'] ?? 'OFFLINE',
      roll: (lean['roll'] ?? 0.0).toDouble(),
      pitch: (lean['pitch'] ?? 0.0).toDouble(),
      confidence: (lean['confidence'] ?? 1.0).toDouble(),
      leanOnline: (lean['online'] ?? 0) == 1,
      criticalRollDeg: (lean['criticalRollDeg'] ?? 30.0).toDouble(),
      criticalPitchDeg: (lean['criticalPitchDeg'] ?? 20.0).toDouble(),

      rearState: rear['state'] ?? 0,
      rearStateName: rear['stateName'] ?? 'OFFLINE',
      rearStateColor: _parseHexColor(rear['stateColor'] ?? '#1db954'),
      rearDistance: (rear['filteredDistanceCm'] ?? -1.0).toDouble(),
      rearOnline: (rear['online'] ?? 0) == 1,

      laneState: lane['state'] ?? 0,
      laneStateName: lane['stateName'] ?? 'OFFLINE',
      laneStateColor: _parseHexColor(lane['stateColor'] ?? '#1db954'),
      laneOnline: (lane['online'] ?? 0) == 1,

      speed: (front['closingSpeedCmS'] ?? 0.0).toDouble().abs(),
      brakeActive: (front['state'] ?? 0) == 3,
      ldwActive: (lane['state'] ?? 0) != 0,
    );

    _dataHistory.add(_currentData);
    if (_dataHistory.length > 500) _dataHistory.removeAt(0);

    _processSafetyAlerts(_currentData);
    unawaited(_cloudService.saveTelemetrySnapshot(_currentData));
    for (final alert in _activeAlerts) {
      unawaited(_cloudService.logAlertEvent(alert));
    }
    notifyListeners();
  }

  void _processSafetyAlerts(DrivoraSensorData data) {
    _activeAlerts.clear();
    AlertType? triggerAlert;
    
    // --- PRIORITY 1: CRITICAL COLLISION WARNING ---
    if (data.frontState == 3) {
      _activeAlerts.add(SafetyAlert(
        title: 'BRAKE NOW', 
        message: 'FRONT COLLISION IMMINENT', 
        severity: AlertSeverity.critical, 
        unitSource: 'RADAR'
      ));
      triggerAlert = AlertType.collision;
    }
    // --- PRIORITY 2: CRITICAL REAR PROXIMITY ---
    else if (data.rearState == 3) {
      _activeAlerts.add(SafetyAlert(
        title: 'REAR WARNING', 
        message: 'REAR PROXIMITY CRITICAL', 
        severity: AlertSeverity.danger, 
        unitSource: 'REAR'
      ));
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 3: CRITICAL LEAN/ROLLOVER RISK ---
    else if (data.leanRiskLevel == 2) {
      _activeAlerts.add(SafetyAlert(
        title: 'ROLLOVER RISK', 
        message: 'CRITICAL VEHICLE LEAN', 
        severity: AlertSeverity.critical, 
        unitSource: 'COG'
      ));
      triggerAlert = AlertType.drowsiness;
    }
    // --- PRIORITY 4: LANE DEPARTURE ---
    else if (data.laneState != 0) {
      _activeAlerts.add(SafetyAlert(
        title: 'LANE DRIFT', 
        message: data.laneStateName, 
        severity: AlertSeverity.warning, 
        unitSource: 'VISION'
      ));
      triggerAlert = AlertType.laneWarning;
    }
    // --- PRIORITY 5: APPROACHING OBSTACLE (FRONT) ---
    else if (data.frontState == 2) {
      _activeAlerts.add(SafetyAlert(
        title: 'APPROACH WARNING', 
        message: 'OBJECT GETTING CLOSER', 
        severity: AlertSeverity.danger, 
        unitSource: 'RADAR'
      ));
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 6: REAR CAUTION ---
    else if (data.rearState == 2) {
      _activeAlerts.add(SafetyAlert(
        title: 'REAR CAUTION', 
        message: 'OBJECT DETECTED CLOSE', 
        severity: AlertSeverity.warning, 
        unitSource: 'REAR'
      ));
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 7: LEAN CAUTION ---
    else if (data.leanRiskLevel == 1) {
      _activeAlerts.add(SafetyAlert(
        title: 'LEAN CAUTION', 
        message: 'INCREASING LEAN ANGLE', 
        severity: AlertSeverity.warning, 
        unitSource: 'COG'
      ));
      triggerAlert = AlertType.laneWarning;
    }
    // --- INFO: OBJECT DETECTED ---
    else if (data.frontState == 1 || data.rearState == 1) {
      _activeAlerts.add(SafetyAlert(
        title: 'OBJECT DETECTED',
        message: 'No immediate threat',
        severity: AlertSeverity.info,
        unitSource: data.frontState == 1 ? 'RADAR' : 'REAR'
      ));
    }
    
    // --- TRIGGER AUDIO ALERT ---
    _updateAudioAlert(triggerAlert, data);
  }
  
  void _updateAudioAlert(AlertType? newAlert, DrivoraSensorData data) {
    if (!_audioEnabled) return;
    
    // Stop previous alert if it's no longer relevant
    if (_lastAudioAlert != null && newAlert != _lastAudioAlert) {
      _audioService.stopAll();
    }
    
    // Trigger new alert
    if (newAlert != null && newAlert != _lastAudioAlert) {
      switch (newAlert) {
        case AlertType.collision:
          _audioService.playCollisionAlert();
          break;
        case AlertType.obstacleProx:
          _audioService.playObstacleProximity(
            distanceCm: math.max(data.frontDistance, data.rearDistance)
          );
          break;
        case AlertType.laneWarning:
          _audioService.playLaneWarning();
          break;
        case AlertType.drowsiness:
          _audioService.playDrowsinessAlert();
          break;
        case AlertType.info:
          _audioService.playGeneralAlert();
          break;
        case AlertType.systemAlert:
          _audioService.playSystemAlert();
          break;
        case AlertType.calibration:
          _audioService.playCalibrationSuccess();
          break;
      }
      _lastAudioAlert = newAlert;
    } else if (newAlert == null && _lastAudioAlert != null) {
      _audioService.stopAll();
      _lastAudioAlert = null;
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
