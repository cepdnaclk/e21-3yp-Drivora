---
layout: home
permalink: index.html

# Please update this with your repository name and project title
repository-name: e21-3yp-Drivora
title: Drivora
---

[comment]: # "This is the standard layout for the project, but you can clean this and use your own template"

# Drivora: Distributed Universal Advanced Driver Assistance System

---

## Team
-  E/21/050, Bandara H.B.C.T., [e21050@eng.pdn.ac.lk](mailto:e21050@eng.pdn.ac.lk)
-  E/21/052, Bandara H.M.P.D., [e21052@eng.pdn.ac.lk](mailto:e21052@eng.pdn.ac.lk)
-  E/21/077, Darshana K.M.S., [e21077@eng.pdn.ac.lk](mailto:e21077@eng.pdn.ac.lk)
-  E/21/269, Nirmal A.P.S., [e21269@eng.pdn.ac.lk](mailto:e21269@eng.pdn.ac.lk)

<!-- Image (photo/drawing of the final hardware) should be here -->

<!-- This is a sample image, to show how to add images to your page. To learn more options, please refer [this](https://projects.ce.pdn.ac.lk/docs/faq/how-to-add-an-image/) -->

<!-- ![Sample Image](./images/sample.png) -->

#### Table of Contents
1. [Introduction](#introduction)
2. [Solution Architecture](#solution-architecture )
3. [Hardware & Software Designs](#hardware-and-software-designs)
4. [Testing](#testing)
5. [Detailed budget](#detailed-budget)
6. [Conclusion](#conclusion)
7. [Links](#links)

## Introduction

Drivora is a Distributed Retrofit Safety System designed to improve driver awareness in legacy vehicles that lack modern safety assistance features. It uses multiple hardware units placed around the vehicle to monitor the front area, rear blind spots, lane position, and vehicle lean condition. These units communicate through a CAN-Bus backbone, while a Raspberry Pi 3 Model B acts as the central brain for camera processing, data fusion, warning generation, audio alerts, and dashboard hosting. The system targets older passenger vehicles and small-scale retrofit applications where built-in ADAS features are not available.

## Solution Architecture

The system utilizes a decentralized architecture with distributed sensing units linked through a vehicle-wide CAN-Bus communication backbone.

* **Unit A (Front Unit):** Positioned near the front bumper/grille area to monitor front obstacles using ultrasonic sensing and support front collision warning.
* **Unit B (Rear Safety Hub):** Mounted at the rear side of the vehicle with three waterproof ultrasonic probes placed at the left, center, and right rear zones for blind-spot monitoring and reverse safety.
* **Unit C (Center / Lean Monitoring Unit):** Mounted inside the vehicle to track vehicle tilt and lean behavior using an IMU sensor.
* **Unit D (Brain Unit):** Built using a Raspberry Pi 3 Model B and Raspberry Pi Camera Module 3 to handle lane detection, camera-based object detection, warning fusion, local dashboard hosting, and audio warning output.

## Hardware and Software Designs

Drivora integrates distributed microcontroller-based sensor units with a Raspberry Pi-based central processing unit to deliver real-time safety warnings.

### Hardware Architecture
* **Central Processor:** Raspberry Pi 3 Model B used as the main brain for camera processing, warning fusion, dashboard hosting, and system control.
* **Camera Module:** Raspberry Pi Camera Module 3 used for lane departure detection and camera-based front object detection.
* **Distributed Controllers:** ESP32-C3 Super Mini modules used as localized controllers for the front, rear, and center sensor units.
* **Sensing Suite:** Ultrasonic sensors are used for front obstacle detection and rear left, center, and right zone monitoring.
* **Stability Tracking:** MPU-6050 IMU sensor used to monitor vehicle tilt and lean condition.
* **CAN Communication:** TJA1050 CAN modules are used to connect the distributed units through the CAN-Bus backbone. An ESP32-C3 CAN bridge is used to pass CAN data to the Raspberry Pi brain.

### Software Features
* **Collision Detection:** Front sensor data and camera-based object detection are combined to identify possible collision risks in front of the vehicle.
* **Lane Departure Warning:** A computer vision pipeline running on the Raspberry Pi processes camera input to detect lane markings and warn about unintentional lane drifting.
* **Rear Blind-Spot Monitoring:** Rear ultrasonic sensor data is processed as left, center, and right zones to support blind-spot and reverse obstacle warnings.
* **Lean Monitoring:** IMU data is processed to detect unsafe vehicle lean or tilt conditions.
* **Warning Fusion:** The Raspberry Pi brain combines incoming data from all units and displays the most critical warning clearly on the dashboard.
* **Local Dashboard:** A smartphone can connect to the Raspberry Pi hotspot and view the real-time dashboard through a local web interface.

## Testing

Comprehensive testing ensures the system's reliability in a high-vibration automotive environment.
* **Sensor Validation:** Evaluating the detection range and consistency of front and rear ultrasonic sensors under different obstacle positions and distances.
* **Vision Accuracy:** Testing the Raspberry Pi Camera Module 3 and vision pipeline for lane marking detection and front object detection under different lighting and road conditions.
* **Network Integrity:** Verifying that the CAN-Bus backbone maintains data synchronization between the distributed units and the Raspberry Pi brain without noticeable delay.
* **HMI Performance:** Testing the responsiveness, readability, and reliability of the smartphone-based dashboard connected through the Raspberry Pi hotspot.
* **Vehicle Fitment Testing:** Checking the mounting positions, wiring paths, enclosure stability, and rear bumper sensor probe placement on the demonstration vehicle.

## Detailed budget

| Item | Quantity | Unit Cost (LKR) | Total (LKR) |
| :--- | :---: | :---: | :---: |
| CDM324 Radar Sensor | 1 | 522.00 | 522.00 |
| ESP32-C3 Super Mini Board | 3 | 790.00 | 2,370.00 |
| MPU-6050 IMU sensor | 1 | 680.00 | 680.00 |
| TJA1050 CAN Module | 4 | 250.00 | 1,000.00 |
| JSN-SR04T Ultrasonic Sensor | 3 | 1,100.00 | 3,300.00 |
| LM358 Gain Amplification Module | 2 | 160.00 | 320.00 |
| XL4016 Buck Converter | 1 | 750.00 | 750.00 |
| 1N5408 Diode | 2 | 10.00 | 20.00 |
| Jumper wire set Female-to-Female | 1 | 130.00 | 130.00 |
| Courier fee for Tronic LK | 1 | 480.00 | 480.00 |
| JSN-SR04T Ultrasonic Sensor 3.0 | 1 | 1,890.00 | 1,890.00 |
| Male to Male jumper wire set (20) | 1 | 110.00 | 110.00 |
| JSN-SR04T Ultrasonic Sensor 3.0 | 1 | 1,880.00 | 1,880.00 |
| MCP2515 CAN Module | 1 | 400.00 | 400.00 |
| Twine Wire | 4 | 100.00 | 400.00 |
| JSN-SR04T Ultrasonic Sensor 3.0 | 3 | 1,850.00 | 5,550.00 |
| Glass Fuse 5x20mm | 1 | 10.00 | 10.00 |
| Waterproof Connectors | 6 | 310.00 | 1,860.00 |
| Courier fee for Tronic LK | 1 | 600.00 | 600.00 |
| Heat Shrink Tubes 2mm | 1 | 35.00 | 35.00 |
| Heat Shrink Tubes 10mm | 1 | 75.00 | 75.00 |
| Brass Threaded Inserts | 2 | 225.00 | 450.00 |
| M3 Screws + Nuts | 20 | 4.50 | 90.00 |
| Cable Ties (Zip Ties) | 5 | 6.00 | 30.00 |
| 4 Core Wires | 8 | 225.00 | 1,800.00 |
| 3D print of Front Unit | 1 | 3,500.00 | 3,500.00 |
| 3D print of Rear Unit and MainHub mounts | 1 | 2,250.00 | 2,250.00 |
| **Total** | | | **30,502.00** |

## Conclusion

Drivora provides an affordable safety modernization approach for legacy vehicles by combining distributed sensing, CAN-based communication, Raspberry Pi-based vision processing, and a real-time smartphone dashboard. The current prototype demonstrates front obstacle warning, rear blind-spot and reverse safety monitoring, lane departure warning, lean monitoring, audio alerts, and fused warning display. Future work will focus on improving detection accuracy, refining enclosure and vehicle installation methods, and enhancing long-term data logging and driver safety analytics.

## Links

- [Project Repository](https://github.com/cepdnaclk/e21-3yp-Drivora)
- [Project Page](https://cepdnaclk.github.io/e21-3yp-Drivora/)
- [Department of Computer Engineering](http://www.ce.pdn.ac.lk/)
- [Faculty of Engineering, University of Peradeniya](https://eng.pdn.ac.lk/)

[//]: # (Please refer this to learn more about Markdown syntax)
[//]: # (https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)
