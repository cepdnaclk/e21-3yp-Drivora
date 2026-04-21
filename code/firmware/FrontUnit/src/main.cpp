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

// Close / blind-zone related thresholds
const float VERY_CLOSE_ZONE_CM      = 35.0f;
const float BLIND_ENTRY_TRIGGER_CM  = 30.0f;
const float CLEAR_DISTANCE_CM       = 205.0f;

// Suspicious reading logic
const float SUSPICIOUS_JUMP_CM      = 18.0f;
const float BLIND_RELEASE_MIN_CM    = 34.0f;
const int   BLIND_RELEASE_COUNT_REQ = 2;

// Moving-away based blind release
const float BLIND_RELEASE_MOVING_AWAY_CM_S = -6.0f;
const float BLIND_RELEASE_MOVING_AWAY_MIN_CM = 28.0f;

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
    bool erraticNearBlind = (rawDist <= BLIND_RELEASE_MIN_CM);
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
  .audioRow{
    margin-bottom:10px;
    display:flex;
    gap:8px;
    flex-wrap:wrap;
  }
  .audioBtn{
    padding:12px 16px;
    border:0;
    border-radius:12px;
    background:#2b2f38;
    color:white;
    font-size:15px;
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

  <div class="audioRow">
    <button id="audioBtn" class="audioBtn" onclick="enableAudio()">Enable Beep Sound</button>
  </div>

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

let audioCtx = null;
let audioEnabled = false;
let lastBeepMs = 0;

async function enableAudio() {
  if (!audioCtx) {
    audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  }

  try {
    if (audioCtx.state === "suspended") {
      await audioCtx.resume();
    }

    audioEnabled = true;
    document.getElementById("audioBtn").innerText = "Beep Sound Enabled";
    playBeep(1050, 100, 0.10);
  } catch (e) {
    document.getElementById("audioBtn").innerText = "Tap Again to Enable Sound";
  }
}

function playBeep(freq = 900, durationMs = 80, volume = 0.09) {
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

document.addEventListener("touchstart", () => {
  if (!audioEnabled) enableAudio();
}, { passive: true, once: false });

document.addEventListener("click", () => {
  if (!audioEnabled) enableAudio();
}, { once: false });

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
    " | blindLatched: " + (d.blindZoneLatched ? "YES" : "NO") +
    " | suspicious: " + (d.suspiciousReading ? "YES" : "NO") +
    " | fastBlind: " + (d.fastBlindTriggered ? "YES" : "NO") +
    " | invalidStreak: " + d.invalidStreak +
    " | loop: " + d.loopMs.toFixed(0) + " ms";

  const now = Date.now();
  if (audioEnabled) {
    if (d.state === 2) {
      if (now - lastBeepMs > 700) {
        playBeep(850, 70, 0.09);
        lastBeepMs = now;
      }
    } else if (d.state === 3) {
      if (now - lastBeepMs > 250) {
        playBeep(1250, 90, 0.11);
        lastBeepMs = now;
      }
    }
  }
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
  lastValidDistanceMs = millis();

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
  Serial.println(stateName(currentState));

  String data;
  data.reserve(540);
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
  data += "\"blindZoneLatched\":" + String(blindZoneLatched ? 1 : 0) + ",";
  data += "\"suspiciousReading\":" + String(suspicious ? 1 : 0) + ",";
  data += "\"fastBlindTriggered\":" + String(fastBlind ? 1 : 0) + ",";
  data += "\"invalidStreak\":" + String(invalidStreak) + ",";
  data += "\"loopMs\":" + String(loopMs, 0);
  data += "}";

  webSocket.broadcastTXT(data);

  delay(20);
}