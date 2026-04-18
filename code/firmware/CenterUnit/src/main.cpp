#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <MPU6050.h>
#include <math.h>

// ================= WIFI =================
const char* ssid = "LeanMonitor";
const char* password = "12345678";

// ================= I2C PINS =================
static const int I2C_SDA = 8;
static const int I2C_SCL = 9;

// ================= SERVERS =================
WebServer server(80);
WebSocketsServer webSocket(81);

// ================= MPU =================
MPU6050 mpu;

// ================= MODE =================
bool autoMode = false;
bool calibrated = false;

// Frame mode:
// false = normal raw frame
// true  = upside-frame emulation (the mode that behaved best for you)
bool useUpsideFrame = true;

// ================= VEHICLE MODEL =================
// These are now fully controllable from the UI
int vehicleType = 3;          // 1 / 2 / 3
float trackWidth_m = 1.90f;   // meters
float vehicleHeight_m = 3.20f;// meters
int loadCondition = 2;        // 0 light, 1 normal, 2 heavy
int suspensionType = 0;       // 0 normal, 1 stiff

float criticalRollDeg = 30.0f;
float criticalPitchDeg = 20.0f;
float vehicleFactor = 1.15f;

// ================= CALIBRATION / REFERENCE =================
float axBias = 0, ayBias = 0, azBias = 0;
float gxBias = 0, gyBias = 0, gzBias = 0;

float calibPitchRef = 0.0f;
float calibRollRef  = 0.0f;

unsigned long calibrationHoldUntil = 0;

// ================= FILTER STATE =================
float pitchAngle = 0.0f, rollAngle = 0.0f;
float pitchDisplay = 0.0f, rollDisplay = 0.0f;

unsigned long lastMicros = 0;
unsigned long lastRiskChangeMs = 0;

// ================= BASE TUNING =================
float baseAlphaStill   = 0.93f;
float baseAlphaMotion  = 0.998f;
float baseAccelWarn    = 0.04f;
float baseAccelHigh    = 0.16f;
float baseDisplayAlpha = 0.35f;
float baseDeadband     = 0.12f;

// ================= LIVE TUNING VALUES =================
float alphaStill   = 0.93f;
float alphaMotion  = 0.998f;
float accelWarn    = 0.04f;
float accelHigh    = 0.16f;
float displayAlpha = 0.35f;
float deadband     = 0.12f;

// ================= OUTPUT =================
int stableRisk = 0;

static inline float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

float mapAlpha(float err) {
  if (accelHigh <= accelWarn + 0.0001f) {
    accelHigh = accelWarn + 0.0001f;
  }

  if (err <= accelWarn) return alphaStill;
  if (err >= accelHigh) return alphaMotion;

  float t = (err - accelWarn) / (accelHigh - accelWarn);
  return alphaStill + t * (alphaMotion - alphaStill);
}

int riskLevel(float s) {
  if (s < 0.35f) return 0;
  if (s < 0.60f) return 1;
  if (s < 0.80f) return 2;
  return 3;
}

void computeVehicle() {
  float base;
  switch (vehicleType) {
    case 1: base = 0.32f; vehicleFactor = 0.90f; break;
    case 2: base = 0.42f; vehicleFactor = 1.10f; break;
    case 3: base = 0.40f; vehicleFactor = 1.15f; break;
    default: base = 0.40f; vehicleFactor = 1.00f; break;
  }

  float loadF = (loadCondition == 2) ? 1.12f : (loadCondition == 1) ? 1.00f : 0.92f;
  float suspF = (suspensionType == 0) ? 1.05f : 1.00f;

  float cogH = vehicleHeight_m * base * loadF;
  if (cogH < 0.001f) cogH = 0.001f;

  criticalRollDeg = atan(trackWidth_m / (2.0f * cogH)) * 180.0f / PI;
  criticalPitchDeg = 20.0f;
  vehicleFactor *= suspF;
}

void applyManualTuning() {
  alphaStill   = baseAlphaStill;
  alphaMotion  = baseAlphaMotion;
  accelWarn    = baseAccelWarn;
  accelHigh    = baseAccelHigh;
  displayAlpha = baseDisplayAlpha;
  deadband     = baseDeadband;
}

void autoTune(float accErr, float angRate) {
  float stability = clampf(1.0f - accErr * 5.0f, 0.0f, 1.0f);
  float motion = clampf(angRate / 15.0f, 0.0f, 1.0f);

  alphaStill   = clampf(baseAlphaStill + 0.05f * stability, 0.80f, 0.99f);
  alphaMotion  = clampf(baseAlphaMotion + 0.004f * motion, 0.990f, 0.9999f);
  accelWarn    = clampf(baseAccelWarn + 0.05f * motion, 0.000f, 0.25f);
  accelHigh    = clampf(baseAccelHigh + 0.10f * motion, accelWarn + 0.01f, 0.40f);
  displayAlpha = clampf(baseDisplayAlpha + 0.20f * stability - 0.05f * motion, 0.10f, 0.95f);
  deadband     = clampf(baseDeadband + 0.08f * (1.0f - stability), 0.0f, 0.30f);
}

// Emulate the useful upside-down frame in software.
// Applied before bias subtraction and calibration.
void applyMountTransform(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
  if (!useUpsideFrame) return;

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

    float fax = (float)a;
    float fay = (float)b;
    float faz = (float)c;
    float fgx = (float)d;
    float fgy = (float)e;
    float fgz = (float)f;

    applyMountTransform(fax, fay, faz, fgx, fgy, fgz);

    ax += (long)fax;
    ay += (long)fay;
    az += (long)faz;
    gx += (long)fgx;
    gy += (long)fgy;
    gz += (long)fgz;

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

  for (int i = 0; i < 800; i++) {
    int16_t a, b, c, d, e, f;
    mpu.getMotion6(&a, &b, &c, &d, &e, &f);

    float fax = (float)a;
    float fay = (float)b;
    float faz = (float)c;
    float fgx = (float)d;
    float fgy = (float)e;
    float fgz = (float)f;

    applyMountTransform(fax, fay, faz, fgx, fgy, fgz);

    float axn = (fax - axBias) / 16384.0f;
    float ayn = (fay - ayBias) / 16384.0f;
    float azn = (faz - azBias) / 16384.0f;

    float p = atan2(axn, sqrt(ayn * ayn + azn * azn)) * 180.0f / PI;
    float r = -atan2(ayn, sqrt(axn * axn + azn * azn)) * 180.0f / PI;

    pitchSum += p;
    rollSum  += r;

    delay(2);
  }

  calibPitchRef = pitchSum / 800.0;
  calibRollRef  = rollSum / 800.0;

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

String payloadToString(uint8_t* payload, size_t length) {
  String s;
  s.reserve(length);
  for (size_t i = 0; i < length; i++) {
    s += (char)payload[i];
  }
  return s;
}

void handleCommand(const String& msg) {
  if (msg == "CAL") {
    calibrate();
    return;
  }

  if (msg == "AUTO_ON") {
    autoMode = true;
    return;
  }

  if (msg == "AUTO_OFF") {
    autoMode = false;
    return;
  }

  if (msg == "FRAME_UP") {
    useUpsideFrame = true;
    calibrate();
    return;
  }

  if (msg == "FRAME_NORMAL") {
    useUpsideFrame = false;
    calibrate();
    return;
  }

  JsonDocument doc;
  if (deserializeJson(doc, msg)) return;

  bool vehicleChanged = false;

  if (doc["vehicleType"].is<int>()) {
    int v = doc["vehicleType"].as<int>();
    if (v >= 1 && v <= 3) {
      vehicleType = v;
      vehicleChanged = true;
    }
  }

  if (doc["trackWidth_m"].is<float>()) {
    trackWidth_m = clampf(doc["trackWidth_m"].as<float>(), 0.80f, 4.00f);
    vehicleChanged = true;
  }

  if (doc["vehicleHeight_m"].is<float>()) {
    vehicleHeight_m = clampf(doc["vehicleHeight_m"].as<float>(), 0.50f, 6.00f);
    vehicleChanged = true;
  }

  if (doc["loadCondition"].is<int>()) {
    int v = doc["loadCondition"].as<int>();
    if (v >= 0 && v <= 2) {
      loadCondition = v;
      vehicleChanged = true;
    }
  }

  if (doc["suspensionType"].is<int>()) {
    int v = doc["suspensionType"].as<int>();
    if (v >= 0 && v <= 1) {
      suspensionType = v;
      vehicleChanged = true;
    }
  }

  if (doc["alphaStill"].is<float>())   baseAlphaStill = clampf(doc["alphaStill"].as<float>(), 0.80f, 0.99f);
  if (doc["alphaMotion"].is<float>())  baseAlphaMotion = clampf(doc["alphaMotion"].as<float>(), 0.990f, 0.9999f);
  if (doc["accelWarn"].is<float>())    baseAccelWarn = clampf(doc["accelWarn"].as<float>(), 0.0f, 0.25f);
  if (doc["accelHigh"].is<float>())    baseAccelHigh = clampf(doc["accelHigh"].as<float>(), baseAccelWarn + 0.01f, 0.40f);
  if (doc["displayAlpha"].is<float>())  baseDisplayAlpha = clampf(doc["displayAlpha"].as<float>(), 0.10f, 0.95f);
  if (doc["deadband"].is<float>())      baseDeadband = clampf(doc["deadband"].as<float>(), 0.0f, 0.30f);

  if (vehicleChanged) {
    computeVehicle();
  }

  if (!autoMode) {
    applyManualTuning();
  }
}

void onWebSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  if (type == WStype_TEXT) {
    String msg = payloadToString(payload, length);
    handleCommand(msg);
  }
}

// ================= WEB UI =================
const char webpage[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body {
    margin: 0;
    background: #111;
    color: white;
    font-family: Arial, sans-serif;
  }
  #visual {
    position: relative;
    width: 100%;
    height: 52vh;
    background: #000;
    overflow: hidden;
    border-bottom: 1px solid #222;
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

  #dot {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    background: #ff4040;
    box-shadow: 0 0 12px rgba(255, 64, 64, 0.9);
  }

  #statusBar {
    padding: 10px 12px 0 12px;
    font-size: 14px;
    line-height: 1.5;
  }

  #controls {
    padding: 10px 12px 18px 12px;
  }

  .row {
    margin-bottom: 10px;
  }

  button, select {
    padding: 10px 12px;
    margin-right: 6px;
    margin-bottom: 8px;
    border: 0;
    border-radius: 10px;
    background: #2b2b2b;
    color: white;
    font-size: 14px;
  }
  button:active { background: #404040; }

  .groupTitle {
    margin: 12px 0 6px 0;
    font-size: 15px;
    color: #ddd;
    font-weight: bold;
  }

  .label {
    display: flex;
    justify-content: space-between;
    font-size: 13px;
    color: #cfcfcf;
    margin: 8px 0 3px 0;
  }

  input[type="range"], input[type="number"] {
    width: 100%;
  }

  .valueBox {
    margin-top: 8px;
    padding: 10px;
    border-radius: 10px;
    background: #1b1b1b;
    border: 1px solid #2a2a2a;
    font-size: 12px;
    line-height: 1.55;
    color: #d7d7d7;
  }

  .badge {
    display: inline-block;
    padding: 4px 8px;
    border-radius: 999px;
    font-size: 12px;
    margin-left: 8px;
    background: #2d2d2d;
    color: #fff;
  }
</style>
</head>
<body>

<div id="visual">
  <div id="c1" class="circle"></div>
  <div id="c2" class="circle"></div>
  <div id="c3" class="circle"></div>
  <div id="c4" class="circle"></div>
  <div id="c5" class="circle"></div>

  <div id="lineV" class="line"></div>
  <div id="lineH" class="line"></div>
  <div id="dot"></div>
</div>

<div id="statusBar">
  <div>
    <span id="modeBadge" class="badge">MANUAL</span>
    <span id="frameBadge" class="badge">FRAME: UPSIDE</span>
    <span id="calBadge" class="badge">NOT CALIBRATED</span>
  </div>
  <div id="statusText">Roll: 0.00° | Pitch: 0.00° | Confidence: 1.00 | Risk: SAFE</div>
</div>

<div id="controls">
  <div class="row">
    <button onclick="calibrate()">Calibrate</button>
    <button onclick="setAuto(true)">AUTO MODE</button>
    <button onclick="setAuto(false)">MANUAL MODE</button>
    <button onclick="setFrame(true)">UPSIDE FRAME</button>
    <button onclick="setFrame(false)">NORMAL FRAME</button>
  </div>

  <div class="groupTitle">Vehicle settings</div>

  <div class="label"><span>Vehicle type</span><span id="vehicleTypeVal">3</span></div>
  <select id="vehicleType" onchange="sendParam('vehicleType', this.value)">
    <option value="1">Type 1</option>
    <option value="2">Type 2</option>
    <option value="3" selected>Type 3</option>
  </select>

  <div class="label"><span>Track width (m)</span><span id="trackWidthVal">1.90 m</span></div>
  <input id="trackWidth_m" type="range" min="0.80" max="4.00" step="0.01" value="1.90"
         oninput="vehicleNumberChanged('trackWidth_m', this.value, 'trackWidthVal', ' m')">

  <div class="label"><span>Vehicle height (m)</span><span id="vehicleHeightVal">3.20 m</span></div>
  <input id="vehicleHeight_m" type="range" min="0.50" max="6.00" step="0.01" value="3.20"
         oninput="vehicleNumberChanged('vehicleHeight_m', this.value, 'vehicleHeightVal', ' m')">

  <div class="label"><span>Load condition</span><span id="loadConditionVal">2</span></div>
  <select id="loadCondition" onchange="sendParam('loadCondition', this.value)">
    <option value="0">Light</option>
    <option value="1">Normal</option>
    <option value="2" selected>Heavy</option>
  </select>

  <div class="label"><span>Suspension type</span><span id="suspensionTypeVal">0</span></div>
  <select id="suspensionType" onchange="sendParam('suspensionType', this.value)">
    <option value="0" selected>Normal</option>
    <option value="1">Stiff / sport</option>
  </select>

  <div class="groupTitle">Quick tuning</div>

  <div class="label"><span>Stability ↔ Responsiveness</span><span id="quickBalanceVal">0.50</span></div>
  <input id="quickBalance" type="range" min="0" max="1" step="0.01" value="0.50" oninput="quickBalanceChanged(this.value)">

  <div class="label"><span>Visual smoothing</span><span id="quickSmoothVal">0.50</span></div>
  <input id="quickSmooth" type="range" min="0" max="1" step="0.01" value="0.50" oninput="quickSmoothChanged(this.value)">

  <div class="label"><span>Deadband</span><span id="quickDeadVal">0.50</span></div>
  <input id="quickDead" type="range" min="0" max="1" step="0.01" value="0.50" oninput="quickDeadChanged(this.value)">

  <div class="groupTitle">Manual tuning parameters</div>

  <div class="label"><span>alphaStill</span><span id="alphaStillVal">0.930</span></div>
  <input id="alphaStill" type="range" min="0.80" max="0.99" step="0.001" value="0.930" oninput="sendParam('alphaStill', this.value)">

  <div class="label"><span>alphaMotion</span><span id="alphaMotionVal">0.998</span></div>
  <input id="alphaMotion" type="range" min="0.990" max="0.9999" step="0.0001" value="0.998" oninput="sendParam('alphaMotion', this.value)">

  <div class="label"><span>accelWarn</span><span id="accelWarnVal">0.040</span></div>
  <input id="accelWarn" type="range" min="0.000" max="0.250" step="0.001" value="0.040" oninput="sendParam('accelWarn', this.value)">

  <div class="label"><span>accelHigh</span><span id="accelHighVal">0.160</span></div>
  <input id="accelHigh" type="range" min="0.050" max="0.400" step="0.001" value="0.160" oninput="sendParam('accelHigh', this.value)">

  <div class="label"><span>displayAlpha</span><span id="displayAlphaVal">0.350</span></div>
  <input id="displayAlpha" type="range" min="0.10" max="0.95" step="0.01" value="0.350" oninput="sendParam('displayAlpha', this.value)">

  <div class="label"><span>deadband</span><span id="deadbandVal">0.120</span></div>
  <input id="deadband" type="range" min="0.00" max="0.30" step="0.01" value="0.120" oninput="sendParam('deadband', this.value)">

  <div class="groupTitle">Live values</div>
  <div id="paramBox" class="valueBox"></div>
</div>

<script>
let ws = new WebSocket("ws://" + location.hostname + ":81");
let dot = document.getElementById("dot");

function calibrate() {
  ws.send("CAL");
}

function setAuto(v) {
  ws.send(v ? "AUTO_ON" : "AUTO_OFF");
}

function setFrame(v) {
  ws.send(v ? "FRAME_UP" : "FRAME_NORMAL");
}

function sendParam(k, v) {
  let obj = {};
  obj[k] = (k === "vehicleType" || k === "loadCondition" || k === "suspensionType") ? parseInt(v) : parseFloat(v);
  ws.send(JSON.stringify(obj));
}

function vehicleNumberChanged(k, v, labelId, suffix) {
  document.getElementById(labelId).innerText = parseFloat(v).toFixed(2) + suffix;
  sendParam(k, v);
}

function quickBalanceChanged(v) {
  let x = parseFloat(v);
  document.getElementById("quickBalanceVal").innerText = x.toFixed(2);

  let alphaStill   = 0.86 + 0.13 * x;
  let alphaMotion  = 0.995 + 0.0045 * x;
  let accelWarn    = 0.01 + 0.07 * x;
  let accelHigh    = 0.08 + 0.22 * x;

  ws.send(JSON.stringify({
    alphaStill: alphaStill,
    alphaMotion: alphaMotion,
    accelWarn: accelWarn,
    accelHigh: accelHigh
  }));
}

function quickSmoothChanged(v) {
  let x = parseFloat(v);
  document.getElementById("quickSmoothVal").innerText = x.toFixed(2);

  let displayAlpha = 0.10 + 0.85 * x;
  ws.send(JSON.stringify({ displayAlpha: displayAlpha }));
}

function quickDeadChanged(v) {
  let x = parseFloat(v);
  document.getElementById("quickDeadVal").innerText = x.toFixed(2);

  let deadband = 0.30 * x;
  ws.send(JSON.stringify({ deadband: deadband }));
}

ws.onmessage = (msg) => {
  let d = JSON.parse(msg.data);

  let x = 50 + d.roll * 1.6;
  let y = 50 + d.pitch * 1.6;

  if (x < 0) x = 0;
  if (x > 100) x = 100;
  if (y < 0) y = 0;
  if (y > 100) y = 100;

  dot.style.left = x + "%";
  dot.style.top = y + "%";

  document.getElementById("modeBadge").innerText = d.autoMode ? "AUTO" : "MANUAL";
  document.getElementById("frameBadge").innerText = d.useUpsideFrame ? "FRAME: UPSIDE" : "FRAME: NORMAL";
  document.getElementById("calBadge").innerText = d.calibrated ? "CALIBRATED" : "NOT CALIBRATED";

  let riskText = ["SAFE", "CAUTION", "HIGH", "CRITICAL"][d.level] || "SAFE";

  document.getElementById("statusText").innerText =
    "Roll: " + d.roll.toFixed(2) + "° | " +
    "Pitch: " + d.pitch.toFixed(2) + "° | " +
    "Confidence: " + d.confidence.toFixed(2) + " | " +
    "Risk: " + riskText;

  document.getElementById("vehicleType").value = d.vehicleType;
  document.getElementById("loadCondition").value = d.loadCondition;
  document.getElementById("suspensionType").value = d.suspensionType;

  document.getElementById("trackWidth_m").value = d.trackWidth_m.toFixed(2);
  document.getElementById("vehicleHeight_m").value = d.vehicleHeight_m.toFixed(2);
  document.getElementById("trackWidthVal").innerText = d.trackWidth_m.toFixed(2) + " m";
  document.getElementById("vehicleHeightVal").innerText = d.vehicleHeight_m.toFixed(2) + " m";

  document.getElementById("vehicleTypeVal").innerText = d.vehicleType;
  document.getElementById("loadConditionVal").innerText = d.loadCondition;
  document.getElementById("suspensionTypeVal").innerText = d.suspensionType;

  document.getElementById("alphaStill").value = d.baseAlphaStill.toFixed(3);
  document.getElementById("alphaMotion").value = d.baseAlphaMotion.toFixed(4);
  document.getElementById("accelWarn").value = d.baseAccelWarn.toFixed(3);
  document.getElementById("accelHigh").value = d.baseAccelHigh.toFixed(3);
  document.getElementById("displayAlpha").value = d.baseDisplayAlpha.toFixed(3);
  document.getElementById("deadband").value = d.baseDeadband.toFixed(3);

  document.getElementById("alphaStillVal").innerText = d.alphaStill.toFixed(3);
  document.getElementById("alphaMotionVal").innerText = d.alphaMotion.toFixed(4);
  document.getElementById("accelWarnVal").innerText = d.accelWarn.toFixed(3);
  document.getElementById("accelHighVal").innerText = d.accelHigh.toFixed(3);
  document.getElementById("displayAlphaVal").innerText = d.displayAlpha.toFixed(3);
  document.getElementById("deadbandVal").innerText = d.deadband.toFixed(3);

  document.getElementById("paramBox").innerHTML =
    "<b>Vehicle</b><br>" +
    "vehicleType: " + d.vehicleType + "<br>" +
    "trackWidth: " + d.trackWidth_m.toFixed(2) + " m<br>" +
    "vehicleHeight: " + d.vehicleHeight_m.toFixed(2) + " m<br>" +
    "loadCondition: " + d.loadCondition + "<br>" +
    "suspensionType: " + d.suspensionType + "<br>" +
    "criticalRollDeg: " + d.criticalRollDeg.toFixed(2) + "°<br>" +
    "criticalPitchDeg: " + d.criticalPitchDeg.toFixed(2) + "°<br>" +
    "vehicleFactor: " + d.vehicleFactor.toFixed(3) + "<br><br>" +

    "<b>Base values</b><br>" +
    "alphaStill: " + d.baseAlphaStill.toFixed(3) + "<br>" +
    "alphaMotion: " + d.baseAlphaMotion.toFixed(4) + "<br>" +
    "accelWarn: " + d.baseAccelWarn.toFixed(3) + "<br>" +
    "accelHigh: " + d.baseAccelHigh.toFixed(3) + "<br>" +
    "displayAlpha: " + d.baseDisplayAlpha.toFixed(3) + "<br>" +
    "deadband: " + d.baseDeadband.toFixed(3) + "<br><br>" +

    "<b>Live values</b><br>" +
    "alphaStill: " + d.alphaStill.toFixed(3) + "<br>" +
    "alphaMotion: " + d.alphaMotion.toFixed(4) + "<br>" +
    "accelWarn: " + d.accelWarn.toFixed(3) + "<br>" +
    "accelHigh: " + d.accelHigh.toFixed(3) + "<br>" +
    "displayAlpha: " + d.displayAlpha.toFixed(3) + "<br>" +
    "deadband: " + d.deadband.toFixed(3) + "<br><br>" +

    "<b>Calibration reference</b><br>" +
    "calibRollRef: " + d.calibRollRef.toFixed(3) + "<br>" +
    "calibPitchRef: " + d.calibPitchRef.toFixed(3);
};
</script>

</body>
</html>
)rawliteral";

// ================= SETUP =================
void setup() {
  Serial.begin(115200);
  delay(200);

  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password);
  WiFi.setSleep(false);

  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/", []() {
    server.send_P(200, "text/html", webpage);
  });
  server.begin();

  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);

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

  computeVehicle();
  applyManualTuning();

  lastMicros = micros();
  lastRiskChangeMs = millis();

  Serial.println("Ready. Connect phone to WiFi and open 192.168.4.1");
}

// ================= LOOP =================
void loop() {
  server.handleClient();
  webSocket.loop();

  int16_t axR, ayR, azR, gxR, gyR, gzR;
  mpu.getMotion6(&axR, &ayR, &azR, &gxR, &gyR, &gzR);

  float rawAx = (float)axR;
  float rawAy = (float)ayR;
  float rawAz = (float)azR;
  float rawGx = (float)gxR;
  float rawGy = (float)gyR;
  float rawGz = (float)gzR;

  applyMountTransform(rawAx, rawAy, rawAz, rawGx, rawGy, rawGz);

  float dt = (micros() - lastMicros) / 1000000.0f;
  lastMicros = micros();
  if (dt <= 0.0f || dt > 0.1f) dt = 0.01f;

  float ax = (rawAx - axBias) / 16384.0f;
  float ay = (rawAy - ayBias) / 16384.0f;
  float az = (rawAz - azBias) / 16384.0f;

  float gx = (rawGx - gxBias) / 131.0f;
  float gy = (rawGy - gyBias) / 131.0f;

  float accMag = sqrt(ax * ax + ay * ay + az * az);
  float accErr = fabs(accMag - 1.0f);

  float pitchAccRaw = atan2(ax, sqrt(ay * ay + az * az)) * 180.0f / PI;
  float rollAccRaw  = -atan2(ay, sqrt(ax * ax + az * az)) * 180.0f / PI;

  float pitchAcc = pitchAccRaw - calibPitchRef;
  float rollAcc  = rollAccRaw - calibRollRef;

  float pitchGyro = pitchAngle + gy * dt;
  float rollGyro  = rollAngle + gx * dt;

  float angRate = max(fabs(gx), fabs(gy));

  if (autoMode) {
    autoTune(accErr, angRate);
  } else {
    applyManualTuning();
  }

  float alpha = mapAlpha(accErr);

  pitchAngle = alpha * pitchGyro + (1.0f - alpha) * pitchAcc;
  rollAngle  = alpha * rollGyro  + (1.0f - alpha) * rollAcc;

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

  float baseRisk = vehicleFactor * (0.6f * nRoll + 0.4f * nPitch);
  baseRisk = clampf(baseRisk, 0.0f, 1.0f);

  float effectiveRisk = baseRisk * (0.7f + 0.3f * confidence);

  int desired = riskLevel(effectiveRisk);
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

  // Only flip pitch for the visualizer
  float visualRoll = rollDisplay;
  float visualPitch = useUpsideFrame ? pitchDisplay : -pitchDisplay;

  String data;
  data.reserve(520);
  data += "{";
  data += "\"roll\":" + String(visualRoll, 3) + ",";
  data += "\"pitch\":" + String(visualPitch, 3) + ",";
  data += "\"confidence\":" + String(confidence, 3) + ",";
  data += "\"risk\":" + String(effectiveRisk, 3) + ",";
  data += "\"level\":" + String(stableRisk) + ",";
  data += "\"autoMode\":" + String(autoMode ? 1 : 0) + ",";
  data += "\"useUpsideFrame\":" + String(useUpsideFrame ? 1 : 0) + ",";
  data += "\"calibrated\":" + String(calibrated ? 1 : 0) + ",";
  data += "\"vehicleType\":" + String(vehicleType) + ",";
  data += "\"trackWidth_m\":" + String(trackWidth_m, 2) + ",";
  data += "\"vehicleHeight_m\":" + String(vehicleHeight_m, 2) + ",";
  data += "\"loadCondition\":" + String(loadCondition) + ",";
  data += "\"suspensionType\":" + String(suspensionType) + ",";
  data += "\"criticalRollDeg\":" + String(criticalRollDeg, 2) + ",";
  data += "\"criticalPitchDeg\":" + String(criticalPitchDeg, 2) + ",";
  data += "\"vehicleFactor\":" + String(vehicleFactor, 3) + ",";
  data += "\"baseAlphaStill\":" + String(baseAlphaStill, 3) + ",";
  data += "\"baseAlphaMotion\":" + String(baseAlphaMotion, 4) + ",";
  data += "\"baseAccelWarn\":" + String(baseAccelWarn, 3) + ",";
  data += "\"baseAccelHigh\":" + String(baseAccelHigh, 3) + ",";
  data += "\"baseDisplayAlpha\":" + String(baseDisplayAlpha, 3) + ",";
  data += "\"baseDeadband\":" + String(baseDeadband, 3) + ",";
  data += "\"alphaStill\":" + String(alphaStill, 3) + ",";
  data += "\"alphaMotion\":" + String(alphaMotion, 4) + ",";
  data += "\"accelWarn\":" + String(accelWarn, 3) + ",";
  data += "\"accelHigh\":" + String(accelHigh, 3) + ",";
  data += "\"displayAlpha\":" + String(displayAlpha, 3) + ",";
  data += "\"deadband\":" + String(deadband, 3) + ",";
  data += "\"calibRollRef\":" + String(calibRollRef, 3) + ",";
  data += "\"calibPitchRef\":" + String(calibPitchRef, 3);
  data += "}";

  webSocket.broadcastTXT(data);

  delay(10);
}