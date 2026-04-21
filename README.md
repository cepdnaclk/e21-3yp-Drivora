<<<<<<< HEAD
# DRIVORA - Advanced Flutter Driver Assistant with WiFi Sensor Integration

## Project Overview

DRIVORA is a sophisticated driver assistance system built entirely with Flutter, designed to monitor vehicle sensors via wireless WiFi connectivity and provide real-time analytics with an attractive 3D visualization interface.

## Features Completed

### ✅ Core Architecture
- **Flutter-Only**: Removed all native Android and iOS code
- **Clean Separation**: Dedicated services, models, screens, widgets, and themes
- **State Management**: Provider pattern for efficient data flow
- **Real-time Updates**: Stream-based sensor data delivery

### ✅ WiFi Sensor Integration
- **WiFiSensorService**: Complete service for WiFi connectivity management
- **Real-time Data Streaming**: Continuous sensor data collection with configurable intervals
- **Alert System**: Automatic alert generation for anomalies (high speed, low fuel, high temp, etc.)
- **Data History**: Maintains up to 1000 historical data points
- **Simulation Mode**: Built-in realistic data simulation for testing

### ✅ Sensor Data Monitoring
Comprehensive sensor tracking including:
- **Engine**: Speed (km/h), RPM, Temperature (°C), Oil Pressure (PSI)
- **Fuel**: Level percentage
- **Battery**: System charge level
- **Dynamics**: Acceleration (m/s²), Roll Angle, Pitch Angle, Steering Angle
- **Tires**: Individual pressure monitoring (FL, FR, RL, RR)
- **Signals**: Turn signals (left/right), Brake status

### ✅ Beautiful 3D Car Visualization
- **Custom 3D Painter**: Top-view perspective car with realistic design
- **Dynamic Updates**: Real-time steering angle and brake visualization
- **Status Indicators**: Headlights, brake lights, turn signals
- **Animated Wheels**: Rotating wheel animation synchronized with speed
- **Responsive Design**: Grid background with scaling animations

### ✅ Attractive UI with Modern Dark Theme
- **Glassmorphism Ready**: With gradient overlays and blur effects
- **Neon Colors**: Cyan primary, purple secondary with status colors
- **Consistent Typography**: Google Fonts integration (Roboto family)
- **Status Colors**: Success (green), Warning (orange), Danger (red), Info (blue)
- **Smooth Animations**: Glow effects and transition animations

### ✅ Complete Dashboard
- **3D Car Visualization**: Real-time vehicle status display
- **Stats Grid**: 4-card layout showing RPM, Temperature, Fuel, Battery
- **Vehicle Status Panel**: Engine, Brake, and Signal indicators
- **Tire Pressure Monitor**: All 4 wheels with color-coded pressure levels
- **WiFi Connection Panel**: Online/offline status and connection controls
- **Start/Stop Simulation**: One-click simulation controls

### ✅ Additional Screens
- **Alerts Screen**: Real-time alerts with timestamps and severity indicators
- **Analytics Screen**: Speed and temperature analysis with statistics
- **Settings Screen**: WiFi configuration, notifications, preferences
- **Bottom Navigation**: Easy navigation between all screens

## Project Structure

```
drivora/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── sensor_data.dart     # Enhanced sensor data models
│   ├── services/
│   │   └── wifi_sensor_service.dart  # WiFi connectivity & data
│   ├── screens/
│   │   ├── dashboard_screen.dart
│   │   ├── alerts_screen.dart
│   │   ├── analytics_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   └── car_3d_visualization.dart  # 3D car widget
│   └── theme/
│       ├── app_theme.dart       # Material theme
│       └── app_colors.dart      # Color constants
├── assets/
│   ├── images/
│   └── animations/
├── pubspec.yaml                 # Dependencies
└── analysis_options.yaml        # Lint rules
```

## Dependencies

Core packages used:
- **flutter**: Core framework
- **provider**: State management
- **connectivity_plus**: WiFi status monitoring
- **permission_handler**: System permissions
- **shared_preferences**: Local data persistence
- **fl_chart**: Charts and analytics
- **google_fonts**: Typography
- **glassmorphism**: UI effects
- **animations**: Smooth transitions

## Getting Started

### 1. Install Flutter
```bash
flutter --version
```

### 2. Get Dependencies
```bash
cd drivora
flutter pub get
```

### 3. Run the App
```bash
# For development
flutter run

# For release
flutter run --release

# Specific device
flutter run -d <device_id>
```

### 4. Start Simulation
- Tap "Start Sim" button in the WiFi Connection panel
- Watch real-time sensor data updates
- Monitor alerts in real-time
- View analytics and statistics

## Real WiFi Integration

The WiFiSensorService is ready for real WiFi sensor data integration:

```dart
// Connect to actual WiFi sensor device
await sensorService.connectToDevice('192.168.1.100');

// Implement WiFi socket communication in connectToDevice() method
// Parse incoming JSON sensor data using SensorData.fromJson()
```

## Customization

### Add New Sensors
1. Update `SensorData` model in `lib/models/sensor_data.dart`
2. Add collection logic to `WiFiSensorService`
3. Create display widget in dashboard or analytics

### Modify Alert Thresholds
Edit `_checkForAlerts()` in `WiFiSensorService`:
```dart
if (data.speed > 150) {  // Change threshold
  _addAlert(...);
}
```

### Change Color Scheme
Update `AppTheme` and `AppColors` classes for new theme

## Performance Considerations

- **Data History Limit**: Maintains max 1000 data points to prevent memory overflow
- **Update Interval**: 500ms (2Hz) configurable in WiFiSensorService
- **Efficient Rendering**: Uses CustomPaint for 3D visualization
- **Stream Management**: Proper disposal of streams and controllers

## Future Enhancements

1. **Real WiFi Socket**: Implement actual socket communication
2. **Database**: SQLite for persistent trip history
3. **Maps Integration**: Route tracking and visualization
4. **Cloud Sync**: Firebase integration for cloud backup
5. **Multi-Device**: Support multiple sensor units
6. **ML Analytics**: Predictive maintenance alerts
7. **Voice Commands**: Voice-controlled navigation
8. **Export Features**: Trip report generation (PDF)

## Troubleshooting

### App Won't Start
```bash
flutter clean
flutter pub get
flutter run
```

### High Battery Usage
- Check simulation frequency in WiFiSensorService
- Increase update interval in DEFAULT_PORT configuration

### No Data Appearing
- Verify WiFi connection in settings
- Check permissions (location, WiFi access)
- Start simulation mode for testing

## License

This project is licensed under the MIT License.

## Support

For issues or feature requests, contact the development team.

---

**Version**: 1.0.0  
**Build**: 001  
**Platform**: Flutter (iOS, Android, Web)  
**Minimum SDK**: Flutter 3.0.0
=======
# Drivora: Distributed Universal Advanced Driver Assistance System (U-ADAS)

**Drivora** is a comprehensive, distributed retrofit safety platform designed to modernize legacy passenger vehicles and enhance the safety of heavy commercial transport. Unlike traditional integrated factory systems, Drivora utilizes a multi-unit hardware suite that communicates over a robust **CAN-Bus backbone**, creating a "Safety Shield" around the vehicle.

## Key Features
* **Forward Collision Warning (FCW):** Utilizes dual 24GHz Doppler radar to calculate Time-to-Collision (TTC) and alert drivers of imminent frontal impacts.
* **Side & Rear Safety:** A distributed three-sensor array monitors blind spots during lane changes and provides Rear-Cross Traffic alerts while reversing.
* **Lane Departure Warning (LDW):** An AI-vision system powered by the ESP32-S3 and an OV2640 camera to identify road markings and warn of unintentional drifting.
* **Dynamics & Rollover Monitoring (COG):** Real-time tracking of the vehicle's Center of Gravity, lateral G-forces, and tilt angles to prevent rollovers.

## Hardware Architecture
The system is decentralized into four core units to ensure high-performance processing and ease of installation:

| Unit | Hardware Components | Primary Function |
| :--- | :--- | :--- |
| **Unit A: Front Radar Array** | ESP32-C3, 2x CDM324 Radar, LM358 Amp | Monitors the forward path and "cut-in" maneuvers. |
| **Unit B: Rear Safety Hub** | ESP32-C3, 3x JSN-SR04T Ultrasonic | Provides blind-spot monitoring and reverse path protection. |
| **Unit C: COG & Dynamics** | ESP32-C3, BNO055 (9-Axis IMU) | Tracks vehicle stability and suspension health from the chassis center. |
| **Unit D: Windshield Hub** | ESP32-S3 (8MB PSRAM), OV2640 Cam | The "Brain" of the system; handles AI-vision and smartphone data streaming. |

## Smartphone HMI & Cloud Connectivity
* **Wireless Dashboard:** All safety alerts, distance data, and stability scores are streamed in real-time to a smartphone-mounted display via Bluetooth.
* **Asynchronous Cloud Sync:** The system logs high-G events and maintenance diagnostics locally, synchronizing to a cloud-based telematics dashboard when a stable connection is available.
* **Safety Scorecard:** Drivers can review long-term safety metrics and suspension health trends through a web-based portal.

## Installation & Wiring
The project utilizes a **4-core shielded "Backbone"** (Power, Ground, CAN_H, CAN_L) that runs through the vehicle's A-pillar and chassis to link all units.

---
*Developed as a 3rd Year Undergraduate Project in Computer Engineering.*
>>>>>>> 428f767cc7ccd29c4bd8f75903baef63fb64e6e6
