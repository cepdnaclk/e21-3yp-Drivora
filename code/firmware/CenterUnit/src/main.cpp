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

  if (doc["wheelBase_m"].is<float>()) {
    wheelBase_m = clampf(doc["wheelBase_m"].as<float>(), 1.50f, 6.00f);
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

  if (vehicleChanged) {
    computeVehicle();
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
  #field {
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

  #dotAuto {
    width: 16px;
    height: 16px;
    border-radius: 50%;
    position: absolute;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    background: rgba(64, 128, 255, 0.62);
    box-shadow: 0 0 12px rgba(64, 128, 255, 0.62);
  }

  #statusBar {
    padding: 10px 12px 0 12px;
    font-size: 14px;
    line-height: 1.5;
  }

  #legend {
    padding: 6px 12px 2px 12px;
    font-size: 13px;
    color: #ddd;
  }

  .legendItem {
    display: inline-flex;
    align-items: center;
    margin-right: 16px;
  }

  .legendDot {
    width: 12px;
    height: 12px;
    border-radius: 50%;
    display: inline-block;
    margin-right: 6px;
  }

  .legendAuto {
    background: rgba(64, 128, 255, 0.62);
    box-shadow: 0 0 8px rgba(64, 128, 255, 0.62);
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

  input[type="range"] {
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
  <div id="field">
    <div id="c1" class="circle"></div>
    <div id="c2" class="circle"></div>
    <div id="c3" class="circle"></div>
    <div id="c4" class="circle"></div>
    <div id="c5" class="circle"></div>

    <div id="lineV" class="line"></div>
    <div id="lineH" class="line"></div>
    <div id="dotAuto"></div>
  </div>
</div>

<div id="statusBar">
  <div>
    <span id="modeBadge" class="badge">AUTO</span>
    <span id="frameBadge" class="badge">FRAME: UPSIDE</span>
    <span id="vehBadge" class="badge">Tall vehicle / SUV</span>
    <span id="calBadge" class="badge">NOT CALIBRATED</span>
  </div>
  <div id="statusText">Roll: 0.00° | Pitch: 0.00° | Confidence: 1.00 | Risk: SAFE</div>
</div>

<div id="legend">
  <span class="legendItem"><span class="legendDot legendAuto"></span>Auto</span>
</div>

<div id="controls">
  <div class="row">
    <button onclick="calibrate()">Calibrate</button>
  </div>

  <div class="groupTitle">Vehicle settings</div>

  <div class="label"><span>Vehicle type</span></div>
  <select id="vehicleType" onchange="sendParam('vehicleType', this.value)">
    <option value="1">Compact / low profile</option>
    <option value="2">Passenger vehicle</option>
    <option value="3" selected>Tall vehicle / SUV</option>
  </select>

  <div class="label"><span>Track width (m)</span><span id="trackWidthVal">1.90 m</span></div>
  <input id="trackWidth_m" type="range" min="0.80" max="4.00" step="0.01" value="1.90"
         oninput="vehicleNumberChanged('trackWidth_m', this.value, 'trackWidthVal', ' m')">

  <div class="label"><span>Wheelbase (m)</span><span id="wheelBaseVal">2.65 m</span></div>
  <input id="wheelBase_m" type="range" min="1.50" max="6.00" step="0.01" value="2.65"
         oninput="vehicleNumberChanged('wheelBase_m', this.value, 'wheelBaseVal', ' m')">

  <div class="label"><span>Vehicle height (m)</span><span id="vehicleHeightVal">3.20 m</span></div>
  <input id="vehicleHeight_m" type="range" min="0.50" max="6.00" step="0.01" value="3.20"
         oninput="vehicleNumberChanged('vehicleHeight_m', this.value, 'vehicleHeightVal', ' m')">

  <div class="label"><span>Load condition</span></div>
  <select id="loadCondition" onchange="sendParam('loadCondition', this.value)">
    <option value="0">Light</option>
    <option value="1">Normal</option>
    <option value="2" selected>Heavy</option>
  </select>

  <div class="groupTitle">Live values</div>
  <div id="paramBox" class="valueBox"></div>
</div>

<script>
let ws = new WebSocket("ws://" + location.hostname + ":81");
let dotAuto = document.getElementById("dotAuto");
let field = document.getElementById("field");

function resizeField() {
  const visual = document.getElementById("visual");
  const rect = visual.getBoundingClientRect();
  const side = Math.min(rect.width, rect.height) * 0.92;
  field.style.width = side + "px";
  field.style.height = side + "px";
}

window.addEventListener("resize", resizeField);
window.addEventListener("load", resizeField);

function calibrate() {
  ws.send("CAL");
}

function sendParam(k, v) {
  let obj = {};
  obj[k] = (k === "vehicleType" || k === "loadCondition") ? parseInt(v) : parseFloat(v);
  ws.send(JSON.stringify(obj));
}

function vehicleNumberChanged(k, v, labelId, suffix) {
  document.getElementById(labelId).innerText = parseFloat(v).toFixed(2) + suffix;
  sendParam(k, v);
}

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

ws.onmessage = (msg) => {
  let d = JSON.parse(msg.data);

  const rect = field.getBoundingClientRect();
  const centerX = rect.width / 2;
  const centerY = rect.height / 2;
  const radius = Math.min(rect.width, rect.height) / 2 - 12;

  const pxAuto = centerX + softAxisPosition(d.roll, d.criticalRollDeg, radius);
  const pyAuto = centerY + softAxisPosition(d.pitch, d.criticalPitchDeg, radius);

  dotAuto.style.left = pxAuto + "px";
  dotAuto.style.top = pyAuto + "px";

  document.getElementById("modeBadge").innerText = "AUTO";
  document.getElementById("frameBadge").innerText = "FRAME: UPSIDE";
  document.getElementById("vehBadge").innerText = d.vehicleTypeName;
  document.getElementById("calBadge").innerText = d.calibrated ? "CALIBRATED" : "NOT CALIBRATED";

  let riskText = ["SAFE", "CAUTION", "HIGH"][d.level] || "SAFE";

  document.getElementById("statusText").innerText =
    "Roll: " + d.roll.toFixed(2) + "° | " +
    "Pitch: " + d.pitch.toFixed(2) + "° | " +
    "Confidence: " + d.confidence.toFixed(2) + " | " +
    "Risk: " + riskText;

  document.getElementById("vehicleType").value = d.vehicleType;
  document.getElementById("loadCondition").value = d.loadCondition;

  document.getElementById("trackWidth_m").value = d.trackWidth_m.toFixed(2);
  document.getElementById("wheelBase_m").value = d.wheelBase_m.toFixed(2);
  document.getElementById("vehicleHeight_m").value = d.vehicleHeight_m.toFixed(2);

  document.getElementById("trackWidthVal").innerText = d.trackWidth_m.toFixed(2) + " m";
  document.getElementById("wheelBaseVal").innerText = d.wheelBase_m.toFixed(2) + " m";
  document.getElementById("vehicleHeightVal").innerText = d.vehicleHeight_m.toFixed(2) + " m";

  document.getElementById("paramBox").innerHTML =
    "<b>Vehicle</b><br>" +
    "vehicleType: " + d.vehicleTypeName + "<br>" +
    "trackWidth: " + d.trackWidth_m.toFixed(2) + " m<br>" +
    "wheelBase: " + d.wheelBase_m.toFixed(2) + " m<br>" +
    "vehicleHeight: " + d.vehicleHeight_m.toFixed(2) + " m<br>" +
    "loadCondition: " + d.loadCondition + "<br>" +
    "criticalRollDeg: " + d.criticalRollDeg.toFixed(2) + "°<br>" +
    "criticalPitchDeg: " + d.criticalPitchDeg.toFixed(2) + "°<br><br>" +

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

  String data;
  data.reserve(900);
  data += "{";
  data += "\"roll\":" + String(rollDisplay, 3) + ",";
  data += "\"pitch\":" + String(pitchDisplay, 3) + ",";
  data += "\"confidence\":" + String(confidence, 3) + ",";
  data += "\"risk\":" + String(effectiveRisk, 3) + ",";
  data += "\"level\":" + String(stableRisk) + ",";
  data += "\"calibrated\":" + String(calibrated ? 1 : 0) + ",";
  data += "\"vehicleType\":" + String(vehicleType) + ",";
  data += "\"vehicleTypeName\":\"";
  data += vehicleTypeName(vehicleType);
  data += "\",";
  data += "\"trackWidth_m\":" + String(trackWidth_m, 2) + ",";
  data += "\"wheelBase_m\":" + String(wheelBase_m, 2) + ",";
  data += "\"vehicleHeight_m\":" + String(vehicleHeight_m, 2) + ",";
  data += "\"loadCondition\":" + String(loadCondition) + ",";
  data += "\"criticalRollDeg\":" + String(criticalRollDeg, 2) + ",";
  data += "\"criticalPitchDeg\":" + String(criticalPitchDeg, 2) + ",";

  data += "\"autoBaseAlphaStill\":" + String(autoBaseAlphaStill, 3) + ",";
  data += "\"autoBaseAlphaMotion\":" + String(autoBaseAlphaMotion, 4) + ",";
  data += "\"autoBaseAccelWarn\":" + String(autoBaseAccelWarn, 3) + ",";
  data += "\"autoBaseAccelHigh\":" + String(autoBaseAccelHigh, 3) + ",";
  data += "\"autoBaseDisplayAlpha\":" + String(autoBaseDisplayAlpha, 3) + ",";
  data += "\"autoBaseDeadband\":" + String(autoBaseDeadband, 3) + ",";

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