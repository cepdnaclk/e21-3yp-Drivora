import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cloud_service.dart';

class UserProvider extends ChangeNotifier {
  final CloudService _cloudService = CloudService();
  
  // User data
  String? _userName;
  String? _userEmail;
  String? _vehicleModel;
  double? _vehicleHeight;
  double? _vehicleWidth;
  String? _driverExperience;
  String? _vehicleType;
  int? _alertSensitivity;
  int? _audioVolume;
  
  Map<String, dynamic>? _cloudData;
  bool _isLoading = false;
  String? _error;

  // Getters
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get vehicleModel => _vehicleModel;
  double? get vehicleHeight => _vehicleHeight;
  double? get vehicleWidth => _vehicleWidth;
  String? get driverExperience => _driverExperience;
  String? get vehicleType => _vehicleType;
  int? get alertSensitivity => _alertSensitivity;
  int? get audioVolume => _audioVolume;
  Map<String, dynamic>? get cloudData => _cloudData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUserRegistered => _userEmail != null && _userEmail!.trim().isNotEmpty;

  /// Initialize user data from local storage and Firebase
  Future<void> initializeUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load from local storage using all possible keys for resilience
      _userEmail = prefs.getString('userEmail') ??
          prefs.getString('email') ??
          prefs.getString('user_mail') ??
          prefs.getString('registeredEmail');
          
      _userName = prefs.getString('userName') ?? prefs.getString('driverName');
      
      _vehicleModel = prefs.getString('vehicleModel') ?? 
          prefs.getString('carModel') ?? 
          prefs.getString('vehicle_model');
          
      // Check both naming conventions (vHeight/vehicleHeight)
      _vehicleHeight = prefs.getDouble('vehicleHeight') ?? prefs.getDouble('vHeight');
      _vehicleWidth = prefs.getDouble('vehicleWidth') ?? prefs.getDouble('vWidth');
      
      _driverExperience = prefs.getString('driverExperience') ?? prefs.getString('experience');
      _vehicleType = prefs.getString('vehicleType') ?? prefs.getString('vehicle_type');
      _alertSensitivity = prefs.getInt('alertSensitivity') ?? prefs.getInt('sensitivity');
      _audioVolume = prefs.getInt('audioVolume') ?? prefs.getInt('volume');

      // Attempt Cloud Recovery if email is missing but UID exists
      if (_userEmail == null || _userEmail!.isEmpty) {
        final storedUid = prefs.getString('userUid');
        if (storedUid != null && storedUid.isNotEmpty) {
          await _recoverUserByUid(storedUid, prefs);
        }
      }

      // Sync with Firebase if we have an identity
      if (_userEmail != null && _userEmail!.isNotEmpty) {
        await _syncWithCloud();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Initialization Error: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Recover user email from Firestore using the Firebase Auth UID
  Future<void> _recoverUserByUid(String uid, SharedPreferences prefs) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
          
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        _userEmail = doc.id; // Email is the document ID
        await prefs.setString('userEmail', _userEmail!);
        _cloudData = doc.data();
        _populateFromMap(_cloudData!);
      }
    } catch (e) {
      print('UID Recovery Failed: $e');
    }
  }

  /// Sync user data with Firebase Cloud document
  Future<void> _syncWithCloud() async {
    try {
      if (_userEmail == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userEmail)
          .get();

      if (doc.exists) {
        _cloudData = doc.data();
        if (_cloudData != null) {
          _populateFromMap(_cloudData!);
        }
      }
    } catch (e) {
      print('Cloud Sync Error: $e');
    }
  }

  /// Map Cloud Firestore fields to local Provider state
  void _populateFromMap(Map<String, dynamic> data) {
    if (data['name'] != null) _userName = data['name'];
    if (data['carModel'] != null) _vehicleModel = data['carModel'];
    if (data['email'] != null) _userEmail = data['email'];
    
    // Check Calibration Map
    final calibration = data['calibration'] as Map<String, dynamic>?;
    if (calibration != null) {
      if (calibration['height'] != null) _vehicleHeight = (calibration['height'] as num).toDouble();
      if (calibration['width'] != null) _vehicleWidth = (calibration['width'] as num).toDouble();
    }

    // Check Onboarding Map
    final onboarding = data['onboarding'] as Map<String, dynamic>?;
    if (onboarding != null) {
      if (onboarding['driverExperience'] != null) _driverExperience = onboarding['driverExperience'];
      if (onboarding['vehicleType'] != null) _vehicleType = onboarding['vehicleType'];
      if (onboarding['alertSensitivity'] != null) _alertSensitivity = onboarding['alertSensitivity'];
      if (onboarding['audioVolume'] != null) _audioVolume = onboarding['audioVolume'];
      
      // Fallback for dimensions if stored in onboarding map
      if (_vehicleHeight == null && onboarding['vehicleHeight'] != null) {
        _vehicleHeight = (onboarding['vehicleHeight'] as num).toDouble();
      }
      if (_vehicleWidth == null && onboarding['vehicleWidth'] != null) {
        _vehicleWidth = (onboarding['vehicleWidth'] as num).toDouble();
      }
    }
    
    // Check Top-level fallback for onboarding fields
    if (_driverExperience == null && data['experience'] != null) _driverExperience = data['experience'];
    if (_vehicleType == null && data['vehicleType'] != null) _vehicleType = data['vehicleType'];
  }

  /// Update user profile in both local and cloud storage
  Future<bool> updateUserProfile({
    String? name,
    String? experience,
    String? vehicleType,
    String? vehicleModel,
    double? vehicleHeight,
    double? vehicleWidth,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Update local state and SharedPreferences
      if (name != null) {
        _userName = name;
        await prefs.setString('userName', name);
      }
      if (experience != null) {
        _driverExperience = experience;
        await prefs.setString('driverExperience', experience);
      }
      if (vehicleType != null) {
        _vehicleType = vehicleType;
        await prefs.setString('vehicleType', vehicleType);
      }
      if (vehicleModel != null) {
        _vehicleModel = vehicleModel;
        await prefs.setString('carModel', vehicleModel);
      }
      if (vehicleHeight != null) {
        _vehicleHeight = vehicleHeight;
        await prefs.setDouble('vHeight', vehicleHeight);
      }
      if (vehicleWidth != null) {
        _vehicleWidth = vehicleWidth;
        await prefs.setDouble('vWidth', vehicleWidth);
      }

      // 2. Sync updates to Firebase Firestore
      if (_userEmail != null && _userEmail!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userEmail)
            .update({
          if (name != null) 'name': name,
          if (vehicleModel != null) 'carModel': vehicleModel,
          if (experience != null) 'experience': experience,
          if (vehicleType != null) 'vehicleType': vehicleType,
          if (vehicleHeight != null || vehicleWidth != null)
            'calibration': {
              if (vehicleHeight != null) 'height': vehicleHeight,
              if (vehicleWidth != null) 'width': vehicleWidth,
            },
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Update Failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Clear user data (logout)
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    _userName = null;
    _userEmail = null;
    _vehicleModel = null;
    _vehicleHeight = null;
    _vehicleWidth = null;
    _driverExperience = null;
    _vehicleType = null;
    _cloudData = null;

    // Clear all potential keys
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('carModel');
    await prefs.remove('vHeight');
    await prefs.remove('vWidth');
    await prefs.remove('driverExperience');
    await prefs.remove('vehicleType');
    await prefs.remove('userUid');
    
    notifyListeners();
  }
}
