import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';
import 'wifi_sensor_service.dart' show WiFiSensorService;

class CloudService {
  final FirebaseFirestore _db   = FirebaseFirestore.instance;
  final FirebaseAuth      _auth = FirebaseAuth.instance;

  // ── Offline pending queue ────────────────────────────────────────────────────
  // Events that failed to upload are serialised here and retried next time
  // flushPendingEvents() succeeds (called on app start, login, and after any
  // successful Firestore write).
  static const String _pendingQueueKey = 'drivora_pending_cloud_v1';
  static const int    _maxQueueSize    = 500;

  // ── Registration ────────────────────────────────────────────────────────────

  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required String vehicleModel,
    required String vehicleCategory,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user?.updateDisplayName(name);
      final uid = cred.user!.uid;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName',        name);
      await prefs.setString('userEmail',       email.trim());
      await prefs.setString('vehicleModel',    vehicleModel);
      await prefs.setString('vehicleCategory', vehicleCategory);
      await prefs.setString('userUid',         uid);

      await _db.collection('users').doc(email.trim()).set({
        'uid':             uid,
        'name':            name,
        'email':           email.trim(),
        'vehicleModel':    vehicleModel,
        'vehicleCategory': vehicleCategory,
        'registeredAt':    FieldValue.serverTimestamp(),
      });

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Registration error: ${e.code} – ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Registration error: $e');
      return false;
    }
  }

  /// Returns the FirebaseAuthException code string on failure, null on success.
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Pull profile from Firestore into local prefs.
      try {
        final doc = await _db.collection('users').doc(email.trim()).get();
        if (doc.exists) {
          final d = doc.data()!;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName',        d['name']            ?? '');
          await prefs.setString('userEmail',       email.trim());
          await prefs.setString('vehicleModel',    d['vehicleModel']    ?? '');
          await prefs.setString('vehicleCategory', d['vehicleCategory'] ?? '');
          await prefs.setString('userUid',         d['uid']             ?? '');
        }
      } catch (_) {}

      // After login, flush any events that were queued while offline.
      unawaited(flushPendingEvents());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code;
    } catch (e) {
      return 'unknown';
    }
  }

  // ── Incident / alert logging ─────────────────────────────────────────────────

  /// Writes one incident event to `users/{email}/incidents`.
  /// On network failure the event is serialised into a local queue and retried
  /// the next time [flushPendingEvents] is called.
  ///
  /// Required keys in [alert]:
  ///   title, message, severity (String: info/warning/danger/critical),
  ///   unitSource (display label), sourceUnit (analytics key: front/rear/center/lane)
  /// Optional: realTimeMs (int epoch-ms, defaults to now)
  Future<void> logAlertEvent(Map<String, dynamic> alert) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) return;

    final payload = _buildPayload(alert);
    try {
      await _db
          .collection('users').doc(email)
          .collection('incidents')
          .add(payload);
      // Successful write — try flushing the pending queue while we have internet.
      unawaited(flushPendingEvents());
    } catch (e) {
      debugPrint('CloudService.logAlertEvent offline, queuing: $e');
      await _enqueue({'email': email, ...payload});
    }
  }

  /// Tries to upload every queued event to Firestore.
  /// Items that fail (still no internet) remain in the queue.
  /// Safe to call at any time; silently no-ops if queue is empty.
  Future<void> flushPendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey);
      if (raw == null) return;

      final queue = (json.decode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (queue.isEmpty) return;

      final failed = <Map<String, dynamic>>[];
      for (final item in queue) {
        final email = item['email'] as String? ??
            prefs.getString('userEmail') ?? '';
        if (email.isEmpty) { failed.add(item); continue; }
        try {
          final payload = Map<String, dynamic>.from(item)..remove('email');
          await _db
              .collection('users').doc(email)
              .collection('incidents')
              .add(payload);
        } catch (_) {
          failed.add(item);
        }
      }
      await prefs.setString(_pendingQueueKey, json.encode(failed));
    } catch (e) {
      debugPrint('flushPendingEvents error: $e');
    }
  }

  /// Fetches all incidents from Firestore and returns them in the format
  /// used by [WiFiSensorService._incidentRecords].
  /// Used to restore history after app reinstall + login.
  Future<List<Map<String, dynamic>>> fetchIncidentsAsRecords({
    int limit = 200,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) return [];
    try {
      final snap = await _db
          .collection('users').doc(email)
          .collection('incidents')
          .orderBy('realTimeMs', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final d  = doc.data();
        final ms = (d['realTimeMs'] as int?) ??
            (d['timestamp'] as Timestamp?)
                ?.toDate().millisecondsSinceEpoch ?? 0;
        return <String, dynamic>{
          'id':           doc.id.hashCode.abs(),
          'title':        d['title']       as String? ?? '',
          'message':      d['message']     as String? ?? '',
          'severity':     d['severityInt'] as int? ??
              _severityStrToInt(d['severity'] as String? ?? 'info'),
          'sourceUnit':   d['sourceUnit']  as String? ??
              _unitSourceToAnalyticsKey(d['unitSource'] as String? ?? ''),
          'realTimeMs':   ms,
          'receivedAtMs': ms,
          'fromCloud':    true,
        };
      }).toList();
    } catch (e) {
      debugPrint('fetchIncidentsAsRecords error: $e');
      return [];
    }
  }

  // ── Legacy: SafetyAlert fetch (kept for backward compat) ────────────────────

  Future<List<SafetyAlert>> fetchAlertHistory({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) return [];
    try {
      // Try the newer 'incidents' subcollection first, fall back to 'alerts'.
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _db
            .collection('users').doc(email)
            .collection('incidents')
            .orderBy('realTimeMs', descending: true)
            .limit(limit)
            .get();
      } catch (_) {
        snap = await _db
            .collection('users').doc(email)
            .collection('alerts')
            .orderBy('timestamp', descending: true)
            .limit(limit)
            .get();
      }

      return snap.docs.map((doc) {
        final d   = doc.data();
        final ts  = (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final sev = _parseSeverity(d['severity'] as String? ?? 'info');
        return SafetyAlert(
          title:      d['title']      as String? ?? '',
          message:    d['message']    as String? ?? '',
          severity:   sev,
          unitSource: d['unitSource'] as String? ?? '',
          timestamp:  ts,
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchAlertHistory error: $e');
      return [];
    }
  }

  // ── Profile ──────────────────────────────────────────────────────────────────

  Future<bool> updateUserProfile({
    required String name,
    required String vehicleModel,
    required String vehicleCategory,
    required String email,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(name);
      await _db.collection('users').doc(email).update({
        'name':            name,
        'vehicleModel':    vehicleModel,
        'vehicleCategory': vehicleCategory,
      });
      return true;
    } catch (e) {
      debugPrint('updateUserProfile error: $e');
      return false;
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Map<String, dynamic> _buildPayload(Map<String, dynamic> alert) => {
    'timestamp':   FieldValue.serverTimestamp(),
    'realTimeMs':  alert['realTimeMs'] as int? ??
        DateTime.now().millisecondsSinceEpoch,
    'title':       alert['title']      as String? ?? '',
    'message':     alert['message']    as String? ?? '',
    'severity':    alert['severity']   as String? ?? 'info',
    'severityInt': _severityStrToInt(alert['severity'] as String? ?? 'info'),
    'unitSource':  alert['unitSource'] as String? ?? '',
    'sourceUnit':  alert['sourceUnit'] as String? ??
        _unitSourceToAnalyticsKey(alert['unitSource'] as String? ?? ''),
  };

  Future<void> _enqueue(Map<String, dynamic> item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingQueueKey) ?? '[]';
      final queue = (json.decode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      // Remove FieldValue.serverTimestamp() — not serialisable.
      final storable = Map<String, dynamic>.from(item)
        ..remove('timestamp');
      queue.add(storable);
      if (queue.length > _maxQueueSize) {
        queue.removeRange(0, queue.length - _maxQueueSize);
      }
      await prefs.setString(_pendingQueueKey, json.encode(queue));
    } catch (e) {
      debugPrint('_enqueue error: $e');
    }
  }

  static int _severityStrToInt(String s) {
    switch (s) {
      case 'critical': return 3;
      case 'danger':   return 2;
      case 'warning':  return 2;
      default:         return 1;
    }
  }

  static String _unitSourceToAnalyticsKey(String unitSource) {
    switch (unitSource.toUpperCase()) {
      case 'RADAR': return 'front';
      case 'REAR':  return 'rear';
      case 'COG':   return 'center';
      case 'VISION': return 'lane';
      default:      return unitSource.toLowerCase();
    }
  }

  AlertSeverity _parseSeverity(String s) {
    switch (s) {
      case 'critical': return AlertSeverity.critical;
      case 'danger':   return AlertSeverity.danger;
      case 'warning':  return AlertSeverity.warning;
      default:         return AlertSeverity.info;
    }
  }

  // ── Legacy shims ─────────────────────────────────────────────────────────────

  Future<bool> registerUserFirebase({
    required String name,
    required String email,
    required String carModel,
    required double height,
    required double width,
  }) => registerUser(
        name: name,
        email: email,
        password: 'changeme123',
        vehicleModel: carModel,
        vehicleCategory: 'Sedan',
      );

  Future<bool> saveOnboardingData({
    required String driverName,
    required String driverExperience,
    required String vehicleType,
    required String vehicleModel,
    required double vehicleHeight,
    required double vehicleWidth,
    required int alertSensitivity,
    required int audioVolume,
    String? driverEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicleType',  vehicleType);
    await prefs.setString('vehicleModel', vehicleModel);
    await prefs.setDouble('vHeight',      vehicleHeight);
    await prefs.setDouble('vWidth',       vehicleWidth);
    await prefs.setBool('setupComplete',  true);
    return true;
  }

  Future<DocumentSnapshot> getCloudProfile(String email) =>
      _db.collection('users').doc(email).get();

  Future<bool> syncUserProfileToCloud({
    required String email,
    Map<String, dynamic>? userData,
  }) async => true;

  Future<void> logSafetyHistory(Map<String, dynamic> telemetry) async {}
  Future<void> saveTelemetrySnapshot(Map<String, dynamic> data) async {}
}
