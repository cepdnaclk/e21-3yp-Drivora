#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <math.h>
#include "driver/twai.h"

// ================= WIFI / WEB =================
const char* ssid = "ADASBrain";
const char* password = "12345678";

WebServer server(80);
WebSocketsServer webSocket(81);

// ================= CAN / TWAI =================
static const gpio_num_t CAN_TX_PIN = GPIO_NUM_17;
static const gpio_num_t CAN_RX_PIN = GPIO_NUM_16;

const uint32_t LEAN_MAIN_ID   = 0x100;
const uint32_t LEAN_DEBUG_ID  = 0x101;
const uint32_t FRONT_MAIN_ID  = 0x200;
const uint32_t FRONT_DEBUG_ID = 0x201;
const uint32_t REAR_MAIN_ID   = 0x300;
const uint32_t REAR_DEBUG_ID  = 0x301;

// ================= LANE UART =================
static const int LANE_RX_PIN = 21;
static const int LANE_TX_PIN = 22;   // reserved for future use
String laneRxBuffer = "";

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
  uint8_t state = 0;              // 0 CLEAR, 1 OBJECT_DETECTED, 2 CAUTION, 3 WARNING
  float filteredDistanceCm = -1.0f;
  float rawDistanceCm = -1.0f;
  unsigned long lastUpdateMs = 0;

  // Debug payload from 0x301
  uint8_t debugFlags = 0;
  uint8_t warningReleaseCounter = 0;
  uint8_t fastWarningReleaseCounter = 0;
  uint8_t invalidStreak = 0;
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

const unsigned long UI_BROADCAST_MS = 50;
const unsigned long STALE_MS        = 300;
const unsigned long OFFLINE_MS      = 1000;

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

void receiveCANFrames(unsigned long nowMs) {
  twai_message_t message;

  while (twai_receive(&message, 0) == ESP_OK) {
    if (message.extd || message.rtr) continue;

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

      Serial.print("CAN Lean Main | risk=");
      Serial.print(leanData.riskLevel);
      Serial.print(" roll=");
      Serial.print(leanData.rollDeg, 2);
      Serial.print(" pitch=");
      Serial.print(leanData.pitchDeg, 2);
      Serial.print(" conf=");
      Serial.print(leanData.confidence, 2);
      Serial.print(" calibrated=");
      Serial.println(leanData.calibrated ? "YES" : "NO");
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

      Serial.print("CAN Lean Debug | criticalRoll=");
      Serial.print(leanData.criticalRollDeg, 2);
      Serial.print(" criticalPitch=");
      Serial.print(leanData.criticalPitchDeg, 2);
      Serial.print(" vehicleType=");
      Serial.print(leanData.vehicleType);
      Serial.print(" load=");
      Serial.println(leanData.loadCondition);
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

      Serial.print("CAN Front Main | state=");
      Serial.print(frontData.state);
      Serial.print(" filtered=");
      Serial.print(frontData.filteredDistanceCm, 1);
      Serial.print(" raw=");
      Serial.print(frontData.rawDistanceCm, 1);
      Serial.print(" speed=");
      Serial.println(frontData.closingSpeedCmS, 1);
    }
    else if (message.identifier == FRONT_DEBUG_ID && message.data_length_code >= 8) {
      frontData.debugFlags          = message.data[0];
      frontData.approachCounter     = message.data[1];
      frontData.warningCounter      = message.data[2];
      frontData.blindReleaseCounter = message.data[3];
      frontData.invalidStreak       = message.data[4];
      frontData.debugCounter        = message.data[7];
      frontData.lastDebugUpdateMs   = nowMs;

      Serial.print("CAN Front Debug | flags=0x");
      Serial.print(frontData.debugFlags, HEX);
      Serial.print(" approach=");
      Serial.print(frontData.approachCounter);
      Serial.print(" warning=");
      Serial.print(frontData.warningCounter);
      Serial.print(" blindRelease=");
      Serial.print(frontData.blindReleaseCounter);
      Serial.print(" invalid=");
      Serial.println(frontData.invalidStreak);
    }
    else if (message.identifier == REAR_MAIN_ID && message.data_length_code >= 8) {
      rearData.state = message.data[0];

      uint16_t filtered_x10 = packU16FromBytes(message.data[1], message.data[2]);
      uint16_t raw_x10      = packU16FromBytes(message.data[3], message.data[4]);

      rearData.filteredDistanceCm = unpackDistanceCm(filtered_x10);
      rearData.rawDistanceCm      = unpackDistanceCm(raw_x10);
      rearData.online             = true;
      rearData.lastUpdateMs       = nowMs;

      Serial.print("CAN Rear Main | state=");
      Serial.print(rearData.state);
      Serial.print(" filtered=");
      Serial.print(rearData.filteredDistanceCm, 1);
      Serial.print(" raw=");
      Serial.println(rearData.rawDistanceCm, 1);
    }
    else if (message.identifier == REAR_DEBUG_ID && message.data_length_code >= 8) {
      rearData.debugFlags                = message.data[0];
      rearData.warningReleaseCounter     = message.data[1];
      rearData.fastWarningReleaseCounter = message.data[2];
      rearData.invalidStreak             = message.data[3];
      rearData.debugCounter              = message.data[7];
      rearData.lastDebugUpdateMs         = nowMs;

      Serial.print("CAN Rear Debug | flags=0x");
      Serial.print(rearData.debugFlags, HEX);
      Serial.print(" release=");
      Serial.print(rearData.warningReleaseCounter);
      Serial.print(" fastRelease=");
      Serial.print(rearData.fastWarningReleaseCounter);
      Serial.print(" invalid=");
      Serial.println(rearData.invalidStreak);
    }
  }
}

// ================= LANE UART RECEIVE =================
void applyLaneStateLine(const String& line, unsigned long nowMs) {
  String msg = trimLine(line);

  Serial.print("RAW LANE LINE: [");
  Serial.print(msg);
  Serial.println("]");

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

  Serial.print("LANE UART | state=");
  Serial.println(laneStateName(laneData.state));
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

// ================= JSON BROADCAST =================
void broadcastCombinedState(unsigned long nowMs) {
  String data;
  data.reserve(1800);

  bool leanOffline  = isOffline(leanData.lastUpdateMs, nowMs);
  bool frontOffline = isOffline(frontData.lastUpdateMs, nowMs);
  bool rearOffline  = isOffline(rearData.lastUpdateMs, nowMs);
  bool laneOffline  = isOffline(laneData.lastUpdateMs, nowMs);

  data += "{";

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
  data += "\"state\":" + String(rearData.state) + ",";
  data += "\"stateName\":\"" + String(rearStateName(rearData.state)) + "\",";
  data += "\"stateColor\":\"" + String(stateColorByLevel(rearData.state)) + "\",";
  data += "\"filteredDistanceCm\":" + String(rearData.filteredDistanceCm, 1) + ",";
  data += "\"rawDistanceCm\":" + String(rearData.rawDistanceCm, 1) + ",";
  data += "\"debugFlags\":" + String(rearData.debugFlags) + ",";
  data += "\"warningReleaseCounter\":" + String(rearData.warningReleaseCounter) + ",";
  data += "\"fastWarningReleaseCounter\":" + String(rearData.fastWarningReleaseCounter) + ",";
  data += "\"invalidStreak\":" + String(rearData.invalidStreak);
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
  :root{
    --bg:#0f1115;
    --card:#171a21;
    --text:#f2f4f8;
    --muted:#b6bcc8;
    --border:#262b35;
  }
  *{box-sizing:border-box}
  html, body{
    margin:0;
    background:var(--bg);
    color:var(--text);
    font-family:Arial,Helvetica,sans-serif;
  }
  body{
    padding:10px;
  }
  .wrap{
    max-width:1600px;
    margin:0 auto;
  }
  .topTitle{
    font-size:18px;
    font-weight:700;
    margin-bottom:8px;
  }
  .statusRow{
    display:flex;
    gap:6px;
    flex-wrap:wrap;
    margin-bottom:10px;
    align-items:center;
  }
  .badge{
    display:inline-block;
    padding:5px 8px;
    border-radius:999px;
    background:#2b2f38;
    font-size:11px;
  }
  button{
    padding:10px 12px;
    border:0;
    border-radius:10px;
    background:#2b2f38;
    color:white;
    font-size:13px;
  }

  .cards{
    display:flex;
    flex-direction:column;
    gap:10px;
  }

  .panel{
    background:var(--card);
    border:1px solid var(--border);
    border-radius:16px;
    padding:10px;
    min-width:0;
  }

  .sensorPanel{
    display:flex;
    flex-direction:column;
  }

  .sensorPanel .stateBox{
    flex:1 1 auto;
  }

  .sensorPanel .grid{
    margin-top:auto;
  }

  .panelHead{
    display:flex;
    justify-content:space-between;
    align-items:center;
    gap:8px;
    margin-bottom:8px;
  }

  .panelTitle{
    font-size:15px;
    font-weight:700;
    min-width:0;
  }

  .stateBox{
    width:100%;
    border-radius:14px;
    min-height:72px;
    display:flex;
    align-items:center;
    justify-content:center;
    text-align:center;
    font-size:22px;
    font-weight:800;
    color:white;
    margin-bottom:10px;
    transition:background-color 120ms linear;
  }

  .grid{
    display:grid;
    grid-template-columns:1fr 1fr;
    gap:8px;
  }

  .cell{
    background:#11151b;
    border:1px solid #232933;
    border-radius:12px;
    padding:8px;
    min-width:0;
  }

  .cell.full{
    grid-column:1 / -1;
  }

  .label{
    color:var(--muted);
    font-size:11px;
    margin-bottom:4px;
  }

  .value{
    font-size:18px;
    font-weight:700;
    word-break:break-word;
    line-height:1.15;
  }

  #frontPanel .grid{
    grid-template-columns:1fr 1fr;
  }

  #leanPanel .grid{
    grid-template-columns:1fr 1fr 1fr;
  }
  #leanPanel .cell.confidenceCell{
    grid-column:auto;
  }

  #leanVisual {
    position: relative;
    width: 100%;
    height: 250px;
    background: #000;
    overflow: hidden;
    border-radius: 16px;
    margin-bottom: 10px;
  }
  #leanField {
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
  }
  .circle {
    position: absolute;
    border: 1px solid #555;
    border-radius: 50%;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    box-sizing: border-box;
  }
  #c1 { width: 88%; height: 88%; }
  #c2 { width: 70%; height: 70%; }
  #c3 { width: 52%; height: 52%; }
  #c4 { width: 34%; height: 34%; }
  #c5 { width: 16%; height: 16%; }
  .line {
    position: absolute;
    background: #555;
  }
  #lineV {
    width: 2px;
    height: 100%;
    left: 50%;
    top: 0;
  }
  #lineH {
    width: 100%;
    height: 2px;
    top: 50%;
    left: 0;
  }
  #leanDot {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    background: rgba(64, 128, 255, 0.75);
    box-shadow: 0 0 12px rgba(64, 128, 255, 0.75);
  }

  #laneVisual {
    width: 100%;
    height: 220px;
    background: #0b0d12;
    border-radius: 16px;
    position: relative;
    overflow: hidden;
    margin-bottom: 10px;
    border: 1px solid #232933;
  }

  #laneRoadCenter {
    position: absolute;
    left: 50%;
    top: 0;
    transform: translateX(-50%);
    width: 70%;
    height: 100%;
  }

  .laneMark {
    position: absolute;
    top: 8%;
    width: 8px;
    height: 84%;
    border-radius: 999px;
    background: #9aa3b2;
    opacity: 0.95;
    transition: background-color 120ms linear, box-shadow 120ms linear;
  }

  #laneLeftMark {
    left: 30%;
    transform: translateX(-50%) rotate(8deg);
  }

  #laneRightMark {
    left: 70%;
    transform: translateX(-50%) rotate(-8deg);
  }

  .laneAlert {
    background: #ffb020 !important;
    box-shadow: 0 0 18px rgba(255,176,32,0.65);
  }

  @media (orientation: landscape) and (max-width: 1400px) {
    body{
      padding:8px;
    }
    .topTitle{
      font-size:16px;
      margin-bottom:6px;
    }
    .statusRow{
      gap:5px;
      margin-bottom:8px;
    }
    button{
      padding:8px 10px;
      font-size:12px;
    }

    .cards{
      flex-direction:row;
      align-items:stretch;
      gap:8px;
      flex-wrap:wrap;
    }
    .panel{
      flex:1 1 calc(50% - 8px);
      padding:8px;
    }

    .panelHead{
      margin-bottom:6px;
      gap:6px;
    }
    .panelTitle{
      font-size:13px;
    }
    .badge{
      padding:4px 7px;
      font-size:10px;
    }
    .stateBox{
      min-height:52px;
      font-size:16px;
      margin-bottom:8px;
      border-radius:12px;
    }
    #frontPanel .stateBox,
    #rearPanel .stateBox{
      min-height:120px;
    }
    #leanVisual{
      height:164px;
      margin-bottom:8px;
      border-radius:12px;
    }
    #laneVisual{
      height:164px;
      margin-bottom:8px;
      border-radius:12px;
    }
    .grid{
      grid-template-columns:1fr;
      gap:6px;
    }

    #frontPanel .grid{
      grid-template-columns:1fr 1fr;
      gap:6px;
    }

    #leanPanel .grid{
      grid-template-columns:1fr 1fr 1fr;
      gap:6px;
    }
    #leanPanel .cell.confidenceCell{
      grid-column:auto;
    }

    .cell{
      padding:6px 7px;
      border-radius:10px;
    }
    .label{
      font-size:10px;
      margin-bottom:2px;
    }
    .value{
      font-size:14px;
      line-height:1.05;
    }
  }

  @media (min-width: 1401px) {
    .cards{
      flex-direction:row;
      align-items:stretch;
      flex-wrap:wrap;
    }
    .panel{
      flex:1 1 calc(25% - 10px);
    }
  }
</style>
</head>
<body>
<div class="wrap">
  <div class="topTitle">ADAS Brain Monitor</div>

  <div class="statusRow">
    <span class="badge">Brain AP: ADASBrain</span>
    <button id="audioBtn" onclick="enableAudio()">Enable Sound</button>
  </div>

  <div class="cards">
    <div class="panel sensorPanel" id="frontPanel">
      <div class="panelHead">
        <div class="panelTitle">Front Collision Warning</div>
        <span class="badge" id="frontBadge">Offline</span>
      </div>
      <div id="frontStateBox" class="stateBox" style="background:#1db954;">CLEAR</div>
      <div class="grid">
        <div class="cell"><div class="label">Distance</div><div id="frontDist" class="value">--</div></div>
        <div class="cell"><div class="label">Speed</div><div id="frontSpeed" class="value">--</div></div>
      </div>
    </div>

    <div class="panel" id="leanPanel">
      <div class="panelHead">
        <div class="panelTitle">Lean Monitor</div>
        <span class="badge" id="leanBadge">Offline</span>
      </div>
      <div id="leanVisual">
        <div id="leanField">
          <div id="c1" class="circle"></div>
          <div id="c2" class="circle"></div>
          <div id="c3" class="circle"></div>
          <div id="c4" class="circle"></div>
          <div id="c5" class="circle"></div>
          <div id="lineV" class="line"></div>
          <div id="lineH" class="line"></div>
          <div id="leanDot"></div>
        </div>
      </div>
      <div id="leanStateBox" class="stateBox" style="background:#1db954;">SAFE</div>
      <div class="grid">
        <div class="cell"><div class="label">Roll</div><div id="leanRoll" class="value">0.00°</div></div>
        <div class="cell"><div class="label">Pitch</div><div id="leanPitch" class="value">0.00°</div></div>
        <div class="cell confidenceCell"><div class="label">Conf</div><div id="leanConf" class="value">1.00</div></div>
      </div>
    </div>

    <div class="panel sensorPanel" id="rearPanel">
      <div class="panelHead">
        <div class="panelTitle">Rear Blindspot</div>
        <span class="badge" id="rearBadge">Offline</span>
      </div>
      <div id="rearStateBox" class="stateBox" style="background:#1db954;">CLEAR</div>
      <div class="grid">
        <div class="cell full"><div class="label">Distance</div><div id="rearDist" class="value">--</div></div>
      </div>
    </div>

    <div class="panel sensorPanel" id="lanePanel">
      <div class="panelHead">
        <div class="panelTitle">Lane Departure Warning</div>
        <span class="badge" id="laneBadge">Offline</span>
      </div>
      <div id="laneVisual">
        <div id="laneRoadCenter">
          <div id="laneLeftMark" class="laneMark"></div>
          <div id="laneRightMark" class="laneMark"></div>
        </div>
      </div>
      <div id="laneStateBox" class="stateBox" style="background:#1db954;">SAFE</div>
    </div>
  </div>
</div>

<script>
const ws = new WebSocket("ws://" + location.hostname + ":81");

let audioCtx = null;
let audioEnabled = false;
let lastFrontBeepMs = 0;
let lastRearBeepMs = 0;
let lastLaneBeepMs = 0;

let leanDotCurrentX = 0;
let leanDotCurrentY = 0;
let leanDotTargetX = 0;
let leanDotTargetY = 0;
let leanDotInitialized = false;

function enableAudio() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }
  audioCtx.resume().then(() => {
    audioEnabled = true;
    document.getElementById("audioBtn").innerText = "Sound Enabled";
  });
}

function playBeep(freq = 900, durationMs = 80, volume = 0.08) {
  if (!audioEnabled || !audioCtx) return;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();

  osc.type = "sine";
  osc.frequency.value = freq;
  gain.gain.value = volume;

  osc.connect(gain);
  gain.connect(audioCtx.destination);

  const now = audioCtx.currentTime;
  osc.start(now);
  osc.stop(now + durationMs / 1000);
  gain.gain.setValueAtTime(volume, now);
  gain.gain.exponentialRampToValueAtTime(0.0001, now + durationMs / 1000);
}

function resizeLeanField() {
  const visual = document.getElementById("leanVisual");
  const rect = visual.getBoundingClientRect();
  const side = Math.min(rect.width, rect.height) * 0.92;
  const field = document.getElementById("leanField");
  field.style.width = side + "px";
  field.style.height = side + "px";
}
window.addEventListener("resize", resizeLeanField);
window.addEventListener("load", resizeLeanField);

function softAxisPosition(valueDeg, criticalDeg, radiusPx) {
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

function animateLeanDot() {
  if (!leanDotInitialized) {
    requestAnimationFrame(animateLeanDot);
    return;
  }

  const leanDot = document.getElementById("leanDot");
  const SMOOTH = 0.35;

  leanDotCurrentX += (leanDotTargetX - leanDotCurrentX) * SMOOTH;
  leanDotCurrentY += (leanDotTargetY - leanDotCurrentY) * SMOOTH;

  leanDot.style.left = leanDotCurrentX + "px";
  leanDot.style.top = leanDotCurrentY + "px";

  requestAnimationFrame(animateLeanDot);
}

requestAnimationFrame(animateLeanDot);

function fmtCm(v){
  if (v < 0) return "Invalid";
  return v.toFixed(1) + " cm";
}
function fmtSpeed(v){
  return (v >= 0 ? "+" : "") + v.toFixed(1) + " cm/s";
}

function statusText(obj){
  if (!obj.online) return "Offline";
  if (obj.stale) return "Stale";
  return "Online";
}

ws.onmessage = (evt) => {
  const d = JSON.parse(evt.data);

  // Lean
  const lean = d.lean;
  document.getElementById("leanBadge").innerText = statusText(lean);
  document.getElementById("leanStateBox").innerText = lean.riskName;
  document.getElementById("leanStateBox").style.backgroundColor = lean.riskLevel === 2 ? "#ff3b30" : (lean.riskLevel === 1 ? "#ffb020" : "#1db954");
  document.getElementById("leanRoll").innerText = lean.roll.toFixed(2) + "°";
  document.getElementById("leanPitch").innerText = lean.pitch.toFixed(2) + "°";
  document.getElementById("leanConf").innerText = lean.confidence.toFixed(2);

  const field = document.getElementById("leanField");
  const rect = field.getBoundingClientRect();
  const centerX = rect.width / 2;
  const centerY = rect.height / 2;
  const radius = Math.min(rect.width, rect.height) / 2 - 12;

  const px = centerX + softAxisPosition(lean.roll, lean.criticalRollDeg, radius);
  const py = centerY + softAxisPosition(lean.pitch, lean.criticalPitchDeg, radius);

  leanDotTargetX = px;
  leanDotTargetY = py;

  if (!leanDotInitialized) {
    leanDotCurrentX = px;
    leanDotCurrentY = py;
    leanDotInitialized = true;
  }

  // Front
  const front = d.front;
  document.getElementById("frontBadge").innerText = statusText(front);
  document.getElementById("frontStateBox").innerText = front.stateName;
  document.getElementById("frontStateBox").style.backgroundColor = front.stateColor;
  document.getElementById("frontDist").innerText = fmtCm(front.filteredDistanceCm);
  document.getElementById("frontSpeed").innerText = fmtSpeed(front.closingSpeedCmS);

  // Rear
  const rear = d.rear;
  document.getElementById("rearBadge").innerText = statusText(rear);
  document.getElementById("rearStateBox").innerText = rear.stateName;
  document.getElementById("rearStateBox").style.backgroundColor = rear.stateColor;
  document.getElementById("rearDist").innerText = fmtCm(rear.filteredDistanceCm);

  // Lane
  const lane = d.lane;
  document.getElementById("laneBadge").innerText = statusText(lane);
  document.getElementById("laneStateBox").innerText = lane.stateName;
  document.getElementById("laneStateBox").style.backgroundColor = lane.stateColor;

  const leftMark = document.getElementById("laneLeftMark");
  const rightMark = document.getElementById("laneRightMark");

  leftMark.classList.remove("laneAlert");
  rightMark.classList.remove("laneAlert");

  if (lane.state === 1) {
    leftMark.classList.add("laneAlert");
  } else if (lane.state === 2) {
    rightMark.classList.add("laneAlert");
  }

  // Brain-generated beeps
  const now = Date.now();

  if (audioEnabled) {
    if (front.state === 2) {
      if (now - lastFrontBeepMs > 700) {
        playBeep(850, 70, 0.07);
        lastFrontBeepMs = now;
      }
    } else if (front.state === 3) {
      if (now - lastFrontBeepMs > 250) {
        playBeep(1250, 90, 0.09);
        lastFrontBeepMs = now;
      }
    }

    if (rear.state === 1) {
      if (now - lastRearBeepMs > 900) {
        playBeep(820, 70, 0.06);
        lastRearBeepMs = now;
      }
    } else if (rear.state === 2) {
      if (now - lastRearBeepMs > 450) {
        playBeep(980, 80, 0.07);
        lastRearBeepMs = now;
      }
    } else if (rear.state === 3) {
      if (now - lastRearBeepMs > 180) {
        playBeep(1250, 90, 0.09);
        lastRearBeepMs = now;
      }
    }

    if (lane.state === 1 || lane.state === 2) {
      if (now - lastLaneBeepMs > 220) {
        playBeep(1100, 80, 0.08);
        lastLaneBeepMs = now;
      }
    }
  }
};
</script>
</body>
</html>
)rawliteral";

// ================= WEBSOCKET =================
void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_TEXT) {
    String msg = payloadToString(payload, length);
    if (msg == "PING") return;
  }
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  delay(200);

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

  Serial.println("ADAS Brain UI skeleton ready");
}

// ================= LOOP =================
void loop() {
  unsigned long nowMs = millis();

  server.handleClient();
  webSocket.loop();

  receiveCANFrames(nowMs);
  receiveLaneUART(nowMs);

  if (nowMs - lastBroadcastMs >= UI_BROADCAST_MS) {
    lastBroadcastMs = nowMs;
    broadcastCombinedState(nowMs);
  }
}