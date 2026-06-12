import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  // Incident records from ESP32 incident buffer (properly debounced events).
  final List<Map<String, dynamic>> _incidentRecords = [];
  static const String _incidentPrefsKey = 'drivora_incidents_v2';
  static const int _maxLocalIncidents = 150;

  // Internet / cloud-sync state
  bool _internetAvailable = false;
  Timer? _internetCheckTimer;

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
  bool get internetAvailable => _internetAvailable;
  String get status => _status;
  List<SafetyAlert> get activeAlerts => _activeAlerts;
  List<SafetyAlert> get alertHistory => List.unmodifiable(_alertHistory);
  List<DrivoraSensorData> get dataHistory => _dataHistory;
  Map<AlertType, int> get soundProfiles => Map.unmodifiable(_soundProfiles);

  // ── Incident statistics getters ────────────────────────────────────────────
  List<Map<String, dynamic>> get incidentRecords => List.unmodifiable(_incidentRecords);

  List<Map<String, dynamic>> incidentsForRange(int? days) {
    if (days == null) return incidentRecords;
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    return _incidentRecords.where((r) {
      final ts = (r['realTimeMs'] as int?) ?? (r['receivedAtMs'] as int?) ?? 0;
      return ts == 0 || ts >= cutoff;
    }).toList();
  }

  int totalEventCount(int? days) => incidentsForRange(days).length;
  int frontEventCount(int? days) =>
      incidentsForRange(days).where((r) => r['sourceUnit'] == 'front').length;
  int rearEventCount(int? days) =>
      incidentsForRange(days).where((r) => r['sourceUnit'] == 'rear').length;
  int stabilityEventCount(int? days) =>
      incidentsForRange(days).where((r) => r['sourceUnit'] == 'center').length;
  int laneEventCount(int? days) =>
      incidentsForRange(days).where((r) => r['sourceUnit'] == 'lane').length;
  int criticalEventCount(int? days) =>
      incidentsForRange(days).where((r) => (r['severity'] as int? ?? 0) >= 3).length;

  int driverScore(int? days) {
    final inc = incidentsForRange(days);
    final front = inc.where((r) => r['sourceUnit'] == 'front').length;
    final rear  = inc.where((r) => r['sourceUnit'] == 'rear').length;
    final stab  = inc.where((r) => r['sourceUnit'] == 'center').length;
    final lane  = inc.where((r) => r['sourceUnit'] == 'lane').length;
    final crit  = inc.where((r) => (r['severity'] as int? ?? 0) >= 3).length;
    final multi = inc.where((r) => r['sourceUnit'] == 'multiple').length;
    var score = 100;
    score -= (crit  * 18).clamp(0, 72);
    score -= (front * 10).clamp(0, 50);
    score -= (rear  *  8).clamp(0, 40);
    score -= (stab  *  8).clamp(0, 40);
    score -= (lane  *  5).clamp(0, 25);
    score -= (multi * 12).clamp(0, 48);
    return score.clamp(0, 100);
  }

  Future<void> initialize() async {
    _audioService = AudioService();
    _cloudService = CloudService();
    await _loadIncidentsFromPrefs();
    _status = 'Drivora Core Initialized';
    notifyListeners();
    _startInternetMonitor();
  }

  @override
  void dispose() {
    _internetCheckTimer?.cancel();
    stopAllStreams();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internet / cloud-sync monitor
  // ---------------------------------------------------------------------------

  void _startInternetMonitor() {
    // Run an immediate check, then repeat every 25 seconds.
    unawaited(_checkInternetAndSync());
    _internetCheckTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _checkInternetAndSync(),
    );
  }

  /// DNS-lookup-based connectivity probe. Fast (~50 ms on live internet,
  /// fails within 3 s on an isolated WiFi like the ADAS hotspot).
  /// When the phone transitions from offline → online the pending cloud queue
  /// is flushed automatically.
  Future<void> _checkInternetAndSync() async {
    bool online;
    try {
      final result = await InternetAddress.lookup('connectivitycheck.gstatic.com')
          .timeout(const Duration(seconds: 3));
      online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      online = false;
    }

    final justCameOnline = !_internetAvailable && online;
    if (_internetAvailable != online) {
      _internetAvailable = online;
      notifyListeners(); // updates TopBar cloud indicator
    }

    // Flush any locally-queued alert events now that we have internet.
    if (justCameOnline) {
      unawaited(_cloudService.flushPendingEvents());
    }
  }

  // ── Incident persistence ───────────────────────────────────────────────────

  Future<void> _loadIncidentsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_incidentPrefsKey);
      if (raw != null) {
        final decoded = json.decode(raw) as List<dynamic>;
        _incidentRecords
          ..clear()
          ..addAll(decoded.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('Load incidents error: $e');
    }
  }

  Future<void> _saveIncidentsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_incidentPrefsKey, json.encode(_incidentRecords));
    } catch (e) {
      debugPrint('Save incidents error: $e');
    }
  }

  void _handleIncidentMessage(Map<String, dynamic> incident) {
    final id = incident['id'] as int? ?? 0;
    final alreadyStored = _incidentRecords.any((r) => (r['id'] as int?) == id && id > 0);
    if (!alreadyStored && id > 0) {
      final record = Map<String, dynamic>.from(incident)
        ..['receivedAtMs'] = DateTime.now().millisecondsSinceEpoch;
      _incidentRecords.insert(0, record);
      if (_incidentRecords.length > _maxLocalIncidents) {
        _incidentRecords.removeLast();
      }
      unawaited(_saveIncidentsToPrefs());
      // Sync all non-info incidents to Firestore (queued offline if needed).
      if ((incident['severity'] as int? ?? 0) >= 1) {
        unawaited(_cloudService.logAlertEvent({
          'title':      incident['title']      ?? '',
          'message':    incident['message']    ?? '',
          'severity':   _incidentSeverityStr(incident['severity'] as int? ?? 0),
          'unitSource': incident['sourceUnit'] ?? '',
          'sourceUnit': incident['sourceUnit'] ?? '',
          'realTimeMs': (record['realTimeMs'] as int?) ??
              (record['receivedAtMs'] as int?) ??
              DateTime.now().millisecondsSinceEpoch,
        }));
      }
      notifyListeners();
    }
    // Always ack so ESP32 can free its buffer slot
    if (_wsChannel != null && id > 0) {
      _wsChannel!.sink.add(json.encode({'cmd': 'incidentAck', 'incidentId': id}));
    }
  }

  static String _incidentSeverityStr(int sev) {
    if (sev >= 3) return 'critical';
    if (sev == 2) return 'warning';
    return 'info';
  }

  static int _alertSeverityToInt(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical: return 3;
      case AlertSeverity.danger:   return 2;
      case AlertSeverity.warning:  return 1;
      default:                     return 0;
    }
  }

  static String _srcToUnit(String src) {
    switch (src) {
      case 'RADAR':  return 'front';
      case 'REAR':   return 'rear';
      case 'COG':    return 'center';
      case 'VISION': return 'lane';
      default:       return src.toLowerCase();
    }
  }

  static String _rearZoneLabel(DrivoraSensorData data) {
    if (data.rearCenterState >= 2) return 'CENTER';
    if (data.rearLeftState   >= 2) return 'LEFT';
    if (data.rearRightState  >= 2) return 'RIGHT';
    return 'MULTI';
  }

  void clearLocalIncidents() {
    _incidentRecords.clear();
    unawaited(_saveIncidentsToPrefs());
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
      unawaited(connectToHardwareHub('10.42.0.1'));
    }
  }

  Future<void> connectToHardwareHub(String ipAddress) async {
    stopAllStreams();
    _status = 'Connecting to ADAS Brain...';
    notifyListeners();

    try {
      final wsUrl = Uri.parse('ws://$ipAddress/ws');
      _wsChannel = WebSocketChannel.connect(wsUrl);

      await _wsChannel!.ready.timeout(const Duration(seconds: 5));

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
        cancelOnError: true,
      );
    } on TimeoutException {
      _handleError('Timeout: Ensure WiFi is ADASBrain');
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
    // Incident messages are dispatched separately from telemetry
    if (json['type'] == 'incident') {
      final incident = json['incident'] as Map<String, dynamic>?;
      if (incident != null) _handleIncidentMessage(incident);
      return;
    }

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

    notifyListeners();
  }

  void _processSafetyAlerts(DrivoraSensorData data) {
    _activeAlerts.clear();
    AlertType? triggerAlert;
    // Severity string and analytics sourceUnit for the deduped cloud log below.
    var sev = 'info';
    var src = '';

    // --- PRIORITY 1: CRITICAL COLLISION WARNING ---
    if (data.frontState == 3) {
      _activeAlerts.add(SafetyAlert(title: 'BRAKE NOW',
          message: 'FRONT COLLISION IMMINENT',
          severity: AlertSeverity.critical, unitSource: 'RADAR'));
      sev = 'critical'; src = 'RADAR';
      triggerAlert = AlertType.collision;
    }
    // --- PRIORITY 2: CRITICAL REAR PROXIMITY ---
    else if (data.rearState == 3) {
      _activeAlerts.add(SafetyAlert(title: 'REAR WARNING',
          message: 'REAR PROXIMITY CRITICAL',
          severity: AlertSeverity.danger, unitSource: 'REAR'));
      sev = 'danger'; src = 'REAR';
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 3: CRITICAL LEAN/ROLLOVER RISK ---
    else if (data.leanRiskLevel == 2) {
      _activeAlerts.add(SafetyAlert(title: 'ROLLOVER RISK',
          message: 'CRITICAL VEHICLE LEAN',
          severity: AlertSeverity.critical, unitSource: 'COG'));
      sev = 'critical'; src = 'COG';
      triggerAlert = AlertType.drowsiness;
    }
    // --- PRIORITY 4: LANE DEPARTURE ---
    else if (data.laneState != 0) {
      _activeAlerts.add(SafetyAlert(title: 'LANE DRIFT',
          message: data.laneStateName,
          severity: AlertSeverity.warning, unitSource: 'VISION'));
      sev = 'warning'; src = 'VISION';
      triggerAlert = AlertType.laneWarning;
    }
    // --- PRIORITY 5: APPROACHING OBSTACLE (FRONT) ---
    else if (data.frontState == 2) {
      _activeAlerts.add(SafetyAlert(title: 'APPROACH WARNING',
          message: 'OBJECT GETTING CLOSER',
          severity: AlertSeverity.danger, unitSource: 'RADAR'));
      sev = 'danger'; src = 'RADAR';
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 6: REAR CAUTION ---
    else if (data.rearState == 2) {
      _activeAlerts.add(SafetyAlert(title: 'REAR CAUTION',
          message: 'OBJECT DETECTED CLOSE',
          severity: AlertSeverity.warning, unitSource: 'REAR'));
      sev = 'warning'; src = 'REAR';
      triggerAlert = AlertType.obstacleProx;
    }
    // --- PRIORITY 7: LEAN CAUTION ---
    else if (data.leanRiskLevel == 1) {
      _activeAlerts.add(SafetyAlert(title: 'LEAN CAUTION',
          message: 'INCREASING LEAN ANGLE',
          severity: AlertSeverity.warning, unitSource: 'COG'));
      sev = 'warning'; src = 'COG';
      triggerAlert = AlertType.laneWarning;
    }
    // --- INFO: OBJECT DETECTED ---
    else if (data.frontState == 1 || data.rearState == 1) {
      _activeAlerts.add(SafetyAlert(title: 'OBJECT DETECTED',
          message: 'No immediate threat',
          severity: AlertSeverity.info,
          unitSource: data.frontState == 1 ? 'RADAR' : 'REAR'));
      sev = 'info'; src = data.frontState == 1 ? 'RADAR' : 'REAR';
    }

    // --- SESSION HISTORY + LOCAL INCIDENT RECORD + CLOUD LOG ----------------
    // Fires once per condition-change (debounced by _lastHistoryKey).
    if (_activeAlerts.isNotEmpty) {
      final current = _activeAlerts.first;
      final key = '${current.title}|${current.severity.name}';
      if (key != _lastHistoryKey) {
        _lastHistoryKey = key;
        _alertHistory.insert(0, current);
        if (_alertHistory.length > 200) _alertHistory.removeLast();

        // ── Save to _incidentRecords so Statistics page updates in real-time ──
        final nowMs   = DateTime.now().millisecondsSinceEpoch;
        final unit    = _srcToUnit(src);
        final sevInt  = _alertSeverityToInt(current.severity);
        final record  = <String, dynamic>{
          'id':           nowMs,          // unique within the local store
          'title':        current.title,
          'message':      current.message,
          'severity':     sevInt,
          'sourceUnit':   unit,
          'realTimeMs':   nowMs,
          'receivedAtMs': nowMs,
        };
        // Attach sensor telemetry so the detail row in the incident card shows.
        if (src == 'RADAR' && data.frontDistance >= 0) {
          record['frontDistanceCm'] = data.frontDistance;
          record['frontSpeedCmS']   = data.closingSpeed;
        } else if (src == 'REAR' && data.rearDistance >= 0) {
          record['rearNearestDistanceCm'] = data.rearDistance;
          record['rearZone'] = _rearZoneLabel(data);
        } else if (src == 'COG') {
          record['leanRollDeg']  = data.roll;
          record['leanPitchDeg'] = data.pitch;
        }
        _incidentRecords.insert(0, record);
        if (_incidentRecords.length > _maxLocalIncidents) {
          _incidentRecords.removeLast();
        }
        unawaited(_saveIncidentsToPrefs());

        // ── Cloud log (queued offline when no internet, flushed on reconnect) ──
        unawaited(_cloudService.logAlertEvent({
          'title':      current.title,
          'message':    current.message,
          'severity':   sev,
          'unitSource': src,
          'sourceUnit': src,
          'realTimeMs': nowMs,
        }));
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
    if (valid.isEmpty) return -1;
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

  /// Send vehicle configuration (type, load, dimensions) as saveVehicle command.
  Future<bool> sendVehicleToHardware({
    required int vehicleType,
    required int loadCondition,
    required double trackWidthM,
    required double wheelBaseM,
    required double vehicleHeightM,
  }) async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add(json.encode({
        'cmd': 'saveVehicle',
        'vehicleType': vehicleType,
        'loadCondition': loadCondition,
        'trackWidth_m': trackWidthM,
        'wheelBase_m': wheelBaseM,
        'vehicleHeight_m': vehicleHeightM,
        'setupCompleted': true,
      }));
      return true;
    } catch (e) {
      debugPrint('Send vehicle error: $e');
      return false;
    }
  }

  /// Send front sensor sensitivity preset (0=near, 1=normal, 2=far).
  Future<bool> sendFrontPresetToHardware(int preset) async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add(json.encode({'cmd': 'saveFrontPreset', 'frontPreset': preset}));
      return true;
    } catch (e) {
      debugPrint('Send front preset error: $e');
      return false;
    }
  }

  /// Send rear sensor sensitivity preset (0=near, 1=normal, 2=far).
  Future<bool> sendRearPresetToHardware(int preset) async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add(json.encode({'cmd': 'saveRearPreset', 'rearPreset': preset}));
      return true;
    } catch (e) {
      debugPrint('Send rear preset error: $e');
      return false;
    }
  }

  /// Send buzzer pattern+volume assignments. All 4 patterns must be unique (0–3).
  Future<bool> sendSoundSettingsToHardware({
    required int frontPattern,
    required int rearPattern,
    required int lanePattern,
    required int leanPattern,
    required int frontVolume,
    required int rearVolume,
    required int laneVolume,
    required int leanVolume,
  }) async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add(json.encode({
        'cmd': 'saveSoundSettings',
        'frontSoundPattern': frontPattern,
        'rearSoundPattern': rearPattern,
        'laneSoundPattern': lanePattern,
        'leanSoundPattern': leanPattern,
        'frontSoundVolume': frontVolume,
        'rearSoundVolume': rearVolume,
        'laneSoundVolume': laneVolume,
        'leanSoundVolume': leanVolume,
      }));
      return true;
    } catch (e) {
      debugPrint('Send sound settings error: $e');
      return false;
    }
  }

  /// Send new WiFi credentials to ADAS Brain. ESP32 restarts immediately after saving.
  Future<bool> sendWifiSetupToHardware({
    required String ssid,
    required String password,
  }) async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add(json.encode({'cmd': 'saveWifiSetup', 'ssid': ssid, 'password': password}));
      return true;
    } catch (e) {
      debugPrint('Send WiFi setup error: $e');
      return false;
    }
  }

  /// Trigger IMU center calibration. Vehicle must be stationary and level.
  Future<bool> sendCenterCalibration() async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add('CAL_CENTER');
      return true;
    } catch (e) {
      debugPrint('Send center calibration error: $e');
      return false;
    }
  }

  /// Play a hardware buzzer test pattern (pattern 0–3, volume 30–100).
  Future<bool> testSoundOnHardware(int pattern, int volume) async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add(json.encode({'cmd': 'testSound', 'pattern': pattern, 'volume': volume}));
      return true;
    } catch (e) {
      debugPrint('Test sound error: $e');
      return false;
    }
  }

  /// Tell the ADAS Brain to wipe its stored config back to factory defaults.
  Future<bool> sendResetDefaults() async {
    if (_wsChannel == null) return false;
    try {
      _wsChannel!.sink.add('RESET_DEFAULTS');
      return true;
    } catch (e) {
      debugPrint('Send reset defaults error: $e');
      return false;
    }
  }

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