# Drivora CAN Protocol Specification
Version: 2.0  
Bus: Classical CAN, Standard 11-bit IDs, 500 kbps  
Payload size: 8 bytes per frame  
Endian: Little-endian for multi-byte values

---

## 1. Overview

This protocol is used for communication between the Drivora brain unit and the sensor units:

- Center / Lean Monitoring Unit
- Front Collision Warning Unit
- Rear Blindspot Detection Unit

The protocol is divided into two categories:

1. **Telemetry frames**  
   Sent from each sensor unit to the brain for live dashboard display, logging, and health monitoring.

2. **Configuration / command frames**  
   Sent from the brain to sensor units for setup, sensitivity configuration, and calibration control.

Lane Departure Warning is currently connected directly to the brain through UART and is not part of this CAN protocol.

---

## 2. General Rules

- All IDs are standard 11-bit CAN IDs.
- All nodes should transmit only 8-byte data frames.
- Multi-byte integers are encoded in **little-endian** format.
- Invalid distance value is encoded as:
  - `0xFFFF` for unsigned 16-bit distance fields
- Rolling counters are 8-bit and may wrap from `255` to `0`.
- Reserved bytes should be transmitted as `0` unless defined later.

---

## 3. Unit ID Map

### Lean / Center Unit
- `0x100` Lean Main Telemetry
- `0x101` Lean Debug Telemetry
- `0x110` Lean Config A
- `0x111` Lean Command
- `0x112` Lean Config B

### Front Unit
- `0x200` Front Main Telemetry
- `0x201` Front Debug Telemetry
- `0x210` Front Config

### Rear Unit
- `0x300` Rear Main Telemetry
- `0x301` Rear Debug Telemetry
- `0x302` Rear Extra Telemetry (reserved / optional existing use)
- `0x310` Rear Config

---

## 4. Telemetry Frames

---

### 4.1 Lean Main Telemetry (`0x100`)
Direction: Center Unit -> Brain

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | riskLevel | uint8 | 0=SAFE, 1=CAUTION, 2=HIGH |
| 1-2 | roll_x100 | int16 | Roll angle in degrees x100 |
| 3-4 | pitch_x100 | int16 | Pitch angle in degrees x100 |
| 5 | confidence_x100 | uint8 | Confidence from 0 to 100 |
| 6 | flags | uint8 | bit0=calibrated |
| 7 | counter | uint8 | Rolling counter |

Notes:
- `rollDeg = roll_x100 / 100.0`
- `pitchDeg = pitch_x100 / 100.0`
- `confidence = confidence_x100 / 100.0`

---

### 4.2 Lean Debug Telemetry (`0x101`)
Direction: Center Unit -> Brain

| Byte | Field | Type | Description |
|---|---|---|---|
| 0-1 | criticalRoll_x100 | uint16 | Critical roll angle in degrees x100 |
| 2-3 | criticalPitch_x100 | uint16 | Critical pitch angle in degrees x100 |
| 4 | vehicleType | uint8 | 1=Compact, 2=Passenger, 3=Tall/SUV |
| 5 | loadCondition | uint8 | 0=Light, 1=Normal, 2=Heavy |
| 6 | debugFlags2 | uint8 | Reserved for debug status |
| 7 | counter | uint8 | Rolling counter |

---

### 4.3 Front Main Telemetry (`0x200`)
Direction: Front Unit -> Brain

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | state | uint8 | 0=CLEAR, 1=OBJECT_AHEAD, 2=APPROACHING, 3=WARNING |
| 1-2 | filteredDistance_x10 | uint16 | Filtered distance in cm x10 |
| 3-4 | closingSpeed_x10 | int16 | Closing speed in cm/s x10 |
| 5-6 | rawDistance_x10 | uint16 | Raw distance in cm x10 |
| 7 | counter | uint8 | Rolling counter |

Notes:
- Invalid distance is encoded as `0xFFFF`
- `distanceCm = value / 10.0`
- `closingSpeedCmS = value / 10.0`

---

### 4.4 Front Debug Telemetry (`0x201`)
Direction: Front Unit -> Brain

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | debugFlags | uint8 | Bit flags for internal debug status |
| 1 | approachCounter | uint8 | Internal approach confirmation counter |
| 2 | warningCounter | uint8 | Internal warning confirmation counter |
| 3 | blindReleaseCounter | uint8 | Blind-zone release counter |
| 4 | invalidStreak | uint8 | Invalid reading streak |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

---

### 4.5 Rear Main Telemetry (`0x300`)
Direction: Rear Unit -> Brain

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | state | uint8 | 0=CLEAR, 1=OBJECT_DETECTED, 2=CAUTION, 3=WARNING |
| 1-2 | filteredDistance_x10 | uint16 | Filtered distance in cm x10 |
| 3-4 | rawDistance_x10 | uint16 | Raw distance in cm x10 |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

Notes:
- Invalid distance is encoded as `0xFFFF`

---

### 4.6 Rear Debug Telemetry (`0x301`)
Direction: Rear Unit -> Brain

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | debugFlags | uint8 | Bit flags for internal debug status |
| 1 | warningReleaseCounter | uint8 | Warning release counter |
| 2 | fastWarningReleaseCounter | uint8 | Fast-release counter |
| 3 | invalidStreak | uint8 | Invalid reading streak |
| 4 | reserved | uint8 | Reserved |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

---

### 4.7 Rear Extra Telemetry (`0x302`)
Direction: Rear Unit -> Brain

Reserved for future expansion or extra rear diagnostic data.

Current recommendation:
- keep optional
- do not depend on it for main UI logic

---

## 5. Configuration and Command Frames

These frames are sent by the brain after boot, after settings changes, and during guided setup.

---

### 5.1 Lean Config A (`0x110`)
Direction: Brain -> Center Unit

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | vehicleType | uint8 | 1=Compact, 2=Passenger, 3=Tall/SUV |
| 1 | loadCondition | uint8 | 0=Light, 1=Normal, 2=Heavy |
| 2-3 | trackWidth_mm | uint16 | Track width in millimeters |
| 4-5 | wheelBase_mm | uint16 | Wheelbase in millimeters |
| 6 | flags | uint8 | bit0=applyNow, other bits reserved |
| 7 | counter | uint8 | Rolling counter |

Notes:
- Example: 1.56 m -> 1560 mm

---

### 5.2 Lean Config B (`0x112`)
Direction: Brain -> Center Unit

| Byte | Field | Type | Description |
|---|---|---|---|
| 0-1 | vehicleHeight_mm | uint16 | Vehicle height in millimeters |
| 2 | flags | uint8 | bit0=applyNow, other bits reserved |
| 3 | reserved | uint8 | Reserved |
| 4 | reserved | uint8 | Reserved |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

---

### 5.3 Lean Command (`0x111`)
Direction: Brain -> Center Unit

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | commandBits | uint8 | bit0=calibrate, bit1=clear calibration, others reserved |
| 1 | reserved | uint8 | Reserved |
| 2 | reserved | uint8 | Reserved |
| 3 | reserved | uint8 | Reserved |
| 4 | reserved | uint8 | Reserved |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

Notes:
- Calibration is modeled as an action command, not as a persistent setting.

---

### 5.4 Front Config (`0x210`)
Direction: Brain -> Front Unit

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | sensitivityPreset | uint8 | 0=Near, 1=Normal, 2=Far |
| 1 | flags | uint8 | Reserved for future use |
| 2 | reserved | uint8 | Reserved |
| 3 | reserved | uint8 | Reserved |
| 4 | reserved | uint8 | Reserved |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

Preset meaning:
- Near = shorter warning range
- Normal = default
- Far = earlier warning / longer range

---

### 5.5 Rear Config (`0x310`)
Direction: Brain -> Rear Unit

| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | sensitivityPreset | uint8 | 0=Near, 1=Normal, 2=Far |
| 1 | flags | uint8 | Reserved for future use |
| 2 | reserved | uint8 | Reserved |
| 3 | reserved | uint8 | Reserved |
| 4 | reserved | uint8 | Reserved |
| 5 | reserved | uint8 | Reserved |
| 6 | reserved | uint8 | Reserved |
| 7 | counter | uint8 | Rolling counter |

Preset meaning:
- Near = tighter rear warning zones
- Normal = default
- Far = wider / earlier warning zones

---

## 6. Preset Interpretation

The brain sends only the preset ID.  
Each node maps the preset internally to its own threshold set.

This keeps the UI simple and avoids exposing raw threshold parameters during normal setup.

### Suggested mapping approach

#### Front Unit
- Near -> reduced OBJECT_ZONE / WARNING_ZONE
- Normal -> current default values
- Far -> increased OBJECT_ZONE / WARNING_ZONE

#### Rear Unit
- Near -> reduced OBJECT_DETECTED / CAUTION / WARNING thresholds
- Normal -> current default values
- Far -> increased OBJECT_DETECTED / CAUTION / WARNING thresholds

---

## 7. Startup and Settings Synchronization

### On brain boot
1. Brain loads saved setup profile from persistent storage
2. Brain sends:
   - `0x110` Lean Config A
   - `0x112` Lean Config B
   - `0x210` Front Config
   - `0x310` Rear Config
3. Units apply settings internally
4. Dashboard uses telemetry frames to confirm unit state

### On settings change
- Brain updates stored profile
- Brain sends only the relevant config frame(s)

### On center calibration request
- Brain sends `0x111` Lean Command with `bit0 = 1`

---

## 8. Timeout Guidance for Dashboard

Recommended dashboard interpretation:

### CAN-based units
- stale after `300 ms`
- offline after `1000 ms`

These values apply to:
- Lean unit
- Front unit
- Rear unit

Lane Departure Warning currently uses UART, so its timeout handling can remain separate from this CAN document.

---

## 9. Future Extensions

Possible future additions:
- explicit ACK frames for config application
- multiple saved installation profiles
- advanced custom threshold mode
- diagnostic fault codes
- firmware version reporting
- sensor mounting profile reporting

---

## 10. Summary

This protocol version keeps all current live telemetry frames unchanged and adds a clean set of brain-to-node configuration and command frames.

Benefits:
- simple guided setup support
- editable settings later
- centralized configuration in brain
- minimal changes to current telemetry design
- future-proof structure for cloud logging and diagnostics