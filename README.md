<<<<<<< HEAD
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
=======
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
>>>>>>> 0b283b9 (Updated Drivora project files)

---
*Developed as a 3rd Year Undergraduate Project in Computer Engineering.*
