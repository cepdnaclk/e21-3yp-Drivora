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
  bool get isUserRegistered =>
      (_userEmail != null && _userEmail!.isNotEmpty) ||
      (_userName != null && _userName!.isNotEmpty) ||
      (_vehicleModel != null && _vehicleModel!.isNotEmpty);

  /// Initialize user data from local storage and Firebase
  Future<void> initializeUser() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _userEmail = prefs.getString('userEmail') ?? prefs.getString('email');
      _userName = prefs.getString('userName') ?? prefs.getString('driverName');
      _vehicleModel = prefs.getString('vehicleModel') ?? prefs.getString('carModel');
      _vehicleHeight = prefs.getDouble('vehicleHeight') ?? prefs.getDouble('vHeight');
      _vehicleWidth = prefs.getDouble('vehicleWidth') ?? prefs.getDouble('vWidth');
      _driverExperience = prefs.getString('driverExperience');
      _vehicleType = prefs.getString('vehicleType');
      _alertSensitivity = prefs.getInt('alertSensitivity');
      _audioVolume = prefs.getInt('audioVolume');

      if (_userEmail != null && _userEmail!.isNotEmpty) {
        await _syncWithCloud();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize user: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sync user data with Firebase Cloud
  Future<void> _syncWithCloud() async {
    try {
      if (_userEmail == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userEmail)
          .get();

      if (doc.exists) {
        _cloudData = doc.data();
        
        // Update local variables from cloud data if available
        final data = _cloudData!;
        if (data['name'] != null) _userName = data['name'];
        if (data['carModel'] != null) _vehicleModel = data['carModel'];
        
        final calibration = data['calibration'] as Map<String, dynamic>?;
        if (calibration != null) {
          if (calibration['height'] != null) _vehicleHeight = calibration['height'];
          if (calibration['width'] != null) _vehicleWidth = calibration['width'];
        }

        final onboarding = data['onboarding'] as Map<String, dynamic>?;
        if (onboarding != null) {
          if (onboarding['driverExperience'] != null) _driverExperience = onboarding['driverExperience'];
          if (onboarding['vehicleType'] != null) _vehicleType = onboarding['vehicleType'];
          if (onboarding['alertSensitivity'] != null) _alertSensitivity = onboarding['alertSensitivity'];
          if (onboarding['audioVolume'] != null) _audioVolume = onboarding['audioVolume'];
        }
      }
    } catch (e) {
      print('Cloud sync error: $e');
    }
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

      // Update local storage
      if (name != null) {
        _userName = name;
        await prefs.setString('userName', name);
        await prefs.setString('driverName', name);
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
        await prefs.setString('vehicleModel', vehicleModel);
        await prefs.setString('carModel', vehicleModel);
      }
      if (vehicleHeight != null) {
        _vehicleHeight = vehicleHeight;
        await prefs.setDouble('vehicleHeight', vehicleHeight);
      }
      if (vehicleWidth != null) {
        _vehicleWidth = vehicleWidth;
        await prefs.setDouble('vehicleWidth', vehicleWidth);
      }

      // Update Firebase if email exists
      if (_userEmail != null && _userEmail!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userEmail)
            .update({
          if (name != null) 'name': name,
          if (vehicleModel != null) 'carModel': vehicleModel,
          if (vehicleHeight != null || vehicleWidth != null)
            'calibration': {
              if (vehicleHeight != null) 'height': vehicleHeight,
              if (vehicleWidth != null) 'width': vehicleWidth,
            },
          if (experience != null ||
              vehicleType != null ||
              vehicleModel != null)
            'onboarding': {
              if (experience != null) 'driverExperience': experience,
              if (vehicleType != null) 'vehicleType': vehicleType,
              if (vehicleModel != null) 'vehicleModel': vehicleModel,
            },
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update profile: $e';
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

    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('vehicleModel');
    await prefs.remove('carModel');
    
    notifyListeners();
  }
}
