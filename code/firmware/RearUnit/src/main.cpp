#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <WebSocketsServer.h>

// ================= WIFI / WEB =================
const char* ssid = "BlindspotMonitor";
const char* password = "12345678";

WebServer server(80);
WebSocketsServer webSocket(81);

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

const char* stateColorHex(RearState s) {
  switch (s) {
    case CLEAR: return "#1db954";
    case OBJECT_DETECTED: return "#f5c542";
    case CAUTION: return "#ff8c42";
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

  // Invalid reading path:
  // If already latched, keep warning through blind-zone instability.
  if (warningLatched) {
    warningReleaseCounter = 0;
    fastWarningReleaseCounter = 0;
    currentState = WARNING;
    return;
  }

  // If we very recently had a close valid reading, treat sudden invalid as warning entry.
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
<title>Blindspot Monitor</title>
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
  <div class="title">Blindspot / Rear Monitor</div>

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
      <div class="label">Min Valid Range</div>
      <div id="minValid" class="value small">23 cm</div>
    </div>

    <div class="card">
      <div class="label">Max Valid Range</div>
      <div id="maxValid" class="value small">250 cm</div>
    </div>

    <div class="card full">
      <div class="label">Distance in Alert Zone</div>
      <div id="distancePercentText" class="value small">0%</div>
      <div class="barWrap"><div id="distanceBar" class="bar"></div></div>
    </div>

    <div class="card full">
      <div class="label">Diagnostics</div>
      <div id="diag" class="value small">Waiting for data...</div>
    </div>
  </div>

  <div class="footerNote">Connect to BlindspotMonitor Wi-Fi and open 192.168.4.1</div>
</div>

<script>
const ws = new WebSocket("ws://" + location.hostname + ":81");

const stateBox = document.getElementById("stateBox");
const stateText = document.getElementById("stateText");
const rawDistance = document.getElementById("rawDistance");
const filteredDistance = document.getElementById("filteredDistance");
const minValid = document.getElementById("minValid");
const maxValid = document.getElementById("maxValid");
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
    playBeep(1000, 90, 0.10);
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

  minValid.textContent = d.minValidCm.toFixed(0) + " cm";
  maxValid.textContent = d.maxValidCm.toFixed(0) + " cm";

  let pct = 0;
  if (d.filteredDistance > 0) {
    const span = d.maxValidCm - d.minValidCm;
    pct = ((d.maxValidCm - d.filteredDistance) / span) * 100.0;
    pct = clamp(pct, 0, 100);
  }
  distanceBar.style.width = pct.toFixed(1) + "%";
  distancePercentText.textContent = pct.toFixed(0) + "%";

  diag.textContent =
    "objectDetected: " + d.objectDetectedCm.toFixed(0) + " cm" +
    " | caution: " + d.cautionCm.toFixed(0) + " cm" +
    " | warning: " + d.warningCm.toFixed(0) + " cm" +
    " | warningLatched: " + (d.warningLatched ? "YES" : "NO") +
    " | releaseCounter: " + d.warningReleaseCounter +
    " | fastReleaseCounter: " + d.fastWarningReleaseCounter +
    " | fastWarning: " + (d.fastWarningTriggered ? "YES" : "NO") +
    " | suspiciousLatched: " + (d.suspiciousLatched ? "YES" : "NO") +
    " | invalidStreak: " + d.invalidStreak +
    " | loop: " + d.loopMs.toFixed(0) + " ms";

  const now = Date.now();
  if (audioEnabled) {
    if (d.state === 1) {
      if (now - lastBeepMs > 900) {
        playBeep(820, 70, 0.08);
        lastBeepMs = now;
      }
    } else if (d.state === 2) {
      if (now - lastBeepMs > 450) {
        playBeep(980, 80, 0.09);
        lastBeepMs = now;
      }
    } else if (d.state === 3) {
      if (now - lastBeepMs > 180) {
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
  Serial.begin(115200);

  pinMode(TRIGPIN, OUTPUT);
  pinMode(ECHOPIN, INPUT);

  digitalWrite(TRIGPIN, LOW);
  delay(1000);

  WiFi.mode(WIFI_AP);
  WiFi.softAP(ssid, password);
  WiFi.setSleep(false);

  Serial.println("Blindspot / Rear Prototype Started");
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  server.on("/", []() {
    server.send_P(200, "text/html", webpage);
  });
  server.begin();

  webSocket.begin();
  webSocket.onEvent(onWebSocketEvent);

  lastLoopMs = millis();
  lastValidSeenMs = millis();
  lastValidDistanceMs = millis();
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
  Serial.println(stateName(currentState));

  String data;
  data.reserve(600);
  data += "{";
  data += "\"rawDistance\":" + String(rawDistance, 1) + ",";
  data += "\"filteredDistance\":" + String(smoothedDistance, 1) + ",";
  data += "\"state\":" + String((int)currentState) + ",";
  data += "\"stateName\":\"" + String(stateName(currentState)) + "\",";
  data += "\"stateColor\":\"" + String(stateColorHex(currentState)) + "\",";
  data += "\"minValidCm\":" + String(MIN_VALID_CM, 1) + ",";
  data += "\"maxValidCm\":" + String(MAX_VALID_CM, 1) + ",";
  data += "\"objectDetectedCm\":" + String(OBJECT_DETECTED_CM, 1) + ",";
  data += "\"cautionCm\":" + String(CAUTION_CM, 1) + ",";
  data += "\"warningCm\":" + String(WARNING_CM, 1) + ",";
  data += "\"warningLatched\":" + String(warningLatched ? 1 : 0) + ",";
  data += "\"warningReleaseCounter\":" + String(warningReleaseCounter) + ",";
  data += "\"fastWarningReleaseCounter\":" + String(fastWarningReleaseCounter) + ",";
  data += "\"fastWarningTriggered\":" + String(fastWarning ? 1 : 0) + ",";
  data += "\"suspiciousLatched\":" + String(suspiciousLatched ? 1 : 0) + ",";
  data += "\"invalidStreak\":" + String(invalidStreak) + ",";
  data += "\"loopMs\":" + String(loopMs, 0);
  data += "}";

  webSocket.broadcastTXT(data);

  delay(20);
}