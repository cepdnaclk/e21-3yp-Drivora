#include <Arduino.h>
#include "driver/twai.h"

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_6;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_7;

const uint32_t REAR_MAIN_ID  = 0x300;
const uint32_t REAR_DEBUG_ID = 0x301;

unsigned long lastCanSendMs = 0;
const unsigned long CAN_SEND_MS = 50;

unsigned long lastDebugSendMs = 0;
const unsigned long DEBUG_SEND_MS = 200;

uint8_t rearCanCounter = 0;
uint8_t rearDebugCounter = 0;

// ================= ULTRASONIC PINS =================
#define TRIGPIN 3
#define ECHOPIN 4

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
float filteredDistance = -1.0f;
const float distanceFilterAlpha = 0.55f;

// ================= SENSOR / RECOVERY =================
int invalidStreak = 0;
const int INVALID_STREAK_RESET_THRESHOLD = 20;
unsigned long lastRecoveryMs = 0;
const unsigned long RECOVERY_COOLDOWN_MS = 1500;

// ================= LATCH MEMORY =================
bool warningLatched = false;
int warningReleaseCounter = 0;
int fastWarningReleaseCounter = 0;
unsigned long lastValidSeenMs = 0;
float lastValidDistance = -1.0f;
unsigned long lastValidDistanceMs = 0;
float lastLatchedCloseDistance = -1.0f;

// ================= OUTPUT STATE =================
enum RearState {
  CLEAR = 0,
  OBJECT_DETECTED = 1,
  CAUTION = 2,
  WARNING = 3
};

RearState currentState = CLEAR;

// ================= TIMING / EXTRA TEST DATA =================
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

uint8_t buildRearDebugFlags(bool suspiciousLatched, bool fastWarning) {
  uint8_t flags = 0;
  if (warningLatched) flags |= (1 << 0);
  if (suspiciousLatched) flags |= (1 << 1);
  if (fastWarning) flags |= (1 << 2);
  if (filteredDistance < 0.0f) flags |= (1 << 3);
  return flags;
}

void sendRearMainFrame(unsigned long nowMs, float rawDistance, float smoothedDistance) {
  if (nowMs - lastCanSendMs < CAN_SEND_MS) return;
  lastCanSendMs = nowMs;

  uint16_t filtered_x10 = encodeDistanceX10(smoothedDistance);
  uint16_t raw_x10      = encodeDistanceX10(rawDistance);

  twai_message_t msg = {};
  msg.identifier = REAR_MAIN_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)currentState;
  msg.data[1] = (uint8_t)(filtered_x10 & 0xFF);
  msg.data[2] = (uint8_t)((filtered_x10 >> 8) & 0xFF);
  msg.data[3] = (uint8_t)(raw_x10 & 0xFF);
  msg.data[4] = (uint8_t)((raw_x10 >> 8) & 0xFF);
  msg.data[5] = 0;
  msg.data[6] = 0;
  msg.data[7] = rearCanCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN MAIN TX | state=");
    Serial.print((int)currentState);
    Serial.print(" filtered=");
    Serial.print(smoothedDistance, 1);
    Serial.print(" raw=");
    Serial.println(rawDistance, 1);
  }
}

void sendRearDebugFrame(unsigned long nowMs, bool suspiciousLatched, bool fastWarning) {
  if (nowMs - lastDebugSendMs < DEBUG_SEND_MS) return;
  lastDebugSendMs = nowMs;

  uint8_t flags = buildRearDebugFlags(suspiciousLatched, fastWarning);

  twai_message_t msg = {};
  msg.identifier = REAR_DEBUG_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = flags;
  msg.data[1] = (uint8_t)warningReleaseCounter;
  msg.data[2] = (uint8_t)fastWarningReleaseCounter;
  msg.data[3] = (uint8_t)invalidStreak;
  msg.data[4] = 0;
  msg.data[5] = 0;
  msg.data[6] = 0;
  msg.data[7] = rearDebugCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN DEBUG TX | flags=0x");
    Serial.print(flags, HEX);
    Serial.print(" release=");
    Serial.print(warningReleaseCounter);
    Serial.print(" fastRelease=");
    Serial.print(fastWarningReleaseCounter);
    Serial.print(" invalid=");
    Serial.println(invalidStreak);
  }
}

void resetSensorState() {
  filteredDistance = -1.0f;
  warningLatched = false;
  warningReleaseCounter = 0;
  fastWarningReleaseCounter = 0;
  lastValidSeenMs = millis();
  lastValidDistance = -1.0f;
  lastValidDistanceMs = millis();
  lastLatchedCloseDistance = -1.0f;
  digitalWrite(TRIGPIN, LOW);
}

// ================= READ DISTANCE =================
float readQualityDistanceCm() {
  int validCount = 0;

  for (int i = 0; i < sampleSize; i++) {
    digitalWrite(TRIGPIN, LOW);
    delayMicroseconds(5);
    digitalWrite(TRIGPIN, HIGH);
    delayMicroseconds(20);
    digitalWrite(TRIGPIN, LOW);

    long duration = pulseIn(ECHOPIN, HIGH, 25000);

    if (duration > 0) {
      readings[validCount] = duration / 58.2f;
      validCount++;
    }

    delay(15);
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
float updateFilteredDistance(float rawDistance) {
  if (rawDistance < 0) {
    filteredDistance = -1.0f;
    return -1.0f;
  }

  if (filteredDistance < 0) {
    filteredDistance = rawDistance;
  } else {
    filteredDistance =
      distanceFilterAlpha * rawDistance +
      (1.0f - distanceFilterAlpha) * filteredDistance;
  }

  return filteredDistance;
}

// ================= VALID DISTANCE MEMORY =================
void updateLastValidDistance(float dist, unsigned long nowMs) {
  if (dist < 0.0f) return;
  lastValidDistance = dist;
  lastValidDistanceMs = nowMs;
  lastValidSeenMs = nowMs;
}

// ================= CORE STABILITY HELPERS =================
bool isRecentValidMemoryAvailable(unsigned long nowMs) {
  if (lastValidDistance < 0.0f) return false;
  return (nowMs - lastValidDistanceMs) <= RECENT_VALID_MEMORY_MS;
}

bool isSuspiciousReadingWhileLatched(float rawDist, float dist, unsigned long nowMs) {
  if (!warningLatched) return false;

  if (dist < 0.0f) return true;

  if (dist >= FAST_WARNING_RELEASE_CM) return false;

  bool nearBlindArea = (dist <= WARNING_LATCH_RELEASE_CM);

  bool jumpFromLatchedClose = false;
  if (lastLatchedCloseDistance >= 0.0f) {
    jumpFromLatchedClose = fabs(dist - lastLatchedCloseDistance) >= RELEASE_SUSPICIOUS_JUMP_CM;
  }

  bool jumpFromRecentValid = false;
  if (isRecentValidMemoryAvailable(nowMs) && lastValidDistance >= 0.0f) {
    jumpFromRecentValid = fabs(dist - lastValidDistance) >= RELEASE_SUSPICIOUS_JUMP_CM;
  }

  bool rawLooksBlindish = false;
  if (rawDist > 0.0f) {
    rawLooksBlindish = (rawDist <= WARNING_LATCH_ENTRY_CM);
  }

  return nearBlindArea || rawLooksBlindish || jumpFromLatchedClose || jumpFromRecentValid;
}

// ================= FAST WARNING ENTRY DETECTOR =================
bool shouldFastLatchWarning(float rawDist, float filteredDist, unsigned long nowMs) {
  if (warningLatched) return false;
  if (lastValidDistance < 0.0f) return false;
  if ((nowMs - lastValidDistanceMs) > FAST_WARNING_MEMORY_MS) return false;

  bool wasClose = (lastValidDistance <= FAST_WARNING_ARM_CM);
  if (!wasClose) return false;

  bool invalidNow = (filteredDist < 0.0f);

  bool suspiciousNow = false;
  if (rawDist > 0.0f) {
    bool erraticNearBlind = (rawDist <= WARNING_LATCH_ENTRY_CM);
    bool suddenJumpTowardBlind =
      ((lastValidDistance - rawDist) >= FAST_ENTRY_JUMP_CM) &&
      (rawDist <= CAUTION_CM);
    suspiciousNow = erraticNearBlind || suddenJumpTowardBlind;
  } else {
    suspiciousNow = true;
  }

  return invalidNow || suspiciousNow;
}

// ================= REAR STATE LOGIC =================
void updateRearState(float rawDist, float dist, unsigned long nowMs) {
  if (shouldFastLatchWarning(rawDist, dist, nowMs)) {
    warningLatched = true;
    warningReleaseCounter = 0;
    fastWarningReleaseCounter = 0;
    lastLatchedCloseDistance = lastValidDistance;
    currentState = WARNING;
    return;
  }

  if (dist >= 0.0f) {
    if (dist <= WARNING_LATCH_ENTRY_CM) {
      warningLatched = true;
      warningReleaseCounter = 0;
      fastWarningReleaseCounter = 0;
      lastLatchedCloseDistance = dist;
    }

    if (warningLatched) {
      bool suspiciousWhileLatched = isSuspiciousReadingWhileLatched(rawDist, dist, nowMs);

      if (suspiciousWhileLatched) {
        warningReleaseCounter = 0;
        fastWarningReleaseCounter = 0;
        currentState = WARNING;
        return;
      }

      if (dist >= FAST_WARNING_RELEASE_CM) {
        fastWarningReleaseCounter++;
      } else {
        fastWarningReleaseCounter = 0;
      }

      if (fastWarningReleaseCounter >= FAST_WARNING_RELEASE_CONFIRM) {
        warningLatched = false;
        warningReleaseCounter = 0;
        fastWarningReleaseCounter = 0;
        lastLatchedCloseDistance = -1.0f;
      } else if (dist >= WARNING_LATCH_RELEASE_CM) {
        warningReleaseCounter++;
      } else {
        warningReleaseCounter = 0;
      }

      if (warningLatched && warningReleaseCounter >= WARNING_LATCH_RELEASE_CONFIRM) {
        warningLatched = false;
        warningReleaseCounter = 0;
        fastWarningReleaseCounter = 0;
        lastLatchedCloseDistance = -1.0f;
      } else if (warningLatched) {
        currentState = WARNING;
        return;
      }
    }

    if (dist <= WARNING_CM) {
      currentState = WARNING;
    } else if (dist <= CAUTION_CM) {
      currentState = CAUTION;
    } else if (currentState == CAUTION && dist <= CAUTION_EXIT_CM) {
      currentState = CAUTION;
    } else if (dist <= OBJECT_DETECTED_CM) {
      currentState = OBJECT_DETECTED;
    } else if (currentState == OBJECT_DETECTED && dist <= OBJECT_DETECTED_EXIT_CM) {
      currentState = OBJECT_DETECTED;
    } else {
      currentState = CLEAR;
    }

    return;
  }

  if (warningLatched) {
    warningReleaseCounter = 0;
    fastWarningReleaseCounter = 0;
    currentState = WARNING;
    return;
  }

  if (isRecentValidMemoryAvailable(nowMs) && lastValidDistance <= WARNING_LATCH_ENTRY_CM) {
    warningLatched = true;
    warningReleaseCounter = 0;
    fastWarningReleaseCounter = 0;
    lastLatchedCloseDistance = lastValidDistance;
    currentState = WARNING;
    return;
  }

  currentState = CLEAR;
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  pinMode(TRIGPIN, OUTPUT);
  pinMode(ECHOPIN, INPUT);

  digitalWrite(TRIGPIN, LOW);
  delay(1000);

  initCAN();

  lastLoopMs = millis();
  lastValidSeenMs = millis();
  lastValidDistanceMs = millis();

  Serial.println("Blindspot / Rear CAN Node Started");
}

// ================= LOOP =================
void loop() {
  unsigned long nowMs = millis();
  float loopMs = (float)(nowMs - lastLoopMs);
  lastLoopMs = nowMs;

  float rawDistance = readQualityDistanceCm();
  float smoothedDistance = updateFilteredDistance(rawDistance);

  if (rawDistance < 0) {
    invalidStreak++;
  } else {
    invalidStreak = 0;
  }

  if (invalidStreak >= INVALID_STREAK_RESET_THRESHOLD &&
      (nowMs - lastRecoveryMs) > RECOVERY_COOLDOWN_MS &&
      !warningLatched &&
      currentState != WARNING) {
    resetSensorState();
    lastRecoveryMs = nowMs;
    invalidStreak = 0;
  }

  bool fastWarning = shouldFastLatchWarning(rawDistance, smoothedDistance, nowMs);
  bool suspiciousLatched = isSuspiciousReadingWhileLatched(rawDistance, smoothedDistance, nowMs);

  updateRearState(rawDistance, smoothedDistance, nowMs);
  updateLastValidDistance(smoothedDistance, nowMs);

  sendRearMainFrame(nowMs, rawDistance, smoothedDistance);
  sendRearDebugFrame(nowMs, suspiciousLatched, fastWarning);

  Serial.print("Raw: ");
  if (rawDistance < 0) Serial.print("Invalid");
  else Serial.print(rawDistance, 1);

  Serial.print(" cm | Filtered: ");
  if (smoothedDistance < 0) Serial.print("Invalid");
  else Serial.print(smoothedDistance, 1);

  Serial.print(" cm | WarningLatched: ");
  Serial.print(warningLatched ? "YES" : "NO");
  Serial.print(" | ReleaseCounter: ");
  Serial.print(warningReleaseCounter);
  Serial.print(" | FastReleaseCounter: ");
  Serial.print(fastWarningReleaseCounter);
  Serial.print(" | FastWarning: ");
  Serial.print(fastWarning ? "YES" : "NO");
  Serial.print(" | SuspiciousLatched: ");
  Serial.print(suspiciousLatched ? "YES" : "NO");
  Serial.print(" | InvalidStreak: ");
  Serial.print(invalidStreak);
  Serial.print(" | State: ");
  Serial.print(stateName(currentState));
  Serial.print(" | Loop: ");
  Serial.println(loopMs, 0);
}