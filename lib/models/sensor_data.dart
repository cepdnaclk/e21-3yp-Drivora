enum AlertType { info, warning, danger, critical }
enum AlertSeverity { low, medium, high, critical }

class Alert {
  final String title;
  final String message;
  final AlertType type;
  final DateTime timestamp;

  Alert({
    required this.title,
    required this.message,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SensorData {
  final double speed; // km/h
  final double battery; // percentage
  final double temperature; // °C
  final double rpm; // revolutions per minute
  final double heading; // degrees 0-360
  final double latitude;
  final double longitude;
  final bool engineStatus;
  final bool leftSignal;
  final bool rightSignal;
  final bool brakeStatus;
  final double fuelLevel; // percentage
  final double oilPressure; // PSI
  final double acceleration; // m/s²
  final double rollAngle; // degrees
  final double pitchAngle; // degrees
  final double tirePressureFL; // PSI
  final double tirePressureFR; // PSI
  final double tirePressureRL; // PSI
  final double tirePressureRR; // PSI
  final double steeringAngle; // degrees
  final DateTime timestamp;

  SensorData({
    required this.speed,
    required this.battery,
    required this.temperature,
    required this.rpm,
    required this.heading,
    required this.latitude,
    required this.longitude,
    required this.engineStatus,
    required this.leftSignal,
    required this.rightSignal,
    required this.brakeStatus,
    required this.fuelLevel,
    this.oilPressure = 0.0,
    this.acceleration = 0.0,
    this.rollAngle = 0.0,
    this.pitchAngle = 0.0,
    this.tirePressureFL = 32,
    this.tirePressureFR = 32,
    this.tirePressureRL = 32,
    this.tirePressureRR = 32,
    this.steeringAngle = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      speed: (json['speed'] ?? 0).toDouble(),
      battery: (json['battery'] ?? 100).toDouble(),
      temperature: (json['temperature'] ?? 20).toDouble(),
      rpm: (json['rpm'] ?? 0).toDouble(),
      heading: (json['heading'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? 6.9271).toDouble(),
      longitude: (json['longitude'] ?? 80.7789).toDouble(),
      engineStatus: json['engineStatus'] ?? false,
      leftSignal: json['leftSignal'] ?? false,
      rightSignal: json['rightSignal'] ?? false,
      brakeStatus: json['brakeStatus'] ?? false,
      fuelLevel: (json['fuelLevel'] ?? 100).toDouble(),
      oilPressure: (json['oilPressure'] ?? 0).toDouble(),
      acceleration: (json['acceleration'] ?? 0).toDouble(),
      rollAngle: (json['rollAngle'] ?? 0).toDouble(),
      pitchAngle: (json['pitchAngle'] ?? 0).toDouble(),
      tirePressureFL: (json['tpFL'] ?? 32).toDouble(),
      tirePressureFR: (json['tpFR'] ?? 32).toDouble(),
      tirePressureRL: (json['tpRL'] ?? 32).toDouble(),
      tirePressureRR: (json['tpRR'] ?? 32).toDouble(),
      steeringAngle: (json['steering'] ?? 0).toDouble(),
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speed': speed,
      'battery': battery,
      'temperature': temperature,
      'rpm': rpm,
      'heading': heading,
      'latitude': latitude,
      'longitude': longitude,
      'engineStatus': engineStatus,
      'leftSignal': leftSignal,
      'rightSignal': rightSignal,
      'brakeStatus': brakeStatus,
      'fuelLevel': fuelLevel,
      'oilPressure': oilPressure,
      'acceleration': acceleration,
      'rollAngle': rollAngle,
      'pitchAngle': pitchAngle,
      'tpFL': tirePressureFL,
      'tpFR': tirePressureFR,
      'tpRL': tirePressureRL,
      'tpRR': tirePressureRR,
      'steering': steeringAngle,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TripData {
  final double distance;
  final Duration duration;
  final double averageSpeed;
  final double maxSpeed;
  final double fuelConsumed;
  final int alertCount;
  final DateTime startTime;
  final DateTime endTime;

  TripData({
    required this.distance,
    required this.duration,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.fuelConsumed,
    required this.alertCount,
    required this.startTime,
    required this.endTime,
  });
}
