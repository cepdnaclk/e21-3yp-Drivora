import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class CloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registers user and vehicle calibration data to Firebase Firestore.
  Future<bool> registerUserFirebase({
    required String name,
    required String email,
    required String carModel,
    required double height,
    required double width,
  }) async {
    try {
      // 1. Create a Firebase Auth account (anonymous session)
      UserCredential userCredential = await _auth.signInAnonymously();
      String uid = userCredential.user?.uid ?? email;

      // 2. Save locally for session management
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', name);
      await prefs.setString('userEmail', email);
      await prefs.setString('carModel', carModel);
      await prefs.setDouble('vHeight', height);
      await prefs.setDouble('vWidth', width);
      await prefs.setString('userUid', uid);

      // 3. Save to Firestore Cloud
      await _db.collection('users').doc(email).set({
        'uid': uid,
        'name': name,
        'email': email,
        'carModel': carModel,
        'calibration': {
          'height': height,
          'width': width,
        },
        'registeredAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Firebase Sync Error: $e');
      return false;
    }
  }

  /// Saves onboarding initialisation data to Firebase and local storage.
  ///
  /// [driverEmail] is optional — when omitted (or passed as an empty string)
  /// the method falls back to whatever email is already stored in
  /// SharedPreferences, matching the behaviour callers that don't supply it
  /// expect.
  Future<bool> saveOnboardingData({
    required String driverName,
    String driverEmail = '',                 // ← now optional, defaults to ''
    required String driverExperience,
    required String vehicleType,
    required String vehicleModel,
    required double vehicleHeight,
    required double vehicleWidth,
    required int alertSensitivity,
    required int audioVolume,
    Map<String, int> soundProfiles = const {},
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Resolve email: prefer the supplied value, fall back to stored value.
      final email = driverEmail.isNotEmpty
          ? driverEmail
          : (prefs.getString('userEmail') ?? '');

      if (email.isEmpty) {
        print('Error: No email provided or found in storage for onboarding.');
        return false;
      }

      // 1. Save locally
      await prefs.setString('userName', driverName);
      await prefs.setString('userEmail', email);
      await prefs.setString('driverExperience', driverExperience);
      await prefs.setString('vehicleType', vehicleType);
      await prefs.setString('carModel', vehicleModel);
      await prefs.setDouble('vHeight', vehicleHeight);
      await prefs.setDouble('vWidth', vehicleWidth);
      await prefs.setInt('alertSensitivity', alertSensitivity);
      await prefs.setInt('audioVolume', audioVolume);
      await prefs.setBool('setupComplete', true);

      // Save sound profiles locally
      for (final entry in soundProfiles.entries) {
        await prefs.setInt('sound_profile_${entry.key}', entry.value);
      }

      // 2. Save to Firestore Cloud
      await _db.collection('users').doc(email).set({
        'name': driverName,
        'email': email,
        'carModel': vehicleModel,
        'experience': driverExperience,
        'vehicleType': vehicleType,
        'calibration': {
          'height': vehicleHeight,
          'width': vehicleWidth,
        },
        'settings': {
          'sensitivity': alertSensitivity,
          'volume': audioVolume,
          'soundProfiles': soundProfiles,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      print('Onboarding Sync Error: $e');
      return false;
    }
  }

  /// Logs safety events to the cloud.
  Future<void> logSafetyHistory(Map<String, dynamic> telemetry) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null) return;

    try {
      await _db.collection('users').doc(email).collection('history').add({
        'timestamp': FieldValue.serverTimestamp(),
        'data': telemetry,
      });
    } catch (e) {
      print('Cloud Logging Error: $e');
    }
  }

  /// Fetches profile data for [email].
  Future<DocumentSnapshot> getCloudProfile(String email) {
    return _db.collection('users').doc(email).get();
  }

  /// Saves a snapshot of sensor data to the cloud for analytics.
  Future<void> saveTelemetrySnapshot(Map<String, dynamic> telemetry) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null) return;

    try {
      await _db.collection('users').doc(email).collection('telemetry').add({
        'timestamp': FieldValue.serverTimestamp(),
        ...telemetry,
      });
    } catch (e) {
      print('Telemetry Snapshot Error: $e');
    }
  }

  /// Logs a specific alert event to the cloud for history.
  Future<void> logAlertEvent(Map<String, dynamic> alertData) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null) return;

    try {
      await _db.collection('users').doc(email).collection('history').add({
        'timestamp': FieldValue.serverTimestamp(),
        ...alertData,
      });
    } catch (e) {
      print('Alert Event Logging Error: $e');
    }
  }

  /// Fetches the alert history for the current user from Firebase.
  Future<List<SafetyAlert>> fetchAlertHistory({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) return [];

    try {
      final snap = await _db
          .collection('users')
          .doc(email)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        return SafetyAlert(
          title: (data['title'] as String?) ?? 'Alert',
          message: (data['message'] as String?) ?? '',
          severity: SafetyAlert.parseSeverity((data['severity'] as String?) ?? 'info'),
          unitSource: (data['unitSource'] as String?) ?? '',
          timestamp: (data['timestamp'] is Timestamp)
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Fetch Alert History Error: $e');
      return [];
    }
  }

  /// Syncs user profile from local storage to Firebase Cloud.
  Future<bool> syncUserProfileToCloud({
    required String email,
    Map<String, dynamic>? userData,
  }) async {
    try {
      if (email.isEmpty) {
        print('Cannot sync: Email is empty');
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final dataToSync = userData ?? {
        'name': prefs.getString('userName') ?? prefs.getString('driverName') ?? 'DRIVER',
        'email': email,
        'carModel': prefs.getString('vehicleModel') ?? 'NOT SET',
        'calibration': {
          'height': prefs.getDouble('vehicleHeight') ?? 0.0,
          'width': prefs.getDouble('vehicleWidth') ?? 0.0,
        },
        'onboarding': {
          'driverExperience': prefs.getString('driverExperience') ?? 'NOT SET',
          'vehicleType': prefs.getString('vehicleType') ?? 'NOT SET',
          'alertSensitivity': prefs.getInt('alertSensitivity') ?? 0,
          'audioVolume': prefs.getInt('audioVolume') ?? 0,
        },
        'lastSyncedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('users').doc(email).set(
        dataToSync,
        SetOptions(merge: true),
      );

      print('User profile synced to Firebase: $email');
      return true;
    } catch (e) {
      print('Cloud Sync Profile Error: $e');
      return false;
    }
  }
}