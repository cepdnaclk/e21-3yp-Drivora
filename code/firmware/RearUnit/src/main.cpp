#include <Arduino.h>
#include "driver/twai.h"

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_6;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_7;

const uint32_t REAR_MAIN_ID  = 0x300;
const uint32_t REAR_DEBUG_ID = 0x301;
const uint32_t REAR_DIST_ID  = 0x302;

unsigned long lastMainSendMs = 0;
const unsigned long MAIN_SEND_MS = 50;

unsigned long lastDistSendMs = 0;
const unsigned long DIST_SEND_MS = 50;

unsigned long lastDebugSendMs = 0;
const unsigned long DEBUG_SEND_MS = 200;

uint8_t rearMainCounter  = 0;
uint8_t rearDistCounter  = 0;
uint8_t rearDebugCounter = 0;

// ================= ULTRASONIC PINS =================
#define TRIG_LEFT    5
#define ECHO_LEFT    0

#define TRIG_CENTER  3
#define ECHO_CENTER  4

#define TRIG_RIGHT   2
#define ECHO_RIGHT   1

const unsigned long SENSOR_GAP_MS = 3;

// ================= DISTANCE SETTINGS =================
const float MIN_VALID_CM = 23.0f;
const float MAX_VALID_CM = 250.0f;

const float OBJECT_DETECTED_CM = 120.0f;
const float CAUTION_CM         = 50.0f;
const float WARNING_CM         = 30.0f;

// ================= STATE HYSTERESIS =================
const float OBJECT_DETECTED_EXIT_CM = 128.0f;
const float CAUTION_EXIT_CM         = 56.0f;

// ================= REAR WARNING LATCH =================
const float WARNING_LATCH_ENTRY_CM   = 30.0f;
const float WARNING_LATCH_RELEASE_CM = 34.0f;
const int   WARNING_LATCH_RELEASE_CONFIRM = 3;
const float FAST_WARNING_RELEASE_CM  = 37.0f;
const int   FAST_WARNING_RELEASE_CONFIRM = 2;

// ================= FAST WARNING ENTRY =================
const float FAST_WARNING_ARM_CM   = 45.0f;
const float FAST_ENTRY_JUMP_CM    = 12.0f;
const unsigned long FAST_WARNING_MEMORY_MS = 800;

// ================= CORE STABILITY =================
const float RELEASE_SUSPICIOUS_JUMP_CM = 18.0f;
const unsigned long RECENT_VALID_MEMORY_MS = 800;

// ================= SAMPLING =================
const int sampleSize = 2;
float readings[sampleSize];

// ================= FILTERING =================
const float distanceFilterAlpha = 0.55f;

// ================= SENSOR / RECOVERY =================
const int INVALID_STREAK_RESET_THRESHOLD = 20;
const unsigned long RECOVERY_COOLDOWN_MS = 1500;

// ================= OUTPUT STATE =================
enum RearState {
  CLEAR = 0,
  OBJECT_DETECTED = 1,
  CAUTION = 2,
  WARNING = 3
};

struct SensorChannel {
  int trigPin = -1;
  int echoPin = -1;

  float rawDistance = -1.0f;
  float filteredDistance = -1.0f;

  int invalidStreak = 0;
  unsigned long lastRecoveryMs = 0;

  bool warningLatched = false;
  int warningReleaseCounter = 0;
  int fastWarningReleaseCounter = 0;

  unsigned long lastValidSeenMs = 0;
  float lastValidDistance = -1.0f;
  unsigned long lastValidDistanceMs = 0;
  float lastLatchedCloseDistance = -1.0f;

  bool suspiciousLatched = false;
  bool fastWarningTriggered = false;

  RearState currentState = CLEAR;
};

SensorChannel leftSensor;
SensorChannel centerSensor;
SensorChannel rightSensor;

// ================= TIMING =================
unsigned long lastLoopMs = 0;

// ================= HELPERS =================
const char* stateName(RearState s) {
  switch (s) {
    case CLEAR: return "CLEAR";
    case OBJECT_DETECTED: return "OBJECT_DETECTED";
    case CAUTION: return "CAUTION";
    case WARNING: return "WARNING";
    default: return "CLEAR";
  }
}

uint16_t encodeDistanceX10(float distCm) {
  if (distCm < 0.0f) return 0xFFFF;
  int v = (int)roundf(distCm * 10.0f);
  if (v < 0) v = 0;
  if (v > 65534) v = 65534;
  return (uint16_t)v;
}

uint8_t buildRearFlags(const SensorChannel& s) {
  uint8_t flags = 0;
  if (s.warningLatched)       flags |= (1 << 0);
  if (s.suspiciousLatched)    flags |= (1 << 1);
  if (s.fastWarningTriggered) flags |= (1 << 2);
  if (s.filteredDistance < 0) flags |= (1 << 3);
  return flags;
}

RearState overallRearState() {
  int m = max((int)leftSensor.currentState, max((int)centerSensor.currentState, (int)rightSensor.currentState));
  return (RearState)m;
}

uint8_t nearestSensorIndex() {
  float dl = leftSensor.filteredDistance;
  float dc = centerSensor.filteredDistance;
  float dr = rightSensor.filteredDistance;

  bool vl = (dl >= 0.0f);
  bool vc = (dc >= 0.0f);
  bool vr = (dr >= 0.0f);

  if (!vl && !vc && !vr) return 0;

  float best = 1e9f;
  uint8_t idx = 0;

  if (vl && dl < best) { best = dl; idx = 1; }
  if (vc && dc < best) { best = dc; idx = 2; }
  if (vr && dr < best) { best = dr; idx = 3; }

  return idx;
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

  Serial.println("TWAI started on rear node");
  return true;
}

void sendRearMainFrame(unsigned long nowMs) {
  if (nowMs - lastMainSendMs < MAIN_SEND_MS) return;
  lastMainSendMs = nowMs;

  twai_message_t msg = {};
  msg.identifier = REAR_MAIN_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)leftSensor.currentState;
  msg.data[1] = (uint8_t)centerSensor.currentState;
  msg.data[2] = (uint8_t)rightSensor.currentState;
  msg.data[3] = buildRearFlags(leftSensor);
  msg.data[4] = buildRearFlags(centerSensor);
  msg.data[5] = buildRearFlags(rightSensor);
  msg.data[6] = (uint8_t)overallRearState();
  msg.data[7] = rearMainCounter++;

  twai_transmit(&msg, 0);
}

void sendRearDistanceFrame(unsigned long nowMs) {
  if (nowMs - lastDistSendMs < DIST_SEND_MS) return;
  lastDistSendMs = nowMs;

  uint16_t left_x10   = encodeDistanceX10(leftSensor.filteredDistance);
  uint16_t center_x10 = encodeDistanceX10(centerSensor.filteredDistance);
  uint16_t right_x10  = encodeDistanceX10(rightSensor.filteredDistance);

  twai_message_t msg = {};
  msg.identifier = REAR_DIST_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)(left_x10 & 0xFF);
  msg.data[1] = (uint8_t)((left_x10 >> 8) & 0xFF);
  msg.data[2] = (uint8_t)(center_x10 & 0xFF);
  msg.data[3] = (uint8_t)((center_x10 >> 8) & 0xFF);
  msg.data[4] = (uint8_t)(right_x10 & 0xFF);
  msg.data[5] = (uint8_t)((right_x10 >> 8) & 0xFF);
  msg.data[6] = nearestSensorIndex();
  msg.data[7] = rearDistCounter++;

  twai_transmit(&msg, 0);
}

void sendRearDebugFrame(unsigned long nowMs) {
  if (nowMs - lastDebugSendMs < DEBUG_SEND_MS) return;
  lastDebugSendMs = nowMs;

  uint8_t maxInvalid = max(leftSensor.invalidStreak, max(centerSensor.invalidStreak, rightSensor.invalidStreak));

  twai_message_t msg = {};
  msg.identifier = REAR_DEBUG_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)leftSensor.warningReleaseCounter;
  msg.data[1] = (uint8_t)centerSensor.warningReleaseCounter;
  msg.data[2] = (uint8_t)rightSensor.warningReleaseCounter;
  msg.data[3] = (uint8_t)leftSensor.fastWarningReleaseCounter;
  msg.data[4] = (uint8_t)centerSensor.fastWarningReleaseCounter;
  msg.data[5] = (uint8_t)rightSensor.fastWarningReleaseCounter;
  msg.data[6] = maxInvalid;
  msg.data[7] = rearDebugCounter++;

  twai_transmit(&msg, 0);
}

void resetSensorState(SensorChannel& s) {
  s.rawDistance = -1.0f;
  s.filteredDistance = -1.0f;
  s.invalidStreak = 0;
  s.warningLatched = false;
  s.warningReleaseCounter = 0;
  s.fastWarningReleaseCounter = 0;
  s.lastValidSeenMs = millis();
  s.lastValidDistance = -1.0f;
  s.lastValidDistanceMs = millis();
  s.lastLatchedCloseDistance = -1.0f;
  s.suspiciousLatched = false;
  s.fastWarningTriggered = false;
  digitalWrite(s.trigPin, LOW);
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

    long duration = pulseIn(echoPin, HIGH, 15000);

    if (duration > 0) {
      readings[validCount] = duration / 58.2f;
      validCount++;
    }

    delay(3);
    yield();
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

// ================= VALID DISTANCE MEMORY =================
void updateLastValidDistance(SensorChannel& s, float dist, unsigned long nowMs) {
  if (dist < 0.0f) return;
  s.lastValidDistance = dist;
  s.lastValidDistanceMs = nowMs;
  s.lastValidSeenMs = nowMs;
}

// ================= CORE STABILITY HELPERS =================
bool isRecentValidMemoryAvailable(const SensorChannel& s, unsigned long nowMs) {
  if (s.lastValidDistance < 0.0f) return false;
  return (nowMs - s.lastValidDistanceMs) <= RECENT_VALID_MEMORY_MS;
}

bool isSuspiciousReadingWhileLatched(const SensorChannel& s, float rawDist, float dist, unsigned long nowMs) {
  if (!s.warningLatched) return false;

  if (dist < 0.0f) return true;

  if (dist >= FAST_WARNING_RELEASE_CM) return false;

  bool nearBlindArea = (dist <= WARNING_LATCH_RELEASE_CM);

  bool jumpFromLatchedClose = false;
  if (s.lastLatchedCloseDistance >= 0.0f) {
    jumpFromLatchedClose = fabs(dist - s.lastLatchedCloseDistance) >= RELEASE_SUSPICIOUS_JUMP_CM;
  }

  bool jumpFromRecentValid = false;
  if (isRecentValidMemoryAvailable(s, nowMs) && s.lastValidDistance >= 0.0f) {
    jumpFromRecentValid = fabs(dist - s.lastValidDistance) >= RELEASE_SUSPICIOUS_JUMP_CM;
  }

  bool rawLooksBlindish = false;
  if (rawDist > 0.0f) {
    rawLooksBlindish = (rawDist <= WARNING_LATCH_ENTRY_CM);
  }

  return nearBlindArea || rawLooksBlindish || jumpFromLatchedClose || jumpFromRecentValid;
}

// ================= FAST WARNING ENTRY DETECTOR =================
bool shouldFastLatchWarning(const SensorChannel& s, float rawDist, float filteredDist, unsigned long nowMs) {
  if (s.warningLatched) return false;
  if (s.lastValidDistance < 0.0f) return false;
  if ((nowMs - s.lastValidDistanceMs) > FAST_WARNING_MEMORY_MS) return false;

  bool wasClose = (s.lastValidDistance <= FAST_WARNING_ARM_CM);
  if (!wasClose) return false;

  bool invalidNow = (filteredDist < 0.0f);

  bool suspiciousNow = false;
  if (rawDist > 0.0f) {
    bool erraticNearBlind = (rawDist <= WARNING_LATCH_ENTRY_CM);
    bool suddenJumpTowardBlind =
      ((s.lastValidDistance - rawDist) >= FAST_ENTRY_JUMP_CM) &&
      (rawDist <= CAUTION_CM);
    suspiciousNow = erraticNearBlind || suddenJumpTowardBlind;
  } else {
    suspiciousNow = true;
  }

  return invalidNow || suspiciousNow;
}

// ================= REAR STATE LOGIC =================
void updateRearState(SensorChannel& s, float rawDist, float dist, unsigned long nowMs) {
  s.fastWarningTriggered = shouldFastLatchWarning(s, rawDist, dist, nowMs);
  s.suspiciousLatched = false;

  if (s.fastWarningTriggered) {
    s.warningLatched = true;
    s.warningReleaseCounter = 0;
    s.fastWarningReleaseCounter = 0;
    s.lastLatchedCloseDistance = s.lastValidDistance;
    s.currentState = WARNING;
    return;
  }

  if (dist >= 0.0f) {
    if (dist <= WARNING_LATCH_ENTRY_CM) {
      s.warningLatched = true;
      s.warningReleaseCounter = 0;
      s.fastWarningReleaseCounter = 0;
      s.lastLatchedCloseDistance = dist;
    }

    if (s.warningLatched) {
      s.suspiciousLatched = isSuspiciousReadingWhileLatched(s, rawDist, dist, nowMs);

      if (s.suspiciousLatched) {
        s.warningReleaseCounter = 0;
        s.fastWarningReleaseCounter = 0;
        s.currentState = WARNING;
        return;
      }

      if (dist >= FAST_WARNING_RELEASE_CM) {
        s.fastWarningReleaseCounter++;
      } else {
        s.fastWarningReleaseCounter = 0;
      }

      if (s.fastWarningReleaseCounter >= FAST_WARNING_RELEASE_CONFIRM) {
        s.warningLatched = false;
        s.warningReleaseCounter = 0;
        s.fastWarningReleaseCounter = 0;
        s.lastLatchedCloseDistance = -1.0f;
      } else if (dist >= WARNING_LATCH_RELEASE_CM) {
        s.warningReleaseCounter++;
      } else {
        s.warningReleaseCounter = 0;
      }

      if (s.warningLatched && s.warningReleaseCounter >= WARNING_LATCH_RELEASE_CONFIRM) {
        s.warningLatched = false;
        s.warningReleaseCounter = 0;
        s.fastWarningReleaseCounter = 0;
        s.lastLatchedCloseDistance = -1.0f;
      } else if (s.warningLatched) {
        s.currentState = WARNING;
        return;
      }
    }

    if (dist <= WARNING_CM) {
      s.currentState = WARNING;
    } else if (dist <= CAUTION_CM) {
      s.currentState = CAUTION;
    } else if (s.currentState == CAUTION && dist <= CAUTION_EXIT_CM) {
      s.currentState = CAUTION;
    } else if (dist <= OBJECT_DETECTED_CM) {
      s.currentState = OBJECT_DETECTED;
    } else if (s.currentState == OBJECT_DETECTED && dist <= OBJECT_DETECTED_EXIT_CM) {
      s.currentState = OBJECT_DETECTED;
    } else {
      s.currentState = CLEAR;
    }

    return;
  }

  if (s.warningLatched) {
    s.warningReleaseCounter = 0;
    s.fastWarningReleaseCounter = 0;
    s.currentState = WARNING;
    return;
  }

  if (isRecentValidMemoryAvailable(s, nowMs) && s.lastValidDistance <= WARNING_LATCH_ENTRY_CM) {
    s.warningLatched = true;
    s.warningReleaseCounter = 0;
    s.fastWarningReleaseCounter = 0;
    s.lastLatchedCloseDistance = s.lastValidDistance;
    s.currentState = WARNING;
    return;
  }

  s.currentState = CLEAR;
}

// ================= SENSOR PROCESSING =================
void processSensor(SensorChannel& s, unsigned long nowMs) {
  s.rawDistance = readQualityDistanceCm(s.trigPin, s.echoPin);
  float smoothedDistance = updateFilteredDistance(s, s.rawDistance);

  if (s.rawDistance < 0) s.invalidStreak++;
  else s.invalidStreak = 0;

  if (s.invalidStreak >= INVALID_STREAK_RESET_THRESHOLD &&
      (nowMs - s.lastRecoveryMs) > RECOVERY_COOLDOWN_MS &&
      !s.warningLatched &&
      s.currentState != WARNING) {
    resetSensorState(s);
    s.lastRecoveryMs = nowMs;
    s.invalidStreak = 0;
  }

  updateRearState(s, s.rawDistance, smoothedDistance, nowMs);
  updateLastValidDistance(s, smoothedDistance, nowMs);
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  leftSensor.trigPin = TRIG_LEFT;
  leftSensor.echoPin = ECHO_LEFT;

  centerSensor.trigPin = TRIG_CENTER;
  centerSensor.echoPin = ECHO_CENTER;

  rightSensor.trigPin = TRIG_RIGHT;
  rightSensor.echoPin = ECHO_RIGHT;

  pinMode(leftSensor.trigPin, OUTPUT);
  pinMode(leftSensor.echoPin, INPUT);

  pinMode(centerSensor.trigPin, OUTPUT);
  pinMode(centerSensor.echoPin, INPUT);

  pinMode(rightSensor.trigPin, OUTPUT);
  pinMode(rightSensor.echoPin, INPUT);

  digitalWrite(leftSensor.trigPin, LOW);
  digitalWrite(centerSensor.trigPin, LOW);
  digitalWrite(rightSensor.trigPin, LOW);

  delay(1000);

  initCAN();

  lastLoopMs = millis();
  leftSensor.lastValidSeenMs = millis();
  leftSensor.lastValidDistanceMs = millis();
  centerSensor.lastValidSeenMs = millis();
  centerSensor.lastValidDistanceMs = millis();
  rightSensor.lastValidSeenMs = millis();
  rightSensor.lastValidDistanceMs = millis();

  Serial.println("Rear ultrasonic array CAN node started");
}

// ================= LOOP =================
void loop() {
  unsigned long nowMs = millis();

  processSensor(leftSensor, nowMs);
  delay(SENSOR_GAP_MS);

  nowMs = millis();
  processSensor(centerSensor, nowMs);
  delay(SENSOR_GAP_MS);

  nowMs = millis();
  processSensor(rightSensor, nowMs);

  sendRearMainFrame(nowMs);
  sendRearDistanceFrame(nowMs);
  sendRearDebugFrame(nowMs);

  float loopMs = (float)(nowMs - lastLoopMs);
  lastLoopMs = nowMs;

  Serial.print("L raw=");
  if (leftSensor.rawDistance < 0) Serial.print("Invalid");
  else Serial.print(leftSensor.rawDistance, 1);
  Serial.print(" filt=");
  if (leftSensor.filteredDistance < 0) Serial.print("Invalid");
  else Serial.print(leftSensor.filteredDistance, 1);
  Serial.print(" state=");
  Serial.print(stateName(leftSensor.currentState));

  Serial.print(" | C raw=");
  if (centerSensor.rawDistance < 0) Serial.print("Invalid");
  else Serial.print(centerSensor.rawDistance, 1);
  Serial.print(" filt=");
  if (centerSensor.filteredDistance < 0) Serial.print("Invalid");
  else Serial.print(centerSensor.filteredDistance, 1);
  Serial.print(" state=");
  Serial.print(stateName(centerSensor.currentState));

  Serial.print(" | R raw=");
  if (rightSensor.rawDistance < 0) Serial.print("Invalid");
  else Serial.print(rightSensor.rawDistance, 1);
  Serial.print(" filt=");
  if (rightSensor.filteredDistance < 0) Serial.print("Invalid");
  else Serial.print(rightSensor.filteredDistance, 1);
  Serial.print(" state=");
  Serial.print(stateName(rightSensor.currentState));

  Serial.print(" | overall=");
  Serial.print(stateName(overallRearState()));
  Serial.print(" | nearest=");
  Serial.print((int)nearestSensorIndex());
  Serial.print(" | Loop: ");
  Serial.println(loopMs, 0);
}