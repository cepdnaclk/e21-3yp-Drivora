import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

class CloudService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Registers user and vehicle calibration data to Firebase Firestore
  Future<bool> registerUserFirebase({
    required String name,
    required String email,
    required String carModel,
    required double height,
    required double width,
  }) async {
    try {
      // 1. Create a Firebase Auth account (Anonymous sign-in for seamless entry)
      final userCredential = await _auth.signInAnonymously();
      final uid = userCredential.user?.uid ?? email;

      // 2. Save locally for session management with consistent keys
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', name);
      await prefs.setString('driverName', name);
      await prefs.setString('userEmail', email);
      await prefs.setString('vehicleModel', carModel);
      await prefs.setString('carModel', carModel);
      await prefs.setDouble('vehicleHeight', height);
      await prefs.setDouble('vHeight', height);
      await prefs.setDouble('vehicleWidth', width);
      await prefs.setDouble('vWidth', width);
      await prefs.setString('userUid', uid);
      print('✓ Registration: Saved to SharedPreferences: email=$email, uid=$uid');

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

  /// Logs safety events to the cloud
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

  /// Saves telemetry snapshot to Firebase
  Future<void> saveTelemetrySnapshot(Map<String, dynamic> sensorData) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null) return;

    try {
      await _db.collection('users').doc(email).collection('telemetry').add({
        'timestamp': FieldValue.serverTimestamp(),
        'frontDistance': sensorData['frontDistance'],
        'rearDistance': sensorData['rearDistance'],
        'roll': sensorData['roll'],
        'pitch': sensorData['pitch'],
        'speed': sensorData['speed'],
        'laneState': sensorData['laneState'],
      });
    } catch (e) {
      print('Telemetry Save Error: $e');
    }
  }

  /// Logs alert events to Firebase
  Future<void> logAlertEvent(Map<String, dynamic> alert) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null) return;

    try {
      await _db.collection('users').doc(email).collection('alerts').add({
        'timestamp': FieldValue.serverTimestamp(),
        'title': alert['title'],
        'message': alert['message'],
        'severity': alert['severity'],
        'unitSource': alert['unitSource'],
      });
    } catch (e) {
      print('Alert Log Error: $e');
    }
  }

  /// Saves onboarding initialization data to Firebase and local storage
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
    try {
      // 1. Save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driverName', driverName);
      await prefs.setString('driverExperience', driverExperience);
      await prefs.setString('vehicleType', vehicleType);
      await prefs.setString('vehicleModel', vehicleModel);
      await prefs.setDouble('vehicleHeight', vehicleHeight);
      await prefs.setDouble('vehicleWidth', vehicleWidth);
      await prefs.setInt('alertSensitivity', alertSensitivity);
      await prefs.setInt('audioVolume', audioVolume);
      await prefs.setBool('setupComplete', true);

      // 2. Get user email from local storage
      final userEmail = prefs.getString('userEmail');
      if (userEmail == null) {
        print('No user email found for onboarding sync');
        return false;
      }

      // 3. Save to Firestore Cloud
      await _db.collection('users').doc(userEmail).update({
        'onboarding': {
          'driverName': driverName,
          'driverExperience': driverExperience,
          'vehicleType': vehicleType,
          'vehicleModel': vehicleModel,
          'vehicleHeight': vehicleHeight,
          'vehicleWidth': vehicleWidth,
          'alertSensitivity': alertSensitivity,
          'audioVolume': audioVolume,
        },
        'setupCompleteAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Onboarding Sync Error: $e');
      return false;
    }
  }

  /// Fetches profile data
  Future<DocumentSnapshot> getCloudProfile(String email) => 
    _db.collection('users').doc(email).get();

  /// Syncs user profile from local storage to Firebase Cloud
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
          'vehicleModel': prefs.getString('vehicleModel') ?? 'NOT SET',
          'alertSensitivity': prefs.getInt('alertSensitivity') ?? 0,
          'audioVolume': prefs.getInt('audioVolume') ?? 0,
        },
        'lastSyncedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('users').doc(email).set(
        dataToSync,
        SetOptions(merge: true), // Merge with existing data
      );

      print('User profile synced to Firebase: $email');
      return true;
    } catch (e) {
      print('Cloud Sync Profile Error: $e');
      return false;
    }
  }

  /// Fetches past alert history from Firebase (alerts collection).
  Future<List<SafetyAlert>> fetchAlertHistory({int limit = 100}) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('userEmail');
    if (email == null || email.isEmpty) return [];

    try {
      final snapshot = await _db
          .collection('users')
          .doc(email)
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        final sevStr = data['severity'] as String? ?? 'info';
        final sev = sevStr == 'critical'
            ? AlertSeverity.critical
            : sevStr == 'danger'
                ? AlertSeverity.danger
                : sevStr == 'warning'
                    ? AlertSeverity.warning
                    : AlertSeverity.info;
        return SafetyAlert(
          title: data['title'] as String? ?? '',
          message: data['message'] as String? ?? '',
          severity: sev,
          unitSource: data['unitSource'] as String? ?? '',
          timestamp: ts,
        );
      }).toList();
    } catch (e) {
      print('Fetch alert history error: $e');
      return [];
    }
  }
}
