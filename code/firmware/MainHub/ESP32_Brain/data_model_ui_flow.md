# Drivora Setup Data Model, UI Flow, and Alert/Incident Architecture
Version: 1.5

---

## 1. Purpose

This document defines the current planned product behavior for Drivora, including:

- mobile app structure
- setup and onboarding flow
- persistent data model
- live dashboard model
- alert fusion model
- critical incident model
- local-first cloud sync behavior
- settings and user preferences

This document reflects the current intended **final Flutter app architecture**, while the current AP-mode brain web app is treated as the prototype implementation path.

---

## 2. Core System Architecture

Drivora consists of:

- **Front Unit**
- **Rear Unit**
- **Center / Lean Monitoring Unit**
- **Lane Departure Unit**
- **Brain Unit**
- **Flutter Mobile App**
- **Firebase Cloud Backend**

### Responsibilities

#### Sensor units
Generate raw telemetry and local unit states.

#### Brain unit
Acts as:
- central configuration master
- warning fusion controller
- critical incident classifier
- hardware buzzer controller
- local device Wi-Fi host

#### Mobile app
Acts as:
- user login/account interface
- setup/configuration interface
- live dashboard display
- statistics/history viewer
- local incident storage manager
- Firebase sync client

#### Firebase
Stores:
- user profile data
- vehicle profile data
- setup/profile data
- critical incident logs
- statistics summaries

---

## 3. Final Top-Level App Navigation

The app should have **three** top-level pages:

- **Dashboard**
- **Statistics**
- **Settings**

This is the final intended navigation model.

---

## 4. User Journey

## 4.1 Account and Cloud Onboarding

The user first opens the app with an internet connection.

Flow:
1. Create account or log in
2. Firebase user record is created or loaded
3. Vehicle/profile storage becomes available in cloud

This stage requires internet.

---

## 4.2 Local Hardware Onboarding

After account creation:

1. User powers on Drivora hardware
2. App connects to the brain’s local Wi-Fi using the default SSID/password
3. User is required to change the local Wi-Fi password for security
4. App reconnects using the new custom password
5. User runs the guided setup wizard
6. User is directed to the Dashboard

This stage does **not** require internet after login/account creation.

---

## 4.3 Daily Use

In normal operation:
- app connects locally to the brain
- Dashboard shows live state
- Statistics page shows historical analytics and incidents
- Settings allows configuration changes, recalibration, and rerunning setup
- installation testing is accessed through the Guided Setup Wizard in v1

---

## 5. Dashboard Model

The Dashboard is the live driving page.

For v1, the Dashboard should be optimized primarily for **landscape use**.

It should be built around:
1. one **primary fused warning**
2. one **2D vehicle top-view visualization**
3. one **context data panel** focused mainly on the current primary warning

### 5.1 Overall landscape layout

Use a two-column layout:

- **Left half**: 2D top-view vehicle visualization
- **Right half (top)**: primary fused warning panel
- **Right half (bottom)**: primary warning context data panel

This keeps the visual vehicle state and the driver guidance visible at the same time.

### 5.2 Top bar

The top bar should include:
- vehicle name or system name
- cloud/app sync indicator
- current sound mode indicator
- online/offline state of each hardware unit using compact status dots

Recommended unit status indicators:
- Front
- Rear
- Center
- Lane

Recommended color meaning:
- green = online
- amber = stale
- red = offline

This avoids repeating separate large online/offline cards elsewhere in the Dashboard.

### 5.3 Primary fused warning panel

Only **one** driver-facing warning is shown prominently at a time.

This primary warning panel should include:
- warning title
- severity color/state
- short user-facing message
- optional short action hint

Examples:
- `ALL CLEAR`
- `FRONT COLLISION WARNING`
- `REAR LEFT BLINDSPOT WARNING`
- `LANE DEPARTURE RIGHT`
- `VEHICLE INSTABILITY DETECTED`

This is the most important non-visual guidance area on the Dashboard.

### 5.4 2D top-view vehicle visualization

A **2D top-view vehicle visualization** shows all unit states simultaneously.

Recommended visual elements:

#### Front
- one front warning zone ahead of the vehicle
- color/state based on front unit state

#### Rear
Rear warnings should be shown as **three separate zones**:
- rear-left
- rear-center
- rear-right

This reflects the real sensor placement and makes rear warnings easier to understand.

#### Center / lean
The center of the vehicle should contain the **lean dot with target rings** using the current visual style.

Recommended behavior:
- lean dot shown at the center of the vehicle body
- target rings remain visible
- severity can be reflected using color/glow
- the dot remains the main live lean indicator

#### Lane departure
- left lane line
- right lane line
- highlight the active side when lane departure is detected

### 5.5 Context data panel

The context data panel should focus mainly on the **current primary fused warning**.

#### Main rule
Do **not** show all raw data from all units equally in the main context area.

Instead:
- show **detailed data relevant to the current primary warning**
- show only a **compact summary** for the other units if needed

Examples:

#### If primary warning = Front Collision Warning
Show:
- front state
- distance
- closing speed

#### If primary warning = Rear Left Blindspot Warning
Show:
- rear-left state
- rear-left distance

#### If primary warning = Lane Departure Right
Show:
- lane state
- departure side

#### If primary warning = Vehicle Instability Detected
Show:
- lean state
- roll
- pitch
- confidence

Optional secondary compact summaries may still be shown for the other units in a visually quieter way, but there should be no separate secondary-alert UI layer.

### 5.6 Dashboard rules

- Show all unit states visually in the 2D top view
- Show only one primary fused warning prominently
- Focus the context panel on the primary warning’s relevant data
- Do **not** show a separate secondary-alert chip/list layer in v1
- Do **not** include dashboard layout customization in v1

### 5.7 Optional setup banner

If no setup has been completed:
- show `Setup required`
- show button `Open Setup Wizard`

---

## 6. Statistics Page Model

The Statistics page is the historical analysis page.

Main content:
- overall driver score
- score trend over the last 7 / 30 days
- number of critical incidents over the last 30 days
- critical incident history list
- incident detail view
- sync status of incidents

### v1 statistics window
For v1:
- the **driver score** is calculated using a rolling **last 30 days** window
- the **default incident history shown in the app** is also limited to the **last 30 days**
- older critical incidents may remain stored in Firebase for long-term record keeping, but they are outside the default Statistics view unless a future archive view is added

### Incident list item fields
- timestamp
- primary incident type
- severity
- short summary
- sync status

### Incident detail fields
- primary fused warning
- trigger rule
- per-unit snapshot states
- CAN main/debug frame snapshot data
- lane snapshot
- upload/sync metadata

---

## 7. Settings Page Model

Settings contains all non-live configuration and maintenance actions.

### Settings sections
1. Vehicle Profile
2. Device Connectivity
3. Front Sensitivity
4. Rear Sensitivity
5. Center Calibration
6. Guided Setup Wizard
7. Alerts Preferences
8. System / Reset

### Important placement decision
- The **Setup Wizard entry** lives inside Settings
- The **Installation Test flow** is kept inside the Guided Setup Wizard in v1 and is not exposed as a standalone normal Settings section

This keeps top-level navigation clean.

---

## 8. Persistent Brain Profile

This profile is stored in the brain’s non-volatile storage.

```json
{
  "profileName": "My Vehicle",
  "setupCompleted": true,
  "vehicleType": 3,
  "trackWidth_m": 1.56,
  "wheelBase_m": 2.67,
  "vehicleHeight_m": 1.57,
  "loadCondition": 1,
  "frontSensitivityPreset": 1,
  "rearSensitivityPreset": 1,
  "centerCalibrated": true,
  "deviceConnectivity": {
    "localWifiSSID": "Drivora-Local",
    "localWifiPasswordChanged": true
  },
  "preferences": {
    "visualAlerts": {
      "front": true,
      "rear": true,
      "center": true,
      "lane": true
    },
    "soundAlerts": {
      "outputMode": "BUZZER",
      "front": true,
      "rear": true,
      "center": true,
      "lane": true
    }
  },
  "lastSetupTime": 0
}
```

### Field definitions

| Field | Type | Description |
|---|---|---|
| profileName | string | Friendly installation name |
| setupCompleted | bool | Whether first guided setup has been completed |
| vehicleType | int | 1=Compact, 2=Passenger, 3=Tall/SUV |
| trackWidth_m | float | Track width in meters |
| wheelBase_m | float | Wheelbase in meters |
| vehicleHeight_m | float | Vehicle height in meters |
| loadCondition | int | 0=Light, 1=Normal, 2=Heavy |
| frontSensitivityPreset | int | 0=Near, 1=Normal, 2=Far |
| rearSensitivityPreset | int | 0=Near, 1=Normal, 2=Far |
| centerCalibrated | bool | Whether center calibration has been completed |
| deviceConnectivity.localWifiSSID | string | Current local device Wi-Fi SSID |
| deviceConnectivity.localWifiPasswordChanged | bool | Whether the default local Wi-Fi password has been replaced |
| preferences.visualAlerts.* | bool | Per-unit visual alert visibility |
| preferences.soundAlerts.outputMode | string | `BUZZER`, `IN_APP`, or `OFF` |
| preferences.soundAlerts.* | bool | Per-unit sound participation flags |
| lastSetupTime | timestamp/int | Time of last guided setup completion |

---

## 9. Cloud User and Vehicle Data Model

## 9.1 User Cloud Record

```json
{
  "uid": "firebase-user-id",
  "email": "user@example.com",
  "displayName": "User Name",
  "createdAt": 0,
  "defaultVehicleId": "vehicle-001"
}
```

## 9.2 Vehicle Cloud Record

```json
{
  "vehicleId": "vehicle-001",
  "name": "My Vehicle",
  "brainDeviceId": "brain-001",
  "createdAt": 0,
  "lastSeenAt": 0
}
```

### Suggested Firebase structure

```text
users/{uid}/profile
users/{uid}/vehicles/{vehicleId}
users/{uid}/vehicles/{vehicleId}/settings
users/{uid}/vehicles/{vehicleId}/incidents/{incidentId}
users/{uid}/vehicles/{vehicleId}/stats/summary
```

---

## 10. Runtime Applied Settings

These are the values the brain pushes to the units.

### To Center Unit
- vehicleType
- trackWidth_m
- wheelBase_m
- vehicleHeight_m
- loadCondition

### To Front Unit
- frontSensitivityPreset

### To Rear Unit
- rearSensitivityPreset

---

## 11. Unit-Local Derived State

These are computed locally inside each node and do not need to be directly user-editable in normal setup.

### Center Unit
- calibration offsets
- critical roll angle
- critical pitch angle
- filtered roll / pitch state

### Front Unit
- preset-expanded threshold values
- blind-zone logic state
- approach counters

### Rear Unit
- preset-expanded threshold values
- warning latch state
- release counters

---

## 12. Live Raw Unit States

These raw states remain available for dashboard visuals, diagnostics, and incident logs.

### Front unit raw states
- `CLEAR`
- `OBJECT_AHEAD`
- `APPROACHING`
- `WARNING`

### Rear unit raw states
- `CLEAR`
- `OBJECT_DETECTED`
- `CAUTION`
- `WARNING`

### Center / lean raw states
- `SAFE`
- `CAUTION`
- `HIGH`

### Lane raw states
- `SAFE`
- `LEFT_DEPARTURE`
- `RIGHT_DEPARTURE`

These raw states should be shown in the dashboard’s 2D top-view visualization.

---

## 13. Fused Warning Model

The brain must generate a **single fused driver-facing alert**.

### Recommended fused alert object

```json
{
  "primaryAlertType": "FRONT_COLLISION",
  "primaryAlertSeverity": "WARNING",
  "primaryAlertText": "Obstacle ahead",
  "buzzerPattern": "FRONT_WARNING_FAST",
  "multipleHazards": false,
  "timestamp": 0
}
```

### Field definitions

| Field | Type | Description |
|---|---|---|
| primaryAlertType | string/enum | Main selected warning source/type |
| primaryAlertSeverity | string/enum | `NORMAL`, `INFO`, `CAUTION`, `WARNING`, `CRITICAL` |
| primaryAlertText | string | Short user-facing message |
| buzzerPattern | string/enum | Brain-selected buzzer pattern |
| multipleHazards | bool | Whether multiple meaningful hazards are active |
| timestamp | int | Time of fused alert generation |

### Presentation rules
- Show only the **primary fused warning** prominently
- Do not show separate secondary-alert UI in v1
- Continue showing all per-unit raw states visually in the vehicle top view

### Responsibility rule
The **brain**, not the app, decides:
- warning priority
- fused alert type
- fused severity
- buzzer pattern

---

## 14. Sound and Visual Alert Preferences

These are part of the Settings page.

## 14.1 Visual alert preferences
Per-unit toggles:
- front visual alerts
- rear visual alerts
- center visual alerts
- lane visual alerts

## 14.2 Sound alert preferences
Use a **mutually exclusive output mode**.

### outputMode options
- `BUZZER`
- `IN_APP`
- `OFF`

Only one output mode may be active at a time.

### Per-unit sound participation toggles
- front
- rear
- center
- lane

These toggles apply to the selected output mode.

### v1 decisions
- no separate secondary-alert UI
- no dashboard layout preferences in v1
- only one primary alert is emphasized
- all unit states remain visible in the 2D dashboard top view

---

## 15. Sensitivity Model

Do not expose raw threshold tuning in normal setup for v1.

Use presets instead.

### Front sensitivity presets
- `0 = Near`
- `1 = Normal`
- `2 = Far`

Meaning:
- Near = shorter warning range
- Normal = default
- Far = earlier warning / longer range

### Rear sensitivity presets
- `0 = Near`
- `1 = Normal`
- `2 = Far`

Meaning:
- Near = tighter detection and warning zone
- Normal = default
- Far = wider / earlier detection behavior

### Why presets are preferred
- easier for non-technical users
- faster setup
- lower safety risk
- internal thresholds can still differ per node

---

## 16. Settings Page Sections in Detail

## 16.1 Vehicle Profile
Fields:
- Vehicle Type
- Track Width
- Wheelbase
- Vehicle Height
- Load Condition

Action:
- Save Vehicle Settings

Behavior:
- save in brain profile
- send to center unit
- center unit recomputes critical angles

## 16.2 Device Connectivity
Purpose:
- manage local connection settings of the brain unit

Fields / actions:
- Local Wi-Fi SSID (view-only in v1 unless renamed later)
- Change Local Wi-Fi Password

Recommended password change flow:
1. user opens Device Connectivity
2. enters current password
3. enters new password
4. confirms new password
5. app sends change request to brain
6. brain updates AP credentials and restarts local Wi-Fi
7. app prompts user to reconnect using the new password

Behavior:
- this setting is available both during first-time onboarding and later from Settings
- changing the local Wi-Fi password is a device/network setting, not a wizard-only action

## 16.3 Front Sensitivity
Options:
- Near
- Normal
- Far

Action:
- Apply Front Sensitivity

## 16.4 Rear Sensitivity
Options:
- Near
- Normal
- Far

Action:
- Apply Rear Sensitivity

## 16.5 Center Calibration
Instructions:
- park on level ground
- keep vehicle still
- minimize vibration

Action:
- Calibrate Center Unit

Behavior:
- brain sends calibration command
- center unit calibrates
- result shown to user

## 16.6 Guided Setup Wizard
Action:
- Run Setup Wizard Again

Purpose:
- rerun the full guided installation flow at any time
- useful after remounting, reinstalling, or moving the system to another vehicle

Note:
- installation testing is kept inside the Guided Setup Wizard for v1 and is not exposed as a normal standalone Settings section

## 16.7 Alerts Preferences
Contains:
- visual alert toggles
- sound output mode
- per-unit sound toggles

## 16.8 System / Reset
Suggested actions:
- Reset Settings to Defaults
- Clear Saved Profile
- future: Export Diagnostics

---

## 17. Guided Setup Wizard

The guided setup wizard should be available:
- on first setup
- anytime later from Settings

### Step 1: Welcome
Explain:
- what will be configured
- that the wizard can be rerun later

### Step 2: Vehicle Information
Collect:
- Vehicle Type
- Track Width
- Wheelbase
- Vehicle Height
- Load Condition

### Step 3: Front Sensitivity
Select:
- Near
- Normal
- Far

### Step 4: Rear Sensitivity
Select:
- Near
- Normal
- Far

### Step 5: Center Calibration
Show:
- vehicle on level ground
- vehicle stationary

Action:
- Calibrate Center Unit

### Step 6: Installation Test
Check:
- Front unit online
- Rear unit online
- Center unit online and calibrated
- Lane unit online

Optional guidance:
- place object in front
- move object through rear zone
- verify lean response

### Step 7: Save and Finish
Actions:
- save profile in brain
- push settings to units
- set `setupCompleted = true`

---

## 18. Critical Incident Architecture

Critical incidents must be decided by the **brain**, not by the app.

### Why
Because the brain has:
- all unit data
- real-time fused warning logic
- direct access to CAN frames
- no dependency on app state or internet state

### Pipeline
1. units send telemetry
2. brain computes fused warning
3. brain applies incident classification rules
4. brain creates structured incident record
5. app stores incident locally first
6. app syncs incident to Firebase when internet is available

---

## 19. Critical Incident Rules (v1)

Not every warning should become a critical incident.

### Suggested critical incident triggers

#### Rule 1: Lean high-risk event
- center/lean state = `HIGH`
- sustained briefly

#### Rule 2: Front warning event
- front state = `WARNING`
- sustained or repeated in a short time window

#### Rule 3: Rear warning event
- rear state = `WARNING`
- sustained beyond minimum threshold

#### Rule 4: Multi-hazard event
Two or more serious conditions active together

Examples:
- front WARNING + lane departure
- lean HIGH + front WARNING
- rear WARNING + lane departure

#### Rule 5: Fused alert reaches CRITICAL
If fused severity becomes `CRITICAL`, always create an incident.

---

## 20. Critical Incident Data Model

```json
{
  "incidentId": "incident-001",
  "vehicleId": "vehicle-001",
  "timestamp": 0,
  "timezone": "Asia/Colombo",
  "primaryAlertType": "FRONT_COLLISION",
  "primarySeverity": "CRITICAL",
  "triggerRule": "FRONT_WARNING_SUSTAINED",
  "multiHazard": false,
  "syncStatus": "pending",
  "front": {},
  "rear": {},
  "center": {},
  "lane": {},
  "canFrames": {
    "frontMain": {},
    "frontDebug": {},
    "rearMain": {},
    "rearDebug": {},
    "centerMain": {},
    "centerDebug": {}
  }
}
```

### Recommended record contents

#### Metadata
- incidentId
- vehicleId
- timestamp
- timezone
- syncStatus

#### Primary summary
- primaryAlertType
- primarySeverity
- triggerRule
- multiHazard

#### Per-unit snapshot
- front snapshot
- rear snapshot
- center snapshot
- lane snapshot

#### CAN frame snapshot
- front main/debug
- rear main/debug
- center main/debug

---

## 21. Local-First Incident Storage and Cloud Sync

The app should always use **local-first incident storage**.

### Required flow
1. incident received from brain
2. save locally first
3. mark sync status
4. attempt Firebase upload if internet exists
5. retry automatically later if upload fails or no internet exists

### Suggested sync states
- `pending`
- `synced`
- `failed_retry`

This ensures no critical incident is lost due to connectivity issues.

### Retention policy (v1)
- the app’s default Statistics page uses a **last 30 days** window
- unsynced incidents must remain in local storage until successfully uploaded
- synced incident summaries shown in the app may be limited to 30 days for performance and clarity
- **critical incidents in Firebase should be retained longer than 30 days** because they may be useful for investigation, diagnostics, or insurance-related review

### Recommended v1 retention rule
- keep **all critical incidents** in Firebase, or at least keep them for a much longer archive period than the 30-day score window
- use only the **last 30 days** when calculating score and showing the default Statistics history

---

## 22. Driver Score Model (v1)

The Statistics page may show an overall driver score.

For v1, this should be a **simple, explainable, penalty-based score out of 100**.

### Score window
- use a rolling **last 30 days** window
- do not use lifetime driving history for the main score

### Core principle
Start from 100 and subtract penalties for unsafe events.

```text
Driver Score = 100 - total penalties over last 30 days
```

Clamp the result:
- minimum = 0
- maximum = 100

### Important scoring rule
Use **event clusters**, not raw repeated warning frames.

Examples:
- one sustained front warning should count as **one event**, not many repeated messages
- repeated lane departure detections within a short interval should be grouped into **one lane event cluster**

### Suggested v1 penalty model

#### A. Critical incidents
- each **critical incident**: `-20`

#### B. Warning-level event clusters
- each **warning-level event cluster**: `-8`

#### C. Lane departure frequency
- every **5 lane departure event clusters**: `-5`

#### D. Lean caution frequency
- every **5 lean caution event clusters**: `-4`

#### E. Front approaching frequency
- every **5 front approaching event clusters**: `-4`

#### F. Rear caution frequency
- every **5 rear caution event clusters**: `-3`

### Suggested formula

```text
score = 100
score -= 20 * criticalIncidentCount
score -= 8  * warningClusterCount
score -= 5  * floor(laneDepartureCount / 5)
score -= 4  * floor(leanCautionCount / 5)
score -= 4  * floor(frontApproachingCount / 5)
score -= 3  * floor(rearCautionCount / 5)
score = clamp(score, 0, 100)
```

### Suggested score bands
- **85-100** = Excellent
- **70-84** = Good
- **50-69** = Moderate
- **30-49** = Risky
- **0-29** = Critical

### Suggested Statistics page outputs
- score out of 100
- label band (Excellent / Good / Moderate / Risky / Critical)
- trend over 7 / 30 days
- short explanation of score changes

Example explanation:
- “Frequent lane departures reduced your score this month.”
- “No critical incidents improved your recent score trend.”

### Why this model is recommended for v1
- easy to explain to users
- easy to debug
- not overly dependent on hidden logic
- can be refined later without changing the overall page concept

---

## 23. Brain Responsibilities

The brain is responsible for:
1. storing or applying setup profile data
2. sending config to units
3. recalibration commands
4. warning fusion
5. buzzer control
6. critical incident classification
7. incident record generation
8. local device communication with app

---

## 24. Mobile App Responsibilities

The app is responsible for:
1. account creation and login
2. local Wi-Fi onboarding
3. dashboard display
4. statistics/history UI
5. settings/setup UI
6. local incident storage
7. Firebase sync and retry
8. cloud history retrieval

The app is **not** the final safety decision layer.

---

## 25. Node Responsibilities

### Center Unit
- receive vehicle profile parameters
- recompute critical roll/pitch logic
- execute calibration
- report telemetry

### Front Unit
- receive sensitivity preset
- internally map preset to thresholds
- report telemetry

### Rear Unit
- receive sensitivity preset
- internally map preset to thresholds
- report telemetry

### Lane Unit
- currently outside CAN
- provides lane state to brain
- supports its own calibration flow

---

## 26. Final Summary

### Final top-level navigation
- Dashboard
- Statistics
- Settings

### Dashboard
- one primary fused warning
- landscape-first layout
- left half for 2D vehicle top-view visualization
- right half split into warning panel and warning context panel
- lean dot with target rings at vehicle center
- rear-left / rear-center / rear-right rear zones
- unit online/stale/offline dots in the top bar
- all unit states visually shown

### Statistics
- driver score based on last 30 days
- incident history (default last 30 days)
- incident detail view
- sync status

### Settings
- Vehicle Profile
- Device Connectivity
- Front Sensitivity
- Rear Sensitivity
- Center Calibration
- Guided Setup Wizard
- Alerts Preferences
- System / Reset

### v1 UI/behavior decisions
- only one primary fused warning
- no separate secondary-alert UI
- no dashboard layout preferences
- sound output mode is mutually exclusive:
  - BUZZER
  - IN_APP
  - OFF

This is the current consistent target architecture for the Drivora product.
