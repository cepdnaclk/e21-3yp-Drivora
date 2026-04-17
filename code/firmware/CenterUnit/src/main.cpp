#include <Wire.h>
#include <MPU6050.h>

MPU6050 mpu;

// =====================================================
// HARD-CODED VEHICLE PARAMETERS
// =====================================================
const int VEHICLE_TYPE = 3;   // 1=Car/Van, 2=Bus, 3=Lorry, 4=Tanker

float trackWidth_m     = 1.90f;
float wheelbase_m      = 4.20f;
float vehicleHeight_m  = 3.20f;
int loadCondition      = 2;   // 0=empty, 1=half, 2=full
int suspensionType     = 0;   // 0=leaf, 1=coil, 2=air, 3=unknown

// =====================================================
// CALIBRATION
// =====================================================
float axBias = 0.0f, ayBias = 0.0f, azBias = 0.0f;
float gxBias = 0.0f, gyBias = 0.0f, gzBias = 0.0f;

float pitchZero = 0.0f;
float rollZero  = 0.0f;

// =====================================================
// FILTER STATE
// =====================================================
float pitchAngle = 0.0f;
float rollAngle  = 0.0f;

float pitchDisplay = 0.0f;
float rollDisplay  = 0.0f;

unsigned long lastMicros = 0;
unsigned long lastRiskChangeMs = 0;

// =====================================================
// VEHICLE MODEL
// =====================================================
float estimatedCoGHeight_m = 1.20f;
float criticalRollDeg = 30.0f;
float criticalPitchDeg = 20.0f;
float vehicleFactor = 1.0f;

// =====================================================
// TUNING
// =====================================================
const float alphaStill  = 0.92f;   // faster correction when trustworthy
const float alphaMotion = 0.995f;  // mostly gyro during strong motion

const float accelWarnThreshold = 0.06f;
const float accelHighThreshold = 0.16f;

const float displayAlpha = 0.35f;
const float deadbandDeg = 0.12f;

const unsigned long riskHoldMs = 250;

// =====================================================
// RISK STATE
// =====================================================
float riskScore = 0.0f;
int stableRiskCode = 0;

// =====================================================
// HELPERS
// =====================================================
float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

float applyDeadband(float value, float threshold) {
  if (fabs(value) < threshold) return 0.0f;
  return value;
}

int riskCodeFromScore(float score) {
  if (score < 0.35f) return 0;
  if (score < 0.60f) return 1;
  if (score < 0.80f) return 2;
  return 3;
}

float mapAlphaFromAccError(float err) {
  if (err <= accelWarnThreshold) return alphaStill;
  if (err >= accelHighThreshold) return alphaMotion;

  float t = (err - accelWarnThreshold) / (accelHighThreshold - accelWarnThreshold);
  return alphaStill + t * (alphaMotion - alphaStill);
}

// =====================================================
// VEHICLE MODEL
// =====================================================
void computeVehicleModel() {
  float baseCogFactor;

  switch (VEHICLE_TYPE) {
    case 1: baseCogFactor = 0.32f; vehicleFactor = 0.90f; break;
    case 2: baseCogFactor = 0.42f; vehicleFactor = 1.10f; break;
    case 3: baseCogFactor = 0.40f; vehicleFactor = 1.15f; break;
    case 4: baseCogFactor = 0.46f; vehicleFactor = 1.25f; break;
    default: baseCogFactor = 0.40f; vehicleFactor = 1.00f; break;
  }

  float loadFactor;
  switch (loadCondition) {
    case 0: loadFactor = 0.92f; break;
    case 1: loadFactor = 1.00f; break;
    case 2: loadFactor = 1.12f; break;
    default: loadFactor = 1.00f; break;
  }

  float suspensionFactor;
  switch (suspensionType) {
    case 0: suspensionFactor = 1.05f; break;
    case 1: suspensionFactor = 1.00f; break;
    case 2: suspensionFactor = 1.10f; break;
    default: suspensionFactor = 1.00f; break;
  }

  estimatedCoGHeight_m = vehicleHeight_m * baseCogFactor * loadFactor;
  criticalRollDeg = atan(trackWidth_m / (2.0f * estimatedCoGHeight_m)) * 180.0f / PI;

  switch (VEHICLE_TYPE) {
    case 1: criticalPitchDeg = 28.0f; break;
    case 2: criticalPitchDeg = 22.0f; break;
    case 3: criticalPitchDeg = 20.0f; break;
    case 4: criticalPitchDeg = 18.0f; break;
    default: criticalPitchDeg = 22.0f; break;
  }

  vehicleFactor *= suspensionFactor;
}

// =====================================================
// CALIBRATION
// =====================================================
void calibrateIMU() {
  Serial.println("Calibrating... keep sensor still and level");

  const int samples = 1200;
  long axSum = 0, aySum = 0, azSum = 0;
  long gxSum = 0, gySum = 0, gzSum = 0;

  for (int i = 0; i < samples; i++) {
    int16_t ax, ay, az, gx, gy, gz;
    mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

    axSum += ax;
    aySum += ay;
    azSum += az;
    gxSum += gx;
    gySum += gy;
    gzSum += gz;

    delay(2);
  }

  axBias = axSum / (float)samples;
  ayBias = aySum / (float)samples;
  azBias = (azSum / (float)samples) - 16384.0f;

  gxBias = gxSum / (float)samples;
  gyBias = gySum / (float)samples;
  gzBias = gzSum / (float)samples;

  float ax0 = axBias / 16384.0f;
  float ay0 = ayBias / 16384.0f;
  float az0 = (azBias + 16384.0f) / 16384.0f;

  pitchZero = atan2(ax0, sqrt(ay0 * ay0 + az0 * az0)) * 180.0f / PI;
  rollZero  = -atan2(ay0, sqrt(ax0 * ax0 + az0 * az0)) * 180.0f / PI;

  Serial.println("Calibration complete");
}

// =====================================================
// SETUP
// =====================================================
void setup() {
  Serial.begin(921600);

  Wire.begin(8, 9);
  Wire.setClock(400000);

  mpu.initialize();
  mpu.setDLPFMode(MPU6050_DLPF_BW_20);
  mpu.setRate(4);

  if (!mpu.testConnection()) {
    Serial.println("MPU6050 connection failed");
    while (1) {}
  }

  computeVehicleModel();
  calibrateIMU();

  pitchAngle = 0.0f;
  rollAngle  = 0.0f;
  pitchDisplay = 0.0f;
  rollDisplay  = 0.0f;

  lastMicros = micros();
  lastRiskChangeMs = millis();

  Serial.println("System ready");
  Serial.println("pitch,roll,cogx,cogy,riskScore,riskCode,criticalRoll,criticalPitch,accMag");
}

// =====================================================
// LOOP
// =====================================================
void loop() {
  int16_t axRaw, ayRaw, azRaw, gxRaw, gyRaw, gzRaw;
  mpu.getMotion6(&axRaw, &ayRaw, &azRaw, &gxRaw, &gyRaw, &gzRaw);

  unsigned long nowMicros = micros();
  float dt = (nowMicros - lastMicros) / 1000000.0f;
  lastMicros = nowMicros;

  if (dt <= 0.0f || dt > 0.1f) dt = 0.01f;

  // Bias corrected
  float ax = (axRaw - axBias) / 16384.0f;
  float ay = (ayRaw - ayBias) / 16384.0f;
  float az = (azRaw - azBias) / 16384.0f;

  float gx_dps = (gxRaw - gxBias) / 131.0f;
  float gy_dps = (gyRaw - gyBias) / 131.0f;
  float gz_dps = (gzRaw - gzBias) / 131.0f;

  float accMag = sqrt(ax * ax + ay * ay + az * az);
  float accErr = fabs(accMag - 1.0f);

  // Accel tilt
  float pitchAcc = atan2(ax, sqrt(ay * ay + az * az)) * 180.0f / PI - pitchZero;
  float rollAcc  = -atan2(ay, sqrt(ax * ax + az * az)) * 180.0f / PI - rollZero;

  // Gyro integrate
  float pitchGyro = pitchAngle + gy_dps * dt;
  float rollGyro  = rollAngle  + gx_dps * dt;

  // Adaptive blend
  float alpha = mapAlphaFromAccError(accErr);

  pitchAngle = alpha * pitchGyro + (1.0f - alpha) * pitchAcc;
  rollAngle  = alpha * rollGyro  + (1.0f - alpha) * rollAcc;

  // Final display smoothing only
  pitchDisplay = displayAlpha * pitchAngle + (1.0f - displayAlpha) * pitchDisplay;
  rollDisplay  = displayAlpha * rollAngle  + (1.0f - displayAlpha) * rollDisplay;

  pitchDisplay = applyDeadband(pitchDisplay, deadbandDeg);
  rollDisplay  = applyDeadband(rollDisplay, deadbandDeg);

  float cogX = rollDisplay;
  float cogY = pitchDisplay;

  float normalizedRoll  = fabs(rollDisplay) / criticalRollDeg;
  float normalizedPitch = fabs(pitchDisplay) / criticalPitchDeg;

  float rawRisk = vehicleFactor * (0.58f * normalizedRoll + 0.42f * normalizedPitch);
  riskScore = clampf(rawRisk, 0.0f, 1.0f);

  int desiredRiskCode = riskCodeFromScore(riskScore);
  unsigned long nowMs = millis();

  if (desiredRiskCode != stableRiskCode) {
    if (nowMs - lastRiskChangeMs >= riskHoldMs) {
      stableRiskCode = desiredRiskCode;
      lastRiskChangeMs = nowMs;
    }
  } else {
    lastRiskChangeMs = nowMs;
  }

  Serial.print(pitchDisplay, 3);
  Serial.print(",");
  Serial.print(rollDisplay, 3);
  Serial.print(",");
  Serial.print(cogX, 3);
  Serial.print(",");
  Serial.print(cogY, 3);
  Serial.print(",");
  Serial.print(riskScore, 3);
  Serial.print(",");
  Serial.print(stableRiskCode);
  Serial.print(",");
  Serial.print(criticalRollDeg, 2);
  Serial.print(",");
  Serial.print(criticalPitchDeg, 2);
  Serial.print(",");
  Serial.println(accMag, 3);

  delay(8);
}