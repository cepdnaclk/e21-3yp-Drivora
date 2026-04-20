import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';

class WiFiSensorService extends ChangeNotifier {
  static const int DEFAULT_PORT = 5005;
  
  SensorData? _currentData;
  bool _isConnected = false;
  bool _isSimulating = false;
  String _connectionStatus = 'Ready for connection';
  final List<SensorData> _dataHistory = [];
  final List<Alert> _alerts = [];
  
  StreamSubscription? _simulationSubscription;
  final StreamController<SensorData> _dataController = StreamController<SensorData>.broadcast();

  SensorData? get currentData => _currentData;
  bool get isConnected => _isConnected;
  bool get isSimulating => _isSimulating;
  String get connectionStatus => _connectionStatus;
  List<SensorData> get dataHistory => _dataHistory;
  List<Alert> get alerts => _alerts;
  Stream<SensorData> get dataStream => _dataController.stream;

  Future<void> initialize() async {
    try {
      _connectionStatus = 'Initialized - tap "Start Simulation" or connect device';
      _isConnected = false;
      notifyListeners();
    } catch (e) {
      _connectionStatus = 'Initialization: $e';
      notifyListeners();
    }
  }

  void _checkForAlerts(SensorData data) {
    // Speed alert
    if (data.speed > 120) {
      _addAlert(Alert(
        title: 'High Speed Warning',
        message: 'Current speed: ${data.speed.toStringAsFixed(1)} km/h',
        type: AlertType.warning,
      ));
    }

    // Battery alert
    if (data.battery < 20) {
      _addAlert(Alert(
        title: 'Low Battery Alert',
        message: 'Battery level: ${data.battery.toStringAsFixed(1)}%',
        type: AlertType.danger,
      ));
    }

    // Temperature alert
    if (data.temperature > 100) {
      _addAlert(Alert(
        title: 'High Temperature',
        message: 'Engine temp: ${data.temperature.toStringAsFixed(1)}°C',
        type: AlertType.danger,
      ));
    }

    // Low fuel alert
    if (data.fuelLevel < 15) {
      _addAlert(Alert(
        title: 'Low Fuel Level',
        message: 'Fuel: ${data.fuelLevel.toStringAsFixed(1)}%',
        type: AlertType.warning,
      ));
    }
  }

  void _addAlert(Alert alert) {
    _alerts.add(alert);
    if (_alerts.length > 50) {
      _alerts.removeAt(0);
    }
    notifyListeners();
  }

  void simulateData() {
    if (_isSimulating) {
      debugPrint('Simulation already running');
      return;
    }

    _isSimulating = true;
    _isConnected = true;
    _connectionStatus = 'Simulation Mode Active';
    notifyListeners();

    _simulationSubscription?.cancel();
    _simulationSubscription = Stream.periodic(
      const Duration(milliseconds: 500),
      (count) => count,
    ).listen((count) {
      // Generate realistic variations
      final random = math.Random();
      final baseSpeed = 45.0 + (random.nextDouble() * 40);
      final speedVariation = math.sin(count * 0.05) * 10;
      
      final sensorData = SensorData(
        speed: (baseSpeed + speedVariation).clamp(0, 150).toDouble(),
        battery: (80 + (random.nextDouble() * 15) - (count * 0.01)).clamp(10, 100).toDouble(),
        temperature: (85 + (random.nextDouble() * 20)).clamp(60, 110).toDouble(),
        rpm: (2000 + (random.nextDouble() * 3500)).clamp(0, 7000).toDouble(),
        heading: (count * 2.5 % 360).toDouble(),
        latitude: 6.9271 + (random.nextDouble() * 0.02 - 0.01),
        longitude: 80.7789 + (random.nextDouble() * 0.02 - 0.01),
        engineStatus: true,
        leftSignal: count % 30 < 10,
        rightSignal: count % 40 > 20,
        brakeStatus: count % 50 > 40,
        fuelLevel: (70 - (count * 0.002)).clamp(10, 100).toDouble(),
        timestamp: DateTime.now(),
      );
      
      _currentData = sensorData;
      _dataHistory.add(sensorData);
      
      if (_dataHistory.length > 1000) {
        _dataHistory.removeAt(0);
      }
      
      _dataController.add(sensorData);
      _checkForAlerts(sensorData);
      notifyListeners();
    });
  }

  Future<void> stopSimulation() async {
    _simulationSubscription?.cancel();
    _isSimulating = false;
    _isConnected = false;
    _connectionStatus = 'Simulation stopped';
    notifyListeners();
  }

  Future<void> connectToDevice(String ipAddress) async {
    try {
      _connectionStatus = 'Connecting to $ipAddress...';
      notifyListeners();
      
      // Simulate connection for demo
      await Future.delayed(const Duration(seconds: 2));
      _connectionStatus = 'Connected to $ipAddress';
      _isConnected = true;
      notifyListeners();
      
      debugPrint('Connected to device at $ipAddress');
    } catch (e) {
      _connectionStatus = 'Connection failed: $e';
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    try {
      _simulationSubscription?.cancel();
      _isConnected = false;
      _isSimulating = false;
      _connectionStatus = 'Disconnected';
      _currentData = null;
      notifyListeners();
    } catch (e) {
      _connectionStatus = 'Error disconnecting: $e';
      notifyListeners();
    }
  }

  List<Alert> getRecentAlerts({int limit = 5}) {
    return _alerts.reversed.take(limit).toList();
  }

  void clearAlerts() {
    _alerts.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _simulationSubscription?.cancel();
    _dataController.close();
    disconnect();
    super.dispose();
  }
}
