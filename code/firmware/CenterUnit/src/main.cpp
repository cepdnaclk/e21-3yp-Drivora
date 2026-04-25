#include <Arduino.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>
#include "driver/twai.h"

// ================= I2C PINS =================
static const int I2C_SDA = 8;
static const int I2C_SCL = 9;

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_6;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_7;

const uint32_t LEAN_MAIN_ID  = 0x100;
const uint32_t LEAN_DEBUG_ID = 0x101;

unsigned long lastCanSendMs = 0;
const unsigned long CAN_SEND_MS = 50;

unsigned long lastDebugSendMs = 0;
const unsigned long DEBUG_SEND_MS = 200;

uint8_t leanCanCounter = 0;
uint8_t leanDebugCounter = 0;

// ================= MPU =================
MPU6050 mpu;

// ================= MODE =================
bool calibrated = false;

// ================= VEHICLE MODEL =================
// Controllable from the UI
int vehicleType = 3;           // 1 = Compact / low profile, 2 = Passenger vehicle, 3 = Tall vehicle / SUV
float trackWidth_m = 1.56f;    // meters
float wheelBase_m = 2.67f;     // meters
float vehicleHeight_m = 1.57f; // meters
int loadCondition = 1;         // 0 = Light, 1 = Normal, 2 = Heavy

float criticalRollDeg = 30.0f;
float criticalPitchDeg = 20.0f;

// ================= CALIBRATION / REFERENCE =================
float axBias = 0, ayBias = 0, azBias = 0;
float gxBias = 0, gyBias = 0, gzBias = 0;

float calibPitchRef = 0.0f;
float calibRollRef  = 0.0f;

// Upright reference gravity vector after calibration
float refGravX = 0.0f;
float refGravY = 0.0f;
float refGravZ = 1.0f;

unsigned long calibrationHoldUntil = 0;

// ================= FILTER STATE =================
float pitchAngle = 0.0f, rollAngle = 0.0f;
float pitchDisplay = 0.0f, rollDisplay = 0.0f;

unsigned long lastMicros = 0;
unsigned long lastRiskChangeMs = 0;

// ================= AUTO BASE TUNING =================
float autoBaseAlphaStill   = 0.91f;
float autoBaseAlphaMotion  = 0.9965f;
float autoBaseAccelWarn    = 0.03f;
float autoBaseAccelHigh    = 0.12f;
float autoBaseDisplayAlpha = 0.45f;
float autoBaseDeadband     = 0.10f;

// ================= LIVE TUNING VALUES =================
float alphaStill   = 0.91f;
float alphaMotion  = 0.9965f;
float accelWarn    = 0.03f;
float accelHigh    = 0.12f;
float displayAlpha = 0.45f;
float deadband     = 0.10f;

// ================= OUTPUT =================
int stableRisk = 0;

static inline float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

const char* vehicleTypeName(int v) {
  switch (v) {
    case 1: return "Compact / low profile";
    case 2: return "Passenger vehicle";
    case 3: return "Tall vehicle / SUV";
    default: return "Passenger vehicle";
  }
}

float mapAlphaFor(float err, float aStill, float aMotion, float aWarn, float aHigh) {
  if (aHigh <= aWarn + 0.0001f) {
    aHigh = aWarn + 0.0001f;
  }

  if (err <= aWarn) return aStill;
  if (err >= aHigh) return aMotion;

  float t = (err - aWarn) / (aHigh - aWarn);
  return aStill + t * (aMotion - aStill);
}

int riskLevel(float s) {
  if (s < 0.35f) return 0;     // SAFE
  if (s < 0.70f) return 1;     // CAUTION
  return 2;                    // HIGH
}

void computeVehicle() {
  float base;
  switch (vehicleType) {
    case 1: base = 0.32f; break;
    case 2: base = 0.42f; break;
    case 3: base = 0.40f; break;
    default: base = 0.40f; break;
  }

  float loadF = (loadCondition == 2) ? 1.12f : (loadCondition == 1) ? 1.00f : 0.92f;

  float cogH = vehicleHeight_m * base * loadF;
  if (cogH < 0.001f) cogH = 0.001f;

  criticalRollDeg  = atan(trackWidth_m / (2.0f * cogH)) * 180.0f / PI;
  criticalPitchDeg = atan(wheelBase_m  / (2.0f * cogH)) * 180.0f / PI;
}

// UPSIDE frame behavior, always active.
// Applied after bias correction.
void applyMountTransform(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
  ax = -ax;
  az = -az;
  gx = -gx;
  gz = -gz;
}

void calibrate() {
  Serial.println("Calibrating... keep vehicle stationary on level ground");

  long ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0;

  for (int i = 0; i < 1200; i++) {
    int16_t a, b, c, d, e, f;
    mpu.getMotion6(&a, &b, &c, &d, &e, &f);

    ax += a;
    ay += b;
    az += c;
    gx += d;
    gy += e;
    gz += f;

    delay(2);
  }

  axBias = ax / 1200.0f;
  ayBias = ay / 1200.0f;
  azBias = (az / 1200.0f) - 16384.0f;

  gxBias = gx / 1200.0f;
  gyBias = gy / 1200.0f;
  gzBias = gz / 1200.0f;

  double pitchSum = 0.0;
  double rollSum  = 0.0;
  double gravXSum = 0.0;
  double gravYSum = 0.0;
  double gravZSum = 0.0;

  for (int i = 0; i < 800; i++) {
    int16_t a, b, c, d, e, f;
    mpu.getMotion6(&a, &b, &c, &d, &e, &f);

    float axn = (a - axBias) / 16384.0f;
    float ayn = (b - ayBias) / 16384.0f;
    float azn = (c - azBias) / 16384.0f;

    float gxTmp = (d - gxBias) / 131.0f;
    float gyTmp = (e - gyBias) / 131.0f;
    float gzTmp = (f - gzBias) / 131.0f;

    applyMountTransform(axn, ayn, azn, gxTmp, gyTmp, gzTmp);

    float gmag = sqrt(axn * axn + ayn * ayn + azn * azn);
    if (gmag > 0.0001f) {
      float ngx = axn / gmag;
      float ngy = ayn / gmag;
      float ngz = azn / gmag;

      gravXSum += ngx;
      gravYSum += ngy;
      gravZSum += ngz;
    }

    float p = atan2(axn, sqrt(ayn * ayn + azn * azn)) * 180.0f / PI;
    float r = -atan2(ayn, sqrt(axn * axn + azn * azn)) * 180.0f / PI;

    pitchSum += p;
    rollSum  += r;

    delay(2);
  }

  calibPitchRef = pitchSum / 800.0;
  calibRollRef  = rollSum / 800.0;

  refGravX = gravXSum / 800.0;
  refGravY = gravYSum / 800.0;
  refGravZ = gravZSum / 800.0;

  float refMag = sqrt(refGravX * refGravX + refGravY * refGravY + refGravZ * refGravZ);
  if (refMag > 0.0001f) {
    refGravX /= refMag;
    refGravY /= refMag;
    refGravZ /= refMag;
  } else {
    refGravX = 0.0f;
    refGravY = 0.0f;
    refGravZ = 1.0f;
  }

  pitchAngle = 0.0f;
  rollAngle = 0.0f;
  pitchDisplay = 0.0f;
  rollDisplay = 0.0f;

  calibrated = true;
  calibrationHoldUntil = millis() + 500;
  lastMicros = micros();
  lastRiskChangeMs = millis();

  Serial.println("Calibration done");
}

// ================= CAN HELPERS =================
int16_t encodeAngleX100(float deg) {
  int v = (int)roundf(deg * 100.0f);
  if (v < -32768) v = -32768;
  if (v > 32767) v = 32767;
  return (int16_t)v;
}

uint16_t encodeUnsignedAngleX100(float deg) {
  int v = (int)roundf(deg * 100.0f);
  if (v < 0) v = 0;
  if (v > 65535) v = 65535;
  return (uint16_t)v;
}

uint8_t encodeConfidence0to100(float c) {
  int v = (int)roundf(clampf(c, 0.0f, 1.0f) * 100.0f);
  if (v < 0) v = 0;
  if (v > 100) v = 100;
  return (uint8_t)v;
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

  Serial.println("TWAI started on lean node");
  return true;
}

void sendLeanMainFrame(unsigned long nowMs, float rollOut, float pitchOut, float confidence) {
  if (nowMs - lastCanSendMs < CAN_SEND_MS) return;
  lastCanSendMs = nowMs;

  int16_t roll_x100  = encodeAngleX100(rollOut);
  int16_t pitch_x100 = encodeAngleX100(pitchOut);

  uint8_t flags = 0;
  if (calibrated) flags |= (1 << 0);

  twai_message_t msg = {};
  msg.identifier = LEAN_MAIN_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)stableRisk;
  msg.data[1] = (uint8_t)(roll_x100 & 0xFF);
  msg.data[2] = (uint8_t)((roll_x100 >> 8) & 0xFF);
  msg.data[3] = (uint8_t)(pitch_x100 & 0xFF);
  msg.data[4] = (uint8_t)((pitch_x100 >> 8) & 0xFF);
  msg.data[5] = encodeConfidence0to100(confidence);
  msg.data[6] = flags;
  msg.data[7] = leanCanCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN MAIN TX | risk=");
    Serial.print(stableRisk);
    Serial.print(" roll=");
    Serial.print(rollOut, 2);
    Serial.print(" pitch=");
    Serial.print(pitchOut, 2);
    Serial.print(" conf=");
    Serial.println(confidence, 2);
  }
}

void sendLeanDebugFrame(unsigned long nowMs) {
  if (nowMs - lastDebugSendMs < DEBUG_SEND_MS) return;
  lastDebugSendMs = nowMs;

  uint16_t criticalRoll_x100  = encodeUnsignedAngleX100(criticalRollDeg);
  uint16_t criticalPitch_x100 = encodeUnsignedAngleX100(criticalPitchDeg);

  uint8_t flags2 = 0;

  twai_message_t msg = {};
  msg.identifier = LEAN_DEBUG_ID;
  msg.extd = 0;
  msg.rtr = 0;
  msg.data_length_code = 8;

  msg.data[0] = (uint8_t)(criticalRoll_x100 & 0xFF);
  msg.data[1] = (uint8_t)((criticalRoll_x100 >> 8) & 0xFF);
  msg.data[2] = (uint8_t)(criticalPitch_x100 & 0xFF);
  msg.data[3] = (uint8_t)((criticalPitch_x100 >> 8) & 0xFF);
  msg.data[4] = (uint8_t)vehicleType;
  msg.data[5] = (uint8_t)loadCondition;
  msg.data[6] = flags2;
  msg.data[7] = leanDebugCounter++;

  esp_err_t err = twai_transmit(&msg, 0);
  if (err == ESP_OK) {
    Serial.print("CAN DEBUG TX | criticalRoll=");
    Serial.print(criticalRollDeg, 2);
    Serial.print(" criticalPitch=");
    Serial.print(criticalPitchDeg, 2);
    Serial.print(" vehicleType=");
    Serial.print(vehicleType);
    Serial.print(" load=");
    Serial.println(loadCondition);
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  delay(200);

  Wire.begin(I2C_SDA, I2C_SCL);
  Wire.setClock(400000);

  mpu.initialize();
  mpu.setDLPFMode(MPU6050_DLPF_BW_20);

  if (!mpu.testConnection()) {
    Serial.println("MPU6050 connection failed");
    while (1) {
      delay(1000);
    }
  }

  initCAN();
  computeVehicle();
  calibrate();

  lastMicros = micros();
  lastRiskChangeMs = millis();

  Serial.println("Lean CAN node ready");
}

// ================= LOOP =================
void loop() {
  int16_t axR, ayR, azR, gxR, gyR, gzR;
  mpu.getMotion6(&axR, &ayR, &azR, &gxR, &gyR, &gzR);

  float dt = (micros() - lastMicros) / 1000000.0f;
  lastMicros = micros();
  if (dt <= 0.0f || dt > 0.1f) dt = 0.01f;

  // Bias correction first
  float ax = (axR - axBias) / 16384.0f;
  float ay = (ayR - ayBias) / 16384.0f;
  float az = (azR - azBias) / 16384.0f;

  float gx = (gxR - gxBias) / 131.0f;
  float gy = (gyR - gyBias) / 131.0f;
  float gz = (gzR - gzBias) / 131.0f;

  // Then mount transform
  applyMountTransform(ax, ay, az, gx, gy, gz);

  float accMag = sqrt(ax * ax + ay * ay + az * az);
  float accErr = fabs(accMag - 1.0f);

  float pitchAccRaw = atan2(ax, sqrt(ay * ay + az * az)) * 180.0f / PI;
  float rollAccRaw  = -atan2(ay, sqrt(ax * ax + az * az)) * 180.0f / PI;

  float pitchAcc = pitchAccRaw - calibPitchRef;
  float rollAcc  = rollAccRaw - calibRollRef;

  float angRate = max(fabs(gx), fabs(gy));

  float aStability = clampf(1.0f - accErr * 5.0f, 0.0f, 1.0f);
  float aMotion = clampf(angRate / 15.0f, 0.0f, 1.0f);

  alphaStill   = clampf(autoBaseAlphaStill + 0.05f * aStability, 0.80f, 0.99f);
  alphaMotion  = clampf(autoBaseAlphaMotion + 0.004f * aMotion, 0.990f, 0.9999f);
  accelWarn    = clampf(autoBaseAccelWarn + 0.05f * aMotion, 0.000f, 0.25f);
  accelHigh    = clampf(autoBaseAccelHigh + 0.10f * aMotion, accelWarn + 0.01f, 0.40f);
  displayAlpha = clampf(autoBaseDisplayAlpha + 0.20f * aStability - 0.05f * aMotion, 0.10f, 0.95f);
  deadband     = clampf(autoBaseDeadband + 0.08f * (1.0f - aStability), 0.0f, 0.30f);

  float alphaAuto = mapAlphaFor(accErr, alphaStill, alphaMotion, accelWarn, accelHigh);

  float pitchGyro = pitchAngle + gy * dt;
  float rollGyro  = rollAngle + gx * dt;

  pitchAngle = alphaAuto * pitchGyro + (1.0f - alphaAuto) * pitchAcc;
  rollAngle  = alphaAuto * rollGyro  + (1.0f - alphaAuto) * rollAcc;

  if (!calibrated || millis() < calibrationHoldUntil) {
    pitchAngle = 0.0f;
    rollAngle = 0.0f;
    pitchDisplay = 0.0f;
    rollDisplay = 0.0f;
  }

  pitchDisplay = displayAlpha * pitchAngle + (1.0f - displayAlpha) * pitchDisplay;
  rollDisplay  = displayAlpha * rollAngle  + (1.0f - displayAlpha) * rollDisplay;

  if (fabs(pitchDisplay) < deadband) pitchDisplay = 0.0f;
  if (fabs(rollDisplay) < deadband)  rollDisplay = 0.0f;

  float confidence = 1.0f - clampf((accErr - 0.02f) / 0.18f, 0.0f, 1.0f);

  float nRoll  = fabs(rollDisplay) / criticalRollDeg;
  float nPitch = fabs(pitchDisplay) / criticalPitchDeg;

  // Total 3D tilt from calibrated upright gravity vector
  float severityTilt = 0.0f;
  float gmag = sqrt(ax * ax + ay * ay + az * az);
  if (gmag > 0.0001f) {
    float curGx = ax / gmag;
    float curGy = ay / gmag;
    float curGz = az / gmag;

    float dot = curGx * refGravX + curGy * refGravY + curGz * refGravZ;
    dot = clampf(dot, -1.0f, 1.0f);

    float totalTiltDeg = acos(dot) * 180.0f / PI;
    float criticalTiltDeg = min(criticalRollDeg, criticalPitchDeg);
    severityTilt = totalTiltDeg / criticalTiltDeg;
  }

  float severity = max(max(nRoll, nPitch), severityTilt);
  float effectiveRisk = clampf(severity * (0.7f + 0.3f * confidence), 0.0f, 1.0f);

  int desired;
  if (severity >= 1.0f) {
    desired = 2;   // HIGH
  } else if (severity >= 0.70f) {
    desired = 1;   // CAUTION
  } else {
    desired = 0;   // SAFE
  }

  unsigned long now = millis();
  const unsigned long riskHoldMs = 250;

  if (desired != stableRisk) {
    if (now - lastRiskChangeMs > riskHoldMs) {
      stableRisk = desired;
      lastRiskChangeMs = now;
    }
  } else {
    lastRiskChangeMs = now;
  }

  sendLeanMainFrame(now, rollDisplay, pitchDisplay, confidence);
  sendLeanDebugFrame(now);

  Serial.print("Roll: ");
  Serial.print(rollDisplay, 2);
  Serial.print(" | Pitch: ");
  Serial.print(pitchDisplay, 2);
  Serial.print(" | Confidence: ");
  Serial.print(confidence, 2);
  Serial.print(" | Risk: ");
  Serial.print(stableRisk);
  Serial.print(" | Calibrated: ");
  Serial.println(calibrated ? "YES" : "NO");

  delay(10);
}