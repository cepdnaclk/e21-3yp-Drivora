import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

/// Backend Service for Cloud Synchronization and Data Persistence
class BackendService {
  static const String baseUrl = 'https://drivora-api.herokuapp.com/api';
  // For local testing: 'http://192.168.x.x:5000/api'
  
  static String? _authToken;
  static String? _vehicleId;
  static final List<Map<String, dynamic>> _pendingQueue = [];

  /// Initialize backend service with authentication
  static Future<void> initialize(String token, String vehicleId) async {
    _authToken = token;
    _vehicleId = vehicleId;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('vehicle_id', vehicleId);
  }

  /// Restore initialization from stored preferences
  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    _vehicleId = prefs.getString('vehicle_id');
  }

  /// Check if backend is available
  static Future<bool> isBackendAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Backend unavailable: $e');
      return false;
    }
  }

  /// Save sensor data to cloud (with local fallback)
  static Future<bool> saveSensorData(SensorData data) async {
    if (_vehicleId == null || _authToken == null) {
      print('Warning: Not authenticated');
      await _saveToLocalQueue(data);
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sensors/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'vehicleId': _vehicleId,
          'speed': data.speed,
          'latitude': data.latitude,
          'longitude': data.longitude,
          'lanePosition': data.lanePosition,
          'tiltAngle': data.tiltAngle,
          'brakeActive': data.brakeActive,
          'leftSignal': data.leftSignal,
          'rightSignal': data.rightSignal,
          'safetyScore': data.safetyScore,
          'dataSource': data.dataSource,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        print('✓ Sensor data saved to cloud');
        return true;
      } else {
        print('✗ Cloud save failed (${response.statusCode})');
        await _saveToLocalQueue(data);
        return false;
      }
    } catch (e) {
      print('✗ Error saving sensor data: $e');
      await _saveToLocalQueue(data);
      return false;
    }
  }

  /// Save alert to cloud
  static Future<bool> saveAlert(String type, String severity, String message) async {
    if (_vehicleId == null || _authToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'vehicleId': _vehicleId,
          'type': type,
          'severity': severity,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 201;
    } catch (e) {
      print('Error saving alert: $e');
      return false;
    }
  }

  /// Get real-time sensor data from cloud
  static Future<Map<String, dynamic>?> getRealtimeData() async {
    if (_vehicleId == null || _authToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sensors/realtime/$_vehicleId'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching realtime data: $e');
      return null;
    }
  }

  /// Get sensor data history
  static Future<List<SensorData>?> getSensorHistory({
    int limit = 100,
    int skip = 0,
  }) async {
    if (_vehicleId == null || _authToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sensors/history/$_vehicleId?limit=$limit&skip=$skip'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> sensorList = data['data'] ?? [];
        
        return sensorList
            .map((item) => SensorData.fromJson(item))
            .toList();
      }
      return null;
    } catch (e) {
      print('Error fetching sensor history: $e');
      return null;
    }
  }

  /// Get vehicle alerts
  static Future<List<Map<String, dynamic>>?> getAlerts({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    if (_vehicleId == null || _authToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/alerts/$_vehicleId?limit=$limit&unread=$unreadOnly'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return null;
    } catch (e) {
      print('Error fetching alerts: $e');
      return null;
    }
  }

  /// Start a new driving session
  static Future<String?> startDrivingSession() async {
    if (_vehicleId == null || _authToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sessions/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'vehicleId': _vehicleId,
          'startTime': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data']['_id'];
      }
      return null;
    } catch (e) {
      print('Error starting session: $e');
      return null;
    }
  }

  /// End driving session
  static Future<bool> endDrivingSession(
    String sessionId, {
    required double distance,
    required double avgSpeed,
    required double maxSpeed,
    required double safetyScore,
    required int alertsTriggered,
  }) async {
    if (_vehicleId == null || _authToken == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/sessions/end/$sessionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'endTime': DateTime.now().toIso8601String(),
          'distance': distance,
          'avgSpeed': avgSpeed,
          'maxSpeed': maxSpeed,
          'safetyScore': safetyScore,
          'alertsTriggered': alertsTriggered,
        }),
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Error ending session: $e');
      return false;
    }
  }

  /// Get driving session history
  static Future<List<Map<String, dynamic>>?> getSessionHistory({
    int limit = 20,
  }) async {
    if (_vehicleId == null || _authToken == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sessions/$_vehicleId?limit=$limit'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }
      return null;
    } catch (e) {
      print('Error fetching session history: $e');
      return null;
    }
  }

  // ===== LOCAL PERSISTENCE =====

  /// Save data to local queue for offline mode
  static Future<void> _saveToLocalQueue(SensorData data) async {
    _pendingQueue.add({
      'type': 'sensor_data',
      'timestamp': DateTime.now().toIso8601String(),
      'data': {
        'speed': data.speed,
        'latitude': data.latitude,
        'longitude': data.longitude,
        'lanePosition': data.lanePosition,
        'tiltAngle': data.tiltAngle,
        'brakeActive': data.brakeActive,
        'leftSignal': data.leftSignal,
        'rightSignal': data.rightSignal,
        'safetyScore': data.safetyScore,
        'dataSource': data.dataSource,
      },
    });

    // Keep only last 1000 items
    if (_pendingQueue.length > 1000) {
      _pendingQueue.removeAt(0);
    }

    // Save to SharedPreferences
    await _persistQueueToStorage();
  }

  /// Persist pending queue to local storage
  static Future<void> _persistQueueToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_pendingQueue);
      await prefs.setString('pending_queue', queueJson);
    } catch (e) {
      print('Error persisting queue: $e');
    }
  }

  /// Load pending queue from local storage
  static Future<void> loadPendingQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('pending_queue');
      
      if (queueJson != null) {
        final queue = jsonDecode(queueJson);
        _pendingQueue.addAll(List<Map<String, dynamic>>.from(queue));
      }
    } catch (e) {
      print('Error loading pending queue: $e');
    }
  }

  /// Sync pending queue with cloud
  static Future<void> syncPendingQueue() async {
    if (_pendingQueue.isEmpty || _authToken == null) return;

    print('Syncing ${_pendingQueue.length} pending items...');

    final itemsToRemove = <Map<String, dynamic>>[];

    for (var item in _pendingQueue) {
      try {
        if (item['type'] == 'sensor_data') {
          final response = await http.post(
            Uri.parse('$baseUrl/sensors/save'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
            body: jsonEncode({
              'vehicleId': _vehicleId,
              ...item['data'],
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 201) {
            itemsToRemove.add(item);
          }
        }
      } catch (e) {
        print('Error syncing item: $e');
      }
    }

    // Remove synced items
    for (var item in itemsToRemove) {
      _pendingQueue.remove(item);
    }

    // Update storage
    await _persistQueueToStorage();
    print('✓ Synced ${itemsToRemove.length} items');
  }

  /// Get pending queue count
  static int getPendingQueueCount() => _pendingQueue.length;

  /// Clear pending queue
  static Future<void> clearPendingQueue() async {
    _pendingQueue.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_queue');
  }

  /// Get local storage stats
  static Future<Map<String, dynamic>> getStorageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    int totalBytes = 0;
    for (var key in keys) {
      final value = prefs.get(key);
      if (value is String) {
        totalBytes += value.length;
      }
    }

    return {
      'total_keys': keys.length,
      'total_bytes': totalBytes,
      'pending_queue_size': _pendingQueue.length,
      'auth_token_stored': prefs.containsKey('auth_token'),
      'vehicle_id_stored': prefs.containsKey('vehicle_id'),
    };
  }

  /// Logout and clear all data
  static Future<void> logout() async {
    _authToken = null;
    _vehicleId = null;
    _pendingQueue.clear();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
