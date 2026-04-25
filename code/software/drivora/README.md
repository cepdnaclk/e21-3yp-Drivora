# DRIVORA - Advanced Flutter Driver Assistant with WiFi Sensor Integration

## Project Overview

DRIVORA is a sophisticated driver assistance system built entirely with Flutter, designed to monitor vehicle sensors via wireless WiFi connectivity and provide real-time analytics with an attractive 3D visualization interface.

## Features Completed

### ✅ Core Architecture
- **State Management**: Provider pattern for efficient data flow.
- **Real-time Updates**: Stream-based sensor data delivery.

### ✅ WiFi Sensor Integration
- **WiFiSensorService**: Complete service for WiFi connectivity management.
- **Real-time Data Streaming**: Continuous sensor data collection.
- **Simulation Mode**: Built-in realistic data simulation for testing.

### ✅ 3D Car Visualization
- **Dynamic Updates**: Real-time steering angle and brake visualization.
- **Status Indicators**: Headlights, brake lights, turn signals.

### ✅ Modern Dark Theme
- **Glassmorphism**: Gradient overlays and blur effects.
- **Neon Colors**: Cyan primary, purple secondary.

## Project Structure

```
drivora/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── sensor_data.dart     # Sensor data models
│   ├── services/
│   │   └── wifi_sensor_service.dart  # WiFi connectivity & data
│   ├── screens/
│   │   ├── dashboard_screen.dart # Main UI
│   │   ├── alerts_screen.dart
│   │   ├── analytics_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   └── car_3d_visualization.dart  # 3D car widget
│   └── theme/
│       └── app_theme.dart       # Material theme
```

## Getting Started

1. **Get Dependencies**
   ```bash
   flutter pub get
   ```

2. **Run the App**
   ```bash
   flutter run
   ```

3. **Start Simulation**
   - Tap "ENGAGE SAFETY SHIELD" button on the Dashboard.
   - Watch real-time sensor data updates and 3D car movements.

## Hardware Architecture (Distributed U-ADAS)

| Unit | Hardware Components | Primary Function |
| :--- | :--- | :--- |
| **Unit A: Front Radar** | ESP32-C3, Doppler Radar | Forward path monitoring. |
| **Unit B: Rear Hub** | ESP32-C3, Ultrasonic | Blind-spot & reverse protection. |
| **Unit C: Dynamics** | ESP32-C3, BNO055 IMU | Vehicle stability (COG). |
| **Unit D: Windshield Hub** | ESP32-S3, OV2640 Cam | AI-vision & smartphone streaming. |

---
*Developed as a 3rd Year Undergraduate Project in Computer Engineering.*
