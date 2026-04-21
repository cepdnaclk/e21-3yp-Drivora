#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

// ================= WIFI / WEB =================
const char* ssid = "FCWMonitor";
const char* password = "12345678";

WebServer server(80);
WebSocketsServer webSocket(81);

// ================= ULTRASONIC PINS =================
#define TRIGPIN 3
#define ECHOPIN 4

// ================= DISTANCE SETTINGS =================
const float MIN_VALID_CM = 25.0f;
const float MAX_VALID_CM = 250.0f;

const float OBJECT_ZONE_CM   = 180.0f;
const float WARNING_ZONE_CM  = 80.0f;

// New smarter thresholds
const float VERY_CLOSE_ZONE_CM      = 35.0f;   // close zone, not always warning
const float BLIND_ENTRY_TRIGGER_CM  = 30.0f;   // above blind zone, used to infer blind-zone entry
const float CLEAR_DISTANCE_CM       = 205.0f;  // stronger evidence before returning clear

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

// ================= OUTPUT STATE =================
enum FCWState {
  CLEAR = 0,
  OBJECT_AHEAD = 1,
  APPROACHING = 2,
  WARNING = 3
};

FCWState currentState = CLEAR;

// ================= TIMING / EXTRA TEST DATA =================
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

const char* stateColorHex(FCWState s) {
  switch (s) {
    case CLEAR: return "#1db954";
    case OBJECT_AHEAD: return "#f5c542";
    case APPROACHING: return "#ff8c42";
    case WARNING: return "#ff3b30";
    default: return "#1db954";
  }
}

String payloadToString(uint8_t* payload, size_t length) {
  String s;
  s.reserve(length);
  for (size_t i = 0; i < length; i++) s += (char)payload[i];
  return s;
}

float clampf(float x, float lo, float hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
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

    long duration = pulseIn(ECHOPIN, HIGH, 40000);

    if (duration > 0) {
      readings[validCount] = duration / 58.2f;
      validCount++;
    }

    delay(15);
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

  float rawSpeed = (lastValidDistance - dist) / dt; // positive = approaching
  closingSpeedCmS = 0.65f * closingSpeedCmS + 0.35f * rawSpeed;

  lastValidDistance = dist;
  lastValidDistanceMs = nowMs;
}

// ================= SMART FCW LOGIC =================
void updateFCWState(float dist, unsigned long nowMs) {
  if (dist >= 0) {
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

    // Arm blind-zone hold only when target is very close AND still approaching
    if (dist <= BLIND_ENTRY_TRIGGER_CM && closingSpeedCmS > 0.5f) {
      blindHoldUntilMs = nowMs + BLIND_HOLD_MS;
    }

    // Priority 1: inside normal warning zone and closing fast
    if (dist <= WARNING_ZONE_CM && confirmedWarningSpeed) {
      currentState = WARNING;
      if (dist <= BLIND_ENTRY_TRIGGER_CM) {
        blindHoldUntilMs = nowMs + BLIND_HOLD_MS;
      }
      return;
    }

    // Priority 2: soft close zone
    // - warning only if still closing meaningfully
    // - otherwise just object ahead / approaching
    if (dist <= VERY_CLOSE_ZONE_CM) {
      if (confirmedWarningSpeed || closingSpeedCmS >= (WARNING_SPEED_CM_S * 0.7f)) {
        currentState = WARNING;
        if (dist <= BLIND_ENTRY_TRIGGER_CM) {
          blindHoldUntilMs = nowMs + BLIND_HOLD_MS;
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

    // Priority 3: object ahead and approaching
    if (dist <= OBJECT_ZONE_CM && confirmedApproaching) {
      currentState = APPROACHING;
      return;
    }

    // Priority 4: object ahead but not aggressively approaching
    if (dist <= OBJECT_ZONE_CM) {
      currentState = OBJECT_AHEAD;
      return;
    }

    // Returning to clear should require convincing distance
    if (dist >= CLEAR_DISTANCE_CM) {
      currentState = CLEAR;
    } else {
      currentState = OBJECT_AHEAD;
    }

    return;
  }

  // Invalid reading path:
  // 1) if we recently had a close approaching object, assume blind-zone entry
  if (nowMs < blindHoldUntilMs) {
    currentState = WARNING;
    return;
  }

  // 2) don't instantly clear after a recent valid target
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

  // 3) finally clear when invalid for long enough
  currentState = CLEAR;
  approachCounter = 0;
  warningCounter = 0;
  prevFilteredDistance = -1.0f;
}

// ================= WEB COMMANDS =================
void handleCommand(const String& msg) {
  if (msg == "PING") return;
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
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>FCW Test Monitor</title>
<style>
  :root{
    --bg:#0f1115;
    --card:#171a21;
    --text:#f2f4f8;
    --muted:#b6bcc8;
    --border:#262b35;
    --state:#1db954;
  }
  *{box-sizing:border-box}
  body{
    margin:0;
    background:var(--bg);
    color:var(--text);
    font-family:Arial,Helvetica,sans-serif;
    padding:14px;
  }
  .wrap{
    max-width:720px;
    margin:0 auto;
  }
  .title{
    font-size:18px;
    font-weight:700;
    margin-bottom:10px;
  }
  .stateBox{
    width:100%;
    aspect-ratio:1/1;
    max-height:62vh;
    border-radius:22px;
    background:var(--state);
    display:flex;
    align-items:center;
    justify-content:center;
    text-align:center;
    padding:18px;
    transition: background-color 120ms linear, box-shadow 120ms linear;
    box-shadow:0 0 28px rgba(0,0,0,0.22);
  }
  .stateText{
    font-size:clamp(28px, 7vw, 58px);
    font-weight:800;
    letter-spacing:0.5px;
    line-height:1.05;
    color:white;
    word-break:break-word;
  }
  .grid{
    display:grid;
    grid-template-columns:1fr 1fr;
    gap:10px;
    margin-top:12px;
  }
  .card{
    background:var(--card);
    border:1px solid var(--border);
    border-radius:16px;
    padding:12px;
  }
  .label{
    color:var(--muted);
    font-size:12px;
    margin-bottom:6px;
  }
  .value{
    font-size:24px;
    font-weight:700;
  }
  .value.small{
    font-size:18px;
  }
  .full{
    grid-column:1 / -1;
  }
  .barWrap{
    width:100%;
    height:10px;
    background:#262b35;
    border-radius:999px;
    overflow:hidden;
    margin-top:8px;
  }
  .bar{
    height:100%;
    width:0%;
    background:#8ab4ff;
    transition: width 80ms linear;
  }
  .footerNote{
    margin-top:10px;
    color:var(--muted);
    font-size:12px;
    text-align:center;
  }
</style>
</head>
<body>
<div class="wrap">
  <div class="title">Forward Collision Warning Test</div>

  <div id="stateBox" class="stateBox">
    <div id="stateText" class="stateText">CLEAR</div>
  </div>

  <div class="grid">
    <div class="card">
      <div class="label">Filtered Distance</div>
      <div id="filteredDistance" class="value">--</div>
    </div>

    <div class="card">
      <div class="label">Raw Distance</div>
      <div id="rawDistance" class="value">--</div>
    </div>

    <div class="card">
      <div class="label">Closing Speed</div>
      <div id="closingSpeed" class="value">0.0 cm/s</div>
    </div>

    <div class="card">
      <div class="label">Trusted Range</div>
      <div id="trustedRange" class="value small">25 - 250 cm</div>
    </div>

    <div class="card full">
      <div class="label">Distance in Warning Window</div>
      <div id="distancePercentText" class="value small">0%</div>
      <div class="barWrap"><div id="distanceBar" class="bar"></div></div>
    </div>

    <div class="card full">
      <div class="label">Diagnostics</div>
      <div id="diag" class="value small">Waiting for data...</div>
    </div>
  </div>

  <div class="footerNote">Connect phone to FCWMonitor Wi-Fi and open 192.168.4.1</div>
</div>

<script>
const ws = new WebSocket("ws://" + location.hostname + ":81");

const stateBox = document.getElementById("stateBox");
const stateText = document.getElementById("stateText");
const rawDistance = document.getElementById("rawDistance");
const filteredDistance = document.getElementById("filteredDistance");
const closingSpeed = document.getElementById("closingSpeed");
const trustedRange = document.getElementById("trustedRange");
const distanceBar = document.getElementById("distanceBar");
const distancePercentText = document.getElementById("distancePercentText");
const diag = document.getElementById("diag");

function fmtCm(v){
  if (v < 0) return "Invalid";
  return v.toFixed(1) + " cm";
}

function clamp(x, lo, hi){
  return Math.max(lo, Math.min(hi, x));
}

ws.onmessage = (evt) => {
  const d = JSON.parse(evt.data);

  stateText.textContent = d.stateName;
  stateBox.style.backgroundColor = d.stateColor;

  rawDistance.textContent = fmtCm(d.rawDistance);
  filteredDistance.textContent = fmtCm(d.filteredDistance);

  const sp = d.closingSpeedCmS;
  closingSpeed.textContent = (sp >= 0 ? "+" : "") + sp.toFixed(1) + " cm/s";

  trustedRange.textContent = d.minValidCm.toFixed(0) + " - " + d.maxValidCm.toFixed(0) + " cm";

  let pct = 0;
  if (d.filteredDistance > 0) {
    const span = d.maxValidCm - d.minValidCm;
    pct = ((d.maxValidCm - d.filteredDistance) / span) * 100.0;
    pct = clamp(pct, 0, 100);
  }
  distanceBar.style.width = pct.toFixed(1) + "%";
  distancePercentText.textContent = pct.toFixed(0) + "%";

  diag.textContent =
    "approachCounter: " + d.approachCounter +
    " | warningCounter: " + d.warningCounter +
    " | blindHoldMs: " + d.blindHoldRemainingMs +
    " | loop: " + d.loopMs.toFixed(0) + " ms";
};
</script>
</body>
</html>
)rawliteral";

// ================= SETUP =================
void setup() {
  Serial.begin(9600);

  pinMode(TRIGPIN, OUTPUT);
  pinMode(ECHOPIN, INPUT);

  digitalWrite(TRIGPIN, LOW);
  delay(1000);

  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password);
  WiFi.setSleep(false);

  server.on("/", []() {
    server.send_P(200, "text/html", webpage);
  });
  server.begin();

  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);

  lastLoopMs = millis();

  Serial.println("JSN-SR04T FCW Prototype Started");
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());
}

// ================= LOOP =================
void loop() {
  server.handleClient();
  webSocket.loop();

  unsigned long nowMs = millis();
  float loopMs = (float)(nowMs - lastLoopMs);
  lastLoopMs = nowMs;

  float rawDistance = readQualityDistanceCm();
  float smoothedDistance = updateFilteredDistance(rawDistance);

  updateClosingSpeed(smoothedDistance, nowMs);
  updateFCWState(smoothedDistance, nowMs);

  Serial.print("Raw: ");
  if (rawDistance < 0) Serial.print("Invalid");
  else Serial.print(rawDistance, 1);

  Serial.print(" cm | Filtered: ");
  if (smoothedDistance < 0) Serial.print("Invalid");
  else Serial.print(smoothedDistance, 1);

  Serial.print(" cm | Speed: ");
  Serial.print(closingSpeedCmS, 1);
  Serial.print(" cm/s | State: ");
  Serial.println(stateName(currentState));

  unsigned long blindRemain = 0;
  if (blindHoldUntilMs > nowMs) blindRemain = blindHoldUntilMs - nowMs;

  String data;
  data.reserve(420);
  data += "{";
  data += "\"rawDistance\":" + String(rawDistance, 1) + ",";
  data += "\"filteredDistance\":" + String(smoothedDistance, 1) + ",";
  data += "\"closingSpeedCmS\":" + String(closingSpeedCmS, 1) + ",";
  data += "\"state\":" + String((int)currentState) + ",";
  data += "\"stateName\":\"" + String(stateName(currentState)) + "\",";
  data += "\"stateColor\":\"" + String(stateColorHex(currentState)) + "\",";
  data += "\"minValidCm\":" + String(MIN_VALID_CM, 1) + ",";
  data += "\"maxValidCm\":" + String(MAX_VALID_CM, 1) + ",";
  data += "\"objectZoneCm\":" + String(OBJECT_ZONE_CM, 1) + ",";
  data += "\"warningZoneCm\":" + String(WARNING_ZONE_CM, 1) + ",";
  data += "\"veryCloseZoneCm\":" + String(VERY_CLOSE_ZONE_CM, 1) + ",";
  data += "\"blindEntryTriggerCm\":" + String(BLIND_ENTRY_TRIGGER_CM, 1) + ",";
  data += "\"approachCounter\":" + String(approachCounter) + ",";
  data += "\"warningCounter\":" + String(warningCounter) + ",";
  data += "\"blindHoldRemainingMs\":" + String(blindRemain) + ",";
  data += "\"loopMs\":" + String(loopMs, 0);
  data += "}";

  webSocket.broadcastTXT(data);

  delay(40);
}