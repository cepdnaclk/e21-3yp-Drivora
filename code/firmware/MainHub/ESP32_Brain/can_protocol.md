# CAN Protocol Specification
## Brain + Lean + Front + Rear Units

This document defines the CAN message format for the ADAS prototype system.

## 1. System Overview

There are 4 CAN nodes in the system:

- Brain node
- Lean monitoring node (CenterUnit)
- Front collision warning node (FrontUnit)
- Rear blindspot node (RearUnit)

The brain receives CAN data from all sensor nodes and displays them in a single AP-mode web UI.

Each sensor node sends:

- **Main frame** → real-time UI data
- **Debug frame** → diagnostics / logging / future cloud upload data

---

## 2. CAN ID Map

### Lean Node
- `0x100` → Lean main
- `0x101` → Lean debug

### Front Node
- `0x200` → Front main
- `0x201` → Front debug

### Rear Node
- `0x300` → Rear main
- `0x301` → Rear debug

---

## 3. Scaling Rules

To avoid sending floats directly, scaled integers are used.

- Angle: `deg × 100`
- Distance: `cm × 10`
- Speed: `cm/s × 10`
- Confidence: `0 to 100`
- State / risk: integer enum
- Last byte of each frame: rolling counter

### Invalid numeric values
If a distance is invalid:
- use `0xFFFF` for `uint16` distance fields

---

## 4. Lean Node Frames

## 4.1 Lean Main Frame (`0x100`)
Used for:
- lean dot rendering in brain UI
- risk color / state
- confidence display

### Payload
| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | riskLevel | uint8 | 0=SAFE, 1=CAUTION, 2=HIGH |
| 1-2 | roll_x100 | int16 | roll angle in degrees ×100 |
| 3-4 | pitch_x100 | int16 | pitch angle in degrees ×100 |
| 5 | confidence_0_100 | uint8 | confidence from 0 to 100 |
| 6 | flags | uint8 | lean flags |
| 7 | counter | uint8 | rolling counter |

### Lean Flags Byte
| Bit | Meaning |
|---|---|
| 0 | calibrated |
| 1 | reserved |
| 2 | reserved |
| 3 | reserved |
| 4 | reserved |
| 5 | reserved |
| 6 | reserved |
| 7 | reserved |

---

## 4.2 Lean Debug Frame (`0x101`)
Used for:
- diagnostics
- logging
- future cloud data

### Payload
| Byte | Field | Type | Description |
|---|---|---|---|
| 0-1 | criticalRoll_x100 | uint16 | critical roll degree ×100 |
| 2-3 | criticalPitch_x100 | uint16 | critical pitch degree ×100 |
| 4 | vehicleType | uint8 | 1=Compact, 2=Passenger, 3=Tall/SUV |
| 5 | loadCondition | uint8 | 0=Light, 1=Normal, 2=Heavy |
| 6 | flags2 | uint8 | reserved for future |
| 7 | counter | uint8 | rolling counter |

---

## 5. Front Node Frames

## 5.1 Front Main Frame (`0x200`)
Used for:
- front UI state
- color
- beep
- distance
- speed

### Payload
| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | state | uint8 | 0=CLEAR, 1=OBJECT_AHEAD, 2=APPROACHING, 3=WARNING |
| 1-2 | filteredDistance_x10 | uint16 | filtered distance in cm ×10 |
| 3-4 | closingSpeed_x10 | int16 | closing speed in cm/s ×10 |
| 5-6 | rawDistance_x10 | uint16 | raw distance in cm ×10, `0xFFFF` if invalid |
| 7 | counter | uint8 | rolling counter |

---

## 5.2 Front Debug Frame (`0x201`)
Used for:
- diagnostics
- hidden logging
- future cloud data

### Payload
| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | flags | uint8 | front flags |
| 1 | approachCounter | uint8 | approach counter |
| 2 | warningCounter | uint8 | warning counter |
| 3 | blindReleaseCounter | uint8 | blind release counter |
| 4 | invalidStreak | uint8 | invalid streak counter |
| 5 | reserved1 | uint8 | reserved |
| 6 | reserved2 | uint8 | reserved |
| 7 | counter | uint8 | rolling counter |

### Front Flags Byte
| Bit | Meaning |
|---|---|
| 0 | blindZoneLatched |
| 1 | suspiciousReading |
| 2 | fastBlindTriggered |
| 3 | rawInvalid |
| 4 | reserved |
| 5 | reserved |
| 6 | reserved |
| 7 | reserved |

---

## 6. Rear Node Frames

## 6.1 Rear Main Frame (`0x300`)
Used for:
- rear UI state
- color
- beep
- distance

### Payload
| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | state | uint8 | 0=CLEAR, 1=OBJECT_DETECTED, 2=CAUTION, 3=WARNING |
| 1-2 | filteredDistance_x10 | uint16 | filtered distance in cm ×10 |
| 3-4 | rawDistance_x10 | uint16 | raw distance in cm ×10, `0xFFFF` if invalid |
| 5 | flags | uint8 | rear flags |
| 6 | reserved | uint8 | reserved |
| 7 | counter | uint8 | rolling counter |

### Rear Flags Byte
| Bit | Meaning |
|---|---|
| 0 | warningLatched |
| 1 | suspiciousLatched |
| 2 | fastWarningTriggered |
| 3 | rawInvalid |
| 4 | reserved |
| 5 | reserved |
| 6 | reserved |
| 7 | reserved |

---

## 6.2 Rear Debug Frame (`0x301`)
Used for:
- diagnostics
- hidden logging
- future cloud data

### Payload
| Byte | Field | Type | Description |
|---|---|---|---|
| 0 | warningReleaseCounter | uint8 | warning release counter |
| 1 | fastWarningReleaseCounter | uint8 | fast release counter |
| 2 | invalidStreak | uint8 | invalid streak counter |
| 3 | reserved | uint8 | reserved |
| 4-5 | lastValidDistance_x10 | uint16 | last valid distance in cm ×10, `0xFFFF` if invalid |
| 6 | reserved2 | uint8 | reserved |
| 7 | counter | uint8 | rolling counter |

---

## 7. Update Rates

### Main Frames
Send every **50 ms**
- Lean main
- Front main
- Rear main

### Debug Frames
Send every **200 ms**
- Lean debug
- Front debug
- Rear debug

---

## 8. Brain Timeout Rules

The brain uses the latest received main frame from each node.

### Suggested logic
- **Stale** if no main frame for `300 ms`
- **Offline** if no main frame for `1000 ms`

---

## 9. Brain UI Requirements

## Lean UI
Display:
- live moving lean dot
- risk state
- roll
- pitch
- confidence
- online/offline status

## Front UI
Display:
- state with color
- distance
- speed
- beep
- online/offline status

## Rear UI
Display:
- state with color
- distance
- beep
- online/offline status

Note:
Extra debug fields may be stored internally by the brain for future logging even if they are not shown in the current UI.

---

## 10. Counter Behavior

Each transmitted frame should increment its own rolling counter from `0` to `255` and wrap around.

This helps with:
- debugging dropped frames
- logging
- future cloud diagnostics

---

## 11. Notes

- CAN termination must exist only at the two physical ends of the bus.
- Only processed values should be sent, not raw sensor streams.
- The brain web UI will generate the beeps based on received states.
- Sensor nodes should remain responsible for local sensing and local decision-making.