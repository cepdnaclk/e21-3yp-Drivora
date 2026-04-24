import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Fetches profile data
  Future<DocumentSnapshot> getCloudProfile(String email) {
    return _db.collection('users').doc(email).get();
  }
}
