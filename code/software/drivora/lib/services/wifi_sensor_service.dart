import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/sensor_data.dart';
import 'audio_service.dart';
import 'cloud_service.dart';

class WiFiSensorService extends ChangeNotifier {
  DrivoraSensorData _currentData = DrivoraSensorData();
  bool _isConnected = false;
  String _status = 'Systems Standby';

  final List<SafetyAlert> _activeAlerts = [];
  final List<SafetyAlert> _alertHistory = [];
  final List<DrivoraSensorData> _dataHistory = [];

  WebSocketChannel? _wsChannel;
  StreamSubscription? _subscription;

  late AudioService _audioService;
  late CloudService _cloudService;
  AlertType? _lastAudioAlert;
  bool _audioEnabled = true;
  String _lastHistoryKey = '';

  /// Sound profile: maps each AlertType to a volume level (0–100).
  final Map<AlertType, int> _soundProfiles = {
    AlertType.collision: 100,
    AlertType.obstacleProx: 80,
    AlertType.laneWarning: 70,
    AlertType.drowsiness: 90,
    AlertType.info: 50,
    AlertType.systemAlert: 60,
    AlertType.calibration: 60,
  };

  DrivoraSensorData get currentData => _currentData;
  bool get isConnected => _isConnected;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<SafetyAlert> get alertHistory => List.unmodifiable(_alertHistory);
  List<DrivoraSensorData> get dataHistory => _dataHistory;
  Map<AlertType, int> get soundProfiles => Map.unmodifiable(_soundProfiles);

  Future<void> initialize() async {
    _audioService = AudioService();
    _cloudService = CloudService();
    _status = 'Drivora Core Initialized';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Audio helpers
  // ---------------------------------------------------------------------------

  /// Enable/disable audio alerts globally.
  void setAudioEnabled(bool enabled) {
    _audioEnabled = enabled;
    _audioService.setEnabled(enabled);
    notifyListeners();
  }

  bool get audioEnabled => _audioEnabled;

  /// Set the volume level (0–100) for a specific alert type.
  Future<void> setSoundProfile(AlertType type, int volume) async {
    final clamped = volume.clamp(0, 100);
    _soundProfiles[type] = clamped;
    await _audioService.setVolumeForType(type, clamped);
    notifyListeners();
  }

  /// Play a short preview tone at [volume] (0–100) so the user can audition
  /// the sound level during onboarding / settings screens.
  ///
  /// [volume] is an [int] — callers must pass a non-nullable value.
  /// If the source is an [int?], use the null-assertion operator:
  ///   wifi.testTone(v!);
  /// or provide a fallback:
  ///   wifi.testTone(v ?? 50);
  Future<void> testTone(int volume) async {
    if (!_audioEnabled) return;
    final clamped = volume.clamp(0, 100);
    await _audioService.playTestTone(volume: clamped);
  }

  // ---------------------------------------------------------------------------
  // Connection management
  // ---------------------------------------------------------------------------

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
            final Map<String, dynamic> data = json.decode(message as String);
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

  // ---------------------------------------------------------------------------
  // Data processing
  // ---------------------------------------------------------------------------

  void _processHardwareJson(Map<String, dynamic> json) {
    final lean = json['lean'] as Map<String, dynamic>? ?? {};
    final front = json['front'] as Map<String, dynamic>? ?? {};
    final rear = json['rear'] as Map<String, dynamic>? ?? {};
    final lane = json['lane'] as Map<String, dynamic>? ?? {};

    _currentData = DrivoraSensorData(
      frontState: (front['state'] as int?) ?? 0,
      frontStateName: (front['stateName'] as String?) ?? 'OFFLINE',
      frontStateColor: _parseHexColor((front['stateColor'] as String?) ?? '#1db954'),
      frontDistance: ((front['filteredDistanceCm'] as num?) ?? -1.0).toDouble(),
      closingSpeed: ((front['closingSpeedCmS'] as num?) ?? 0.0).toDouble(),
      frontOnline: ((front['online'] as int?) ?? 0) == 1,

      leanRiskLevel: (lean['riskLevel'] as int?) ?? 0,
      leanRiskName: (lean['riskName'] as String?) ?? 'OFFLINE',
      roll: ((lean['roll'] as num?) ?? 0.0).toDouble(),
      pitch: ((lean['pitch'] as num?) ?? 0.0).toDouble(),
      confidence: ((lean['confidence'] as num?) ?? 1.0).toDouble(),
      leanOnline: ((lean['online'] as int?) ?? 0) == 1,
      criticalRollDeg: ((lean['criticalRollDeg'] as num?) ?? 30.0).toDouble(),
      criticalPitchDeg: ((lean['criticalPitchDeg'] as num?) ?? 20.0).toDouble(),

      // Hub sends overallState/overallStateName/overallStateColor for rear aggregate
      rearState: (rear['overallState'] as int?) ?? 0,
      rearStateName: (rear['overallStateName'] as String?) ?? 'CLEAR',
      rearStateColor: _parseHexColor((rear['overallStateColor'] as String?) ?? '#1db954'),
      rearOnline: ((rear['online'] as int?) ?? 0) == 1,

      // Per-sensor rear distances (left / center / right)
      rearLeftState: (rear['leftState'] as int?) ?? 0,
      rearLeftStateName: (rear['leftStateName'] as String?) ?? 'CLEAR',
      rearLeftColor: _parseHexColor((rear['leftStateColor'] as String?) ?? '#1db954'),
      rearLeftDistanceCm: ((rear['leftFilteredDistanceCm'] as num?) ?? -1.0).toDouble(),

      rearCenterState: (rear['centerState'] as int?) ?? 0,
      rearCenterStateName: (rear['centerStateName'] as String?) ?? 'CLEAR',
      rearCenterColor: _parseHexColor((rear['centerStateColor'] as String?) ?? '#1db954'),
      rearCenterDistanceCm: ((rear['centerFilteredDistanceCm'] as num?) ?? -1.0).toDouble(),

      rearRightState: (rear['rightState'] as int?) ?? 0,
      rearRightStateName: (rear['rightStateName'] as String?) ?? 'CLEAR',
      rearRightColor: _parseHexColor((rear['rightStateColor'] as String?) ?? '#1db954'),
      rearRightDistanceCm: ((rear['rightFilteredDistanceCm'] as num?) ?? -1.0).toDouble(),

      // rearDistance = nearest (minimum) of the three sensors
      rearDistance: _nearestRearDistance(
        ((rear['leftFilteredDistanceCm']   as num?) ?? -1.0).toDouble(),
        ((rear['centerFilteredDistanceCm'] as num?) ?? -1.0).toDouble(),
        ((rear['rightFilteredDistanceCm']  as num?) ?? -1.0).toDouble(),
      ),

      laneState: (lane['state'] as int?) ?? 0,
      laneStateName: (lane['stateName'] as String?) ?? 'OFFLINE',
      laneStateColor: _parseHexColor((lane['stateColor'] as String?) ?? '#1db954'),
      laneOnline: ((lane['online'] as int?) ?? 0) == 1,

      speed: ((front['closingSpeedCmS'] as num?) ?? 0.0).toDouble().abs(),
      brakeActive: ((front['state'] as int?) ?? 0) == 3,
      ldwActive: ((lane['state'] as int?) ?? 0) != 0,
    );

    _dataHistory.add(_currentData);
    if (_dataHistory.length > 500) _dataHistory.removeAt(0);

    _processSafetyAlerts(_currentData);

    // Save telemetry snapshot to Firebase (fire-and-forget)
    unawaited(_cloudService.saveTelemetrySnapshot({
      'frontDistance': _currentData.frontDistance,
      'rearDistance': _currentData.rearDistance,
      'roll': _currentData.roll,
      'pitch': _currentData.pitch,
      'speed': _currentData.speed,
      'laneState': _currentData.laneState,
    }));

    notifyListeners();
  }

  void _processSafetyAlerts(DrivoraSensorData data) {
    _activeAlerts.clear();
    AlertType? triggerAlert;

    // --- PRIORITY 1: CRITICAL COLLISION WARNING ---
    if (data.frontState == 3) {
      final alert = SafetyAlert(
        title: 'BRAKE NOW',
        message: 'FRONT COLLISION IMMINENT',
        severity: AlertSeverity.critical,
        unitSource: 'RADAR',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'critical',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.collision;
    }
    // --- PRIORITY 2: CRITICAL REAR PROXIMITY ---
    else if (data.rearState == 3) {
      final alert = SafetyAlert(
        title: 'REAR WARNING',
        message: 'REAR PROXIMITY CRITICAL',
        severity: AlertSeverity.danger,
        unitSource: 'REAR',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'danger',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 3: CRITICAL LEAN/ROLLOVER RISK ---
    else if (data.leanRiskLevel == 2) {
      final alert = SafetyAlert(
        title: 'ROLLOVER RISK',
        message: 'CRITICAL VEHICLE LEAN',
        severity: AlertSeverity.critical,
        unitSource: 'COG',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'critical',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.drowsiness;
    }
    // --- PRIORITY 4: LANE DEPARTURE ---
    else if (data.laneState != 0) {
      final alert = SafetyAlert(
        title: 'LANE DRIFT',
        message: data.laneStateName,
        severity: AlertSeverity.warning,
        unitSource: 'VISION',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'warning',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.laneWarning;
    }
    // --- PRIORITY 5: APPROACHING OBSTACLE (FRONT) ---
    else if (data.frontState == 2) {
      final alert = SafetyAlert(
        title: 'APPROACH WARNING',
        message: 'OBJECT GETTING CLOSER',
        severity: AlertSeverity.danger,
        unitSource: 'RADAR',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'danger',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 6: REAR CAUTION ---
    else if (data.rearState == 2) {
      final alert = SafetyAlert(
        title: 'REAR CAUTION',
        message: 'OBJECT DETECTED CLOSE',
        severity: AlertSeverity.warning,
        unitSource: 'REAR',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'warning',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 7: LEAN CAUTION ---
    else if (data.leanRiskLevel == 1) {
      final alert = SafetyAlert(
        title: 'LEAN CAUTION',
        message: 'INCREASING LEAN ANGLE',
        severity: AlertSeverity.warning,
        unitSource: 'COG',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'warning',
        'unitSource': alert.unitSource,
      }));
      triggerAlert = AlertType.laneWarning;
    }
    // --- INFO: OBJECT DETECTED ---
    else if (data.frontState == 1 || data.rearState == 1) {
      final alert = SafetyAlert(
        title: 'OBJECT DETECTED',
        message: 'No immediate threat',
        severity: AlertSeverity.info,
        unitSource: data.frontState == 1 ? 'RADAR' : 'REAR',
      );
      _activeAlerts.add(alert);
      unawaited(_cloudService.logAlertEvent({
        'title': alert.title,
        'message': alert.message,
        'severity': 'info',
        'unitSource': alert.unitSource,
      }));
    }

    // --- ADD TO SESSION HISTORY (deduplicated: only when alert type changes) ---
    if (_activeAlerts.isNotEmpty) {
      final current = _activeAlerts.first;
      final key = '${current.title}|${current.severity.name}';
      if (key != _lastHistoryKey) {
        _lastHistoryKey = key;
        _alertHistory.insert(0, current);
        if (_alertHistory.length > 200) _alertHistory.removeLast();
      }
    } else {
      _lastHistoryKey = '';
    }

    // --- TRIGGER AUDIO ALERT ---
    _updateAudioAlert(triggerAlert, data);
  }

  /// Loads alert history from Firebase and merges with session history.
  Future<void> loadAlertHistory() async {
    final fetched = await _cloudService.fetchAlertHistory();
    for (final alert in fetched) {
      final alreadyPresent = _alertHistory.any(
        (h) => h.timestamp.difference(alert.timestamp).abs() < const Duration(seconds: 2) && h.title == alert.title,
      );
      if (!alreadyPresent) _alertHistory.add(alert);
    }
    _alertHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_alertHistory.length > 200) _alertHistory.length = 200;
    notifyListeners();
  }

  void _updateAudioAlert(AlertType? newAlert, DrivoraSensorData data) {
    if (!_audioEnabled) return;

    // Stop previous alert if it's no longer relevant
    if (_lastAudioAlert != null && newAlert != _lastAudioAlert) {
      _audioService.stopAll();
    }

    // Trigger new alert only when it changes
    if (newAlert != null && newAlert != _lastAudioAlert) {
      switch (newAlert) {
        case AlertType.collision:
          _audioService.playCollisionAlert();
          break;
        case AlertType.obstacleProx:
          _audioService.playObstacleProximity(
            distanceCm: math.max(data.frontDistance, data.rearDistance),
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

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  static double _nearestRearDistance(double l, double c, double r) {
    final valid = [l, c, r].where((d) => d >= 0).toList();
    if (valid.isEmpty) return -1.0;
    return valid.reduce(math.min);
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

  /// Send full vehicle setup to the ADAS Brain hub via WebSocket.
  /// Must be connected before calling. Returns true if sent successfully.
  Future<bool> sendSetupToHardware({
    required int vehicleType,
    required double trackWidthM,
    required double wheelBaseM,
    required double vehicleHeightM,
    required int loadCondition,
    required int frontPreset,
    required int rearPreset,
  }) async {
    if (_wsChannel == null) return false;
    try {
      final payload = json.encode({
        'cmd': 'saveAllSetup',
        'vehicleType': vehicleType,
        'trackWidth_m': trackWidthM,
        'wheelBase_m': wheelBaseM,
        'vehicleHeight_m': vehicleHeightM,
        'loadCondition': loadCondition,
        'frontPreset': frontPreset,
        'rearPreset': rearPreset,
      });
      _wsChannel!.sink.add(payload);
      return true;
    } catch (e) {
      debugPrint('Send setup error: $e');
      return false;
    }
  }

  bool get hardwareSetupComplete =>
      _currentData.frontOnline || _currentData.rearOnline;

  /// Backward-compatible shim used by registration_screen and settings_screen.
  /// Reads saved calibration values from SharedPreferences and delegates to [sendSetupToHardware].
  Future<bool> sendCalibrationToHardware({
    double height = 1.57,
    double width = 1.56,
  }) async {
    final sp = await SharedPreferences.getInstance();
    return sendSetupToHardware(
      vehicleType:    sp.getInt('vehicleTypeCode') ?? 3,
      trackWidthM:    width,
      wheelBaseM:     sp.getDouble('wheelBase') ?? 2.67,
      vehicleHeightM: height,
      loadCondition:  sp.getInt('loadCondition') ?? 1,
      frontPreset:    sp.getInt('frontPreset') ?? 1,
      rearPreset:     sp.getInt('rearPreset') ?? 1,
    );
  }
}