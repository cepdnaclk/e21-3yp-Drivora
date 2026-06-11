#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <Preferences.h>
#include <math.h>
#include "driver/twai.h"

// ================= WIFI / WEB =================
const char* ssid = "ADASBrain";
const char* password = "12345678";

WebServer server(80);
WebSocketsServer webSocket(81);
Preferences prefs;

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_17;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_16;

const uint32_t LEAN_MAIN_ID   = 0x100;
const uint32_t LEAN_DEBUG_ID  = 0x101;
const uint32_t LEAN_CFG_A_ID  = 0x110;
const uint32_t LEAN_CMD_ID    = 0x111;
const uint32_t LEAN_CFG_B_ID  = 0x112;

const uint32_t FRONT_MAIN_ID  = 0x200;
const uint32_t FRONT_DEBUG_ID = 0x201;
const uint32_t FRONT_CFG_ID   = 0x210;

const uint32_t REAR_MAIN_ID   = 0x300;
const uint32_t REAR_DEBUG_ID  = 0x301;
const uint32_t REAR_DIST_ID   = 0x302;
const uint32_t REAR_CFG_ID    = 0x310;

// ================= LANE UART =================
static const int LANE_RX_PIN = 21;
static const int LANE_TX_PIN = 22;   // reserved for future use
String laneRxBuffer = "";

// ================= BUZZER =================
// Passive piezo buzzer output from brain unit.
// Recommended pin on ESP32-WROOM-32: GPIO25.
static const int BUZZER_PIN = 25;
static const int BUZZER_CHANNEL = 0;
static const int BUZZER_RESOLUTION = 10;

bool buzzerEnabled = true;
bool setupWizardBuzzerMuted = false;
int currentBuzzerFreq = -1;
int currentBuzzerDuty = -1;

// Buzzer pattern IDs used by Settings/Wizard.
// 0 = Urgent Triple Pulse, 1 = Wide Double Pulse, 2 = Quick Double Tap, 3 = Two-Tone Stability
const uint8_t BUZZER_PATTERN_URGENT_TRIPLE = 0;
const uint8_t BUZZER_PATTERN_WIDE_DOUBLE   = 1;
const uint8_t BUZZER_PATTERN_QUICK_DOUBLE  = 2;
const uint8_t BUZZER_PATTERN_TWO_TONE      = 3;

const uint8_t BUZZER_VOLUME_MIN = 30;
const uint8_t BUZZER_VOLUME_MAX = 100;

// Buzzer state machine.
// This prevents two practical issues:
// 1) continuous tone when fused warning type changes repeatedly
// 2) short silent gaps caused by one-frame NONE/stale transitions
String activeBuzzerType = "NONE";
uint8_t activeBuzzerSeverity = 0;
unsigned long buzzerPatternStartMs = 0;
unsigned long buzzerSwitchMuteUntilMs = 0;
unsigned long buzzerClearCandidateMs = 0;

const unsigned long BUZZER_MIN_TYPE_HOLD_MS = 650;
const unsigned long BUZZER_SWITCH_GAP_MS = 35;
const unsigned long BUZZER_CLEAR_GRACE_MS = 260;

// Current fused warning snapshot used by the non-blocking buzzer service.
// This lets the buzzer update every loop, independent of the WebSocket broadcast rate.
String currentFusedType = "NONE";
uint8_t currentFusedSeverity = 0;

// Short manual buzzer test state used by the Settings/Wizard test buttons.
// It does not affect the saved buzzer on/off preference or active warning logic.
bool buzzerTestActive = false;
uint8_t testBuzzerPattern = BUZZER_PATTERN_URGENT_TRIPLE;
uint8_t testBuzzerVolume = 100;
unsigned long testBuzzerStartMs = 0;
unsigned long testBuzzerUntilMs = 0;
int buzzerVolumeOverride = -1;

void buzzerOff();
void startBuzzerTest(uint8_t pattern, uint8_t volumePercent);

// ================= CONFIG MODEL =================
struct BrainConfig {
  bool setupCompleted = false;
  String profileName = "My Vehicle";

  uint8_t vehicleType = 3;          // 1 compact, 2 passenger, 3 tall/SUV
  float trackWidth_m = 1.56f;
  float wheelBase_m = 2.67f;
  float vehicleHeight_m = 1.57f;
  uint8_t loadCondition = 1;        // 0 light, 1 normal, 2 heavy

  uint8_t frontSensitivityPreset = 1; // 0 near, 1 normal, 2 far
  uint8_t rearSensitivityPreset  = 1; // 0 near, 1 normal, 2 far

  bool centerCalibrated = false;

  uint8_t frontBuzzerPattern = BUZZER_PATTERN_URGENT_TRIPLE;
  uint8_t rearBuzzerPattern  = BUZZER_PATTERN_WIDE_DOUBLE;
  uint8_t laneBuzzerPattern  = BUZZER_PATTERN_QUICK_DOUBLE;
  uint8_t leanBuzzerPattern  = BUZZER_PATTERN_TWO_TONE;

  uint8_t frontBuzzerVolume = 100;
  uint8_t rearBuzzerVolume  = 100;
  uint8_t laneBuzzerVolume  = 100;
  uint8_t leanBuzzerVolume  = 100;
};

BrainConfig brainConfig;

// ================= COUNTERS =================
uint8_t leanCfgCounter  = 0;
uint8_t leanCmdCounter  = 0;
uint8_t frontCfgCounter = 0;
uint8_t rearCfgCounter  = 0;

// ================= DATA STRUCTS =================
struct LeanData {
  bool online = false;
  bool calibrated = false;
  uint8_t riskLevel = 0;          // 0 SAFE, 1 CAUTION, 2 HIGH
  float rollDeg = 0.0f;
  float pitchDeg = 0.0f;
  float confidence = 1.0f;
  float criticalRollDeg = 30.0f;
  float criticalPitchDeg = 20.0f;
  unsigned long lastUpdateMs = 0;

  // Debug payload from 0x101
  uint8_t vehicleType = 0;
  uint8_t loadCondition = 0;
  uint8_t debugFlags2 = 0;
  uint8_t debugCounter = 0;
  unsigned long lastDebugUpdateMs = 0;
};

struct FrontData {
  bool online = false;
  uint8_t state = 0;              // 0 CLEAR, 1 OBJECT_AHEAD, 2 APPROACHING, 3 WARNING
  float filteredDistanceCm = -1.0f;
  float rawDistanceCm = -1.0f;
  float closingSpeedCmS = 0.0f;
  unsigned long lastUpdateMs = 0;

  // Debug payload from 0x201
  uint8_t debugFlags = 0;
  uint8_t approachCounter = 0;
  uint8_t warningCounter = 0;
  uint8_t blindReleaseCounter = 0;
  uint8_t invalidStreak = 0;
  uint8_t debugCounter = 0;
  unsigned long lastDebugUpdateMs = 0;
};

struct RearData {
  bool online = false;

  // Main payload from 0x300
  uint8_t leftState = 0;
  uint8_t centerState = 0;
  uint8_t rightState = 0;
  uint8_t leftFlags = 0;
  uint8_t centerFlags = 0;
  uint8_t rightFlags = 0;
  uint8_t overallState = 0;
  uint8_t mainCounter = 0;

  // Distance payload from 0x302
  float leftFilteredDistanceCm = -1.0f;
  float centerFilteredDistanceCm = -1.0f;
  float rightFilteredDistanceCm = -1.0f;
  uint8_t nearestSensor = 0;      // 0 none, 1 left, 2 center, 3 right
  uint8_t distCounter = 0;

  unsigned long lastUpdateMs = 0;
  unsigned long lastDistUpdateMs = 0;

  // Debug payload from 0x301
  uint8_t leftWarningReleaseCounter = 0;
  uint8_t centerWarningReleaseCounter = 0;
  uint8_t rightWarningReleaseCounter = 0;
  uint8_t leftFastWarningReleaseCounter = 0;
  uint8_t centerFastWarningReleaseCounter = 0;
  uint8_t rightFastWarningReleaseCounter = 0;
  uint8_t maxInvalidStreak = 0;
  uint8_t debugCounter = 0;
  unsigned long lastDebugUpdateMs = 0;
};

struct LaneData {
  bool online = false;
  uint8_t state = 0;              // 0 SAFE, 1 LEFT_DEPARTURE, 2 RIGHT_DEPARTURE
  unsigned long lastUpdateMs = 0;
};

LeanData leanData;
FrontData frontData;
RearData rearData;
LaneData laneData;

// ================= TIMING =================
unsigned long lastBroadcastMs = 0;
unsigned long lastConfigBroadcastMs = 0;
bool forceConfigBroadcast = true;
bool centerCalibrationRequested = false;

const unsigned long UI_BROADCAST_MS     = 50;
const unsigned long CONFIG_BROADCAST_MS = 1000;
const unsigned long STALE_MS            = 300;
const unsigned long OFFLINE_MS          = 1000;

// ================= HELPERS =================
const char* leanRiskName(uint8_t level) {
  switch (level) {
    case 0: return "SAFE";
    case 1: return "CAUTION";
    case 2: return "HIGH";
    default: return "SAFE";
  }
}

const char* frontStateName(uint8_t state) {
  switch (state) {
    case 0: return "CLEAR";
    case 1: return "OBJECT_AHEAD";
    case 2: return "APPROACHING";
    case 3: return "WARNING";
    default: return "CLEAR";
  }
}

const char* rearStateName(uint8_t state) {
  switch (state) {
    case 0: return "CLEAR";
    case 1: return "OBJECT_DETECTED";
    case 2: return "CAUTION";
    case 3: return "WARNING";
    default: return "CLEAR";
  }
}

const char* laneStateName(uint8_t state) {
  switch (state) {
    case 0: return "SAFE";
    case 1: return "LEFT_DEPARTURE";
    case 2: return "RIGHT_DEPARTURE";
    default: return "SAFE";
  }
}

const char* stateColorByLevel(uint8_t level) {
  switch (level) {
    case 0: return "#1db954";
    case 1: return "#ffb020";
    case 2: return "#ff7230";
    case 3: return "#ff3b30";
    default: return "#1db954";
  }
}

const char* laneStateColor(uint8_t state) {
  switch (state) {
    case 0: return "#1db954";
    case 1: return "#ffb020";
    case 2: return "#ffb020";
    default: return "#1db954";
  }
}

const char* vehicleTypeName(uint8_t v) {
  switch (v) {
    case 1: return "Compact";
    case 2: return "Passenger";
    case 3: return "Tall / SUV";
    default: return "Tall / SUV";
  }
}

const char* loadConditionName(uint8_t v) {
  switch (v) {
    case 0: return "Light";
    case 1: return "Normal";
    case 2: return "Heavy";
    default: return "Normal";
  }
}

const char* presetName(uint8_t v) {
  switch (v) {
    case 0: return "Near";
    case 1: return "Normal";
    case 2: return "Far";
    default: return "Normal";
  }
}

String payloadToString(uint8_t* payload, size_t length) {
  String s;
  s.reserve(length);
  for (size_t i = 0; i < length; i++) s += (char)payload[i];
  return s;
}

bool isStale(unsigned long lastMs, unsigned long nowMs) {
  return (nowMs - lastMs) > STALE_MS;
}

bool isOffline(unsigned long lastMs, unsigned long nowMs) {
  return (nowMs - lastMs) > OFFLINE_MS;
}

uint16_t packU16FromBytes(uint8_t lo, uint8_t hi) {
  return (uint16_t)lo | ((uint16_t)hi << 8);
}

int16_t packS16FromBytes(uint8_t lo, uint8_t hi) {
  return (int16_t)((uint16_t)lo | ((uint16_t)hi << 8));
}

float unpackDistanceCm(uint16_t v) {
  if (v == 0xFFFF) return -1.0f;
  return v / 10.0f;
}

float unpackSpeedCmS(int16_t v) {
  return v / 10.0f;
}

float unpackAngleDegX100(int16_t v) {
  return v / 100.0f;
}

float unpackUnsignedAngleDegX100(uint16_t v) {
  return v / 100.0f;
}

String trimLine(const String& s) {
  String out = s;
  out.trim();
  return out;
}

float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}


uint8_t clampBuzzerPattern(int v) {
  if (v < 0) return 0;
  if (v > 3) return 3;
  return (uint8_t)v;
}

uint8_t clampBuzzerVolume(int v) {
  if (v < BUZZER_VOLUME_MIN) return BUZZER_VOLUME_MIN;
  if (v > BUZZER_VOLUME_MAX) return BUZZER_VOLUME_MAX;
  return (uint8_t)v;
}

void enforceUniqueBuzzerPatterns() {
  uint8_t used[4] = {0, 0, 0, 0};
  uint8_t* patternSlots[4] = {
    &brainConfig.frontBuzzerPattern,
    &brainConfig.rearBuzzerPattern,
    &brainConfig.laneBuzzerPattern,
    &brainConfig.leanBuzzerPattern
  };

  for (int i = 0; i < 4; i++) {
    *patternSlots[i] = clampBuzzerPattern(*patternSlots[i]);
    if (!used[*patternSlots[i]]) {
      used[*patternSlots[i]] = 1;
    } else {
      for (uint8_t p = 0; p < 4; p++) {
        if (!used[p]) {
          *patternSlots[i] = p;
          used[p] = 1;
          break;
        }
      }
    }
  }
}

bool areBuzzerPatternsUnique(uint8_t frontP, uint8_t rearP, uint8_t laneP, uint8_t leanP) {
  uint8_t seen[4] = {0, 0, 0, 0};
  uint8_t values[4] = {
    clampBuzzerPattern(frontP),
    clampBuzzerPattern(rearP),
    clampBuzzerPattern(laneP),
    clampBuzzerPattern(leanP)
  };

  for (int i = 0; i < 4; i++) {
    if (seen[values[i]]) return false;
    seen[values[i]] = 1;
  }

  return true;
}

// ================= PREFERENCES =================
void loadConfig() {
  prefs.begin("drivora", true);

  brainConfig.setupCompleted = prefs.getBool("setupDone", false);
  brainConfig.profileName = prefs.getString("profile", "My Vehicle");

  brainConfig.vehicleType = prefs.getUChar("vehType", 3);
  brainConfig.trackWidth_m = prefs.getFloat("trackW", 1.56f);
  brainConfig.wheelBase_m = prefs.getFloat("wheelB", 2.67f);
  brainConfig.vehicleHeight_m = prefs.getFloat("vehH", 1.57f);
  brainConfig.loadCondition = prefs.getUChar("load", 1);

  brainConfig.frontSensitivityPreset = prefs.getUChar("frontPre", 1);
  brainConfig.rearSensitivityPreset = prefs.getUChar("rearPre", 1);

  brainConfig.centerCalibrated = prefs.getBool("centerCal", false);

  brainConfig.frontBuzzerPattern = prefs.getUChar("fBuzzPat", BUZZER_PATTERN_URGENT_TRIPLE);
  brainConfig.rearBuzzerPattern  = prefs.getUChar("rBuzzPat", BUZZER_PATTERN_WIDE_DOUBLE);
  brainConfig.laneBuzzerPattern  = prefs.getUChar("lBuzzPat", BUZZER_PATTERN_QUICK_DOUBLE);
  brainConfig.leanBuzzerPattern  = prefs.getUChar("nBuzzPat", BUZZER_PATTERN_TWO_TONE);

  brainConfig.frontBuzzerVolume = prefs.getUChar("fBuzzVol", 100);
  brainConfig.rearBuzzerVolume  = prefs.getUChar("rBuzzVol", 100);
  brainConfig.laneBuzzerVolume  = prefs.getUChar("lBuzzVol", 100);
  brainConfig.leanBuzzerVolume  = prefs.getUChar("nBuzzVol", 100);

  buzzerEnabled = prefs.getBool("buzzEn", true);

  prefs.end();

  brainConfig.vehicleType = constrain(brainConfig.vehicleType, 1, 3);
  brainConfig.trackWidth_m = clampf(brainConfig.trackWidth_m, 0.80f, 4.00f);
  brainConfig.wheelBase_m = clampf(brainConfig.wheelBase_m, 1.50f, 6.00f);
  brainConfig.vehicleHeight_m = clampf(brainConfig.vehicleHeight_m, 0.50f, 6.00f);
  brainConfig.loadCondition = constrain(brainConfig.loadCondition, 0, 2);
  brainConfig.frontSensitivityPreset = constrain(brainConfig.frontSensitivityPreset, 0, 2);
  brainConfig.rearSensitivityPreset = constrain(brainConfig.rearSensitivityPreset, 0, 2);

  brainConfig.frontBuzzerPattern = clampBuzzerPattern(brainConfig.frontBuzzerPattern);
  brainConfig.rearBuzzerPattern  = clampBuzzerPattern(brainConfig.rearBuzzerPattern);
  brainConfig.laneBuzzerPattern  = clampBuzzerPattern(brainConfig.laneBuzzerPattern);
  brainConfig.leanBuzzerPattern  = clampBuzzerPattern(brainConfig.leanBuzzerPattern);

  brainConfig.frontBuzzerVolume = clampBuzzerVolume(brainConfig.frontBuzzerVolume);
  brainConfig.rearBuzzerVolume  = clampBuzzerVolume(brainConfig.rearBuzzerVolume);
  brainConfig.laneBuzzerVolume  = clampBuzzerVolume(brainConfig.laneBuzzerVolume);
  brainConfig.leanBuzzerVolume  = clampBuzzerVolume(brainConfig.leanBuzzerVolume);

  enforceUniqueBuzzerPatterns();
}

void saveConfig() {
  prefs.begin("drivora", false);

  prefs.putBool("setupDone", brainConfig.setupCompleted);
  prefs.putString("profile", brainConfig.profileName);

  prefs.putUChar("vehType", brainConfig.vehicleType);
  prefs.putFloat("trackW", brainConfig.trackWidth_m);
  prefs.putFloat("wheelB", brainConfig.wheelBase_m);
  prefs.putFloat("vehH", brainConfig.vehicleHeight_m);
  prefs.putUChar("load", brainConfig.loadCondition);

  prefs.putUChar("frontPre", brainConfig.frontSensitivityPreset);
  prefs.putUChar("rearPre", brainConfig.rearSensitivityPreset);

  prefs.putBool("centerCal", brainConfig.centerCalibrated);
  prefs.putBool("buzzEn", buzzerEnabled);

  prefs.putUChar("fBuzzPat", brainConfig.frontBuzzerPattern);
  prefs.putUChar("rBuzzPat", brainConfig.rearBuzzerPattern);
  prefs.putUChar("lBuzzPat", brainConfig.laneBuzzerPattern);
  prefs.putUChar("nBuzzPat", brainConfig.leanBuzzerPattern);

  prefs.putUChar("fBuzzVol", brainConfig.frontBuzzerVolume);
  prefs.putUChar("rBuzzVol", brainConfig.rearBuzzerVolume);
  prefs.putUChar("lBuzzVol", brainConfig.laneBuzzerVolume);
  prefs.putUChar("nBuzzVol", brainConfig.leanBuzzerVolume);

  prefs.end();
}

// ================= CAN / TWAI =================
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

  Serial.println("TWAI started on brain");
  return true;
}

bool sendCANFrame(uint32_t id, const uint8_t* data, uint8_t len = 8) {
  twai_message_t message = {};
  message.identifier = id;
  message.extd = 0;
  message.rtr = 0;
  message.data_length_code = len;
  for (uint8_t i = 0; i < len; i++) message.data[i] = data[i];

  esp_err_t err = twai_transmit(&message, pdMS_TO_TICKS(10));
  return err == ESP_OK;
}

void sendLeanConfig() {
  uint16_t track_mm = (uint16_t)roundf(brainConfig.trackWidth_m * 1000.0f);
  uint16_t wheel_mm = (uint16_t)roundf(brainConfig.wheelBase_m * 1000.0f);
  uint16_t height_mm = (uint16_t)roundf(brainConfig.vehicleHeight_m * 1000.0f);

  uint8_t dataA[8] = {0};
  dataA[0] = brainConfig.vehicleType;
  dataA[1] = brainConfig.loadCondition;
  dataA[2] = (uint8_t)(track_mm & 0xFF);
  dataA[3] = (uint8_t)((track_mm >> 8) & 0xFF);
  dataA[4] = (uint8_t)(wheel_mm & 0xFF);
  dataA[5] = (uint8_t)((wheel_mm >> 8) & 0xFF);
  dataA[6] = 0x01; // apply now
  dataA[7] = leanCfgCounter++;

  uint8_t dataB[8] = {0};
  dataB[0] = (uint8_t)(height_mm & 0xFF);
  dataB[1] = (uint8_t)((height_mm >> 8) & 0xFF);
  dataB[2] = 0x01; // apply now
  dataB[7] = leanCfgCounter++;

  sendCANFrame(LEAN_CFG_A_ID, dataA, 8);
  delay(4);
  sendCANFrame(LEAN_CFG_B_ID, dataB, 8);

  Serial.printf("TX LeanCfg | type=%u load=%u track=%.2f wheel=%.2f height=%.2f\n",
                brainConfig.vehicleType,
                brainConfig.loadCondition,
                brainConfig.trackWidth_m,
                brainConfig.wheelBase_m,
                brainConfig.vehicleHeight_m);
}

void sendFrontConfig() {
  uint8_t data[8] = {0};
  data[0] = brainConfig.frontSensitivityPreset;
  data[7] = frontCfgCounter++;

  sendCANFrame(FRONT_CFG_ID, data, 8);
  Serial.printf("TX FrontCfg | preset=%u\n", brainConfig.frontSensitivityPreset);
}

void sendRearConfig() {
  uint8_t data[8] = {0};
  data[0] = brainConfig.rearSensitivityPreset;
  data[7] = rearCfgCounter++;

  sendCANFrame(REAR_CFG_ID, data, 8);
  Serial.printf("TX RearCfg | preset=%u\n", brainConfig.rearSensitivityPreset);
}

void sendLeanCalibrateCommand() {
  // App/wizard calibration is considered incomplete until this requested calibration completes.
  // This prevents the center unit's automatic startup calibration from marking setup as completed.
  brainConfig.centerCalibrated = false;
  centerCalibrationRequested = true;
  saveConfig();
  forceConfigBroadcast = true;

  uint8_t data[8] = {0};
  data[0] = 0x01; // bit0 calibrate
  data[7] = leanCmdCounter++;

  sendCANFrame(LEAN_CMD_ID, data, 8);
  Serial.println("TX LeanCmd | CALIBRATE");
}

void sendAllConfigs() {
  sendLeanConfig();
  delay(5);
  sendFrontConfig();
  delay(5);
  sendRearConfig();
}

void resetConfigToDefaults() {
  brainConfig.setupCompleted = false;
  brainConfig.profileName = "My Vehicle";
  brainConfig.vehicleType = 3;
  brainConfig.trackWidth_m = 1.56f;
  brainConfig.wheelBase_m = 2.67f;
  brainConfig.vehicleHeight_m = 1.57f;
  brainConfig.loadCondition = 1;
  brainConfig.frontSensitivityPreset = 1;
  brainConfig.rearSensitivityPreset = 1;
  brainConfig.centerCalibrated = false;

  brainConfig.frontBuzzerPattern = BUZZER_PATTERN_URGENT_TRIPLE;
  brainConfig.rearBuzzerPattern  = BUZZER_PATTERN_WIDE_DOUBLE;
  brainConfig.laneBuzzerPattern  = BUZZER_PATTERN_QUICK_DOUBLE;
  brainConfig.leanBuzzerPattern  = BUZZER_PATTERN_TWO_TONE;

  brainConfig.frontBuzzerVolume = 100;
  brainConfig.rearBuzzerVolume  = 100;
  brainConfig.laneBuzzerVolume  = 100;
  brainConfig.leanBuzzerVolume  = 100;

  buzzerEnabled = true;

  centerCalibrationRequested = false;
  saveConfig();
  forceConfigBroadcast = true;
  sendAllConfigs();
  Serial.println("Settings reset to defaults");
}

void receiveCANFrames(unsigned long nowMs) {
  twai_message_t message;

  while (twai_receive(&message, 0) == ESP_OK) {
    if (message.extd || message.rtr) continue;

    Serial.print("CAN RX ID: 0x");
    Serial.print(message.identifier, HEX);
    Serial.print(" DLC=");
    Serial.println(message.data_length_code);

    if (message.identifier == LEAN_MAIN_ID && message.data_length_code >= 8) {
      leanData.riskLevel = message.data[0];

      int16_t roll_x100  = packS16FromBytes(message.data[1], message.data[2]);
      int16_t pitch_x100 = packS16FromBytes(message.data[3], message.data[4]);

      leanData.rollDeg = unpackAngleDegX100(roll_x100);
      leanData.pitchDeg = unpackAngleDegX100(pitch_x100);
      leanData.confidence = ((float)message.data[5]) / 100.0f;
      leanData.calibrated = (message.data[6] & (1 << 0)) != 0;
      leanData.online = true;
      leanData.lastUpdateMs = nowMs;

      if (centerCalibrationRequested && leanData.calibrated) {
        brainConfig.centerCalibrated = true;
        centerCalibrationRequested = false;
        saveConfig();
        forceConfigBroadcast = true;
      }
    }
    else if (message.identifier == LEAN_DEBUG_ID && message.data_length_code >= 8) {
      uint16_t criticalRoll_x100  = packU16FromBytes(message.data[0], message.data[1]);
      uint16_t criticalPitch_x100 = packU16FromBytes(message.data[2], message.data[3]);

      leanData.criticalRollDeg = unpackUnsignedAngleDegX100(criticalRoll_x100);
      leanData.criticalPitchDeg = unpackUnsignedAngleDegX100(criticalPitch_x100);
      leanData.vehicleType = message.data[4];
      leanData.loadCondition = message.data[5];
      leanData.debugFlags2 = message.data[6];
      leanData.debugCounter = message.data[7];
      leanData.lastDebugUpdateMs = nowMs;
    }
    else if (message.identifier == FRONT_MAIN_ID && message.data_length_code >= 8) {
      frontData.state = message.data[0];

      uint16_t filtered_x10 = packU16FromBytes(message.data[1], message.data[2]);
      int16_t  speed_x10    = packS16FromBytes(message.data[3], message.data[4]);
      uint16_t raw_x10      = packU16FromBytes(message.data[5], message.data[6]);

      frontData.filteredDistanceCm = unpackDistanceCm(filtered_x10);
      frontData.closingSpeedCmS    = unpackSpeedCmS(speed_x10);
      frontData.rawDistanceCm      = unpackDistanceCm(raw_x10);
      frontData.online             = true;
      frontData.lastUpdateMs       = nowMs;
    }
    else if (message.identifier == FRONT_DEBUG_ID && message.data_length_code >= 8) {
      frontData.debugFlags          = message.data[0];
      frontData.approachCounter     = message.data[1];
      frontData.warningCounter      = message.data[2];
      frontData.blindReleaseCounter = message.data[3];
      frontData.invalidStreak       = message.data[4];
      frontData.debugCounter        = message.data[7];
      frontData.lastDebugUpdateMs   = nowMs;
    }
    else if (message.identifier == REAR_MAIN_ID && message.data_length_code >= 8) {
      rearData.leftState    = message.data[0];
      rearData.centerState  = message.data[1];
      rearData.rightState   = message.data[2];
      rearData.leftFlags    = message.data[3];
      rearData.centerFlags  = message.data[4];
      rearData.rightFlags   = message.data[5];
      rearData.overallState = message.data[6];
      rearData.mainCounter  = message.data[7];

      rearData.online       = true;
      rearData.lastUpdateMs = nowMs;
    }
    else if (message.identifier == REAR_DEBUG_ID && message.data_length_code >= 8) {
      rearData.leftWarningReleaseCounter        = message.data[0];
      rearData.centerWarningReleaseCounter      = message.data[1];
      rearData.rightWarningReleaseCounter       = message.data[2];
      rearData.leftFastWarningReleaseCounter    = message.data[3];
      rearData.centerFastWarningReleaseCounter  = message.data[4];
      rearData.rightFastWarningReleaseCounter   = message.data[5];
      rearData.maxInvalidStreak                 = message.data[6];
      rearData.debugCounter                     = message.data[7];
      rearData.lastDebugUpdateMs                = nowMs;
    }
    else if (message.identifier == REAR_DIST_ID && message.data_length_code >= 8) {
      uint16_t left_x10   = packU16FromBytes(message.data[0], message.data[1]);
      uint16_t center_x10 = packU16FromBytes(message.data[2], message.data[3]);
      uint16_t right_x10  = packU16FromBytes(message.data[4], message.data[5]);

      rearData.leftFilteredDistanceCm   = unpackDistanceCm(left_x10);
      rearData.centerFilteredDistanceCm = unpackDistanceCm(center_x10);
      rearData.rightFilteredDistanceCm  = unpackDistanceCm(right_x10);
      rearData.nearestSensor            = message.data[6];
      rearData.distCounter              = message.data[7];
      rearData.lastDistUpdateMs         = nowMs;

      if (!rearData.online) rearData.online = true;
    }
  }
}

// ================= LANE UART RECEIVE =================
void applyLaneStateLine(const String& line, unsigned long nowMs) {
  String msg = trimLine(line);
  if (msg.length() == 0) return;

  int newState = -1;

  if (msg == "0" || msg.endsWith(":0") || msg == "LDW:SAFE" || msg == "SAFE") {
    newState = 0;
  } else if (msg == "1" || msg.endsWith(":1") || msg == "LDW:LEFT" || msg == "LEFT_DEPARTURE") {
    newState = 1;
  } else if (msg == "2" || msg.endsWith(":2") || msg == "LDW:RIGHT" || msg == "RIGHT_DEPARTURE") {
    newState = 2;
  } else {
    return;
  }

  laneData.state = (uint8_t)newState;
  laneData.online = true;
  laneData.lastUpdateMs = nowMs;
}

void receiveLaneUART(unsigned long nowMs) {
  while (Serial2.available()) {
    char c = (char)Serial2.read();

    if (c == '\r') continue;

    if (c == '\n') {
      applyLaneStateLine(laneRxBuffer, nowMs);
      laneRxBuffer = "";
    } else {
      if (laneRxBuffer.length() < 60) {
        laneRxBuffer += c;
      } else {
        laneRxBuffer = "";
      }
    }
  }
}

// ================= COMMANDS FROM WEB UI =================
void handleIncomingCommand(const String& msg) {
  Serial.print("WS RX: ");
  Serial.println(msg);

  if (msg == "PING") return;

  if (msg == "WIZARD_BUZZER_MUTE") {
    setupWizardBuzzerMuted = true;
    buzzerOff();
    Serial.println("Wizard buzzer temporarily muted");
    return;
  }

  if (msg == "WIZARD_BUZZER_ENABLE") {
    setupWizardBuzzerMuted = false;
    Serial.println("Wizard buzzer temporarily enabled");
    return;
  }

  if (msg == "BUZZER_TOGGLE") {
    buzzerEnabled = !buzzerEnabled;
    if (!buzzerEnabled) buzzerOff();
    saveConfig();
    forceConfigBroadcast = true;
    Serial.print("Buzzer ");
    Serial.println(buzzerEnabled ? "ENABLED" : "DISABLED");
    return;
  }

  if (msg == "BUZZER_ON") {
    buzzerEnabled = true;
    saveConfig();
    forceConfigBroadcast = true;
    Serial.println("Buzzer ENABLED");
    return;
  }

  if (msg == "BUZZER_OFF") {
    buzzerEnabled = false;
    buzzerOff();
    saveConfig();
    forceConfigBroadcast = true;
    Serial.println("Buzzer DISABLED");
    return;
  }

  if (msg == "CAL_CENTER") {
    sendLeanCalibrateCommand();
    return;
  }

  if (msg == "PUSH_ALL_CONFIG") {
    sendAllConfigs();
    return;
  }

  if (msg == "RESET_DEFAULTS") {
    resetConfigToDefaults();
    return;
  }

  if (msg == "START_WIZARD") {
    brainConfig.setupCompleted = false;
    brainConfig.centerCalibrated = false;
    centerCalibrationRequested = false;
    setupWizardBuzzerMuted = true;
    buzzerOff();
    saveConfig();
    Serial.println("Setup wizard started; dashboard locked until setup completion");
    return;
  }

  // Very small JSON parser via Arduino String handling to avoid bringing extra JSON lib here
  if (msg.startsWith("{") && msg.endsWith("}")) {
    auto readNumber = [&](const String& key, float fallback)->float {
      String token = "\"" + key + "\":";
      int idx = msg.indexOf(token);
      if (idx < 0) return fallback;
      idx += token.length();
      int end = idx;
      while (end < (int)msg.length() && (isdigit(msg[end]) || msg[end] == '.' || msg[end] == '-')) end++;
      return msg.substring(idx, end).toFloat();
    };

    auto readInt = [&](const String& key, int fallback)->int {
      return (int)roundf(readNumber(key, (float)fallback));
    };

    auto readBool = [&](const String& key, bool fallback)->bool {
      String token = "\"" + key + "\":";
      int idx = msg.indexOf(token);
      if (idx < 0) return fallback;
      idx += token.length();
      String rem = msg.substring(idx);
      if (rem.startsWith("true")) return true;
      if (rem.startsWith("false")) return false;
      return fallback;
    };

    if (msg.indexOf("\"cmd\":\"testSound\"") >= 0) {
      uint8_t pattern = clampBuzzerPattern(readInt("pattern", BUZZER_PATTERN_URGENT_TRIPLE));
      uint8_t volume = clampBuzzerVolume(readInt("volume", 100));
      startBuzzerTest(pattern, volume);
      return;
    }

    if (msg.indexOf("\"cmd\":\"saveVehicle\"") >= 0) {
      brainConfig.vehicleType = constrain(readInt("vehicleType", brainConfig.vehicleType), 1, 3);
      brainConfig.trackWidth_m = clampf(readNumber("trackWidth_m", brainConfig.trackWidth_m), 0.80f, 4.00f);
      brainConfig.wheelBase_m = clampf(readNumber("wheelBase_m", brainConfig.wheelBase_m), 1.50f, 6.00f);
      brainConfig.vehicleHeight_m = clampf(readNumber("vehicleHeight_m", brainConfig.vehicleHeight_m), 0.50f, 6.00f);
      brainConfig.loadCondition = constrain(readInt("loadCondition", brainConfig.loadCondition), 0, 2);
      brainConfig.setupCompleted = readBool("setupCompleted", true);
      saveConfig();
      forceConfigBroadcast = true;
      sendLeanConfig();
      return;
    }

    if (msg.indexOf("\"cmd\":\"saveFrontPreset\"") >= 0) {
      brainConfig.frontSensitivityPreset = constrain(readInt("frontPreset", brainConfig.frontSensitivityPreset), 0, 2);
      brainConfig.setupCompleted = true;
      saveConfig();
      forceConfigBroadcast = true;
      sendFrontConfig();
      return;
    }

    if (msg.indexOf("\"cmd\":\"saveRearPreset\"") >= 0) {
      brainConfig.rearSensitivityPreset = constrain(readInt("rearPreset", brainConfig.rearSensitivityPreset), 0, 2);
      brainConfig.setupCompleted = true;
      saveConfig();
      forceConfigBroadcast = true;
      sendRearConfig();
      return;
    }

    if (msg.indexOf("\"cmd\":\"saveSoundSettings\"") >= 0) {
      uint8_t frontPattern = clampBuzzerPattern(readInt("frontSoundPattern", brainConfig.frontBuzzerPattern));
      uint8_t rearPattern  = clampBuzzerPattern(readInt("rearSoundPattern", brainConfig.rearBuzzerPattern));
      uint8_t lanePattern  = clampBuzzerPattern(readInt("laneSoundPattern", brainConfig.laneBuzzerPattern));
      uint8_t leanPattern  = clampBuzzerPattern(readInt("leanSoundPattern", brainConfig.leanBuzzerPattern));

      if (!areBuzzerPatternsUnique(frontPattern, rearPattern, lanePattern, leanPattern)) {
        Serial.println("Sound settings rejected: duplicate buzzer patterns");
        forceConfigBroadcast = true;
        return;
      }

      brainConfig.frontBuzzerPattern = frontPattern;
      brainConfig.rearBuzzerPattern  = rearPattern;
      brainConfig.laneBuzzerPattern  = lanePattern;
      brainConfig.leanBuzzerPattern  = leanPattern;

      brainConfig.frontBuzzerVolume = clampBuzzerVolume(readInt("frontSoundVolume", brainConfig.frontBuzzerVolume));
      brainConfig.rearBuzzerVolume  = clampBuzzerVolume(readInt("rearSoundVolume", brainConfig.rearBuzzerVolume));
      brainConfig.laneBuzzerVolume  = clampBuzzerVolume(readInt("laneSoundVolume", brainConfig.laneBuzzerVolume));
      brainConfig.leanBuzzerVolume  = clampBuzzerVolume(readInt("leanSoundVolume", brainConfig.leanBuzzerVolume));

      saveConfig();
      forceConfigBroadcast = true;
      Serial.println("Sound settings saved");
      return;
    }

    if (msg.indexOf("\"cmd\":\"saveAllSetup\"") >= 0) {
      brainConfig.vehicleType = constrain(readInt("vehicleType", brainConfig.vehicleType), 1, 3);
      brainConfig.trackWidth_m = clampf(readNumber("trackWidth_m", brainConfig.trackWidth_m), 0.80f, 4.00f);
      brainConfig.wheelBase_m = clampf(readNumber("wheelBase_m", brainConfig.wheelBase_m), 1.50f, 6.00f);
      brainConfig.vehicleHeight_m = clampf(readNumber("vehicleHeight_m", brainConfig.vehicleHeight_m), 0.50f, 6.00f);
      brainConfig.loadCondition = constrain(readInt("loadCondition", brainConfig.loadCondition), 0, 2);
      brainConfig.frontSensitivityPreset = constrain(readInt("frontPreset", brainConfig.frontSensitivityPreset), 0, 2);
      brainConfig.rearSensitivityPreset = constrain(readInt("rearPreset", brainConfig.rearSensitivityPreset), 0, 2);

      uint8_t frontPattern = clampBuzzerPattern(readInt("frontSoundPattern", brainConfig.frontBuzzerPattern));
      uint8_t rearPattern  = clampBuzzerPattern(readInt("rearSoundPattern", brainConfig.rearBuzzerPattern));
      uint8_t lanePattern  = clampBuzzerPattern(readInt("laneSoundPattern", brainConfig.laneBuzzerPattern));
      uint8_t leanPattern  = clampBuzzerPattern(readInt("leanSoundPattern", brainConfig.leanBuzzerPattern));

      if (areBuzzerPatternsUnique(frontPattern, rearPattern, lanePattern, leanPattern)) {
        brainConfig.frontBuzzerPattern = frontPattern;
        brainConfig.rearBuzzerPattern  = rearPattern;
        brainConfig.laneBuzzerPattern  = lanePattern;
        brainConfig.leanBuzzerPattern  = leanPattern;
      }

      brainConfig.frontBuzzerVolume = clampBuzzerVolume(readInt("frontSoundVolume", brainConfig.frontBuzzerVolume));
      brainConfig.rearBuzzerVolume  = clampBuzzerVolume(readInt("rearSoundVolume", brainConfig.rearBuzzerVolume));
      brainConfig.laneBuzzerVolume  = clampBuzzerVolume(readInt("laneSoundVolume", brainConfig.laneBuzzerVolume));
      brainConfig.leanBuzzerVolume  = clampBuzzerVolume(readInt("leanSoundVolume", brainConfig.leanBuzzerVolume));

      brainConfig.setupCompleted = true;
      setupWizardBuzzerMuted = false;
      saveConfig();
      forceConfigBroadcast = true;
      sendAllConfigs();
      return;
    }
  }
}


// ================= BUZZER HELPERS =================
void buzzerBegin() {
  ledcSetup(BUZZER_CHANNEL, 2000, BUZZER_RESOLUTION);
  ledcAttachPin(BUZZER_PIN, BUZZER_CHANNEL);
  ledcWriteTone(BUZZER_CHANNEL, 0);
  ledcWrite(BUZZER_CHANNEL, 0);
  currentBuzzerFreq = 0;
  currentBuzzerDuty = 0;
}

void buzzerOff();

uint16_t buzzerDutyFromVolume(uint8_t volumePercent) {
  volumePercent = clampBuzzerVolume(volumePercent);

  // 10-bit PWM. 100% keeps the current/default loudness level.
  // Minimum is still audible but intentionally limited so vehicle warnings do not become too quiet.
  return map(volumePercent, BUZZER_VOLUME_MIN, BUZZER_VOLUME_MAX, 155, 512);
}

uint8_t getBuzzerVolumeForType(const String& buzzerType) {
  if (buzzerType == "FRONT_ALERT") return brainConfig.frontBuzzerVolume;
  if (buzzerType == "REAR_ALERT") return brainConfig.rearBuzzerVolume;
  if (buzzerType == "LANE_WARNING") return brainConfig.laneBuzzerVolume;
  if (buzzerType == "LEAN_HIGH" || buzzerType == "LEAN_CAUTION") return brainConfig.leanBuzzerVolume;
  return 100;
}

uint8_t getBuzzerPatternForType(const String& buzzerType) {
  if (buzzerType == "FRONT_ALERT") return brainConfig.frontBuzzerPattern;
  if (buzzerType == "REAR_ALERT") return brainConfig.rearBuzzerPattern;
  if (buzzerType == "LANE_WARNING") return brainConfig.laneBuzzerPattern;
  if (buzzerType == "LEAN_HIGH" || buzzerType == "LEAN_CAUTION") return brainConfig.leanBuzzerPattern;
  return BUZZER_PATTERN_URGENT_TRIPLE;
}

void buzzerTone(int freq) {
  if (((!buzzerEnabled || setupWizardBuzzerMuted) && !buzzerTestActive) || freq <= 0) {
    buzzerOff();
    return;
  }

  uint8_t volumeForTone = (buzzerVolumeOverride >= 0)
                            ? (uint8_t)buzzerVolumeOverride
                            : getBuzzerVolumeForType(activeBuzzerType);
  uint16_t duty = buzzerDutyFromVolume(volumeForTone);

  if (currentBuzzerFreq != freq || currentBuzzerDuty != duty) {
    ledcWriteTone(BUZZER_CHANNEL, freq);
    ledcWrite(BUZZER_CHANNEL, duty);
    currentBuzzerFreq = freq;
    currentBuzzerDuty = duty;
  }
}

void buzzerOff() {
  if (currentBuzzerFreq != 0 || currentBuzzerDuty != 0) {
    ledcWriteTone(BUZZER_CHANNEL, 0);
    ledcWrite(BUZZER_CHANNEL, 0);
    currentBuzzerFreq = 0;
    currentBuzzerDuty = 0;
  }
}

void playAssignedBuzzerPattern(uint8_t pattern, uint8_t severity, unsigned long t) {
  pattern = clampBuzzerPattern(pattern);

  if (pattern == BUZZER_PATTERN_URGENT_TRIPLE) {
    unsigned long p;
    if (severity >= 3) {
      p = t % 420;
      if (p < 75 || (p >= 135 && p < 210) || (p >= 270 && p < 345)) buzzerTone(2200);
      else buzzerOff();
    } else if (severity == 2) {
      p = t % 620;
      if (p < 95 || (p >= 210 && p < 305)) buzzerTone(2200);
      else buzzerOff();
    } else {
      p = t % 850;
      if (p < 120) buzzerTone(2200);
      else buzzerOff();
    }
    return;
  }

  if (pattern == BUZZER_PATTERN_WIDE_DOUBLE) {
    unsigned long p;
    if (severity >= 3) {
      p = t % 640;
      if (p < 130 || (p >= 280 && p < 410)) buzzerTone(2150);
      else buzzerOff();
    } else if (severity == 2) {
      p = t % 780;
      if (p < 140) buzzerTone(2150);
      else buzzerOff();
    } else {
      p = t % 980;
      if (p < 110) buzzerTone(2150);
      else buzzerOff();
    }
    return;
  }

  if (pattern == BUZZER_PATTERN_QUICK_DOUBLE) {
    unsigned long p = severity >= 3 ? (t % 620) : (t % 820);
    if (p < 70 || (p >= 145 && p < 215)) buzzerTone(2250);
    else buzzerOff();
    return;
  }

  if (pattern == BUZZER_PATTERN_TWO_TONE) {
    unsigned long p = severity >= 3 ? (t % 600) : (t % 860);
    if (severity >= 3) {
      if (p < 180) buzzerTone(2200);
      else if (p >= 300 && p < 480) buzzerTone(2350);
      else buzzerOff();
    } else {
      if (p < 130) buzzerTone(2300);
      else buzzerOff();
    }
    return;
  }

  buzzerOff();
}

void startBuzzerTest(uint8_t pattern, uint8_t volumePercent) {
  testBuzzerPattern = clampBuzzerPattern(pattern);
  testBuzzerVolume = clampBuzzerVolume(volumePercent);
  testBuzzerStartMs = millis();
  testBuzzerUntilMs = testBuzzerStartMs + 1800;
  buzzerTestActive = true;
  buzzerVolumeOverride = testBuzzerVolume;

  // Stop any live-warning tone briefly so the selected pattern test starts cleanly.
  buzzerOff();

  Serial.print("Buzzer test | pattern=");
  Serial.print(testBuzzerPattern);
  Serial.print(" volume=");
  Serial.println(testBuzzerVolume);
}

String normalizeBuzzerType(const String& fusedType, uint8_t fusedSeverity) {
  if (fusedSeverity == 0 || fusedType == "NONE") return "NONE";

  // Keep one stable buzzer family for all front states.
  // This prevents FRONT_WARNING <-> FRONT_APPROACHING <-> FRONT_OBJECT oscillation
  // from restarting the buzzer pattern and causing stuck/continuous tones.
  if (fusedType == "FRONT_WARNING" ||
      fusedType == "FRONT_APPROACHING" ||
      fusedType == "FRONT_OBJECT") {
    return "FRONT_ALERT";
  }

  // Keep one stable buzzer family for all rear states for the same reason.
  if (fusedType == "REAR_WARNING" ||
      fusedType == "REAR_CAUTION" ||
      fusedType == "REAR_OBJECT") {
    return "REAR_ALERT";
  }

  if (fusedType == "LANE_LEFT" || fusedType == "LANE_RIGHT") return "LANE_WARNING";

  if (fusedType == "LEAN_HIGH") return "LEAN_HIGH";
  if (fusedType == "LEAN_CAUTION") return "LEAN_CAUTION";

  if (fusedSeverity >= 3) return "GENERAL_WARNING";
  return "GENERAL_CAUTION";
}

void selectActiveBuzzerType(const String& requestedType, uint8_t requestedSeverity, unsigned long nowMs) {
  if (!buzzerEnabled || setupWizardBuzzerMuted || requestedType == "NONE" || requestedSeverity == 0) {
    if (activeBuzzerType != "NONE" && buzzerClearCandidateMs == 0) {
      buzzerClearCandidateMs = nowMs;
    }

    if (activeBuzzerType == "NONE" || (nowMs - buzzerClearCandidateMs) >= BUZZER_CLEAR_GRACE_MS) {
      activeBuzzerType = "NONE";
      activeBuzzerSeverity = 0;
      buzzerClearCandidateMs = 0;
      buzzerOff();
    }
    return;
  }

  buzzerClearCandidateMs = 0;

  if (activeBuzzerType == "NONE") {
    activeBuzzerType = requestedType;
    activeBuzzerSeverity = requestedSeverity;
    buzzerPatternStartMs = nowMs;
    buzzerSwitchMuteUntilMs = nowMs + BUZZER_SWITCH_GAP_MS;
    buzzerOff();
    return;
  }

  if (requestedType == activeBuzzerType) {
    activeBuzzerSeverity = requestedSeverity;
    return;
  }

  bool holdCompleted = (nowMs - buzzerPatternStartMs) >= BUZZER_MIN_TYPE_HOLD_MS;
  bool requestedIsMoreUrgent = requestedSeverity > activeBuzzerSeverity;

  if (holdCompleted || requestedIsMoreUrgent) {
    activeBuzzerType = requestedType;
    activeBuzzerSeverity = requestedSeverity;
    buzzerPatternStartMs = nowMs;
    buzzerSwitchMuteUntilMs = nowMs + BUZZER_SWITCH_GAP_MS;
    buzzerOff();
  }
}

void updateBuzzerByFusedType(const String& fusedType, uint8_t fusedSeverity, unsigned long nowMs) {
  if (buzzerTestActive) {
    if (nowMs >= testBuzzerUntilMs) {
      buzzerTestActive = false;
      buzzerVolumeOverride = -1;
      buzzerOff();
    } else {
      buzzerVolumeOverride = testBuzzerVolume;
      playAssignedBuzzerPattern(testBuzzerPattern, 3, nowMs - testBuzzerStartMs);
      buzzerVolumeOverride = -1;
      return;
    }
  }

  String requestedType = normalizeBuzzerType(fusedType, fusedSeverity);

  selectActiveBuzzerType(requestedType, fusedSeverity, nowMs);

  if (!buzzerEnabled || setupWizardBuzzerMuted || activeBuzzerType == "NONE" || activeBuzzerSeverity == 0) {
    buzzerOff();
    return;
  }

  if (nowMs < buzzerSwitchMuteUntilMs) {
    buzzerOff();
    return;
  }

  unsigned long t = nowMs - buzzerPatternStartMs;

  // Loud vehicle-use tone plan:
  // All selectable patterns stay close to the buzzer's loud/resonant area.
  // Unit identity is controlled by the assigned pattern, and volume is controlled
  // by the unit volume sliders.
  uint8_t assignedPattern = getBuzzerPatternForType(activeBuzzerType);
  playAssignedBuzzerPattern(assignedPattern, activeBuzzerSeverity, t);
  return;

  buzzerOff();
}

// ================= JSON BROADCAST =================
void broadcastCombinedState(unsigned long nowMs) {
  String data;
  data.reserve(3200);

  bool leanOffline  = isOffline(leanData.lastUpdateMs, nowMs);
  bool frontOffline = isOffline(frontData.lastUpdateMs, nowMs);
  bool rearOffline  = isOffline(rearData.lastUpdateMs, nowMs);
  bool laneOffline  = isOffline(laneData.lastUpdateMs, nowMs);

  String fusedType = "NONE";
  String fusedTitle = "All Clear";
  String fusedMessage = "No active safety warnings.";
  String fusedColor = "#1db954";
  uint8_t fusedSeverity = 0; // 0 clear, 1 info, 2 caution, 3 warning

  if (!leanOffline && leanData.riskLevel == 2) {
    fusedType = "LEAN_HIGH";
    fusedTitle = "High Lean Risk";
    fusedMessage = "Vehicle lean angle is high. Reduce speed and stabilize the vehicle.";
    fusedColor = "#ff3b30";
    fusedSeverity = 3;
  } else if (!frontOffline && frontData.state == 3) {
    fusedType = "FRONT_WARNING";
    fusedTitle = "Front Collision Warning";
    fusedMessage = "Obstacle ahead with high risk. Brake or slow down.";
    fusedColor = "#ff3b30";
    fusedSeverity = 3;
  } else if (!rearOffline && rearData.overallState == 3) {
    fusedType = "REAR_WARNING";
    fusedTitle = "Rear Blindspot Warning";
    fusedMessage = "Very close object detected behind the vehicle.";
    fusedColor = "#ff3b30";
    fusedSeverity = 3;
  } else if (!laneOffline && laneData.state == 1) {
    fusedType = "LANE_LEFT";
    fusedTitle = "Left Lane Departure";
    fusedMessage = "Vehicle is drifting toward the left lane marking.";
    fusedColor = "#ffb020";
    fusedSeverity = 2;
  } else if (!laneOffline && laneData.state == 2) {
    fusedType = "LANE_RIGHT";
    fusedTitle = "Right Lane Departure";
    fusedMessage = "Vehicle is drifting toward the right lane marking.";
    fusedColor = "#ffb020";
    fusedSeverity = 2;
  } else if (!leanOffline && leanData.riskLevel == 1) {
    fusedType = "LEAN_CAUTION";
    fusedTitle = "Lean Caution";
    fusedMessage = "Vehicle lean is increasing. Drive carefully.";
    fusedColor = "#ffb020";
    fusedSeverity = 2;
  } else if (!frontOffline && frontData.state == 2) {
    fusedType = "FRONT_APPROACHING";
    fusedTitle = "Object Approaching";
    fusedMessage = "Object ahead is getting closer.";
    fusedColor = "#ff7230";
    fusedSeverity = 2;
  } else if (!rearOffline && rearData.overallState == 2) {
    fusedType = "REAR_CAUTION";
    fusedTitle = "Rear Caution";
    fusedMessage = "Object detected close to the rear blindspot area.";
    fusedColor = "#ffb020";
    fusedSeverity = 2;
  } else if (!frontOffline && frontData.state == 1) {
    fusedType = "FRONT_OBJECT";
    fusedTitle = "Object Ahead";
    fusedMessage = "Object detected in front.";
    fusedColor = "#f5c542";
    fusedSeverity = 1;
  } else if (!rearOffline && rearData.overallState == 1) {
    fusedType = "REAR_OBJECT";
    fusedTitle = "Rear Object Detected";
    fusedMessage = "Object detected behind the vehicle.";
    fusedColor = "#f5c542";
    fusedSeverity = 1;
  }

  currentFusedType = fusedType;
  currentFusedSeverity = fusedSeverity;

  bool includeConfig = forceConfigBroadcast || ((nowMs - lastConfigBroadcastMs) >= CONFIG_BROADCAST_MS);
  if (includeConfig) {
    lastConfigBroadcastMs = nowMs;
    forceConfigBroadcast = false;
  }

  data += "{";

  if (includeConfig) {
    data += "\"config\":{";
  data += "\"setupCompleted\":" + String(brainConfig.setupCompleted ? 1 : 0) + ",";
  data += "\"profileName\":\"" + brainConfig.profileName + "\",";
  data += "\"vehicleType\":" + String(brainConfig.vehicleType) + ",";
  data += "\"vehicleTypeName\":\"" + String(vehicleTypeName(brainConfig.vehicleType)) + "\",";
  data += "\"trackWidth_m\":" + String(brainConfig.trackWidth_m, 2) + ",";
  data += "\"wheelBase_m\":" + String(brainConfig.wheelBase_m, 2) + ",";
  data += "\"vehicleHeight_m\":" + String(brainConfig.vehicleHeight_m, 2) + ",";
  data += "\"loadCondition\":" + String(brainConfig.loadCondition) + ",";
  data += "\"loadConditionName\":\"" + String(loadConditionName(brainConfig.loadCondition)) + "\",";
  data += "\"frontPreset\":" + String(brainConfig.frontSensitivityPreset) + ",";
  data += "\"frontPresetName\":\"" + String(presetName(brainConfig.frontSensitivityPreset)) + "\",";
  data += "\"rearPreset\":" + String(brainConfig.rearSensitivityPreset) + ",";
  data += "\"rearPresetName\":\"" + String(presetName(brainConfig.rearSensitivityPreset)) + "\",";
  data += "\"centerCalibrated\":" + String(brainConfig.centerCalibrated ? 1 : 0) + ",";
  data += "\"buzzerEnabled\":" + String(buzzerEnabled ? 1 : 0) + ",";
  data += "\"frontSoundPattern\":" + String(brainConfig.frontBuzzerPattern) + ",";
  data += "\"rearSoundPattern\":" + String(brainConfig.rearBuzzerPattern) + ",";
  data += "\"laneSoundPattern\":" + String(brainConfig.laneBuzzerPattern) + ",";
  data += "\"leanSoundPattern\":" + String(brainConfig.leanBuzzerPattern) + ",";
  data += "\"frontSoundVolume\":" + String(brainConfig.frontBuzzerVolume) + ",";
  data += "\"rearSoundVolume\":" + String(brainConfig.rearBuzzerVolume) + ",";
  data += "\"laneSoundVolume\":" + String(brainConfig.laneBuzzerVolume) + ",";
  data += "\"leanSoundVolume\":" + String(brainConfig.leanBuzzerVolume);
  data += "},";
  }

  data += "\"fused\":{";
  data += "\"type\":\"" + fusedType + "\",";
  data += "\"title\":\"" + fusedTitle + "\",";
  data += "\"message\":\"" + fusedMessage + "\",";
  data += "\"color\":\"" + fusedColor + "\",";
  data += "\"severity\":" + String(fusedSeverity);
  data += "},";

  data += "\"lean\":{";
  data += "\"online\":" + String(leanOffline ? 0 : 1) + ",";
  data += "\"stale\":" + String(isStale(leanData.lastUpdateMs, nowMs) ? 1 : 0) + ",";
  data += "\"calibrated\":" + String(leanData.calibrated ? 1 : 0) + ",";
  data += "\"riskLevel\":" + String(leanData.riskLevel) + ",";
  data += "\"riskName\":\"" + String(leanRiskName(leanData.riskLevel)) + "\",";
  data += "\"roll\":" + String(leanData.rollDeg, 2) + ",";
  data += "\"pitch\":" + String(leanData.pitchDeg, 2) + ",";
  data += "\"confidence\":" + String(leanData.confidence, 2) + ",";
  data += "\"criticalRollDeg\":" + String(leanData.criticalRollDeg, 2) + ",";
  data += "\"criticalPitchDeg\":" + String(leanData.criticalPitchDeg, 2) + ",";
  data += "\"vehicleType\":" + String(leanData.vehicleType) + ",";
  data += "\"loadCondition\":" + String(leanData.loadCondition);
  data += "},";

  data += "\"front\":{";
  data += "\"online\":" + String(frontOffline ? 0 : 1) + ",";
  data += "\"stale\":" + String(isStale(frontData.lastUpdateMs, nowMs) ? 1 : 0) + ",";
  data += "\"state\":" + String(frontData.state) + ",";
  data += "\"stateName\":\"" + String(frontStateName(frontData.state)) + "\",";
  data += "\"stateColor\":\"" + String(stateColorByLevel(frontData.state)) + "\",";
  data += "\"filteredDistanceCm\":" + String(frontData.filteredDistanceCm, 1) + ",";
  data += "\"rawDistanceCm\":" + String(frontData.rawDistanceCm, 1) + ",";
  data += "\"closingSpeedCmS\":" + String(frontData.closingSpeedCmS, 1) + ",";
  data += "\"debugFlags\":" + String(frontData.debugFlags) + ",";
  data += "\"approachCounter\":" + String(frontData.approachCounter) + ",";
  data += "\"warningCounter\":" + String(frontData.warningCounter) + ",";
  data += "\"blindReleaseCounter\":" + String(frontData.blindReleaseCounter) + ",";
  data += "\"invalidStreak\":" + String(frontData.invalidStreak);
  data += "},";

  data += "\"rear\":{";
  data += "\"online\":" + String(rearOffline ? 0 : 1) + ",";
  data += "\"stale\":" + String(isStale(rearData.lastUpdateMs, nowMs) ? 1 : 0) + ",";
  data += "\"leftState\":" + String(rearData.leftState) + ",";
  data += "\"leftStateName\":\"" + String(rearStateName(rearData.leftState)) + "\",";
  data += "\"leftStateColor\":\"" + String(stateColorByLevel(rearData.leftState)) + "\",";
  data += "\"centerState\":" + String(rearData.centerState) + ",";
  data += "\"centerStateName\":\"" + String(rearStateName(rearData.centerState)) + "\",";
  data += "\"centerStateColor\":\"" + String(stateColorByLevel(rearData.centerState)) + "\",";
  data += "\"rightState\":" + String(rearData.rightState) + ",";
  data += "\"rightStateName\":\"" + String(rearStateName(rearData.rightState)) + "\",";
  data += "\"rightStateColor\":\"" + String(stateColorByLevel(rearData.rightState)) + "\",";
  data += "\"overallState\":" + String(rearData.overallState) + ",";
  data += "\"overallStateName\":\"" + String(rearStateName(rearData.overallState)) + "\",";
  data += "\"overallStateColor\":\"" + String(stateColorByLevel(rearData.overallState)) + "\",";
  data += "\"leftFilteredDistanceCm\":" + String(rearData.leftFilteredDistanceCm, 1) + ",";
  data += "\"centerFilteredDistanceCm\":" + String(rearData.centerFilteredDistanceCm, 1) + ",";
  data += "\"rightFilteredDistanceCm\":" + String(rearData.rightFilteredDistanceCm, 1) + ",";
  data += "\"nearestSensor\":" + String(rearData.nearestSensor) + ",";
  data += "\"leftWarningReleaseCounter\":" + String(rearData.leftWarningReleaseCounter) + ",";
  data += "\"centerWarningReleaseCounter\":" + String(rearData.centerWarningReleaseCounter) + ",";
  data += "\"rightWarningReleaseCounter\":" + String(rearData.rightWarningReleaseCounter) + ",";
  data += "\"leftFastWarningReleaseCounter\":" + String(rearData.leftFastWarningReleaseCounter) + ",";
  data += "\"centerFastWarningReleaseCounter\":" + String(rearData.centerFastWarningReleaseCounter) + ",";
  data += "\"rightFastWarningReleaseCounter\":" + String(rearData.rightFastWarningReleaseCounter) + ",";
  data += "\"maxInvalidStreak\":" + String(rearData.maxInvalidStreak);
  data += "},";

  data += "\"lane\":{";
  data += "\"online\":" + String(laneOffline ? 0 : 1) + ",";
  data += "\"stale\":" + String(isStale(laneData.lastUpdateMs, nowMs) ? 1 : 0) + ",";
  data += "\"state\":" + String(laneData.state) + ",";
  data += "\"stateName\":\"" + String(laneStateName(laneData.state)) + "\",";
  data += "\"stateColor\":\"" + String(laneStateColor(laneData.state)) + "\"";
  data += "}";

  data += "}";

  webSocket.broadcastTXT(data);
}

// ================= WEB UI =================
const char webpage[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>ADAS Brain</title>
<style>
  :root{--bg:#0f1115;--card:#171a21;--text:#f2f4f8;--muted:#b6bcc8;--border:#262b35;--btn:#2b2f38;}
  *{box-sizing:border-box}
  html,body{margin:0;background:var(--bg);color:var(--text);font-family:Arial,Helvetica,sans-serif;}
  body{padding:10px;}
  .wrap{max-width:1600px;margin:0 auto;}
  .topTitle{font-size:18px;font-weight:700;margin-bottom:8px;}
  .statusRow,.navRow,.settingsButtons{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px;}
  .badge{display:inline-block;padding:5px 8px;border-radius:999px;background:#2b2f38;font-size:11px;}
  button,select,input{padding:10px 12px;border:0;border-radius:10px;background:var(--btn);color:white;font-size:13px;}
  button{cursor:pointer;}
  input[type="number"],select{width:100%;background:#20242c;}
  .navBtn{flex:1;font-weight:700;}.navBtn.active{background:#3a4250;}
  .hidden{display:none!important;}
  .banner{background:#1b2330;border:1px solid #2c3b56;border-radius:14px;padding:12px;margin-bottom:10px;}
  .cards{display:flex;flex-direction:column;gap:10px;}
  .panel,.settingsSection{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:10px;min-width:0;}
  .sensorPanel{display:flex;flex-direction:column;}.sensorPanel .stateBox{flex:1 1 auto;}.sensorPanel .grid{margin-top:auto;}
  .panelHead{display:flex;justify-content:space-between;align-items:center;gap:8px;margin-bottom:8px;}
  .panelTitle,.settingsTitle{font-size:15px;font-weight:700;min-width:0;margin-bottom:8px;}
  .stateBox{width:100%;border-radius:14px;min-height:72px;display:flex;align-items:center;justify-content:center;text-align:center;font-size:22px;font-weight:800;color:white;margin-bottom:10px;transition:background-color 120ms linear;}
  .grid,.settingsGrid{display:grid;grid-template-columns:1fr 1fr;gap:8px;}
  .cell{background:#11151b;border:1px solid #232933;border-radius:12px;padding:8px;min-width:0;}.cell.full{grid-column:1/-1;}
  .label{color:var(--muted);font-size:11px;margin-bottom:4px;}.value{font-size:18px;font-weight:700;word-break:break-word;line-height:1.15;}
  .help{color:var(--muted);font-size:12px;line-height:1.5;margin-top:4px;}
  .settingsWrap{display:grid;gap:10px;}
  #frontPanel .grid,#leanPanel .grid,#rearPanel .grid{grid-template-columns:1fr 1fr 1fr;}
  #frontPanel .grid{grid-template-columns:1fr 1fr;}
  .rearMiniState{width:100%;border-radius:10px;min-height:40px;display:flex;align-items:center;justify-content:center;text-align:center;font-size:11px;font-weight:800;color:white;margin-bottom:6px;padding:4px;}
  .mainWarning{background:var(--card);border:1px solid var(--border);border-radius:16px;padding:12px;margin-bottom:10px;}
  .mainWarningTitle{font-size:20px;font-weight:800;margin-bottom:6px;}
  .mainWarningMsg{color:var(--muted);font-size:13px;line-height:1.35;}
  #leanVisual{position:relative;width:100%;height:250px;background:#000;overflow:hidden;border-radius:16px;margin-bottom:10px;}
  #leanField{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);}
  .circle{position:absolute;border:1px solid #555;border-radius:50%;left:50%;top:50%;transform:translate(-50%,-50%);box-sizing:border-box;}
  #c1{width:88%;height:88%;}#c2{width:70%;height:70%;}#c3{width:52%;height:52%;}#c4{width:34%;height:34%;}#c5{width:16%;height:16%;}
  .line{position:absolute;background:#555;}#lineV{width:2px;height:100%;left:50%;top:0;}#lineH{width:100%;height:2px;top:50%;left:0;}
  #leanDot{width:16px;height:16px;border-radius:50%;position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);background:rgba(64,128,255,.75);box-shadow:0 0 12px rgba(64,128,255,.75);}
  #laneVisual{width:100%;height:220px;background:#0b0d12;border-radius:16px;position:relative;overflow:hidden;margin-bottom:10px;border:1px solid #232933;}
  #laneRoadCenter{position:absolute;left:50%;top:0;transform:translateX(-50%);width:70%;height:100%;}.laneMark{position:absolute;top:8%;width:8px;height:84%;border-radius:999px;background:#9aa3b2;opacity:.95;transition:background-color 120ms linear,box-shadow 120ms linear;}
  #laneLeftMark{left:30%;transform:translateX(-50%) rotate(8deg);}#laneRightMark{left:70%;transform:translateX(-50%) rotate(-8deg);}.laneAlert{background:#ffb020!important;box-shadow:0 0 18px rgba(255,176,32,.65);}
  .wizardBox{border:1px solid #2c3b56;background:#111824;border-radius:14px;padding:12px;margin-top:10px;}
  .wizardStepTitle{font-size:16px;font-weight:800;margin-bottom:8px;}.wizardProgress{color:var(--muted);font-size:12px;margin-bottom:10px;}.danger{background:#513033;}
  @media (orientation:landscape) and (max-width:1400px){body{padding:8px}.cards{flex-direction:row;align-items:stretch;gap:8px;flex-wrap:wrap}.panel{flex:1 1 calc(50% - 8px);padding:8px}.stateBox{min-height:52px;font-size:16px;margin-bottom:8px;border-radius:12px}#frontPanel .stateBox,#rearPanel .stateBox{min-height:120px}#leanVisual,#laneVisual{height:164px;margin-bottom:8px;border-radius:12px}.grid{gap:6px}.cell{padding:6px 7px;border-radius:10px}.value{font-size:14px;line-height:1.05}.label{font-size:10px;margin-bottom:2px}}
  @media (min-width:1401px){.cards{flex-direction:row;align-items:stretch;flex-wrap:wrap}.panel{flex:1 1 calc(25% - 10px)}}
  @media (max-width:900px){.settingsGrid{grid-template-columns:1fr}}

  .wizardHealth{
    display:grid;
    grid-template-columns:1fr 1fr;
    gap:8px;
    margin-top:10px;
  }
  .unitCheck{
    background:#11151b;
    border:1px solid #232933;
    border-radius:12px;
    padding:10px;
  }
  .unitCheckName{
    font-size:12px;
    color:var(--muted);
    margin-bottom:6px;
  }
  .unitCheckStatus{
    font-size:16px;
    font-weight:800;
  }
  .okText{color:#1db954;}
  .warnText{color:#ffb020;}
  .badText{color:#ff3b30;}
  .wizardCleanNote{
    color:var(--muted);
    font-size:12px;
    line-height:1.45;
  }
  .soundUnitCard{
    background:#11151b;
    border:1px solid #232933;
    border-radius:12px;
    padding:10px;
  }
  .soundVolumeRow{
    display:flex;
    gap:10px;
    align-items:center;
    margin-top:8px;
  }
  .soundVolumeRow input{
    flex:1;
  }
  .soundVolumeValue{
    width:46px;
    text-align:right;
    color:var(--muted);
    font-size:12px;
  }
  @media (max-width: 650px){
    .wizardHealth{grid-template-columns:1fr;}
  }

</style>
</head>
<body>
<div class="wrap">
  <div class="topTitle">ADAS Brain Monitor</div>
  <div class="statusRow"><span class="badge">Brain AP: ADASBrain</span><button id="audioBtn" onclick="toggleBuzzer()">Buzzer On</button></div>
  <div class="navRow"><button id="tabDashboardBtn" class="navBtn active" onclick="showTab('dashboard')">Dashboard</button><button id="tabSettingsBtn" class="navBtn" onclick="showTab('settings')">Settings</button></div>

  <div id="dashboardTab">
    <div id="setupBanner" class="banner hidden"><div style="font-weight:700;margin-bottom:6px;">Setup required</div><div class="help">Complete the guided setup before normal use.</div><div class="settingsButtons"><button onclick="openSetupWizard()">Open Setup Wizard</button></div></div>
    <div class="mainWarning" id="mainWarningBox">
      <div id="mainWarningTitle" class="mainWarningTitle">All Clear</div>
      <div id="mainWarningMsg" class="mainWarningMsg">No active safety warnings.</div>
    </div>
    <div class="cards">
      <div class="panel sensorPanel" id="frontPanel"><div class="panelHead"><div class="panelTitle">Front Collision Warning</div><span class="badge" id="frontBadge">Offline</span></div><div id="frontStateBox" class="stateBox" style="background:#1db954;">CLEAR</div><div class="grid"><div class="cell"><div class="label">Distance</div><div id="frontDist" class="value">--</div></div><div class="cell"><div class="label">Speed</div><div id="frontSpeed" class="value">--</div></div></div></div>
      <div class="panel" id="leanPanel"><div class="panelHead"><div class="panelTitle">Lean Monitor</div><span class="badge" id="leanBadge">Offline</span></div><div id="leanVisual"><div id="leanField"><div id="c1" class="circle"></div><div id="c2" class="circle"></div><div id="c3" class="circle"></div><div id="c4" class="circle"></div><div id="c5" class="circle"></div><div id="lineV" class="line"></div><div id="lineH" class="line"></div><div id="leanDot"></div></div></div><div id="leanStateBox" class="stateBox" style="background:#1db954;">SAFE</div><div class="grid"><div class="cell"><div class="label">Roll</div><div id="leanRoll" class="value">0.00°</div></div><div class="cell"><div class="label">Pitch</div><div id="leanPitch" class="value">0.00°</div></div><div class="cell"><div class="label">Conf</div><div id="leanConf" class="value">1.00</div></div></div></div>
      <div class="panel sensorPanel" id="rearPanel"><div class="panelHead"><div class="panelTitle">Rear Blindspot</div><span class="badge" id="rearBadge">Offline</span></div><div id="rearStateBox" class="stateBox" style="background:#1db954;">CLEAR</div><div class="grid"><div class="cell"><div class="label">Left</div><div id="rearLeftStateBox" class="rearMiniState" style="background:#1db954;">CLEAR</div><div id="rearLeftDist" class="value">--</div></div><div class="cell"><div class="label">Center</div><div id="rearCenterStateBox" class="rearMiniState" style="background:#1db954;">CLEAR</div><div id="rearCenterDist" class="value">--</div></div><div class="cell"><div class="label">Right</div><div id="rearRightStateBox" class="rearMiniState" style="background:#1db954;">CLEAR</div><div id="rearRightDist" class="value">--</div></div></div></div>
      <div class="panel sensorPanel" id="lanePanel"><div class="panelHead"><div class="panelTitle">Lane Departure Warning</div><span class="badge" id="laneBadge">Offline</span></div><div id="laneVisual"><div id="laneRoadCenter"><div id="laneLeftMark" class="laneMark"></div><div id="laneRightMark" class="laneMark"></div></div></div><div id="laneStateBox" class="stateBox" style="background:#1db954;">SAFE</div></div>
    </div>
  </div>

  <div id="settingsTab" class="hidden">
  <div class="settingsWrap">

    <div class="settingsSection">
      <div class="settingsTitle">Command Status</div>
      <div id="cmdStatus" class="help">Waiting for WebSocket connection...</div>
    </div>

    <div id="wizardHeader" class="settingsSection hidden">
      <div id="wizardProgress" class="wizardProgress">Step 1 of 8</div>
      <div id="wizardTitle" class="wizardStepTitle">Welcome</div>
      <div id="wizardBody" class="wizardCleanNote">Set up Drivora for this vehicle.</div>
    </div>

    <div id="vehicleSection" class="settingsSection configSection wizardStepSection" data-step="1">
      <div class="settingsTitle">Vehicle Profile</div>
      <div class="settingsGrid">
        <div>
          <div class="label">Vehicle Type</div>
          <select id="cfgVehicleType">
            <option value="1">Compact</option>
            <option value="2">Passenger</option>
            <option value="3">Tall / SUV</option>
          </select>
        </div>
        <div>
          <div class="label">Load Condition</div>
          <select id="cfgLoadCondition">
            <option value="0">Light</option>
            <option value="1">Normal</option>
            <option value="2">Heavy</option>
          </select>
        </div>
        <div>
          <div class="label">Track Width (m)</div>
          <input id="cfgTrackWidth" type="number" step="0.01" min="0.80" max="4.00">
        </div>
        <div>
          <div class="label">Wheelbase (m)</div>
          <input id="cfgWheelBase" type="number" step="0.01" min="1.50" max="6.00">
        </div>
        <div>
          <div class="label">Vehicle Height (m)</div>
          <input id="cfgVehicleHeight" type="number" step="0.01" min="0.50" max="6.00">
        </div>
      </div>
    </div>

    <div id="frontSection" class="settingsSection configSection wizardStepSection" data-step="2">
      <div class="settingsTitle">Front Sensitivity</div>
      <div class="settingsGrid">
        <div>
          <div class="label">Front preset</div>
          <select id="cfgFrontPreset">
            <option value="0">Near</option>
            <option value="1">Normal</option>
            <option value="2">Far</option>
          </select>
          <div class="help">Near gives shorter warning range. Far gives earlier warnings.</div>
        </div>
      </div>
    </div>

    <div id="rearSection" class="settingsSection configSection wizardStepSection" data-step="3">
      <div class="settingsTitle">Rear Sensitivity</div>
      <div class="settingsGrid">
        <div>
          <div class="label">Rear preset</div>
          <select id="cfgRearPreset">
            <option value="0">Near</option>
            <option value="1">Normal</option>
            <option value="2">Far</option>
          </select>
          <div class="help">Near gives a tighter rear zone. Far gives earlier rear warnings.</div>
        </div>
      </div>
    </div>

    <div id="calibrationSection" class="settingsSection configSection wizardStepSection" data-step="4">
      <div class="settingsTitle">Center Calibration</div>
      <div class="settingsGrid">
        <div>
          <div class="label">Calibration Status</div>
          <div id="cfgCenterCalStatus" class="value">Not calibrated</div>
        </div>
      </div>
      <div class="help">Park on level ground and keep the vehicle still.</div>
      <div class="settingsButtons">
        <button onclick="calibrateCenter()">Calibrate Center Unit</button>
      </div>
      <div id="wizardCalibrationStatus" class="help hidden">Calibration is required before continuing.</div>
    </div>

    <div id="testSection" class="settingsSection configSection wizardStepSection wizardOnly" data-step="5">
      <div class="settingsTitle">Installation Test</div>
      <div class="help">Check that each unit is online before finishing setup.</div>
      <div class="wizardHealth">
        <div class="unitCheck">
          <div class="unitCheckName">Front Unit</div>
          <div id="wizardFrontStatus" class="unitCheckStatus badText">Offline</div>
        </div>
        <div class="unitCheck">
          <div class="unitCheckName">Center Unit</div>
          <div id="wizardCenterStatus" class="unitCheckStatus badText">Offline</div>
        </div>
        <div class="unitCheck">
          <div class="unitCheckName">Rear Unit</div>
          <div id="wizardRearStatus" class="unitCheckStatus badText">Offline</div>
        </div>
        <div class="unitCheck">
          <div class="unitCheckName">Lane Unit</div>
          <div id="wizardLaneStatus" class="unitCheckStatus badText">Offline</div>
        </div>
      </div>
      <div id="wizardTestHint" class="help">You can continue after confirming the required units are responding.</div>
    </div>

    <div id="soundSection" class="settingsSection configSection wizardStepSection" data-step="6">
      <div class="settingsTitle">Sound Settings</div>
      <div class="settingsGrid">
        <div class="soundUnitCard">
          <div class="label">Buzzer Output</div>
          <button id="soundBuzzerBtn" onclick="toggleBuzzer()">Buzzer On</button>
        </div>
        <div class="soundUnitCard">
          <div class="label">Front Unit Pattern</div>
          <select id="cfgFrontSoundPattern" class="soundPatternSelect">
            <option value="0">Urgent Triple Pulse</option>
            <option value="1">Wide Double Pulse</option>
            <option value="2">Quick Double Tap</option>
            <option value="3">Two-Tone Stability</option>
          </select>
          <div class="label" style="margin-top:8px;">Front Volume</div>
          <div class="soundVolumeRow"><input id="cfgFrontSoundVolume" type="range" min="30" max="100" step="5"><div id="frontSoundVolumeText" class="soundVolumeValue">100%</div></div>
          <button class="soundTestBtn" onclick="testSound('front')">Test Front Sound</button>
        </div>
        <div class="soundUnitCard">
          <div class="label">Rear Unit Pattern</div>
          <select id="cfgRearSoundPattern" class="soundPatternSelect">
            <option value="0">Urgent Triple Pulse</option>
            <option value="1">Wide Double Pulse</option>
            <option value="2">Quick Double Tap</option>
            <option value="3">Two-Tone Stability</option>
          </select>
          <div class="label" style="margin-top:8px;">Rear Volume</div>
          <div class="soundVolumeRow"><input id="cfgRearSoundVolume" type="range" min="30" max="100" step="5"><div id="rearSoundVolumeText" class="soundVolumeValue">100%</div></div>
          <button class="soundTestBtn" onclick="testSound('rear')">Test Rear Sound</button>
        </div>
        <div class="soundUnitCard">
          <div class="label">Lane Unit Pattern</div>
          <select id="cfgLaneSoundPattern" class="soundPatternSelect">
            <option value="0">Urgent Triple Pulse</option>
            <option value="1">Wide Double Pulse</option>
            <option value="2">Quick Double Tap</option>
            <option value="3">Two-Tone Stability</option>
          </select>
          <div class="label" style="margin-top:8px;">Lane Volume</div>
          <div class="soundVolumeRow"><input id="cfgLaneSoundVolume" type="range" min="30" max="100" step="5"><div id="laneSoundVolumeText" class="soundVolumeValue">100%</div></div>
          <button class="soundTestBtn" onclick="testSound('lane')">Test Lane Sound</button>
        </div>
        <div class="soundUnitCard">
          <div class="label">Center / Lean Unit Pattern</div>
          <select id="cfgLeanSoundPattern" class="soundPatternSelect">
            <option value="0">Urgent Triple Pulse</option>
            <option value="1">Wide Double Pulse</option>
            <option value="2">Quick Double Tap</option>
            <option value="3">Two-Tone Stability</option>
          </select>
          <div class="label" style="margin-top:8px;">Center Volume</div>
          <div class="soundVolumeRow"><input id="cfgLeanSoundVolume" type="range" min="30" max="100" step="5"><div id="leanSoundVolumeText" class="soundVolumeValue">100%</div></div>
          <button class="soundTestBtn" onclick="testSound('lean')">Test Center Sound</button>
        </div>
      </div>
    </div>

    <div id="finishSection" class="settingsSection configSection wizardStepSection wizardOnly" data-step="7">
      <div class="settingsTitle">Save and Finish</div>
      <div class="help">Save this setup and unlock the dashboard.</div>
      <div class="settingsButtons">
        <button onclick="finishWizardSetup()">Save and Finish Setup</button>
      </div>
    </div>

    <div id="wizardControls" class="settingsSection hidden">
      <div class="settingsButtons">
        <button id="wizardBackBtn" onclick="wizardBack()">Back</button>
        <button id="wizardNextBtn" onclick="wizardNext()">Next</button>
      </div>
    </div>

    <div id="saveSettingsSection" class="settingsSection normalOnly">
      <div class="settingsButtons">
        <button onclick="saveAllNormalSettings()">Save Settings</button>
      </div>
    </div>

    <div id="normalSetupWizardSection" class="settingsSection normalOnly">
      <div class="settingsTitle">Guided Setup Wizard</div>
      <div class="help">Run the full setup again after reinstalling, remounting, or moving the system to another vehicle.</div>
      <div class="settingsButtons">
        <button onclick="openSetupWizard()">Open Setup Wizard</button>
      </div>
    </div>

    <div id="systemSection" class="settingsSection normalOnly">
      <div class="settingsTitle">System / Reset</div>
      <div class="help">Reset returns vehicle dimensions and sensitivity presets to defaults. Setup must be completed again afterwards.</div>
      <div class="settingsButtons">
        <button class="danger" onclick="resetDefaults()">Reset Settings to Defaults</button>
      </div>
    </div>

  </div>
</div>
</div>

<script>
const ws = new WebSocket("ws://" + location.hostname + ":81");

let buzzerUiEnabled = true;

let leanDotCurrentX = 0;
let leanDotCurrentY = 0;
let leanDotTargetX = 0;
let leanDotTargetY = 0;
let leanDotInitialized = false;

let latestConfig = null;
let latestHealth = {
  front: {online:false, stale:true},
  lean:  {online:false, stale:true},
  rear:  {online:false, stale:true},
  lane:  {online:false, stale:true}
};

let settingsUiInitialized = false;
let settingsDirty = false;
let wizardStep = 0;
let wizardMode = false;
let forceFormRefresh = false;
let wizardCalibrationRequested = false;
let wizardCalibrationStartedAt = 0;
let previousSoundPatternValues = {};

const DEFAULT_CFG = {
  setupCompleted: 0,
  vehicleType: 3,
  loadCondition: 1,
  trackWidth_m: 1.56,
  wheelBase_m: 2.67,
  vehicleHeight_m: 1.57,
  frontPreset: 1,
  rearPreset: 1,
  centerCalibrated: 0,
  frontSoundPattern: 0,
  rearSoundPattern: 1,
  laneSoundPattern: 2,
  leanSoundPattern: 3,
  frontSoundVolume: 100,
  rearSoundVolume: 100,
  laneSoundVolume: 100,
  leanSoundVolume: 100,
  buzzerEnabled: 1
};

function $(id){ return document.getElementById(id); }

function isSetupLocked(){
  return wizardMode || !latestConfig || !latestConfig.setupCompleted;
}

function showTab(tab){
  if (tab === "dashboard" && isSetupLocked()) {
    $("dashboardTab").classList.add("hidden");
    $("settingsTab").classList.remove("hidden");
    $("tabDashboardBtn").classList.add("hidden");
    $("tabSettingsBtn").classList.add("active");
    $("tabSettingsBtn").innerText = "Setup";
    const audioBtn = $("audioBtn");
    if (audioBtn) audioBtn.classList.add("hidden");
    setCmdStatus("Complete setup to unlock the dashboard.");
    return;
  }

  $("dashboardTab").classList.toggle("hidden", tab !== "dashboard");
  $("settingsTab").classList.toggle("hidden", tab !== "settings");
  $("tabDashboardBtn").classList.toggle("active", tab === "dashboard");
  $("tabSettingsBtn").classList.toggle("active", tab === "settings");
  const audioBtn = $("audioBtn");
  if (audioBtn) audioBtn.classList.toggle("hidden", tab !== "dashboard");
}

function setCmdStatus(msg){
  const el = $("cmdStatus");
  if (el) el.innerText = msg;
}

ws.onopen = () => setCmdStatus("WebSocket connected.");
ws.onclose = () => setCmdStatus("WebSocket disconnected. Refresh the page.");
ws.onerror = () => setCmdStatus("WebSocket error. Refresh the page.");

function updateBuzzerButton(enabled){
  buzzerUiEnabled = !!enabled;
  const label = buzzerUiEnabled ? "Buzzer On" : "Buzzer Off";
  const btn = $("audioBtn");
  const soundBtn = $("soundBuzzerBtn");
  if (btn) btn.innerText = label;
  if (soundBtn) soundBtn.innerText = label;
}

function toggleBuzzer(){
  if (ws.readyState !== WebSocket.OPEN) {
    setCmdStatus("WebSocket not connected. Refresh the page.");
    return;
  }

  ws.send("BUZZER_TOGGLE");
  buzzerUiEnabled = !buzzerUiEnabled;
  updateBuzzerButton(buzzerUiEnabled);
  setCmdStatus(buzzerUiEnabled ? "Buzzer enabled." : "Buzzer disabled.");
}

function sendWizardBuzzerMode(){
  if (ws.readyState !== WebSocket.OPEN) return;
  if (!(wizardMode || !latestConfig || !latestConfig.setupCompleted)) return;

  // Keep warning beeps silent during setup until the Installation Test step.
  // This is temporary and does not change the saved user buzzer preference.
  if (wizardStep >= 5) ws.send("WIZARD_BUZZER_ENABLE");
  else ws.send("WIZARD_BUZZER_MUTE");
}

function resizeLeanField(){
  const visual = $("leanVisual");
  const rect = visual.getBoundingClientRect();
  const side = Math.min(rect.width, rect.height) * 0.92;
  const field = $("leanField");
  field.style.width = side + "px";
  field.style.height = side + "px";
}

window.addEventListener("resize", resizeLeanField);
window.addEventListener("load", () => {
  resizeLeanField();
  markSettingsDirtyHandlers();
});

function softAxisPosition(valueDeg, criticalDeg, radiusPx){
  const INNER_RATIO = 0.78;
  const OUTER_RATIO = 0.90;
  const HEADROOM = 2.85;

  const absV = Math.abs(valueDeg);
  const sign = valueDeg >= 0 ? 1 : -1;

  const innerSpan = Math.max(criticalDeg, 0.01);
  const outerSpan = Math.max(criticalDeg * HEADROOM, innerSpan + 0.01);

  let magRatio;
  if (absV <= innerSpan) {
    magRatio = (absV / innerSpan) * INNER_RATIO;
  } else {
    const t = Math.min((absV - innerSpan) / (outerSpan - innerSpan), 1.0);
    const eased = 1.0 - Math.exp(-3.2 * t);
    const easedNorm = eased / (1.0 - Math.exp(-3.2));
    magRatio = INNER_RATIO + (OUTER_RATIO - INNER_RATIO) * easedNorm;
  }

  return sign * magRatio * radiusPx;
}

function animateLeanDot(){
  if (leanDotInitialized) {
    const dot = $("leanDot");
    const SMOOTH = 0.35;
    leanDotCurrentX += (leanDotTargetX - leanDotCurrentX) * SMOOTH;
    leanDotCurrentY += (leanDotTargetY - leanDotCurrentY) * SMOOTH;
    dot.style.left = leanDotCurrentX + "px";
    dot.style.top = leanDotCurrentY + "px";
  }
  requestAnimationFrame(animateLeanDot);
}
requestAnimationFrame(animateLeanDot);

function fmtCm(v){ return v < 0 ? "Invalid" : v.toFixed(1) + " cm"; }
function fmtSpeed(v){ return (v >= 0 ? "+" : "") + v.toFixed(1) + " cm/s"; }
function statusText(o){
  if (!o.online) return "Offline";
  if (o.stale) return "Stale";
  return "Online";
}

function setUnitStatus(el, obj){
  const text = statusText(obj);
  el.innerText = text;
  el.classList.remove("okText", "warnText", "badText");
  if (!obj.online) el.classList.add("badText");
  else if (obj.stale) el.classList.add("warnText");
  else el.classList.add("okText");
}

function safeSend(msg){
  if (ws.readyState !== WebSocket.OPEN) {
    setCmdStatus("WebSocket not connected. Refresh the page.");
    return false;
  }

  ws.send(msg);
  setCmdStatus("Command sent: " + msg);
  return true;
}

function sendObj(obj){
  if (ws.readyState !== WebSocket.OPEN) {
    setCmdStatus("WebSocket not connected. Refresh the page.");
    return false;
  }

  ws.send(JSON.stringify(obj));
  settingsDirty = false;
  setCmdStatus("Settings command sent.");
  return true;
}

function getSetupObj(cmd){
  return {
    cmd: cmd,
    vehicleType: parseInt($("cfgVehicleType").value),
    loadCondition: parseInt($("cfgLoadCondition").value),
    trackWidth_m: parseFloat($("cfgTrackWidth").value),
    wheelBase_m: parseFloat($("cfgWheelBase").value),
    vehicleHeight_m: parseFloat($("cfgVehicleHeight").value),
    frontPreset: parseInt($("cfgFrontPreset").value),
    rearPreset: parseInt($("cfgRearPreset").value),
    frontSoundPattern: parseInt($("cfgFrontSoundPattern").value),
    rearSoundPattern: parseInt($("cfgRearSoundPattern").value),
    laneSoundPattern: parseInt($("cfgLaneSoundPattern").value),
    leanSoundPattern: parseInt($("cfgLeanSoundPattern").value),
    frontSoundVolume: parseInt($("cfgFrontSoundVolume").value),
    rearSoundVolume: parseInt($("cfgRearSoundVolume").value),
    laneSoundVolume: parseInt($("cfgLaneSoundVolume").value),
    leanSoundVolume: parseInt($("cfgLeanSoundVolume").value),
    setupCompleted: true
  };
}

function saveVehicleSettings(){
  sendObj({
    cmd: "saveVehicle",
    vehicleType: parseInt($("cfgVehicleType").value),
    loadCondition: parseInt($("cfgLoadCondition").value),
    trackWidth_m: parseFloat($("cfgTrackWidth").value),
    wheelBase_m: parseFloat($("cfgWheelBase").value),
    vehicleHeight_m: parseFloat($("cfgVehicleHeight").value),
    setupCompleted: true
  });
}

function saveFrontPreset(){
  sendObj({cmd:"saveFrontPreset", frontPreset:parseInt($("cfgFrontPreset").value)});
}

function saveRearPreset(){
  sendObj({cmd:"saveRearPreset", rearPreset:parseInt($("cfgRearPreset").value)});
}

function soundPatternsAreUnique(){
  const vals = [
    $("cfgFrontSoundPattern").value,
    $("cfgRearSoundPattern").value,
    $("cfgLaneSoundPattern").value,
    $("cfgLeanSoundPattern").value
  ];
  return new Set(vals).size === vals.length;
}

function saveSoundSettings(){
  if (!soundPatternsAreUnique()) {
    setCmdStatus("Each beep pattern can be assigned to only one unit.");
    return false;
  }

  return sendObj({
    cmd:"saveSoundSettings",
    frontSoundPattern:parseInt($("cfgFrontSoundPattern").value),
    rearSoundPattern:parseInt($("cfgRearSoundPattern").value),
    laneSoundPattern:parseInt($("cfgLaneSoundPattern").value),
    leanSoundPattern:parseInt($("cfgLeanSoundPattern").value),
    frontSoundVolume:parseInt($("cfgFrontSoundVolume").value),
    rearSoundVolume:parseInt($("cfgRearSoundVolume").value),
    laneSoundVolume:parseInt($("cfgLaneSoundVolume").value),
    leanSoundVolume:parseInt($("cfgLeanSoundVolume").value)
  });
}

function testSound(unit){
  const prefixMap = {
    front: ["cfgFrontSoundPattern", "cfgFrontSoundVolume", "Front"],
    rear: ["cfgRearSoundPattern", "cfgRearSoundVolume", "Rear"],
    lane: ["cfgLaneSoundPattern", "cfgLaneSoundVolume", "Lane"],
    lean: ["cfgLeanSoundPattern", "cfgLeanSoundVolume", "Center"]
  };

  const cfg = prefixMap[unit];
  if (!cfg) return;

  if (ws.readyState !== WebSocket.OPEN) {
    setCmdStatus("WebSocket not connected. Refresh the page.");
    return;
  }

  ws.send(JSON.stringify({
    cmd: "testSound",
    pattern: parseInt($(cfg[0]).value),
    volume: parseInt($(cfg[1]).value)
  }));

  setCmdStatus("Testing " + cfg[2] + " sound...");
}

function saveAllSetup(){
  return sendObj(getSetupObj("saveAllSetup"));
}

function saveAllNormalSettings(){
  if (!soundPatternsAreUnique()) {
    setCmdStatus("Each beep pattern can be assigned to only one unit.");
    return false;
  }

  if (sendObj(getSetupObj("saveAllSetup"))) {
    settingsDirty = false;
    setCmdStatus("Settings saved.");
    return true;
  }

  return false;
}

function calibrateCenter(){
  wizardCalibrationRequested = true;
  wizardCalibrationStartedAt = Date.now();
  latestConfig.centerCalibrated = 0;
  $("cfgCenterCalStatus").innerText = "Calibrating...";
  $("wizardCalibrationStatus").innerText = "Calibrating... keep the vehicle still.";
  safeSend("CAL_CENTER");
  renderWizard();
}

function resetDefaults(){
  if (confirm("Reset Drivora settings to defaults? Setup must be completed again afterwards.")) {
    settingsDirty = false;
    settingsUiInitialized = false;
    wizardMode = true;
    wizardStep = 0;
    wizardCalibrationRequested = false;
    wizardCalibrationStartedAt = 0;
    latestConfig = Object.assign({}, DEFAULT_CFG);
    applyConfigToForm(DEFAULT_CFG, true);
    refreshSettingsMode(DEFAULT_CFG);
    safeSend("RESET_DEFAULTS");
    setCmdStatus("Reset command sent. Defaults loaded in UI.");
  }
}

function markSettingsDirtyHandlers(){
  ["cfgVehicleType","cfgLoadCondition","cfgTrackWidth","cfgWheelBase","cfgVehicleHeight","cfgFrontPreset","cfgRearPreset","cfgFrontSoundVolume","cfgRearSoundVolume","cfgLaneSoundVolume","cfgLeanSoundVolume"].forEach(id => {
    const el = $(id);
    if (el) {
      el.addEventListener("input", () => { settingsDirty = true; updateVolumeLabels(); });
      el.addEventListener("change", () => { settingsDirty = true; updateVolumeLabels(); });
    }
  });

  ["cfgFrontSoundPattern","cfgRearSoundPattern","cfgLaneSoundPattern","cfgLeanSoundPattern"].forEach(id => {
    const el = $(id);
    if (el) {
      el.addEventListener("change", () => handleSoundPatternChange(id));
    }
  });
}

function updateVolumeLabels(){
  const pairs = [
    ["cfgFrontSoundVolume", "frontSoundVolumeText"],
    ["cfgRearSoundVolume", "rearSoundVolumeText"],
    ["cfgLaneSoundVolume", "laneSoundVolumeText"],
    ["cfgLeanSoundVolume", "leanSoundVolumeText"]
  ];

  pairs.forEach(pair => {
    const slider = $(pair[0]);
    const label = $(pair[1]);
    if (slider && label) label.innerText = slider.value + "%";
  });
}

function captureSoundPatternValues(){
  ["cfgFrontSoundPattern","cfgRearSoundPattern","cfgLaneSoundPattern","cfgLeanSoundPattern"].forEach(id => {
    const el = $(id);
    if (el) previousSoundPatternValues[id] = el.value;
  });
}

function handleSoundPatternChange(changedId){
  const ids = ["cfgFrontSoundPattern","cfgRearSoundPattern","cfgLaneSoundPattern","cfgLeanSoundPattern"];
  const changedEl = $(changedId);
  if (!changedEl) return;

  const newVal = changedEl.value;
  const oldVal = previousSoundPatternValues[changedId] || newVal;

  const otherId = ids.find(id => id !== changedId && $(id) && $(id).value === newVal);
  if (otherId && $(otherId)) {
    $(otherId).value = oldVal;
    previousSoundPatternValues[otherId] = oldVal;
    setCmdStatus("Sound patterns swapped.");
  }

  previousSoundPatternValues[changedId] = newVal;
  settingsDirty = true;
  updateSoundPatternOptions();
}

function updateSoundPatternOptions(){
  const hint = $("soundPatternHint");
  if (hint) {
    hint.innerText = soundPatternsAreUnique()
      ? "Choosing a used pattern automatically swaps it with the other unit."
      : "Choose a different pattern, or select a used one to swap automatically.";
  }
}

function applyConfigToForm(cfg, force = false){
  if (!force && settingsDirty) return;

  $("cfgVehicleType").value = cfg.vehicleType;
  $("cfgLoadCondition").value = cfg.loadCondition;
  $("cfgTrackWidth").value = Number(cfg.trackWidth_m).toFixed(2);
  $("cfgWheelBase").value = Number(cfg.wheelBase_m).toFixed(2);
  $("cfgVehicleHeight").value = Number(cfg.vehicleHeight_m).toFixed(2);
  $("cfgFrontPreset").value = cfg.frontPreset;
  $("cfgRearPreset").value = cfg.rearPreset;

  $("cfgFrontSoundPattern").value = cfg.frontSoundPattern;
  $("cfgRearSoundPattern").value = cfg.rearSoundPattern;
  $("cfgLaneSoundPattern").value = cfg.laneSoundPattern;
  $("cfgLeanSoundPattern").value = cfg.leanSoundPattern;

  $("cfgFrontSoundVolume").value = cfg.frontSoundVolume;
  $("cfgRearSoundVolume").value = cfg.rearSoundVolume;
  $("cfgLaneSoundVolume").value = cfg.laneSoundVolume;
  $("cfgLeanSoundVolume").value = cfg.leanSoundVolume;

  updateVolumeLabels();
  captureSoundPatternValues();
  updateSoundPatternOptions();

  settingsUiInitialized = true;
}

function refreshNavigation(cfg){
  const locked = wizardMode || !cfg.setupCompleted;

  $("tabDashboardBtn").classList.toggle("hidden", locked);
  $("tabSettingsBtn").innerText = locked ? "Setup" : "Settings";
  const audioBtn = $("audioBtn");
  if (audioBtn) audioBtn.classList.toggle("hidden", locked || $("dashboardTab").classList.contains("hidden"));

  if (locked) {
    $("dashboardTab").classList.add("hidden");
    $("settingsTab").classList.remove("hidden");
    $("tabDashboardBtn").classList.remove("active");
    $("tabSettingsBtn").classList.add("active");
  }
}

function refreshSettingsMode(cfg){
  const setupDone = !!cfg.setupCompleted;
  const wizardActive = wizardMode || !setupDone;

  refreshNavigation(cfg);

  $("wizardHeader").classList.toggle("hidden", !wizardActive);
  $("wizardControls").classList.toggle("hidden", !wizardActive);
  $("wizardCalibrationStatus").classList.toggle("hidden", !wizardActive);

  document.querySelectorAll(".normalOnly").forEach(el => {
    el.classList.toggle("hidden", wizardActive);
  });

  document.querySelectorAll(".wizardStepSection").forEach(el => {
    if (wizardActive) {
      const step = parseInt(el.dataset.step);
      el.classList.toggle("hidden", step !== wizardStep);
    } else {
      el.classList.toggle("hidden", el.classList.contains("wizardOnly"));
    }
  });

  if (wizardActive) renderWizard();
}

function updateSettingsUI(cfg){
  latestConfig = cfg;

  if (forceFormRefresh || !settingsUiInitialized) {
    applyConfigToForm(cfg, true);
    forceFormRefresh = false;
  } else {
    applyConfigToForm(cfg, false);
  }

  $("cfgCenterCalStatus").innerText = cfg.centerCalibrated ? "Calibrated" : (wizardCalibrationRequested ? "Calibrating..." : "Not calibrated");
  if (typeof cfg.buzzerEnabled !== "undefined") updateBuzzerButton(!!cfg.buzzerEnabled);
  $("setupBanner").classList.toggle("hidden", !!cfg.setupCompleted);
  refreshSettingsMode(cfg);
}

function openSetupWizard(){
  if (latestConfig && latestConfig.setupCompleted) {
    if (!confirm("Run the setup wizard again? The dashboard will be locked until the setup is completed.")) {
      return;
    }
  }

  showTab("settings");
  wizardMode = true;
  wizardStep = 0;
  settingsDirty = false;
  wizardCalibrationRequested = false;
  wizardCalibrationStartedAt = 0;

  if (latestConfig) {
    latestConfig.setupCompleted = 0;
    latestConfig.centerCalibrated = 0;
    applyConfigToForm(latestConfig, true);
  }

  safeSend("START_WIZARD");
  sendWizardBuzzerMode();
  refreshSettingsMode(latestConfig || DEFAULT_CFG);
  window.scrollTo({top:0, behavior:"smooth"});
}

function wizardBack(){
  if (wizardStep > 0) {
    wizardStep--;
    refreshSettingsMode(latestConfig || DEFAULT_CFG);
  }
}

function wizardNext(){
  if (wizardStep < 7) {
    wizardStep++;
    refreshSettingsMode(latestConfig || DEFAULT_CFG);
  }
}

function calibrationReadyForNext(){
  if (!wizardCalibrationRequested) return false;
  if (!latestConfig || !latestConfig.centerCalibrated) return false;
  return (Date.now() - wizardCalibrationStartedAt) > 2000;
}

function finishWizardSetup(){
  if (saveAllSetup()) {
    wizardMode = false;
    if (ws.readyState === WebSocket.OPEN) ws.send("WIZARD_BUZZER_ENABLE");
    wizardCalibrationRequested = false;
    wizardCalibrationStartedAt = 0;
    settingsDirty = false;
    forceFormRefresh = true;

    if (latestConfig) latestConfig.setupCompleted = 1;

    setCmdStatus("Setup saved. Dashboard unlocked.");
    showTab("dashboard");
  }
}

function renderWizard(){
  const titles = [
    "Welcome",
    "Vehicle Information",
    "Front Sensitivity",
    "Rear Sensitivity",
    "Center Calibration",
    "Installation Test",
    "Warning Sounds",
    "Save and Finish"
  ];

  const bodies = [
    "Set up Drivora for this vehicle.",
    "Enter the vehicle dimensions used by the center unit.",
    "Choose how early the front warning should respond.",
    "Choose how early the rear warning should respond.",
    "Calibrate the center unit on level ground.",
    "Confirm that the installed units are responding.",
    "Choose unique beep patterns and volumes for the warning units.",
    "Save the setup and unlock the dashboard."
  ];

  $("wizardProgress").innerText = "Step " + (wizardStep + 1) + " of 8";
  $("wizardTitle").innerText = titles[wizardStep];
  $("wizardBody").innerText = bodies[wizardStep];

  $("wizardBackBtn").style.display = wizardStep === 0 ? "none" : "inline-block";
  $("wizardNextBtn").style.display = wizardStep === 7 ? "none" : "inline-block";
  $("wizardNextBtn").innerText = "Next";

  sendWizardBuzzerMode();

  if (wizardStep === 4) {
    const ready = calibrationReadyForNext();

    if (!wizardCalibrationRequested) {
      $("wizardCalibrationStatus").innerText = "Press Calibrate to continue.";
    } else if (!ready) {
      $("wizardCalibrationStatus").innerText = "Waiting for calibration to complete...";
    } else {
      $("wizardCalibrationStatus").innerText = "Calibration completed. You can continue.";
    }

    $("wizardNextBtn").style.display = ready ? "inline-block" : "none";
  }

  if (wizardStep === 5) {
    updateWizardHealth();
  }
}

function updateWizardHealth(){
  setUnitStatus($("wizardFrontStatus"), latestHealth.front);
  setUnitStatus($("wizardCenterStatus"), latestHealth.lean);
  setUnitStatus($("wizardRearStatus"), latestHealth.rear);
  setUnitStatus($("wizardLaneStatus"), latestHealth.lane);

  const requiredOk =
    latestHealth.front.online && !latestHealth.front.stale &&
    latestHealth.lean.online && !latestHealth.lean.stale &&
    latestHealth.rear.online && !latestHealth.rear.stale;

  $("wizardTestHint").innerText = requiredOk
    ? "Core units are responding. Lane unit can be checked if installed."
    : "Waiting for Front, Center, and Rear units to respond.";
}

ws.onmessage = (evt) => {
  const d = JSON.parse(evt.data);

  latestHealth.front = d.front;
  latestHealth.lean = d.lean;
  latestHealth.rear = d.rear;
  latestHealth.lane = d.lane;

  if (d.config) updateSettingsUI(d.config);

  // Fused main warning
  if (d.fused) {
    $("mainWarningBox").style.borderColor = d.fused.color;
    $("mainWarningTitle").innerText = d.fused.title;
    $("mainWarningTitle").style.color = d.fused.color;
    $("mainWarningMsg").innerText = d.fused.message;
  }

  // Lean
  const lean = d.lean;
  $("leanBadge").innerText = statusText(lean);
  $("leanStateBox").innerText = lean.riskName;
  $("leanStateBox").style.backgroundColor = lean.riskLevel === 2 ? "#ff3b30" : (lean.riskLevel === 1 ? "#ffb020" : "#1db954");
  $("leanRoll").innerText = lean.roll.toFixed(2) + "°";
  $("leanPitch").innerText = lean.pitch.toFixed(2) + "°";
  $("leanConf").innerText = lean.confidence.toFixed(2);

  const rect = $("leanField").getBoundingClientRect();
  const cx = rect.width / 2;
  const cy = rect.height / 2;
  const r = Math.min(rect.width, rect.height) / 2 - 12;
  const px = cx + softAxisPosition(lean.roll, lean.criticalRollDeg, r);
  const py = cy + softAxisPosition(lean.pitch, lean.criticalPitchDeg, r);

  leanDotTargetX = px;
  leanDotTargetY = py;

  if (!leanDotInitialized) {
    leanDotCurrentX = px;
    leanDotCurrentY = py;
    leanDotInitialized = true;
  }

  // Front
  const front = d.front;
  $("frontBadge").innerText = statusText(front);
  $("frontStateBox").innerText = front.stateName;
  $("frontStateBox").style.backgroundColor = front.stateColor;
  $("frontDist").innerText = fmtCm(front.filteredDistanceCm);
  $("frontSpeed").innerText = fmtSpeed(front.closingSpeedCmS);

  // Rear
  const rear = d.rear;
  $("rearBadge").innerText = statusText(rear);
  $("rearStateBox").innerText = rear.overallStateName;
  $("rearStateBox").style.backgroundColor = rear.overallStateColor;

  $("rearLeftStateBox").innerText = rear.leftStateName;
  $("rearLeftStateBox").style.backgroundColor = rear.leftStateColor;
  $("rearLeftDist").innerText = fmtCm(rear.leftFilteredDistanceCm);

  $("rearCenterStateBox").innerText = rear.centerStateName;
  $("rearCenterStateBox").style.backgroundColor = rear.centerStateColor;
  $("rearCenterDist").innerText = fmtCm(rear.centerFilteredDistanceCm);

  $("rearRightStateBox").innerText = rear.rightStateName;
  $("rearRightStateBox").style.backgroundColor = rear.rightStateColor;
  $("rearRightDist").innerText = fmtCm(rear.rightFilteredDistanceCm);

  // Lane
  const lane = d.lane;
  $("laneBadge").innerText = statusText(lane);
  $("laneStateBox").innerText = lane.stateName;
  $("laneStateBox").style.backgroundColor = lane.stateColor;

  $("laneLeftMark").classList.remove("laneAlert");
  $("laneRightMark").classList.remove("laneAlert");

  if (lane.state === 1) $("laneLeftMark").classList.add("laneAlert");
  else if (lane.state === 2) $("laneRightMark").classList.add("laneAlert");

  if (wizardStep === 6) updateWizardHealth();

  // Physical buzzer is controlled by the ESP32 brain.
  // Smartphone/browser beep sounds are intentionally disabled.

};
</script>
</body>
</html>
)rawliteral";


// ================= WEBSOCKET =================
void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_TEXT) {
    String msg = payloadToString(payload, length);
    handleIncomingCommand(msg);
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  delay(200);

  buzzerBegin();

  loadConfig();
  setupWizardBuzzerMuted = !brainConfig.setupCompleted;

  Serial2.begin(115200, SERIAL_8N1, LANE_RX_PIN, LANE_TX_PIN);

  WiFi.mode(WIFI_AP);
  bool apOk = WiFi.softAP(ssid, password);
  WiFi.setSleep(false);

  Serial.print("AP start: ");
  Serial.println(apOk ? "OK" : "FAILED");
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/", []() {
    server.send_P(200, "text/html", webpage);
  });
  server.begin();

  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);

  initCAN();
  delay(50);
  sendAllConfigs();

  Serial.println("ADAS Brain UI + Settings ready");
}

// ================= LOOP =================
void loop() {
  unsigned long nowMs = millis();

  server.handleClient();
  webSocket.loop();

  receiveCANFrames(nowMs);
  receiveLaneUART(nowMs);

  // Service buzzer independently from WebSocket broadcasting.
  // This prevents long ON tones if the JSON/web update takes longer than usual.
  updateBuzzerByFusedType(currentFusedType, currentFusedSeverity, nowMs);

  if (nowMs - lastBroadcastMs >= UI_BROADCAST_MS) {
    lastBroadcastMs = nowMs;
    broadcastCombinedState(nowMs);
  }
}