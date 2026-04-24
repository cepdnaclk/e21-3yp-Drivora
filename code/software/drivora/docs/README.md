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

Drivora is a Distributed Retrofit Safety System designed to modernize legacy vehicles that lack contemporary safety technology. It serves as a four-unit hardware suite communicating over a robust CAN-Bus backbone to create a "Safety Shield" around the vehicle. By combining radar-based distance sensing, inertial motion tracking, and computer vision, it provides real-time audio-visual alerts to help prevent collisions and rollovers. This system specifically targets owners of older passenger vehicles and commercial vehicle operators who face massive blind spots and stability risks.

## Solution Architecture

The system utilizes a decentralized architecture with four discrete units linked via a vehicle-wide communication backbone. 

* **Unit A (Front Radar Array):** Positioned at the front bumper to monitor forward collision risks and relative velocity.
* **Unit B (Rear Safety Hub):** Centrally located within the chassis with three distributed probes at the bumper corners and center for blind-spot monitoring and reverse safety.
* **Unit C (COG & Dynamics Unit):** Mounted at the vehicle's geometric center to track orientation, lateral G-forces, and vibration signatures.
* **Unit D (Windshield Hub):** Attached to the upper windshield to handle AI-vision processing and manage the user interface via a smartphone.

## Hardware and Software Designs

Drivora integrates high-performance microcontrollers and specialized sensors to deliver its safety features.

### Hardware Architecture
* **Central Processor:** An ESP32-S3 with 8MB PSRAM for high-speed image processing and smartphone data streaming.
* **Distributed Controllers:** ESP32-C3 SuperMini modules acting as localized controllers for edge units.
* **Sensing Suite:** Dual 24GHz CDM324 Doppler radars for front detection and waterproof JSN-SR04T ultrasonic sensors for rear/side coverage.
* **Stability Tracking:** A high-precision BNO055 9-axis IMU with internal fusion for real-time Center of Gravity (COG) and tilt monitoring.

### Software Features
* **Collision Detection:** Algorithms calculate Time-to-Collision (TTC) using Doppler shift data from the front radar array.
* **Lane Departure Warning:** A computer vision pipeline identifying road markings to detect unintentional drifting.
* **Stability Scoring:** Processing tilt and G-force data to identify rollover risks in high-profile vehicles.
* **Maintenance Diagnostics:** Frequency analysis of chassis oscillations to identify worn-out shock absorbers.

## Testing

Comprehensive testing ensures the system's reliability in a high-vibration automotive environment.
* **Sensor Validation:** Evaluating the detection range and accuracy of both the Doppler radar and ultrasonic arrays at various vehicle speeds.
* **Vision Accuracy:** Testing the ESP32-S3's ability to identify lane markings under diverse lighting conditions through the windshield.
* **Network Integrity:** Verifying that the CAN-Bus backbone maintains data synchronization between the four units without latency issues.
* **HMI Performance:** Testing the reliability of the Bluetooth connection and the real-time responsiveness of the smartphone-based dashboard.

## Detailed budget

| Item | Quantity | Unit Cost (LKR) | Total (LKR) |
| :--- | :---: | :---: | :---: |
| ESP32-S3 (Main Hub) | 1 | 2,100 | 2,100 |
| ESP32-C3 SuperMini | 3 | 800 | 2,400 |
| CDM324 Radar | 2 | 1,500 | 3,000 |
| JSN-SR04T Waterproof Ultrasonic | 3 | 1,266 | 3,800 |
| BNO055 (IMU) | 1 | 2,500 | 2,500 |
| OV2640 Camera | 1 | 1,200 | 1,200 |
| CAN Transceivers (SN65HVD230) | 4 | 500 | 2,000 |
| XL4015 5A Buck Converter | 1 | 540 | 540 |
| Cigarette Plug Adapter | 1 | 170 | 170 |
| Misc (Enclosures / Wires / Switches) | - | - | 7,000 |
| **Total** | | | **24,710 (Approx.)** |

## Conclusion

Drivora provides a comprehensive and affordable safety modernization path for legacy and commercial vehicles. By leveraging a distributed multi-unit architecture and low-cost edge computing, the system achieves complex features like Forward Collision Warning and Stability Monitoring. Future work will focus on refining the experimental Overtake Warning System and enhancing the cloud-based telematics platform for long-term vehicle health tracking.

## Links

- [Project Repository](https://github.com/cepdnaclk/e21-3yp-Drivora){:target="_blank"}
- [Project Page](https://cepdnaclk.github.io/e21-3yp-Drivora/){:target="_blank"}
- [Department of Computer Engineering](http://www.ce.pdn.ac.lk/)
- [Faculty of Engineering, University of Peradeniya](https://eng.pdn.ac.lk/)

[//]: # (Please refer this to learn more about Markdown syntax)
[//]: # (https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)
