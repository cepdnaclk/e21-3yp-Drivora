#include <Arduino.h>
#include "driver/twai.h"

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_6;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_7;

const uint32_t FRONT_MAIN_ID = 0x200;
unsigned long lastCanSendMs = 0;
const unsigned long CAN_SEND_MS = 50;
uint8_t frontCanCounter = 0;

// ================= ULTRASONIC PINS =================
#define TRIGPIN 3
#define ECHOPIN 4

// ================= DISTANCE SETTINGS =================
const float MIN_VALID_CM = 23.0f;
const float MAX_VALID_CM = 250.0f;

const float OBJECT_ZONE_CM   = 180.0f;
const float WARNING_ZONE_CM  = 80.0f;

// Close / blind-zone related thresholds
const float VERY_CLOSE_ZONE_CM      = 25.0f;
const float BLIND_ENTRY_TRIGGER_CM  = 24.0f;
const float CLEAR_DISTANCE_CM       = 205.0f;

// Suspicious reading logic
const float SUSPICIOUS_JUMP_CM      = 18.0f;
const float BLIND_RELEASE_MIN_CM    = 29.0f;
const int   BLIND_RELEASE_COUNT_REQ = 3;

// Moving-away based blind release
const float BLIND_RELEASE_MOVING_AWAY_CM_S = -6.0f;
const float BLIND_RELEASE_MOVING_AWAY_MIN_CM = 25.0f;

// Fast blind-entry detection
const float FAST_BLIND_ARM_CM   = 45.0f;
const float FAST_ENTRY_JUMP_CM  = 12.0f;

// ================= SAMPLING =================
const int sampleSize = 2;
float readings[sampleSize];

// ================= FILTERING =================
float filteredDistance = -1.0f;
float prevFilteredDistance = -1.0f;
const float distanceFilterAlpha = 0.55f;

// ================= SPEED / TREND =================
float closingSpeedCmS = 0.0f;    // positive = getting closer
float lastValidDistance = -1.0f;
unsigned long lastValidDistanceMs = 0;

const float APPROACH_SPEED_CM_S = 8.0f;
const float WARNING_SPEED_CM_S  = 20.0f;

// ================= STATE MEMORY =================
int approachCounter = 0;
int warningCounter = 0;
const int APPROACH_CONFIRM_COUNT = 1;
const int WARNING_CONFIRM_COUNT  = 1;

unsigned long blindHoldUntilMs = 0;
unsigned long lastValidSeenMs = 0;
const unsigned long BLIND_HOLD_MS   = 1200;
const unsigned long INVALID_HOLD_MS = 650;

// Blind-zone latch logic
bool blindZoneLatched = false;
float blindLatchDistance = -1.0f;
unsigned long blindLatchSetMs = 0;
int blindReleaseCounter = 0;

// ================= SENSOR / RECOVERY =================
int invalidStreak = 0;
const int INVALID_STREAK_RESET_THRESHOLD = 20;
unsigned long lastRecoveryMs = 0;
const unsigned long RECOVERY_COOLDOWN_MS = 1500;

// ================= OUTPUT STATE =================
enum FCWState {
  CLEAR = 0,
  OBJECT_AHEAD = 1,
  APPROACHING = 2,
  WARNING = 3
};

FCWState currentState = CLEAR;

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

float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
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

void sendFrontMainFrame(unsigned long nowMs, float rawDistance, float smoothedDistance) {
  if (nowMs - lastCanSendMs < CAN_SEND_MS) return;
  lastCanSendMs = nowMs;

  uint16_t filtered_x10 = encodeDistanceX10(smoothedDistance);
  int16_t  speed_x10    = encodeSpeedX10(closingSpeedCmS);
  uint16_t raw_x10      = encodeDistanceX10(rawDistance);

  twai_message_t msg = {};
  msg.identifier = FRONT_MAIN_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)currentState;
  msg.data[1] = (uint8_t)(filtered_x10 & 0xFF);
  msg.data[2] = (uint8_t)((filtered_x10 >> 8) & 0xFF);
  msg.data[3] = (uint8_t)(speed_x10 & 0xFF);
  msg.data[4] = (uint8_t)((speed_x10 >> 8) & 0xFF);
  msg.data[5] = (uint8_t)(raw_x10 & 0xFF);
  msg.data[6] = (uint8_t)((raw_x10 >> 8) & 0xFF);
  msg.data[7] = frontCanCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN TX | state=");
    Serial.print((int)currentState);
    Serial.print(" filtered=");
    Serial.print(smoothedDistance, 1);
    Serial.print(" raw=");
    Serial.print(rawDistance, 1);
    Serial.print(" speed=");
    Serial.println(closingSpeedCmS, 1);
  }
}

void resetSensorState() {
  filteredDistance = -1.0f;
  prevFilteredDistance = -1.0f;
  closingSpeedCmS = 0.0f;
  lastValidDistance = -1.0f;
  lastValidDistanceMs = millis();

  approachCounter = 0;
  warningCounter = 0;

  blindZoneLatched = false;
  blindLatchDistance = -1.0f;
  blindLatchSetMs = 0;
  blindReleaseCounter = 0;
  blindHoldUntilMs = 0;

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

// ================= SPEED ESTIMATION =================
void updateClosingSpeed(float dist, unsigned long nowMs) {
  if (dist < 0) {
    closingSpeedCmS = 0.0f;
    return;
  }

  if (lastValidDistance < 0.0f) {
    lastValidDistance = dist;
    lastValidDistanceMs = nowMs;
    closingSpeedCmS = 0.0f;
    return;
  }

  float dt = (nowMs - lastValidDistanceMs) / 1000.0f;
  if (dt <= 0.0f) {
    closingSpeedCmS = 0.0f;
    return;
  }

  float rawSpeed = (lastValidDistance - dist) / dt;
  closingSpeedCmS = 0.65f * closingSpeedCmS + 0.35f * rawSpeed;

  lastValidDistance = dist;
  lastValidDistanceMs = nowMs;
}

bool isSuspiciousReading(float dist) {
  if (dist < 0.0f) return true;
  if (!blindZoneLatched) return false;
  if (blindLatchDistance < 0.0f) return false;

  if (fabs(dist - blindLatchDistance) > SUSPICIOUS_JUMP_CM && dist < BLIND_RELEASE_MIN_CM) {
    return true;
  }

  if (dist <= BLIND_RELEASE_MIN_CM && closingSpeedCmS > -2.0f) {
    return true;
  }

  return false;
}

void latchBlindZone(unsigned long nowMs, float refDist) {
  blindZoneLatched = true;
  blindLatchSetMs = nowMs;
  blindLatchDistance = refDist;
  blindReleaseCounter = 0;
  blindHoldUntilMs = nowMs + BLIND_HOLD_MS;
}

// ================= FAST BLIND-ENTRY DETECTOR =================
bool shouldFastLatchBlindZone(float rawDist, float filteredDist) {
  if (blindZoneLatched) return false;
  if (lastValidDistance < 0.0f) return false;

  bool wasClose = (lastValidDistance <= FAST_BLIND_ARM_CM);
  if (!wasClose) return false;

  bool invalidNow = (filteredDist < 0.0f);

  bool suspiciousNow = false;
  if (rawDist > 0.0f) {
    bool erraticNearBlind = (rawDist <= BLIND_ENTRY_TRIGGER_CM);
    bool suddenJumpTowardBlind = ((lastValidDistance - rawDist) >= FAST_ENTRY_JUMP_CM) && (rawDist <= VERY_CLOSE_ZONE_CM);
    suspiciousNow = erraticNearBlind || suddenJumpTowardBlind;
  } else {
    suspiciousNow = true;
  }

  return invalidNow || suspiciousNow;
}

// ================= SMART FCW LOGIC =================
void updateFCWState(float rawDist, float dist, unsigned long nowMs) {
  if (shouldFastLatchBlindZone(rawDist, dist)) {
    latchBlindZone(nowMs, lastValidDistance);
    currentState = WARNING;
    return;
  }

  bool distValid = (dist >= 0.0f);
  bool suspicious = isSuspiciousReading(dist);

  if (distValid && !suspicious) {
    lastValidSeenMs = nowMs;

    bool approachingNow = (closingSpeedCmS >= APPROACH_SPEED_CM_S);
    bool warningSpeedNow = (closingSpeedCmS >= WARNING_SPEED_CM_S);

    if (approachingNow) {
      if (approachCounter < APPROACH_CONFIRM_COUNT) approachCounter++;
    } else {
      if (approachCounter > 0) approachCounter--;
    }

    if (warningSpeedNow) {
      if (warningCounter < WARNING_CONFIRM_COUNT) warningCounter++;
    } else {
      if (warningCounter > 0) warningCounter--;
    }

    bool confirmedApproaching = (approachCounter >= APPROACH_CONFIRM_COUNT);
    bool confirmedWarningSpeed = (warningCounter >= WARNING_CONFIRM_COUNT);

    if (dist <= BLIND_ENTRY_TRIGGER_CM && closingSpeedCmS > 0.5f) {
      latchBlindZone(nowMs, dist);
    }

    if (blindZoneLatched) {
      bool distanceRelease = (dist >= BLIND_RELEASE_MIN_CM);
      bool movingAwayRelease = (closingSpeedCmS <= BLIND_RELEASE_MOVING_AWAY_CM_S &&
                                dist >= BLIND_RELEASE_MOVING_AWAY_MIN_CM);

      if (distanceRelease || movingAwayRelease) {
        blindReleaseCounter++;
      } else {
        blindReleaseCounter = 0;
      }

      if (blindReleaseCounter >= BLIND_RELEASE_COUNT_REQ) {
        blindZoneLatched = false;
        blindReleaseCounter = 0;
        blindLatchDistance = -1.0f;
      } else {
        currentState = WARNING;
        return;
      }
    }

    if (dist <= WARNING_ZONE_CM && confirmedWarningSpeed) {
      currentState = WARNING;
      if (dist <= BLIND_ENTRY_TRIGGER_CM) {
        latchBlindZone(nowMs, dist);
      }
      return;
    }

    if (dist <= VERY_CLOSE_ZONE_CM) {
      if (confirmedWarningSpeed || closingSpeedCmS >= (WARNING_SPEED_CM_S * 0.7f)) {
        currentState = WARNING;
        if (dist <= BLIND_ENTRY_TRIGGER_CM) {
          latchBlindZone(nowMs, dist);
        }
        return;
      }

      if (confirmedApproaching) {
        currentState = APPROACHING;
      } else {
        currentState = OBJECT_AHEAD;
      }
      return;
    }

    if (dist <= OBJECT_ZONE_CM && confirmedApproaching) {
      currentState = APPROACHING;
      return;
    }

    if (dist <= OBJECT_ZONE_CM) {
      currentState = OBJECT_AHEAD;
      return;
    }

    if (dist >= CLEAR_DISTANCE_CM) {
      currentState = CLEAR;
    } else {
      currentState = OBJECT_AHEAD;
    }

    return;
  }

  if (!blindZoneLatched && prevFilteredDistance > 0.0f &&
      prevFilteredDistance <= BLIND_ENTRY_TRIGGER_CM &&
      closingSpeedCmS > 0.5f) {
    latchBlindZone(nowMs, prevFilteredDistance);
  }

  if (blindZoneLatched) {
    currentState = WARNING;
    return;
  }

  if (nowMs < blindHoldUntilMs) {
    currentState = WARNING;
    return;
  }

  if ((nowMs - lastValidSeenMs) <= INVALID_HOLD_MS) {
    if (currentState == APPROACHING || currentState == WARNING) {
      currentState = APPROACHING;
    } else if (currentState == OBJECT_AHEAD) {
      currentState = OBJECT_AHEAD;
    } else {
      currentState = CLEAR;
    }
    return;
  }

  currentState = CLEAR;
  approachCounter = 0;
  warningCounter = 0;
  prevFilteredDistance = -1.0f;
}

// ================= SETUP =================
void setup() {
  Serial.begin(9600);

  pinMode(TRIGPIN, OUTPUT);
  pinMode(ECHOPIN, INPUT);

  digitalWrite(TRIGPIN, LOW);
  delay(1000);

  initCAN();

  lastLoopMs = millis();
  lastValidDistanceMs = millis();

  Serial.println("JSN-SR04T FCW CAN Node Started");
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
      (nowMs - lastRecoveryMs) > RECOVERY_COOLDOWN_MS) {
    resetSensorState();
    lastRecoveryMs = nowMs;
    invalidStreak = 0;
  }

  updateClosingSpeed(smoothedDistance, nowMs);
  bool suspicious = isSuspiciousReading(smoothedDistance);
  bool fastBlind = shouldFastLatchBlindZone(rawDistance, smoothedDistance);
  updateFCWState(rawDistance, smoothedDistance, nowMs);
  sendFrontMainFrame(nowMs, rawDistance, smoothedDistance);

  Serial.print("Raw: ");
  if (rawDistance < 0) Serial.print("Invalid");
  else Serial.print(rawDistance, 1);

  Serial.print(" cm | Filtered: ");
  if (smoothedDistance < 0) Serial.print("Invalid");
  else Serial.print(smoothedDistance, 1);

  Serial.print(" cm | Speed: ");
  Serial.print(closingSpeedCmS, 1);
  Serial.print(" cm/s | BlindLatched: ");
  Serial.print(blindZoneLatched ? "YES" : "NO");
  Serial.print(" | Suspicious: ");
  Serial.print(suspicious ? "YES" : "NO");
  Serial.print(" | FastBlind: ");
  Serial.print(fastBlind ? "YES" : "NO");
  Serial.print(" | InvalidStreak: ");
  Serial.print(invalidStreak);
  Serial.print(" | State: ");
  Serial.print(stateName(currentState));
  Serial.print(" | Loop: ");
  Serial.println(loopMs, 0);
}