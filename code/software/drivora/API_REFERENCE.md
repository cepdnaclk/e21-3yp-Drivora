# DRIVORA API Reference & Developer Guide

## Audio Service API

### Classes & Enums

#### AlertType Enum
```dart
enum AlertType {
  collision,        // Emergency collision warning
  laneWarning,      // Lane departure alert
  obstacleProx,     // Rear obstacle proximity
  drowsiness,       // Drowsiness/lean warning
  info,             // General information
  systemAlert,      // System health alert
  calibration,      // Calibration success
}
```

### AudioService Class

#### Constructor
```dart
AudioService()
```
Initializes audio player and release mode.

#### Methods

##### Play Alert Sounds
```dart
// Front collision - emergency siren pattern
Future<void> playCollisionAlert()

// Lane departure - repeating alert beeps
Future<void> playLaneWarning()

// Rear obstacle - progressive beep system
Future<void> playObstacleProximity({double distanceCm = 300})

// Drowsiness/lean - strong repeating alert
Future<void> playDrowsinessAlert()

// General alert sound
Future<void> playGeneralAlert()

// System health alert
Future<void> playSystemAlert()

// Calibration success - ascending tones
Future<void> playCalibrationSuccess()
```

##### Control Audio
```dart
// Stop all audio and timers
Future<void> stopAll()

// Enable/disable audio playback
void setEnabled(bool enabled)

// Check if audio is playing
bool get isPlayingAlert

// Get current alert type
AlertType? get currentAlertType
```

##### Cleanup
```dart
// Dispose resources when done
void dispose()
```

---

## WiFiSensorService API

### WiFiSensorService Class (extends ChangeNotifier)

#### Getters
```dart
// Current sensor data
DrivoraSensorData get currentData

// Connection status
bool get isConnected

// Status message
String get status

// Active alerts list
List<SafetyAlert> get activeAlerts

// Sensor data history (max 500 items)
List<DrivoraSensorData> get dataHistory

// Audio enabled status
bool get audioEnabled
```

#### Methods

##### Initialization
```dart
// Initialize service
Future<void> initialize()

// Set audio enabled/disabled
void setAudioEnabled(bool enabled)
```

##### Connection Management
```dart
// Connect to hardware hub
void connectToHardwareHub(String ipAddress)
  // Example: connectToHardwareHub('192.168.4.1')

// Disconnect all streams
void stopAllStreams()

// Toggle connection
void toggleSafetyShield()
```

##### Hardware Communication
```dart
// Send calibration data to hardware
Future<void> sendCalibrationToHardware({
  required double height,
  required double width,
  String? ipAddress,
})

// Example:
await service.sendCalibrationToHardware(
  height: 1.57,
  width: 1.56,
  ipAddress: '192.168.4.1',
)
```

##### Alert Management
```dart
// Clear all active alerts
void clearAlerts()
```

---

## DrivoraSensorData Model

### Properties (Read-only)

#### Front Unit (Collision Warning)
```dart
int frontState              // 0=CLEAR, 1=OBJECT, 2=APPROACH, 3=WARNING
String frontStateName       // Human readable state
Color frontStateColor       // Color for UI
double frontDistance        // Distance in cm (-1 if invalid)
double closingSpeed         // Speed in cm/s
bool frontOnline            // Unit is online
```

#### Center Unit (Lean Monitor)
```dart
int leanRiskLevel           // 0=SAFE, 1=CAUTION, 2=HIGH
String leanRiskName         // Human readable risk
double roll                 // Vehicle roll in degrees
double pitch                // Vehicle pitch in degrees
double confidence           // Confidence level (0-1)
bool leanOnline             // Unit is online
bool leanCalibrated         // Calibration status
double criticalRollDeg      // Critical threshold
double criticalPitchDeg     // Critical threshold
```

#### Rear Unit (Blindspot Monitor)
```dart
int rearState               // 0=CLEAR, 1=DETECTED, 2=CAUTION, 3=WARNING
String rearStateName        // Human readable state
Color rearStateColor        // Color for UI
double rearDistance         // Distance in cm
bool rearOnline             // Unit is online
```

#### Lane Unit (Lane Departure Warning)
```dart
int laneState               // 0=SAFE, 1=LEFT, 2=RIGHT
String laneStateName        // Human readable state
Color laneStateColor        // Color for UI
bool laneOnline             // Unit is online
```

#### Derived Properties
```dart
double speed                // Current speed (cm/s)
bool brakeActive            // Brake warning active
bool ldwActive              // Lane warning active
double ttc                  // Time to collision
double tiltAngle            // Alias for roll
bool unitAOnline            // Alias for frontOnline
bool unitBOnline            // Alias for rearOnline
bool unitCOnline            // Alias for leanOnline
bool unitDOnline            // Alias for laneOnline
```

---

## SafetyAlert Model

### Properties
```dart
String title                // Alert title
String message              // Alert message
AlertSeverity severity      // Severity level
String unitSource           // Sensor unit (RADAR, REAR, COG, VISION)
DateTime timestamp          // When alert occurred
```

### AlertSeverity Enum
```dart
enum AlertSeverity {
  info,                     // Informational
  warning,                  // Warning level
  danger,                   // Danger level
  critical,                 // Critical alert
}
```

---

## Usage Examples

### Example 1: Basic Setup
```dart
import 'package:provider/provider.dart';
import 'services/wifi_sensor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WiFiSensorService()..initialize(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}
```

### Example 2: Monitor Sensor Data
```dart
class MySensorWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, service, _) {
        final data = service.currentData;
        
        return Column(
          children: [
            Text('Front: ${data.frontDistance} cm'),
            Text('Lean: ${data.roll}°'),
            Text('Connection: ${service.isConnected ? "ONLINE" : "OFFLINE"}'),
          ],
        );
      },
    );
  }
}
```

### Example 3: Display Alerts
```dart
class AlertWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, service, _) {
        final alerts = service.activeAlerts;
        
        if (alerts.isEmpty) {
          return Text('All Systems Safe');
        }
        
        return ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return Card(
              title: Text(alert.title),
              subtitle: Text(alert.message),
              trailing: Icon(
                Icons.warning,
                color: _getSeverityColor(alert.severity),
              ),
            );
          },
        );
      },
    );
  }
  
  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical: return Colors.red;
      case AlertSeverity.danger: return Colors.orange;
      case AlertSeverity.warning: return Colors.yellow;
      case AlertSeverity.info: return Colors.blue;
    }
  }
}
```

### Example 4: Connect to Hardware
```dart
class ConnectScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, service, _) {
        return ElevatedButton(
          onPressed: () {
            // Connect to ESP32 hardware
            service.connectToHardwareHub('192.168.4.1');
          },
          child: Text(
            service.isConnected ? 'Disconnect' : 'Connect',
          ),
        );
      },
    );
  }
}
```

### Example 5: Send Calibration Data
```dart
Future<void> calibrateVehicle(BuildContext context) async {
  final service = Provider.of<WiFiSensorService>(context, listen: false);
  
  await service.sendCalibrationToHardware(
    height: 1.57,    // Vehicle height in meters
    width: 1.56,     // Vehicle width in meters
    ipAddress: '192.168.4.1',
  );
  
  // Show feedback
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Calibration sent')),
  );
}
```

### Example 6: Control Audio Alerts
```dart
class AudioControlWidget extends StatefulWidget {
  @override
  State<AudioControlWidget> createState() => _AudioControlWidgetState();
}

class _AudioControlWidgetState extends State<AudioControlWidget> {
  bool audioEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<WiFiSensorService>(
      builder: (context, service, _) {
        return Switch(
          value: audioEnabled,
          onChanged: (value) {
            setState(() => audioEnabled = value);
            service.setAudioEnabled(value);
          },
        );
      },
    );
  }
}
```

---

## State Management Pattern

### Using Provider Pattern
```dart
// In your widget
Consumer<WiFiSensorService>(
  builder: (context, sensorService, _) {
    // Automatically rebuilds when data changes
    return YourWidget(data: sensorService.currentData);
  },
)
```

### Without Consumer (Manual Listening)
```dart
@override
void initState() {
  super.initState();
  final service = Provider.of<WiFiSensorService>(
    context,
    listen: false,
  );
  // Manually access data
  print(service.currentData.frontDistance);
}
```

---

## Error Handling

### Connection Errors
```dart
// Monitor status for errors
Consumer<WiFiSensorService>(
  builder: (context, service, _) {
    if (service.status.contains('Error')) {
      return ErrorWidget(message: service.status);
    }
    return YourWidget();
  },
)
```

### Alert Errors
```dart
// Validate alert data before using
final alerts = service.activeAlerts;
if (alerts.isNotEmpty) {
  final alert = alerts.first;
  
  // Check severity
  if (alert.severity == AlertSeverity.critical) {
    // Handle critical alert
  }
}
```

---

## Performance Tips

1. **Use Consumer Wisely**
   - Only wrap widgets that need to update
   - Avoid rebuilding entire screen

2. **Data Limits**
   - History is capped at 500 items
   - Older items auto-removed

3. **WebSocket**
   - Connection is persistent
   - Reconnects automatically on failure

4. **Memory**
   - Dispose resources when done
   - audioService.dispose() on cleanup

---

## Debugging

### Enable Detailed Logging
```dart
// In WiFiSensorService
debugPrint('WS Decode Error: $e');
debugPrint('Handshake Success');
```

### Check Connection Status
```dart
print(service.status);  // Connection status message
print(service.isConnected);  // Boolean
```

### Monitor Audio
```dart
print(service.audioEnabled);
```

---

## Thread Safety

The service is designed to be thread-safe:
- ChangeNotifier handles UI updates
- WebSocket runs on separate thread
- SharedPreferences is atomic

---

## Version Compatibility

- **Min Flutter:** 3.0.0
- **Min Dart:** 3.0.0
- **Android:** SDK 21+
- **iOS:** 11.0+

---

**Last Updated:** May 25, 2026  
**Version:** 1.0.0
