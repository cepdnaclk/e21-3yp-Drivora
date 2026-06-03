#include <Arduino.h>
#include "driver/twai.h"
#include "esp_task_wdt.h"
#include "esp_idf_version.h"

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_6;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_7;

const uint32_t FRONT_MAIN_ID  = 0x200;
const uint32_t FRONT_DEBUG_ID = 0x201;
const uint32_t FRONT_CFG_ID   = 0x210;

unsigned long lastCanSendMs = 0;
const unsigned long CAN_SEND_MS = 50;

unsigned long lastDebugSendMs = 0;
const unsigned long DEBUG_SEND_MS = 200;

uint8_t frontCanCounter = 0;
uint8_t frontDebugCounter = 0;

// ================= WATCHDOG =================
const uint32_t WDT_TIMEOUT_S = 5;

// ================= ULTRASONIC PINS =================
#define TRIGPIN_1 3
#define ECHOPIN_1 4

#define TRIGPIN_2 5
#define ECHOPIN_2 2

const unsigned long SENSOR_GAP_MS = 6;

// ================= DISTANCE SETTINGS =================
const float MIN_VALID_CM = 23.0f;
const float MAX_VALID_CM = 250.0f;

// -------- Preset-controlled thresholds --------
float OBJECT_ZONE_CM   = 180.0f;
float WARNING_ZONE_CM  = 80.0f;

// Close / blind-zone related thresholds
float VERY_CLOSE_ZONE_CM      = 25.0f;
float BLIND_ENTRY_TRIGGER_CM  = 24.0f;
float CLEAR_DISTANCE_CM       = 205.0f;

// Suspicious reading logic
const float SUSPICIOUS_JUMP_CM      = 18.0f;
const float BLIND_RELEASE_MIN_CM    = 29.0f;
const int   BLIND_RELEASE_COUNT_REQ = 3;

// Moving-away based blind release
const float BLIND_RELEASE_MOVING_AWAY_CM_S = -6.0f;
const float BLIND_RELEASE_MOVING_AWAY_MIN_CM = 25.0f;

// Fast blind-entry detection
float FAST_BLIND_ARM_CM   = 45.0f;
const float FAST_ENTRY_JUMP_CM  = 12.0f;

// ================= FRONT PRESET =================
uint8_t frontSensitivityPreset = 1; // 0 Near, 1 Normal, 2 Far
uint8_t lastFrontCfgCounter = 0xFF;

// ================= SAMPLING =================
const int sampleSize = 2;
float readings[sampleSize];

// ================= FILTERING =================
const float distanceFilterAlpha = 0.55f;

// ================= SPEED / TREND =================
const float APPROACH_SPEED_CM_S = 8.0f;
const float WARNING_SPEED_CM_S  = 20.0f;
const float SPEED_DEADBAND_CM_S = 2.0f;

// ================= STATE MEMORY =================
const int APPROACH_CONFIRM_COUNT = 1;
const int WARNING_CONFIRM_COUNT  = 1;

const unsigned long BLIND_HOLD_MS   = 1200;
const unsigned long INVALID_HOLD_MS = 650;

// ================= SENSOR / RECOVERY =================
const int INVALID_STREAK_RESET_THRESHOLD = 20;
const unsigned long RECOVERY_COOLDOWN_MS = 1500;

// ================= OUTPUT STATE =================
enum FCWState {
  CLEAR = 0,
  OBJECT_AHEAD = 1,
  APPROACHING = 2,
  WARNING = 3
};

struct SensorChannel {
  float filteredDistance = -1.0f;
  float prevFilteredDistance = -1.0f;

  float closingSpeedCmS = 0.0f;
  float lastValidDistance = -1.0f;
  unsigned long lastValidDistanceMs = 0;

  int approachCounter = 0;
  int warningCounter = 0;

  unsigned long blindHoldUntilMs = 0;
  unsigned long lastValidSeenMs = 0;

  bool blindZoneLatched = false;
  float blindLatchDistance = -1.0f;
  unsigned long blindLatchSetMs = 0;
  int blindReleaseCounter = 0;

  int invalidStreak = 0;
  unsigned long lastRecoveryMs = 0;

  FCWState currentState = CLEAR;
};

SensorChannel sensor1;
SensorChannel sensor2;

// ================= TIMING =================
unsigned long lastLoopMs = 0;

// ================= HELPERS =================
const char* stateName(FCWState s) {
  switch (s) {
    case CLEAR: return "CLEAR";
    case OBJECT_AHEAD: return "OBJECT_AHEAD";
    case APPROACHING: return "APPROACHING";
    case WARNING: return "WARNING";
    default: return "CLEAR";
  }
}

const char* frontPresetName(uint8_t p) {
  switch (p) {
    case 0: return "Near";
    case 1: return "Normal";
    case 2: return "Far";
    default: return "Normal";
  }
}

void applyFrontSensitivityPreset(uint8_t preset) {
  frontSensitivityPreset = constrain((int)preset, 0, 2);

  if (frontSensitivityPreset == 0) {
    // Near
    OBJECT_ZONE_CM        = 150.0f;
    WARNING_ZONE_CM       = 65.0f;
    VERY_CLOSE_ZONE_CM    = 23.0f;
    BLIND_ENTRY_TRIGGER_CM = 23.0f;
    CLEAR_DISTANCE_CM     = 175.0f;
    FAST_BLIND_ARM_CM     = 38.0f;
  } else if (frontSensitivityPreset == 2) {
    // Far
    OBJECT_ZONE_CM        = 210.0f;
    WARNING_ZONE_CM       = 95.0f;
    VERY_CLOSE_ZONE_CM    = 28.0f;
    BLIND_ENTRY_TRIGGER_CM = 25.0f;
    CLEAR_DISTANCE_CM     = 235.0f;
    FAST_BLIND_ARM_CM     = 55.0f;
  } else {
    // Normal
    OBJECT_ZONE_CM        = 180.0f;
    WARNING_ZONE_CM       = 80.0f;
    VERY_CLOSE_ZONE_CM    = 25.0f;
    BLIND_ENTRY_TRIGGER_CM = 24.0f;
    CLEAR_DISTANCE_CM     = 205.0f;
    FAST_BLIND_ARM_CM     = 45.0f;
  }

  Serial.print("Applied front preset: ");
  Serial.println(frontPresetName(frontSensitivityPreset));
  Serial.print("OBJECT_ZONE_CM = "); Serial.println(OBJECT_ZONE_CM, 1);
  Serial.print("WARNING_ZONE_CM = "); Serial.println(WARNING_ZONE_CM, 1);
  Serial.print("VERY_CLOSE_ZONE_CM = "); Serial.println(VERY_CLOSE_ZONE_CM, 1);
  Serial.print("BLIND_ENTRY_TRIGGER_CM = "); Serial.println(BLIND_ENTRY_TRIGGER_CM, 1);
  Serial.print("CLEAR_DISTANCE_CM = "); Serial.println(CLEAR_DISTANCE_CM, 1);
  Serial.print("FAST_BLIND_ARM_CM = "); Serial.println(FAST_BLIND_ARM_CM, 1);
}

void initWatchdog() {
#if ESP_IDF_VERSION_MAJOR >= 5
  esp_task_wdt_config_t twdt_config = {
    .timeout_ms = WDT_TIMEOUT_S * 1000,
    .idle_core_mask = 0,
    .trigger_panic = true
  };
  esp_task_wdt_init(&twdt_config);
#else
  esp_task_wdt_init(WDT_TIMEOUT_S, true);
#endif
  esp_task_wdt_add(NULL);
  Serial.println("Watchdog started");
}

inline void feedWatchdog() {
  esp_task_wdt_reset();
}

uint16_t encodeDistanceX10(float distCm) {
  if (distCm < 0.0f) return 0xFFFF;
  int v = (int)roundf(distCm * 10.0f);
  if (v < 0) v = 0;
  if (v > 65534) v = 65534;
  return (uint16_t)v;
}

int16_t encodeSpeedX10(float speedCmS) {
  int v = (int)roundf(speedCmS * 10.0f);
  if (v < -32768) v = -32768;
  if (v > 32767) v = 32767;
  return (int16_t)v;
}

float minValid2(float a, float b) {
  bool va = (a >= 0.0f);
  bool vb = (b >= 0.0f);
  if (va && vb) return min(a, b);
  if (va) return a;
  if (vb) return b;
  return -1.0f;
}

bool initCAN() {
  twai_general_config_t g_config = TWAI_GENERAL_CONFIG_DEFAULT(CAN_TX_PIN, CAN_RX_PIN, TWAI_MODE_NORMAL);
  twai_timing_config_t  t_config = TWAI_TIMING_CONFIG_500KBITS();
  twai_filter_config_t  f_config = TWAI_FILTER_CONFIG_ACCEPT_ALL();

  esp_err_t err = twai_driver_install(&g_config, &t_config, &f_config);
  if (err != ESP_OK) {
    Serial.printf("TWAI install failed: %d\n", err);
    return false;
  }

  err = twai_start();
  if (err != ESP_OK) {
    Serial.printf("TWAI start failed: %d\n", err);
    return false;
  }

  Serial.println("TWAI started on front node");
  return true;
}

void receiveCANFrames() {
  twai_message_t msg;

  while (twai_receive(&msg, 0) == ESP_OK) {
    if (msg.extd || msg.rtr) continue;

    if (msg.identifier == FRONT_CFG_ID && msg.data_length_code >= 8) {
      uint8_t counter = msg.data[7];
      if (counter == lastFrontCfgCounter) continue;
      lastFrontCfgCounter = counter;

      uint8_t preset = msg.data[0];
      applyFrontSensitivityPreset(preset);

      Serial.print("RX FrontCfg | preset=");
      Serial.println(frontSensitivityPreset);
    }
  }
}

uint8_t buildFrontDebugFlags(
  const SensorChannel& s1,
  const SensorChannel& s2,
  bool suspicious1,
  bool suspicious2,
  bool fastBlind1,
  bool fastBlind2
) {
  uint8_t flags = 0;
  if (s1.blindZoneLatched || s2.blindZoneLatched) flags |= (1 << 0);
  if (suspicious1 || suspicious2)                flags |= (1 << 1);
  if (fastBlind1 || fastBlind2)                  flags |= (1 << 2);
  if (s1.filteredDistance < 0.0f && s2.filteredDistance < 0.0f) flags |= (1 << 3);
  return flags;
}

void sendFrontMainFrame(unsigned long nowMs, float rawDistance, float smoothedDistance, float fusedSpeed, FCWState fusedState) {
  if (nowMs - lastCanSendMs < CAN_SEND_MS) return;
  lastCanSendMs = nowMs;

  uint16_t filtered_x10 = encodeDistanceX10(smoothedDistance);
  int16_t  speed_x10    = encodeSpeedX10(fusedSpeed);
  uint16_t raw_x10      = encodeDistanceX10(rawDistance);

  twai_message_t msg = {};
  msg.identifier = FRONT_MAIN_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)fusedState;
  msg.data[1] = (uint8_t)(filtered_x10 & 0xFF);
  msg.data[2] = (uint8_t)((filtered_x10 >> 8) & 0xFF);
  msg.data[3] = (uint8_t)(speed_x10 & 0xFF);
  msg.data[4] = (uint8_t)((speed_x10 >> 8) & 0xFF);
  msg.data[5] = (uint8_t)(raw_x10 & 0xFF);
  msg.data[6] = (uint8_t)((raw_x10 >> 8) & 0xFF);
  msg.data[7] = frontCanCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN MAIN TX | state=");
    Serial.print((int)fusedState);
    Serial.print(" filtered=");
    Serial.print(smoothedDistance, 1);
    Serial.print(" raw=");
    Serial.print(rawDistance, 1);
    Serial.print(" speed=");
    Serial.println(fusedSpeed, 1);
  }
}

void sendFrontDebugFrame(
  unsigned long nowMs,
  const SensorChannel& s1,
  const SensorChannel& s2,
  bool suspicious1,
  bool suspicious2,
  bool fastBlind1,
  bool fastBlind2
) {
  if (nowMs - lastDebugSendMs < DEBUG_SEND_MS) return;
  lastDebugSendMs = nowMs;

  uint8_t flags = buildFrontDebugFlags(s1, s2, suspicious1, suspicious2, fastBlind1, fastBlind2);

  twai_message_t msg = {};
  msg.identifier = FRONT_DEBUG_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = flags;
  msg.data[1] = (uint8_t)max(s1.approachCounter, s2.approachCounter);
  msg.data[2] = (uint8_t)max(s1.warningCounter, s2.warningCounter);
  msg.data[3] = (uint8_t)max(s1.blindReleaseCounter, s2.blindReleaseCounter);
  msg.data[4] = (uint8_t)max(s1.invalidStreak, s2.invalidStreak);
  msg.data[5] = frontSensitivityPreset; // helpful debug
  msg.data[6] = 0;
  msg.data[7] = frontDebugCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN DEBUG TX | flags=0x");
    Serial.print(flags, HEX);
    Serial.print(" approach=");
    Serial.print(max(s1.approachCounter, s2.approachCounter));
    Serial.print(" warning=");
    Serial.print(max(s1.warningCounter, s2.warningCounter));
    Serial.print(" blindRelease=");
    Serial.print(max(s1.blindReleaseCounter, s2.blindReleaseCounter));
    Serial.print(" invalid=");
    Serial.print(max(s1.invalidStreak, s2.invalidStreak));
    Serial.print(" preset=");
    Serial.println(frontSensitivityPreset);
  }
}

void resetSensorState(SensorChannel& s, int trigPin) {
  s.filteredDistance = -1.0f;
  s.prevFilteredDistance = -1.0f;
  s.closingSpeedCmS = 0.0f;
  s.lastValidDistance = -1.0f;
  s.lastValidDistanceMs = millis();

  s.approachCounter = 0;
  s.warningCounter = 0;

  s.blindZoneLatched = false;
  s.blindLatchDistance = -1.0f;
  s.blindLatchSetMs = 0;
  s.blindReleaseCounter = 0;
  s.blindHoldUntilMs = 0;

  digitalWrite(trigPin, LOW);
}

// ================= READ DISTANCE =================
float readQualityDistanceCm(int trigPin, int echoPin) {
  int validCount = 0;

  for (int i = 0; i < sampleSize; i++) {
    digitalWrite(trigPin, LOW);
    delayMicroseconds(5);
    digitalWrite(trigPin, HIGH);
    delayMicroseconds(20);
    digitalWrite(trigPin, LOW);

    long duration = pulseIn(echoPin, HIGH, 18000);

    if (duration > 0) {
      readings[validCount] = duration / 58.2f;
      validCount++;
    }

    delay(5);
    yield();
    feedWatchdog();
  }

  if (validCount == 0) return -1.0f;

  for (int i = 0; i < validCount - 1; i++) {
    for (int j = i + 1; j < validCount; j++) {
      if (readings[i] > readings[j]) {
        float temp = readings[i];
        readings[i] = readings[j];
        readings[j] = temp;
      }
    }
  }

  float medianDistance = readings[validCount / 2];

  if (medianDistance < MIN_VALID_CM || medianDistance > MAX_VALID_CM) {
    return -1.0f;
  }

  return medianDistance;
}

// ================= FILTER =================
float updateFilteredDistance(SensorChannel& s, float rawDistance) {
  if (rawDistance < 0) {
    s.filteredDistance = -1.0f;
    return -1.0f;
  }

  if (s.filteredDistance < 0) {
    s.filteredDistance = rawDistance;
  } else {
    s.filteredDistance =
      distanceFilterAlpha * rawDistance +
      (1.0f - distanceFilterAlpha) * s.filteredDistance;
  }

  return s.filteredDistance;
}

// ================= SPEED ESTIMATION =================
void updateClosingSpeed(SensorChannel& s, float dist, unsigned long nowMs) {
  if (dist < 0) {
    s.closingSpeedCmS = 0.0f;
    return;
  }

  if (s.lastValidDistance < 0.0f) {
    s.lastValidDistance = dist;
    s.lastValidDistanceMs = nowMs;
    s.closingSpeedCmS = 0.0f;
    return;
  }

  float dt = (nowMs - s.lastValidDistanceMs) / 1000.0f;
  if (dt <= 0.0f) {
    s.closingSpeedCmS = 0.0f;
    return;
  }

  float rawSpeed = (s.lastValidDistance - dist) / dt;
  s.closingSpeedCmS = 0.65f * s.closingSpeedCmS + 0.35f * rawSpeed;

  if (fabs(s.closingSpeedCmS) < SPEED_DEADBAND_CM_S) {
    s.closingSpeedCmS = 0.0f;
  }

  s.lastValidDistance = dist;
  s.lastValidDistanceMs = nowMs;
}

bool isSuspiciousReading(const SensorChannel& s, float dist) {
  if (dist < 0.0f) return true;
  if (!s.blindZoneLatched) return false;
  if (s.blindLatchDistance < 0.0f) return false;

  if (fabs(dist - s.blindLatchDistance) > SUSPICIOUS_JUMP_CM && dist < BLIND_RELEASE_MIN_CM) {
    return true;
  }

  if (dist <= BLIND_RELEASE_MIN_CM && s.closingSpeedCmS > -2.0f) {
    return true;
  }

  return false;
}

void latchBlindZone(SensorChannel& s, unsigned long nowMs, float refDist) {
  s.blindZoneLatched = true;
  s.blindLatchSetMs = nowMs;
  s.blindLatchDistance = refDist;
  s.blindReleaseCounter = 0;
  s.blindHoldUntilMs = nowMs + BLIND_HOLD_MS;
}

// ================= FAST BLIND-ENTRY DETECTOR =================
bool shouldFastLatchBlindZone(const SensorChannel& s, float rawDist, float filteredDist) {
  if (s.blindZoneLatched) return false;
  if (s.lastValidDistance < 0.0f) return false;

  bool wasClose = (s.lastValidDistance <= FAST_BLIND_ARM_CM);
  if (!wasClose) return false;

  bool invalidNow = (filteredDist < 0.0f);

  bool suspiciousNow = false;
  if (rawDist > 0.0f) {
    bool erraticNearBlind = (rawDist <= BLIND_ENTRY_TRIGGER_CM);
    bool suddenJumpTowardBlind = ((s.lastValidDistance - rawDist) >= FAST_ENTRY_JUMP_CM) && (rawDist <= VERY_CLOSE_ZONE_CM);
    suspiciousNow = erraticNearBlind || suddenJumpTowardBlind;
  } else {
    suspiciousNow = true;
  }

  return invalidNow || suspiciousNow;
}

// ================= SMART FCW LOGIC =================
void updateFCWState(SensorChannel& s, float rawDist, float dist, unsigned long nowMs) {
  if (shouldFastLatchBlindZone(s, rawDist, dist)) {
    latchBlindZone(s, nowMs, s.lastValidDistance);
    s.currentState = WARNING;
    return;
  }

  bool distValid = (dist >= 0.0f);
  bool suspicious = isSuspiciousReading(s, dist);

  if (distValid && !suspicious) {
    s.lastValidSeenMs = nowMs;

    bool approachingNow = (s.closingSpeedCmS >= APPROACH_SPEED_CM_S);
    bool warningSpeedNow = (s.closingSpeedCmS >= WARNING_SPEED_CM_S);

    if (approachingNow) {
      if (s.approachCounter < APPROACH_CONFIRM_COUNT) s.approachCounter++;
    } else {
      if (s.approachCounter > 0) s.approachCounter--;
    }

    if (warningSpeedNow) {
      if (s.warningCounter < WARNING_CONFIRM_COUNT) s.warningCounter++;
    } else {
      if (s.warningCounter > 0) s.warningCounter--;
    }

    bool confirmedApproaching = (s.approachCounter >= APPROACH_CONFIRM_COUNT);
    bool confirmedWarningSpeed = (s.warningCounter >= WARNING_CONFIRM_COUNT);

    if (dist <= BLIND_ENTRY_TRIGGER_CM && s.closingSpeedCmS > 0.5f) {
      latchBlindZone(s, nowMs, dist);
    }

    if (s.blindZoneLatched) {
      bool distanceRelease = (dist >= BLIND_RELEASE_MIN_CM);
      bool movingAwayRelease = (s.closingSpeedCmS <= BLIND_RELEASE_MOVING_AWAY_CM_S &&
                                dist >= BLIND_RELEASE_MOVING_AWAY_MIN_CM);

      if (distanceRelease || movingAwayRelease) {
        s.blindReleaseCounter++;
      } else {
        s.blindReleaseCounter = 0;
      }

      if (s.blindReleaseCounter >= BLIND_RELEASE_COUNT_REQ) {
        s.blindZoneLatched = false;
        s.blindReleaseCounter = 0;
        s.blindLatchDistance = -1.0f;
      } else {
        s.currentState = WARNING;
        return;
      }
    }

    if (dist <= WARNING_ZONE_CM && confirmedWarningSpeed) {
      s.currentState = WARNING;
      if (dist <= BLIND_ENTRY_TRIGGER_CM) {
        latchBlindZone(s, nowMs, dist);
      }
      return;
    }

    if (dist <= VERY_CLOSE_ZONE_CM) {
      if (confirmedWarningSpeed || s.closingSpeedCmS >= (WARNING_SPEED_CM_S * 0.7f)) {
        s.currentState = WARNING;
        if (dist <= BLIND_ENTRY_TRIGGER_CM) {
          latchBlindZone(s, nowMs, dist);
        }
        return;
      }

      if (confirmedApproaching) {
        s.currentState = APPROACHING;
      } else {
        s.currentState = OBJECT_AHEAD;
      }
      return;
    }

    if (dist <= OBJECT_ZONE_CM && confirmedApproaching) {
      s.currentState = APPROACHING;
      return;
    }

    if (dist <= OBJECT_ZONE_CM) {
      s.currentState = OBJECT_AHEAD;
      return;
    }

    if (dist >= CLEAR_DISTANCE_CM) {
      s.currentState = CLEAR;
    } else {
      s.currentState = OBJECT_AHEAD;
    }

    return;
  }

  if (!s.blindZoneLatched && s.prevFilteredDistance > 0.0f &&
      s.prevFilteredDistance <= BLIND_ENTRY_TRIGGER_CM &&
      s.closingSpeedCmS > 0.5f) {
    latchBlindZone(s, nowMs, s.prevFilteredDistance);
  }

  if (s.blindZoneLatched) {
    s.currentState = WARNING;
    return;
  }

  if (nowMs < s.blindHoldUntilMs) {
    s.currentState = WARNING;
    return;
  }

  if ((nowMs - s.lastValidSeenMs) <= INVALID_HOLD_MS) {
    if (s.currentState == APPROACHING || s.currentState == WARNING) {
      s.currentState = APPROACHING;
    } else if (s.currentState == OBJECT_AHEAD) {
      s.currentState = OBJECT_AHEAD;
    } else {
      s.currentState = CLEAR;
    }
    return;
  }

  s.currentState = CLEAR;
  s.approachCounter = 0;
  s.warningCounter = 0;
  s.prevFilteredDistance = -1.0f;
}

// ================= SETUP =================
void setup() {
  Serial.begin(9600);

  pinMode(TRIGPIN_1, OUTPUT);
  pinMode(ECHOPIN_1, INPUT);

  pinMode(TRIGPIN_2, OUTPUT);
  pinMode(ECHOPIN_2, INPUT);

  digitalWrite(TRIGPIN_1, LOW);
  digitalWrite(TRIGPIN_2, LOW);
  delay(1000);

  initCAN();
  initWatchdog();
  applyFrontSensitivityPreset(frontSensitivityPreset);

  lastLoopMs = millis();
  sensor1.lastValidDistanceMs = millis();
  sensor2.lastValidDistanceMs = millis();

  Serial.println("Ultrasonic Array FCW CAN Node Started");
}

// ================= LOOP =================
void loop() {
  feedWatchdog();
  receiveCANFrames();

  unsigned long nowMs = millis();

  // -------- Sensor 1 --------
  float rawDistance1 = readQualityDistanceCm(TRIGPIN_1, ECHOPIN_1);
  float smoothedDistance1 = updateFilteredDistance(sensor1, rawDistance1);

  if (rawDistance1 < 0) sensor1.invalidStreak++;
  else sensor1.invalidStreak = 0;

  if (sensor1.invalidStreak >= INVALID_STREAK_RESET_THRESHOLD &&
      (nowMs - sensor1.lastRecoveryMs) > RECOVERY_COOLDOWN_MS &&
      !sensor1.blindZoneLatched &&
      sensor1.currentState != WARNING) {
    resetSensorState(sensor1, TRIGPIN_1);
    sensor1.lastRecoveryMs = nowMs;
    sensor1.invalidStreak = 0;
  }

  updateClosingSpeed(sensor1, smoothedDistance1, nowMs);
  bool suspicious1 = isSuspiciousReading(sensor1, smoothedDistance1);
  bool fastBlind1 = shouldFastLatchBlindZone(sensor1, rawDistance1, smoothedDistance1);
  updateFCWState(sensor1, rawDistance1, smoothedDistance1, nowMs);

  delay(SENSOR_GAP_MS);
  feedWatchdog();

  // -------- Sensor 2 --------
  nowMs = millis();

  float rawDistance2 = readQualityDistanceCm(TRIGPIN_2, ECHOPIN_2);
  float smoothedDistance2 = updateFilteredDistance(sensor2, rawDistance2);

  if (rawDistance2 < 0) sensor2.invalidStreak++;
  else sensor2.invalidStreak = 0;

  if (sensor2.invalidStreak >= INVALID_STREAK_RESET_THRESHOLD &&
      (nowMs - sensor2.lastRecoveryMs) > RECOVERY_COOLDOWN_MS &&
      !sensor2.blindZoneLatched &&
      sensor2.currentState != WARNING) {
    resetSensorState(sensor2, TRIGPIN_2);
    sensor2.lastRecoveryMs = nowMs;
    sensor2.invalidStreak = 0;
  }

  updateClosingSpeed(sensor2, smoothedDistance2, nowMs);
  bool suspicious2 = isSuspiciousReading(sensor2, smoothedDistance2);
  bool fastBlind2 = shouldFastLatchBlindZone(sensor2, rawDistance2, smoothedDistance2);
  updateFCWState(sensor2, rawDistance2, smoothedDistance2, nowMs);

  // -------- Fusion --------
  bool anyBlindWarning =
    (sensor1.blindZoneLatched && sensor1.currentState == WARNING) ||
    (sensor2.blindZoneLatched && sensor2.currentState == WARNING);

  float fusedRawDistance;
  float fusedFilteredDistance;

  if (anyBlindWarning) {
    fusedRawDistance = -1.0f;
    fusedFilteredDistance = -1.0f;
  } else {
    fusedRawDistance = minValid2(rawDistance1, rawDistance2);
    fusedFilteredDistance = minValid2(smoothedDistance1, smoothedDistance2);
  }

  float fusedSpeed = max(sensor1.closingSpeedCmS, sensor2.closingSpeedCmS);
  FCWState fusedState = (FCWState)max((int)sensor1.currentState, (int)sensor2.currentState);

  sendFrontMainFrame(nowMs, fusedRawDistance, fusedFilteredDistance, fusedSpeed, fusedState);
  sendFrontDebugFrame(nowMs, sensor1, sensor2, suspicious1, suspicious2, fastBlind1, fastBlind2);

  float loopMs = (float)(nowMs - lastLoopMs);
  lastLoopMs = nowMs;

  Serial.print("Preset=");
  Serial.print(frontPresetName(frontSensitivityPreset));

  Serial.print(" | S1 raw=");
  if (rawDistance1 < 0) Serial.print("Invalid");
  else Serial.print(rawDistance1, 1);

  Serial.print(" filt=");
  if (smoothedDistance1 < 0) Serial.print("Invalid");
  else Serial.print(smoothedDistance1, 1);

  Serial.print(" state=");
  Serial.print(stateName(sensor1.currentState));

  Serial.print(" | S2 raw=");
  if (rawDistance2 < 0) Serial.print("Invalid");
  else Serial.print(rawDistance2, 1);

  Serial.print(" filt=");
  if (smoothedDistance2 < 0) Serial.print("Invalid");
  else Serial.print(smoothedDistance2, 1);

  Serial.print(" state=");
  Serial.print(stateName(sensor2.currentState));

  Serial.print(" | Fused raw=");
  if (fusedRawDistance < 0) Serial.print("Invalid");
  else Serial.print(fusedRawDistance, 1);

  Serial.print(" filt=");
  if (fusedFilteredDistance < 0) Serial.print("Invalid");
  else Serial.print(fusedFilteredDistance, 1);

  Serial.print(" speed=");
  Serial.print(fusedSpeed, 1);
  Serial.print(" state=");
  Serial.print(stateName(fusedState));
  Serial.print(" | Loop: ");
  Serial.println(loopMs, 0);

  feedWatchdog();
}