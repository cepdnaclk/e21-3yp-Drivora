# Drivora: Distributed Universal Advanced Driver Assistance System (U-ADAS)

**Drivora** is a distributed retrofit safety platform designed to improve driver awareness in legacy passenger vehicles. The system uses multiple hardware units placed around the vehicle to monitor the front area, rear blind spots, lane position, and vehicle lean condition.

Unlike factory-integrated ADAS systems, Drivora is designed as an add-on system that can be installed on an existing vehicle. The sensor units communicate through a **CAN-Bus backbone**, while a **Raspberry Pi 3 Model B** works as the central brain for data fusion, camera-based vision processing, warning generation, and dashboard hosting.

## Key Features

* **Forward Collision Warning (FCW):** Uses front-mounted ultrasonic sensors together with camera-based object detection to identify possible obstacles in front of the vehicle and generate warning alerts.

* **Rear Blind Spot & Reverse Safety:** Uses a three-sensor rear ultrasonic array to monitor the left, center, and right rear zones of the vehicle. This helps detect nearby obstacles during reversing and blind spot situations.

* **Lane Departure Warning (LDW):** Uses a Raspberry Pi Camera Module 3 connected to the Raspberry Pi brain to detect lane markings and warn the driver when the vehicle unintentionally moves away from its lane.

* **Lean & Stability Monitoring:** Uses an IMU-based center unit to monitor vehicle tilt and lean behavior. This helps identify unsafe leaning conditions, especially during turns or sudden vehicle movement.

* **Fused Warning Output:** Sensor data from multiple units is processed together by the Raspberry Pi brain to generate a single main warning. This reduces driver confusion by highlighting the most important alert at the right time.

## Hardware Architecture

The system is divided into distributed sensor units and a central Raspberry Pi brain unit.

| Unit | Hardware Components | Primary Function |
| :--- | :--- | :--- |
| **Front Unit** | ESP32-C3, 2x Ultrasonic Sensors, CAN Transceiver | Detects front obstacles and sends distance data through CAN. |
| **Rear Unit** | ESP32-C3, 3x JSN-SR04T Ultrasonic Sensors, CAN Transceiver | Monitors rear left, rear center, and rear right obstacle zones. |
| **Center / Lean Unit** | ESP32-C3, MPU6050 IMU, CAN Transceiver | Measures vehicle lean angle and stability-related motion data. |
| **Brain Unit** | Raspberry Pi 3 Model B, Raspberry Pi Camera Module 3, ESP32-C3 CAN Bridge | Performs camera processing, CAN data reception, warning fusion, audio alerts, and dashboard hosting. |

## Brain Unit & Vision Processing

The Raspberry Pi 3 Model B acts as the central processing unit of the Drivora system. It receives sensor data from the CAN network through an ESP32-C3 CAN bridge and combines this data with camera-based lane and object detection.

The Raspberry Pi handles:

* Lane departure detection using the Raspberry Pi Camera Module 3.
* Object detection for front collision confirmation.
* CAN data reception from front, rear, and center units.
* Warning fusion and priority selection.
* Local dashboard hosting through a Wi-Fi hotspot.
* Audio warning control through an integrated buzzer system.

## Smartphone HMI

Drivora provides a real-time dashboard that can be viewed on a smartphone connected to the Raspberry Pi hotspot.

The dashboard displays:

* Online/offline status of each hardware unit.
* Real-time vehicle surrounding visualization.
* Main fused warning for quick driver attention.
* Relevant sensor data such as obstacle distance, rear zone status, and lean condition.
* Compact status indicators for other non-critical sensor states.

The dashboard is designed for landscape use, with a safety-focused layout that prioritizes quick glanceability while driving.

## Installation & Wiring

The system uses a **CAN-Bus backbone** to connect the distributed hardware units. Each sensor unit is connected through power, ground, CAN_H, and CAN_L lines.

The current prototype includes:

* A front unit mounted near the front grille/bumper area.
* A center lean monitoring unit mounted inside the vehicle.
* A rear unit mounted on the rear bumper, where sensor probes are fixed by drilling suitable positions.
* A Raspberry Pi brain unit placed inside the vehicle with the camera module positioned for windshield-based road monitoring.

## Current Prototype Status

The current prototype has been migrated from the earlier ESP32 brain and ESP32-CAM setup to a **Raspberry Pi 3 Model B with Raspberry Pi Camera Module 3**. This improves the system's ability to perform camera-based lane detection, object detection, local dashboard hosting, and warning fusion.

---
*Developed as a 3rd Year Undergraduate Project in Computer Engineering.*
