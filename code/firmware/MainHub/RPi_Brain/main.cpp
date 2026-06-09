#include <pigpio.h>
#include "crow.h"
#include <nlohmann/json.hpp>
#include <iostream>
#include <fstream>
#include <sstream>
#include <thread>
#include <mutex>
#include <chrono>
#include <unordered_set>
#include <cmath>

// Linux networking and SocketCAN headers
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <linux/can.h>
#include <linux/can/raw.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <unistd.h>

using json = nlohmann::json;

// ================= GLOBAL STATE =================
std::mutex stateMutex;
std::unordered_set<crow::websocket::connection *> users;

// ================= TIMING CONSTANTS =================
const unsigned long UI_BROADCAST_MS     = 50;
const unsigned long CONFIG_BROADCAST_MS = 1000;
const unsigned long STALE_MS            = 300;
const unsigned long OFFLINE_MS          = 1000;

unsigned long lastBroadcastMs = 0;
unsigned long lastConfigBroadcastMs = 0;
bool forceConfigBroadcast = true;
bool centerCalibrationRequested = false;

// ================= CAN TRANSMISSION STATE =================
int canSocketFd = -1;
std::mutex canWriteMutex;

void sendCanFrame(uint32_t id, uint8_t len, const uint8_t* data) {
    if (canSocketFd < 0) return;

    struct can_frame frame;
    frame.can_id = id;
    frame.can_dlc = len;
    std::memcpy(frame.data, data, len);

    std::lock_guard<std::mutex> lock(canWriteMutex);
    if (write(canSocketFd, &frame, sizeof(struct can_frame)) < 0) {
        std::cerr << "ERROR: Failed to write frame 0x" << std::hex << id << " to CAN bus.\n";
    }
}

void sendLeanConfig() {
    uint8_t data[8] = {0};
    // Match the exact byte-packing mapping your ESP32 used:
    data[0] = brainConfig.vehicleType;
    
    // Copy track width (float -> 4 bytes)
    std::memcpy(&data[1], &brainConfig.trackWidth_m, sizeof(float));
    
    // Copy load condition
    data[5] = brainConfig.loadCondition;
    
    sendCanFrame(0x110, 6, data);
}

void sendFrontConfig() {
    uint8_t data[8] = {0};
    data[0] = brainConfig.frontSensitivityPreset;
    
    // Copy wheelbase (float -> 4 bytes)
    std::memcpy(&data[1], &brainConfig.wheelBase_m, sizeof(float));
    
    sendCanFrame(0x210, 5, data);
}

void sendRearConfig() {
    uint8_t data[8] = {0};
    data[0] = brainConfig.rearSensitivityPreset;
    
    // Copy vehicle height if required by your nodes
    std::memcpy(&data[1], &brainConfig.vehicleHeight_m, sizeof(float));
    
    sendCanFrame(0x310, 5, data);
}

void sendAllConfigs() {
    sendLeanConfig();
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    sendFrontConfig();
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    sendRearConfig();
}

// ================= CONFIG & DATA STRUCTS =================
const uint8_t BUZZER_PATTERN_URGENT_TRIPLE = 0;
const uint8_t BUZZER_PATTERN_WIDE_DOUBLE   = 1;
const uint8_t BUZZER_PATTERN_QUICK_DOUBLE  = 2;
const uint8_t BUZZER_PATTERN_TWO_TONE      = 3;

struct BrainConfig {
    bool setupCompleted = false;
    std::string profileName = "My Vehicle";
    uint8_t vehicleType = 3;
    float trackWidth_m = 1.56f;
    float wheelBase_m = 2.67f;
    float vehicleHeight_m = 1.57f;
    uint8_t loadCondition = 1;
    uint8_t frontSensitivityPreset = 1;
    uint8_t rearSensitivityPreset  = 1;
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

struct LaneData {
    bool online = false;
    uint8_t state = 0;
    unsigned long lastUpdateMs = 0;
};
LaneData laneData;

struct LeanData {
    bool online = false;
    bool calibrated = false;
    uint8_t riskLevel = 0;
    float rollDeg = 0.0f;
    float pitchDeg = 0.0f;
    float confidence = 1.0f;
    float criticalRollDeg = 30.0f;
    float criticalPitchDeg = 20.0f;
    unsigned long lastUpdateMs = 0;
    uint8_t vehicleType = 0;
    uint8_t loadCondition = 0;
};
LeanData leanData;

struct FrontData {
    bool online = false;
    uint8_t state = 0;
    float filteredDistanceCm = -1.0f;
    float rawDistanceCm = -1.0f;
    float closingSpeedCmS = 0.0f;
    unsigned long lastUpdateMs = 0;
    uint8_t debugFlags = 0;
    uint8_t approachCounter = 0;
    uint8_t warningCounter = 0;
    uint8_t blindReleaseCounter = 0;
    uint8_t invalidStreak = 0;
    bool visionValidated = false;
};
FrontData frontData;

struct RearData {
    bool online = false;
    uint8_t leftState = 0;
    uint8_t centerState = 0;
    uint8_t rightState = 0;
    uint8_t overallState = 0;
    float leftFilteredDistanceCm = -1.0f;
    float centerFilteredDistanceCm = -1.0f;
    float rightFilteredDistanceCm = -1.0f;
    uint8_t nearestSensor = 0;
    uint8_t leftWarningReleaseCounter = 0;
    uint8_t centerWarningReleaseCounter = 0;
    uint8_t rightWarningReleaseCounter = 0;
    uint8_t leftFastWarningReleaseCounter = 0;
    uint8_t centerFastWarningReleaseCounter = 0;
    uint8_t rightFastWarningReleaseCounter = 0;
    uint8_t maxInvalidStreak = 0;
    unsigned long lastUpdateMs = 0;
};
RearData rearData;

// ================= BUZZER STATE =================
const int BUZZER_PIN = 18; 
bool buzzerEnabled = true;
bool setupWizardBuzzerMuted = false;
int currentBuzzerFreq = -1;
int currentBuzzerDuty = -1;

std::string activeBuzzerType = "NONE";
uint8_t activeBuzzerSeverity = 0;
unsigned long buzzerPatternStartMs = 0;
unsigned long buzzerSwitchMuteUntilMs = 0;
unsigned long buzzerClearCandidateMs = 0;

const unsigned long BUZZER_MIN_TYPE_HOLD_MS = 650;
const unsigned long BUZZER_SWITCH_GAP_MS = 35;
const unsigned long BUZZER_CLEAR_GRACE_MS = 260;

std::string currentFusedType = "NONE";
uint8_t currentFusedSeverity = 0;

// ================= INCIDENT / STATISTICS =================
const uint8_t INCIDENT_BUFFER_SIZE = 10;
const unsigned long INCIDENT_RESEND_MS = 700;

struct IncidentRecord {
    bool used = false;
    bool pendingAck = false;
    uint32_t id = 0;
    unsigned long timestampMs = 0;
    uint8_t severity = 0;
    std::string eventType = "";
    std::string sourceUnit = "";
    std::string title = "";
    std::string message = "";
    float frontDistanceCm = -1.0f;
    float frontSpeedCmS = 0.0f;
    float rearNearestDistanceCm = -1.0f;
    float leanRollDeg = 0.0f;
    float leanPitchDeg = 0.0f;
    uint8_t laneState = 0;
};

IncidentRecord incidentBuffer[INCIDENT_BUFFER_SIZE];
uint32_t nextIncidentId = 1;
uint32_t lostIncidentCount = 0;
unsigned long lastIncidentResendMs = 0;

unsigned long frontCriticalStartMs = 0;
unsigned long rearCriticalStartMs = 0;
unsigned long leanCriticalStartMs = 0;
unsigned long laneCriticalStartMs = 0;
unsigned long multiHazardStartMs = 0;

bool frontCriticalLogged = false;
bool rearCriticalLogged = false;
bool leanCriticalLogged = false;
bool laneCriticalLogged = false;
bool multiHazardLogged = false;

unsigned long lastFrontIncidentMs = 0;
unsigned long lastRearIncidentMs = 0;
unsigned long lastLeanIncidentMs = 0;
unsigned long lastLaneIncidentMs = 0;
unsigned long lastMultiIncidentMs = 0;

const unsigned long FRONT_CRITICAL_CONFIRM_MS = 700;
const unsigned long REAR_CRITICAL_CONFIRM_MS = 700;
const unsigned long LEAN_CRITICAL_CONFIRM_MS = 500;
const unsigned long LANE_CRITICAL_CONFIRM_MS = 500;
const unsigned long MULTI_HAZARD_CONFIRM_MS = 500;
const unsigned long INCIDENT_COOLDOWN_MS = 5000;

// ================= UTILITIES =================
unsigned long getMillis() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}

bool isStale(unsigned long lastMs, unsigned long nowMs) { return (nowMs - lastMs) > STALE_MS; }
bool isOffline(unsigned long lastMs, unsigned long nowMs) { return (nowMs - lastMs) > OFFLINE_MS; }

float nearestRearDistanceForIncident() {
    float best = -1.0f;
    if (rearData.leftFilteredDistanceCm >= 0.0f) best = rearData.leftFilteredDistanceCm;
    if (rearData.centerFilteredDistanceCm >= 0.0f && (best < 0.0f || rearData.centerFilteredDistanceCm < best)) best = rearData.centerFilteredDistanceCm;
    if (rearData.rightFilteredDistanceCm >= 0.0f && (best < 0.0f || rearData.rightFilteredDistanceCm < best)) best = rearData.rightFilteredDistanceCm;
    return best;
}

// Convert numbers mapping to string UI elements
std::string leanRiskName(uint8_t level) { return level == 2 ? "HIGH" : (level == 1 ? "CAUTION" : "SAFE"); }
std::string frontStateName(uint8_t state) { return state == 3 ? "WARNING" : (state == 2 ? "APPROACHING" : (state == 1 ? "OBJECT_AHEAD" : "CLEAR")); }
std::string rearStateName(uint8_t state) { return state == 3 ? "WARNING" : (state == 2 ? "CAUTION" : (state == 1 ? "OBJECT_DETECTED" : "CLEAR")); }
std::string laneStateName(uint8_t state) { return state == 2 ? "RIGHT_DEPARTURE" : (state == 1 ? "LEFT_DEPARTURE" : "SAFE"); }
std::string stateColorByLevel(uint8_t level) { return level == 3 ? "#ff3b30" : (level == 2 ? "#ff7230" : (level == 1 ? "#ffb020" : "#1db954")); }
std::string laneStateColor(uint8_t state) { return state != 0 ? "#ffb020" : "#1db954"; }
std::string vehicleTypeName(uint8_t v) { return v == 1 ? "Compact" : (v == 2 ? "Passenger" : "Tall / SUV"); }
std::string loadConditionName(uint8_t v) { return v == 0 ? "Light" : (v == 2 ? "Heavy" : "Normal"); }
std::string presetName(uint8_t v) { return v == 0 ? "Near" : (v == 2 ? "Far" : "Normal"); }

// ================= BUZZER ENGINE (PIGPIO) =================
void buzzerBegin() {
    if (gpioInitialise() < 0) {
        std::cerr << "CRITICAL: pigpio initialization failed. Run with sudo.\n";
        return;
    }
    gpioSetMode(BUZZER_PIN, PI_OUTPUT);
    gpioPWM(BUZZER_PIN, 0);
}

void buzzerOff() {
    if (currentBuzzerFreq != 0 || currentBuzzerDuty != 0) {
        gpioPWM(BUZZER_PIN, 0);
        currentBuzzerFreq = 0;
        currentBuzzerDuty = 0;
    }
}

uint32_t buzzerDutyFromVolume(uint8_t volumePercent) {
    if (volumePercent < 30) volumePercent = 30;
    if (volumePercent > 100) volumePercent = 100;
    return (volumePercent / 100.0f) * 128; // 128 is 50% square wave (max resonance)
}

void buzzerTone(int freq, uint8_t volumePercent) {
    if (!buzzerEnabled || setupWizardBuzzerMuted || freq <= 0) {
        buzzerOff();
        return;
    }
    uint32_t duty = buzzerDutyFromVolume(volumePercent);
    if (currentBuzzerFreq != freq || currentBuzzerDuty != duty) {
        gpioSetPWMfrequency(BUZZER_PIN, freq);
        gpioPWM(BUZZER_PIN, duty);
        currentBuzzerFreq = freq;
        currentBuzzerDuty = duty;
    }
}

uint8_t getBuzzerVolumeForType(const std::string& buzzerType) {
    if (buzzerType == "FRONT_ALERT") return brainConfig.frontBuzzerVolume;
    if (buzzerType == "REAR_ALERT") return brainConfig.rearBuzzerVolume;
    if (buzzerType == "LANE_WARNING") return brainConfig.laneBuzzerVolume;
    if (buzzerType == "LEAN_HIGH" || buzzerType == "LEAN_CAUTION") return brainConfig.leanBuzzerVolume;
    return 100;
}

uint8_t getBuzzerPatternForType(const std::string& buzzerType) {
    if (buzzerType == "FRONT_ALERT") return brainConfig.frontBuzzerPattern;
    if (buzzerType == "REAR_ALERT") return brainConfig.rearBuzzerPattern;
    if (buzzerType == "LANE_WARNING") return brainConfig.laneBuzzerPattern;
    if (buzzerType == "LEAN_HIGH" || buzzerType == "LEAN_CAUTION") return brainConfig.leanBuzzerPattern;
    return BUZZER_PATTERN_URGENT_TRIPLE;
}

void playAssignedBuzzerPattern(uint8_t pattern, uint8_t severity, unsigned long t, uint8_t volume) {
    if (pattern == BUZZER_PATTERN_URGENT_TRIPLE) {
        unsigned long p;
        if (severity >= 3) {
            p = t % 420;
            if (p < 75 || (p >= 135 && p < 210) || (p >= 270 && p < 345)) buzzerTone(2200, volume); else buzzerOff();
        } else if (severity == 2) {
            p = t % 620;
            if (p < 95 || (p >= 210 && p < 305)) buzzerTone(2200, volume); else buzzerOff();
        } else {
            p = t % 850;
            if (p < 120) buzzerTone(2200, volume); else buzzerOff();
        }
        return;
    }
    if (pattern == BUZZER_PATTERN_WIDE_DOUBLE) {
        unsigned long p;
        if (severity >= 3) {
            p = t % 640;
            if (p < 130 || (p >= 280 && p < 410)) buzzerTone(2150, volume); else buzzerOff();
        } else if (severity == 2) {
            p = t % 780;
            if (p < 140) buzzerTone(2150, volume); else buzzerOff();
        } else {
            p = t % 980;
            if (p < 110) buzzerTone(2150, volume); else buzzerOff();
        }
        return;
    }
    if (pattern == BUZZER_PATTERN_QUICK_DOUBLE) {
        unsigned long p = severity >= 3 ? (t % 620) : (t % 820);
        if (p < 70 || (p >= 145 && p < 215)) buzzerTone(2250, volume); else buzzerOff();
        return;
    }
    if (pattern == BUZZER_PATTERN_TWO_TONE) {
        unsigned long p = severity >= 3 ? (t % 600) : (t % 860);
        if (severity >= 3) {
            if (p < 180) buzzerTone(2200, volume);
            else if (p >= 300 && p < 480) buzzerTone(2350, volume);
            else buzzerOff();
        } else {
            if (p < 130) buzzerTone(2300, volume); else buzzerOff();
        }
        return;
    }
    buzzerOff();
}

std::string normalizeBuzzerType(const std::string& fusedType, uint8_t fusedSeverity) {
    if (fusedSeverity == 0 || fusedType == "NONE") return "NONE";
    if (fusedType == "FRONT_WARNING" || fusedType == "FRONT_APPROACHING" || fusedType == "FRONT_OBJECT") return "FRONT_ALERT";
    if (fusedType == "REAR_WARNING" || fusedType == "REAR_CAUTION" || fusedType == "REAR_OBJECT") return "REAR_ALERT";
    if (fusedType == "LANE_LEFT" || fusedType == "LANE_RIGHT") return "LANE_WARNING";
    if (fusedType == "LEAN_HIGH") return "LEAN_HIGH";
    if (fusedType == "LEAN_CAUTION") return "LEAN_CAUTION";
    return fusedSeverity >= 3 ? "GENERAL_WARNING" : "GENERAL_CAUTION";
}

void updateBuzzerByFusedType(const std::string& fusedType, uint8_t fusedSeverity, unsigned long nowMs) {
    std::string requestedType = normalizeBuzzerType(fusedType, fusedSeverity);

    if (!buzzerEnabled || setupWizardBuzzerMuted || requestedType == "NONE" || fusedSeverity == 0) {
        if (activeBuzzerType != "NONE" && buzzerClearCandidateMs == 0) buzzerClearCandidateMs = nowMs;
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
        activeBuzzerSeverity = fusedSeverity;
        buzzerPatternStartMs = nowMs;
        buzzerSwitchMuteUntilMs = nowMs + BUZZER_SWITCH_GAP_MS;
        buzzerOff();
        return;
    }

    bool holdCompleted = (nowMs - buzzerPatternStartMs) >= BUZZER_MIN_TYPE_HOLD_MS;
    bool requestedIsMoreUrgent = fusedSeverity > activeBuzzerSeverity;
    if ((holdCompleted || requestedIsMoreUrgent) && requestedType != activeBuzzerType) {
        activeBuzzerType = requestedType;
        activeBuzzerSeverity = fusedSeverity;
        buzzerPatternStartMs = nowMs;
        buzzerSwitchMuteUntilMs = nowMs + BUZZER_SWITCH_GAP_MS;
        buzzerOff();
    } else if (requestedType == activeBuzzerType) {
        activeBuzzerSeverity = fusedSeverity;
    }

    if (nowMs < buzzerSwitchMuteUntilMs) {
        buzzerOff();
        return;
    }

    unsigned long t = nowMs - buzzerPatternStartMs;
    uint8_t assignedPattern = getBuzzerPatternForType(activeBuzzerType);
    uint8_t vol = getBuzzerVolumeForType(activeBuzzerType);
    playAssignedBuzzerPattern(assignedPattern, activeBuzzerSeverity, t, vol);
}


// ================= INCIDENT ENGINE =================
int findIncidentSlot() {
    for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) if (!incidentBuffer[i].used) return i;
    for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) if (!incidentBuffer[i].pendingAck) return i;
    int oldest = 0;
    for (int i = 1; i < INCIDENT_BUFFER_SIZE; i++) if (incidentBuffer[i].timestampMs < incidentBuffer[oldest].timestampMs) oldest = i;
    lostIncidentCount++;
    return oldest;
}

void acknowledgeIncident(uint32_t id) {
    for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) {
        if (incidentBuffer[i].used && incidentBuffer[i].id == id) {
            incidentBuffer[i].used = false;
            incidentBuffer[i].pendingAck = false;
            return;
        }
    }
}

void storeIncident(std::string eventType, uint8_t severity, std::string sourceUnit, std::string title, std::string message, unsigned long nowMs) {
    int slot = findIncidentSlot();
    incidentBuffer[slot].used = true;
    incidentBuffer[slot].pendingAck = true;
    incidentBuffer[slot].id = nextIncidentId++;
    incidentBuffer[slot].timestampMs = nowMs;
    incidentBuffer[slot].severity = severity;
    incidentBuffer[slot].eventType = eventType;
    incidentBuffer[slot].sourceUnit = sourceUnit;
    incidentBuffer[slot].title = title;
    incidentBuffer[slot].message = message;
    incidentBuffer[slot].frontDistanceCm = frontData.filteredDistanceCm;
    incidentBuffer[slot].frontSpeedCmS = frontData.closingSpeedCmS;
    incidentBuffer[slot].rearNearestDistanceCm = nearestRearDistanceForIncident();
    incidentBuffer[slot].leanRollDeg = leanData.rollDeg;
    incidentBuffer[slot].leanPitchDeg = leanData.pitchDeg;
    incidentBuffer[slot].laneState = laneData.state;
}

void updateIncidentLatch(bool active, unsigned long confirmMs, unsigned long &startMs, bool &logged, unsigned long &lastIncidentMs, unsigned long nowMs, std::string eventType, uint8_t severity, std::string sourceUnit, std::string title, std::string message) {
    if (active) {
        if (startMs == 0) startMs = nowMs;
        if (!logged && (nowMs - startMs >= confirmMs) && (nowMs - lastIncidentMs >= INCIDENT_COOLDOWN_MS)) {
            storeIncident(eventType, severity, sourceUnit, title, message, nowMs);
            logged = true;
            lastIncidentMs = nowMs;
        }
    } else {
        startMs = 0;
        logged = false;
    }
}

void updateCriticalIncidentDetection(unsigned long nowMs) {
    bool leanOffline  = isOffline(leanData.lastUpdateMs, nowMs);
    bool frontOffline = isOffline(frontData.lastUpdateMs, nowMs);
    bool rearOffline  = isOffline(rearData.lastUpdateMs, nowMs);
    bool laneOffline  = isOffline(laneData.lastUpdateMs, nowMs);

    bool rearCritical = !rearOffline && rearData.overallState == 3;
    bool leanCritical = !leanOffline && leanData.riskLevel == 2;
    bool laneCritical = !laneOffline && laneData.state != 0;

    bool frontCritical = !frontOffline && frontData.state == 3 && frontData.visionValidated;

    updateIncidentLatch(frontCritical, FRONT_CRITICAL_CONFIRM_MS, frontCriticalStartMs, frontCriticalLogged, lastFrontIncidentMs, nowMs, "FRONT_CRITICAL", 3, "front", "Front Collision Risk", "A critical front collision warning was detected.");
    updateIncidentLatch(rearCritical, REAR_CRITICAL_CONFIRM_MS, rearCriticalStartMs, rearCriticalLogged, lastRearIncidentMs, nowMs, "REAR_CRITICAL", 3, "rear", "Rear Blindspot Risk", "A critical rear blindspot warning was detected.");
    updateIncidentLatch(leanCritical, LEAN_CRITICAL_CONFIRM_MS, leanCriticalStartMs, leanCriticalLogged, lastLeanIncidentMs, nowMs, "LEAN_CRITICAL", 3, "center", "High Lean Risk", "A critical vehicle lean condition was detected.");

    std::string laneStr = (laneData.state == 1) ? "LANE_LEFT_CRITICAL" : "LANE_RIGHT_CRITICAL";
    std::string laneTitle = (laneData.state == 1) ? "Left Lane Departure" : "Right Lane Departure";
    updateIncidentLatch(laneCritical, LANE_CRITICAL_CONFIRM_MS, laneCriticalStartMs, laneCriticalLogged, lastLaneIncidentMs, nowMs, laneStr, 2, "lane", laneTitle, "A lane departure warning was detected.");

    uint8_t seriousCount = (frontCritical?1:0) + (rearCritical?1:0) + (leanCritical?1:0) + (laneCritical?1:0);
    updateIncidentLatch(seriousCount >= 2, MULTI_HAZARD_CONFIRM_MS, multiHazardStartMs, multiHazardLogged, lastMultiIncidentMs, nowMs, "MULTI_HAZARD", 3, "multiple", "Multiple Safety Warnings", "Multiple critical safety warnings were active at the same time.");
}

json buildIncidentJson(const IncidentRecord &inc) {
    json j;
    j["type"] = "incident";
    j["incident"]["id"] = inc.id;
    j["incident"]["timestampMs"] = inc.timestampMs;
    j["incident"]["eventType"] = inc.eventType;
    j["incident"]["severity"] = inc.severity;
    j["incident"]["sourceUnit"] = inc.sourceUnit;
    j["incident"]["title"] = inc.title;
    j["incident"]["message"] = inc.message;
    j["incident"]["frontDistanceCm"] = inc.frontDistanceCm;
    j["incident"]["frontSpeedCmS"] = inc.frontSpeedCmS;
    j["incident"]["rearNearestDistanceCm"] = inc.rearNearestDistanceCm;
    j["incident"]["leanRollDeg"] = inc.leanRollDeg;
    j["incident"]["leanPitchDeg"] = inc.leanPitchDeg;
    j["incident"]["laneState"] = inc.laneState;
    j["incident"]["lostIncidentCount"] = lostIncidentCount;
    j["incident"]["pendingAck"] = 1;
    return j;
}

// ================= CONFIG STORAGE =================
void saveConfig() {
    // Note: The stateMutex should already be locked by the caller (like the WebSocket thread)
    json j;
    j["setupCompleted"] = brainConfig.setupCompleted;
    j["profileName"] = brainConfig.profileName;
    j["vehicleType"] = brainConfig.vehicleType;
    j["trackWidth_m"] = brainConfig.trackWidth_m;
    j["wheelBase_m"] = brainConfig.wheelBase_m;
    j["vehicleHeight_m"] = brainConfig.vehicleHeight_m;
    j["loadCondition"] = brainConfig.loadCondition;
    j["frontSensitivityPreset"] = brainConfig.frontSensitivityPreset;
    j["rearSensitivityPreset"] = brainConfig.rearSensitivityPreset;
    j["centerCalibrated"] = brainConfig.centerCalibrated;
    j["frontBuzzerPattern"] = brainConfig.frontBuzzerPattern;
    j["rearBuzzerPattern"] = brainConfig.rearBuzzerPattern;
    j["laneBuzzerPattern"] = brainConfig.laneBuzzerPattern;
    j["leanBuzzerPattern"] = brainConfig.leanBuzzerPattern;
    j["frontBuzzerVolume"] = brainConfig.frontBuzzerVolume;
    j["rearBuzzerVolume"] = brainConfig.rearBuzzerVolume;
    j["laneBuzzerVolume"] = brainConfig.laneBuzzerVolume;
    j["leanBuzzerVolume"] = brainConfig.leanBuzzerVolume;
    j["buzzerEnabled"] = buzzerEnabled;

    std::ofstream file("/home/pi/brain_config.json");
    if (file.is_open()) {
        file << j.dump(4); // Pretty print with 4 spaces
        file.close();
    } else {
        std::cerr << "ERROR: Failed to open brain_config.json for writing.\n";
    }
}

void loadConfig() {
    std::ifstream file("brain_config.json");
    if (!file.is_open()) {
        std::cout << "No existing config file found. Using default structure.\n";
        return;
    }
    
    try {
        json j;
        file >> j;
        if (j.contains("setupCompleted")) brainConfig.setupCompleted = j["setupCompleted"].get<bool>();
        if (j.contains("profileName")) brainConfig.profileName = j["profileName"].get<std::string>();
        if (j.contains("vehicleType")) brainConfig.vehicleType = j["vehicleType"].get<uint8_t>();
        if (j.contains("trackWidth_m")) brainConfig.trackWidth_m = j["trackWidth_m"].get<float>();
        if (j.contains("wheelBase_m")) brainConfig.wheelBase_m = j["wheelBase_m"].get<float>();
        if (j.contains("vehicleHeight_m")) brainConfig.vehicleHeight_m = j["vehicleHeight_m"].get<float>();
        if (j.contains("loadCondition")) brainConfig.loadCondition = j["loadCondition"].get<uint8_t>();
        if (j.contains("frontSensitivityPreset")) brainConfig.frontSensitivityPreset = j["frontSensitivityPreset"].get<uint8_t>();
        if (j.contains("rearSensitivityPreset")) brainConfig.rearSensitivityPreset = j["rearSensitivityPreset"].get<uint8_t>();
        if (j.contains("centerCalibrated")) brainConfig.centerCalibrated = j["centerCalibrated"].get<bool>();
        if (j.contains("frontBuzzerPattern")) brainConfig.frontBuzzerPattern = j["frontBuzzerPattern"].get<uint8_t>();
        if (j.contains("rearBuzzerPattern")) brainConfig.rearBuzzerPattern = j["rearBuzzerPattern"].get<uint8_t>();
        if (j.contains("laneBuzzerPattern")) brainConfig.laneBuzzerPattern = j["laneBuzzerPattern"].get<uint8_t>();
        if (j.contains("leanBuzzerPattern")) brainConfig.leanBuzzerPattern = j["leanBuzzerPattern"].get<uint8_t>();
        if (j.contains("frontBuzzerVolume")) brainConfig.frontBuzzerVolume = j["frontBuzzerVolume"].get<uint8_t>();
        if (j.contains("rearBuzzerVolume")) brainConfig.rearBuzzerVolume = j["rearBuzzerVolume"].get<uint8_t>();
        if (j.contains("laneBuzzerVolume")) brainConfig.laneBuzzerVolume = j["laneBuzzerVolume"].get<uint8_t>();
        if (j.contains("leanBuzzerVolume")) brainConfig.leanBuzzerVolume = j["leanBuzzerVolume"].get<uint8_t>();
        if (j.contains("buzzerEnabled")) buzzerEnabled = j["buzzerEnabled"].get<bool>();
        
        std::cout << "Successfully loaded brain_config.json\n";
    } catch (const std::exception& e) {
        std::cerr << "Error parsing config file: " << e.what() << '\n';
    }
}

// ================= HARDWARE THREADS =================

void buzzerThreadLoop() {
    while (true) {
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
        std::lock_guard<std::mutex> lock(stateMutex);
        unsigned long nowMs = getMillis();
        updateBuzzerByFusedType(currentFusedType, currentFusedSeverity, nowMs);
    }
}

void udpListenerThread() {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    sockaddr_in servaddr{};
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(5005);
    bind(sockfd, (const sockaddr *)&servaddr, sizeof(servaddr));

    char buffer[1024];
    while (true) {
        int n = recvfrom(sockfd, buffer, 1024, 0, nullptr, nullptr);
        if (n > 0) {
            buffer[n] = '\0';
            try {
                auto j = json::parse(buffer);
                std::lock_guard<std::mutex> lock(stateMutex);
                if (j.contains("state")) {
                    laneData.state = j["state"].get<uint8_t>();
                    laneData.online = true;
                    laneData.lastUpdateMs = getMillis();
                }
                // --- ADDED BARE-METAL VISION GATE ---
                if (j.contains("objectValid")) {
                    frontData.visionValidated = j["objectValid"].get<bool>();
                }
            } catch (...) {}

        }
    }
}

void canListenerThread() {
    struct sockaddr_can addr;
    struct ifreq ifr;

    canSocketFd = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (canSocketFd < 0) {
        std::cerr << "Error opening SocketCAN raw socket\n";
        return;
    }

    std::strcpy(ifr.ifr_name, "can0");
    if (ioctl(canSocketFd, SIOCGIFINDEX, &ifr) < 0) {
        std::cerr << "Error matching can0 interface\n";
        close(canSocketFd);
        canSocketFd = -1;
        return;
    }

    addr.can_family = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;

    if (bind(canSocketFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        std::cerr << "Error binding SocketCAN to can0\n";
        close(canSocketFd);
        canSocketFd = -1;
        return;
    }

    std::cout << "SocketCAN (can0) successfully bound for bidirectional transfer.\n";

    struct can_frame frame;
    while (true) {
        int nbytes = read(s, &frame, sizeof(can_frame));
        if (nbytes > 0) {
            std::lock_guard<std::mutex> lock(stateMutex);
            unsigned long nowMs = getMillis();
            
            // ── EXISTING: Lean Angle CAN Parser (ID 0x100) ──
            if (frame.can_id == 0x100 && frame.can_dlc >= 8) {
                leanData.riskLevel = frame.data[0];
                int16_t r = frame.data[1] | (frame.data[2] << 8);
                int16_t p = frame.data[3] | (frame.data[4] << 8);
                leanData.rollDeg = r / 100.0f;
                leanData.pitchDeg = p / 100.0f;
                leanData.confidence = frame.data[5] / 100.0f;
                leanData.calibrated = (frame.data[6] & 1) != 0;
                leanData.online = true;
                leanData.lastUpdateMs = nowMs;
            }
            
            // ── NEW: Front Sensor CAN Parser (ID 0x200) & UDP Bridge ──
            if (frame.can_id == 0x200 && frame.can_dlc >= 4) {
                frontData.state = frame.data[0];
                int16_t distRaw = frame.data[1] | (frame.data[2] << 8);
                frontData.filteredDistanceCm = distRaw / 10.0f;
                frontData.online = true;
                frontData.lastUpdateMs = nowMs;

                // Blast distance to Python Vision Script via UDP Port 5006
                json p;
                p["dist"] = frontData.filteredDistanceCm;
                std::string pStr = p.dump();
                sendto(udpSock, pStr.c_str(), pStr.length(), 0, (sockaddr*)&pyAddr, sizeof(pyAddr));
            }
        }
    }
}

void broadcastThread() {
    while (true) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        std::lock_guard<std::mutex> lock(stateMutex);
        
        unsigned long nowMs = getMillis();
        
        updateCriticalIncidentDetection(nowMs);

        if (users.empty()) continue;

        bool leanOffline  = isOffline(leanData.lastUpdateMs, nowMs);
        bool frontOffline = isOffline(frontData.lastUpdateMs, nowMs);
        bool rearOffline  = isOffline(rearData.lastUpdateMs, nowMs);
        bool laneOffline  = isOffline(laneData.lastUpdateMs, nowMs);

        std::string fusedType = "NONE";
        std::string fusedTitle = "All Clear";
        std::string fusedMessage = "No active safety warnings.";
        std::string fusedColor = "#1db954";
        uint8_t fusedSeverity = 0;

        if (!leanOffline && leanData.riskLevel == 2) {
            fusedType = "LEAN_HIGH"; fusedTitle = "High Lean Risk"; fusedMessage = "Vehicle lean angle is high. Reduce speed and stabilize the vehicle."; fusedColor = "#ff3b30"; fusedSeverity = 3;
        } else if (!frontOffline && frontData.state == 3) {
            fusedType = "FRONT_WARNING"; fusedTitle = "Front Collision Warning"; fusedMessage = "Obstacle ahead with high risk. Brake or slow down."; fusedColor = "#ff3b30"; fusedSeverity = 3;
        } else if (!rearOffline && rearData.overallState == 3) {
            fusedType = "REAR_WARNING"; fusedTitle = "Rear Blindspot Warning"; fusedMessage = "Very close object detected behind the vehicle."; fusedColor = "#ff3b30"; fusedSeverity = 3;
        } else if (!laneOffline && laneData.state == 1) {
            fusedType = "LANE_LEFT"; fusedTitle = "Left Lane Departure"; fusedMessage = "Vehicle is drifting toward the left lane marking."; fusedColor = "#ffb020"; fusedSeverity = 2;
        } else if (!laneOffline && laneData.state == 2) {
            fusedType = "LANE_RIGHT"; fusedTitle = "Right Lane Departure"; fusedMessage = "Vehicle is drifting toward the right lane marking."; fusedColor = "#ffb020"; fusedSeverity = 2;
        } else if (!leanOffline && leanData.riskLevel == 1) {
            fusedType = "LEAN_CAUTION"; fusedTitle = "Lean Caution"; fusedMessage = "Vehicle lean is increasing. Drive carefully."; fusedColor = "#ffb020"; fusedSeverity = 2;
        } else if (!frontOffline && frontData.state == 2) {
            fusedType = "FRONT_APPROACHING"; fusedTitle = "Object Approaching"; fusedMessage = "Object ahead is getting closer."; fusedColor = "#ff7230"; fusedSeverity = 2;
        } else if (!rearOffline && rearData.overallState == 2) {
            fusedType = "REAR_CAUTION"; fusedTitle = "Rear Caution"; fusedMessage = "Object detected close to the rear blindspot area."; fusedColor = "#ffb020"; fusedSeverity = 2;
        } else if (!frontOffline && frontData.state == 1) {
            fusedType = "FRONT_OBJECT"; fusedTitle = "Object Ahead"; fusedMessage = "Object detected in front."; fusedColor = "#f5c542"; fusedSeverity = 1;
        } else if (!rearOffline && rearData.overallState == 1) {
            fusedType = "REAR_OBJECT"; fusedTitle = "Rear Object Detected"; fusedMessage = "Object detected behind the vehicle."; fusedColor = "#f5c542"; fusedSeverity = 1;
        }

        currentFusedType = fusedType;
        currentFusedSeverity = fusedSeverity;

        bool includeConfig = forceConfigBroadcast || ((nowMs - lastConfigBroadcastMs) >= CONFIG_BROADCAST_MS);
        if (includeConfig) {
            lastConfigBroadcastMs = nowMs;
            forceConfigBroadcast = false;
        }

        json payload;

        if (includeConfig) {
            payload["config"]["setupCompleted"] = brainConfig.setupCompleted ? 1 : 0;
            payload["config"]["profileName"] = brainConfig.profileName;
            payload["config"]["vehicleType"] = brainConfig.vehicleType;
            payload["config"]["vehicleTypeName"] = vehicleTypeName(brainConfig.vehicleType);
            payload["config"]["trackWidth_m"] = std::round(brainConfig.trackWidth_m * 100) / 100;
            payload["config"]["wheelBase_m"] = std::round(brainConfig.wheelBase_m * 100) / 100;
            payload["config"]["vehicleHeight_m"] = std::round(brainConfig.vehicleHeight_m * 100) / 100;
            payload["config"]["loadCondition"] = brainConfig.loadCondition;
            payload["config"]["loadConditionName"] = loadConditionName(brainConfig.loadCondition);
            payload["config"]["frontPreset"] = brainConfig.frontSensitivityPreset;
            payload["config"]["frontPresetName"] = presetName(brainConfig.frontSensitivityPreset);
            payload["config"]["rearPreset"] = brainConfig.rearSensitivityPreset;
            payload["config"]["rearPresetName"] = presetName(brainConfig.rearSensitivityPreset);
            payload["config"]["centerCalibrated"] = brainConfig.centerCalibrated ? 1 : 0;
            payload["config"]["buzzerEnabled"] = buzzerEnabled ? 1 : 0;
            payload["config"]["frontSoundPattern"] = brainConfig.frontBuzzerPattern;
            payload["config"]["rearSoundPattern"] = brainConfig.rearBuzzerPattern;
            payload["config"]["laneSoundPattern"] = brainConfig.laneBuzzerPattern;
            payload["config"]["leanSoundPattern"] = brainConfig.leanBuzzerPattern;
            payload["config"]["frontSoundVolume"] = brainConfig.frontBuzzerVolume;
            payload["config"]["rearSoundVolume"] = brainConfig.rearBuzzerVolume;
            payload["config"]["laneSoundVolume"] = brainConfig.laneBuzzerVolume;
            payload["config"]["leanSoundVolume"] = brainConfig.leanBuzzerVolume;
        }

        payload["fused"]["type"] = fusedType;
        payload["fused"]["title"] = fusedTitle;
        payload["fused"]["message"] = fusedMessage;
        payload["fused"]["color"] = fusedColor;
        payload["fused"]["severity"] = fusedSeverity;

        payload["lean"]["online"] = leanOffline ? 0 : 1;
        payload["lean"]["stale"] = isStale(leanData.lastUpdateMs, nowMs) ? 1 : 0;
        payload["lean"]["calibrated"] = leanData.calibrated ? 1 : 0;
        payload["lean"]["riskLevel"] = leanData.riskLevel;
        payload["lean"]["riskName"] = leanRiskName(leanData.riskLevel);
        payload["lean"]["roll"] = std::round(leanData.rollDeg * 100) / 100;
        payload["lean"]["pitch"] = std::round(leanData.pitchDeg * 100) / 100;
        payload["lean"]["confidence"] = std::round(leanData.confidence * 100) / 100;
        payload["lean"]["criticalRollDeg"] = std::round(leanData.criticalRollDeg * 100) / 100;
        payload["lean"]["criticalPitchDeg"] = std::round(leanData.criticalPitchDeg * 100) / 100;

        payload["front"]["online"] = frontOffline ? 0 : 1;
        payload["front"]["stale"] = isStale(frontData.lastUpdateMs, nowMs) ? 1 : 0;
        payload["front"]["state"] = frontData.state;
        payload["front"]["stateName"] = frontStateName(frontData.state);
        payload["front"]["stateColor"] = stateColorByLevel(frontData.state);
        payload["front"]["filteredDistanceCm"] = std::round(frontData.filteredDistanceCm * 10) / 10;
        payload["front"]["closingSpeedCmS"] = std::round(frontData.closingSpeedCmS * 10) / 10;

        payload["rear"]["online"] = rearOffline ? 0 : 1;
        payload["rear"]["stale"] = isStale(rearData.lastUpdateMs, nowMs) ? 1 : 0;
        payload["rear"]["overallState"] = rearData.overallState;
        payload["rear"]["overallStateName"] = rearStateName(rearData.overallState);
        payload["rear"]["overallStateColor"] = stateColorByLevel(rearData.overallState);
        payload["rear"]["leftStateName"] = rearStateName(rearData.leftState);
        payload["rear"]["leftStateColor"] = stateColorByLevel(rearData.leftState);
        payload["rear"]["leftFilteredDistanceCm"] = std::round(rearData.leftFilteredDistanceCm * 10) / 10;
        payload["rear"]["centerStateName"] = rearStateName(rearData.centerState);
        payload["rear"]["centerStateColor"] = stateColorByLevel(rearData.centerState);
        payload["rear"]["centerFilteredDistanceCm"] = std::round(rearData.centerFilteredDistanceCm * 10) / 10;
        payload["rear"]["rightStateName"] = rearStateName(rearData.rightState);
        payload["rear"]["rightStateColor"] = stateColorByLevel(rearData.rightState);
        payload["rear"]["rightFilteredDistanceCm"] = std::round(rearData.rightFilteredDistanceCm * 10) / 10;

        payload["lane"]["online"] = laneOffline ? 0 : 1;
        payload["lane"]["stale"] = isStale(laneData.lastUpdateMs, nowMs) ? 1 : 0;
        payload["lane"]["state"] = laneData.state;
        payload["lane"]["stateName"] = laneStateName(laneData.state);
        payload["lane"]["stateColor"] = laneStateColor(laneData.state);

        std::string payloadStr = payload.dump();
        for (auto *u : users) {
            u->send_text(payloadStr);
        }

        if (nowMs - lastIncidentResendMs >= INCIDENT_RESEND_MS) {
            lastIncidentResendMs = nowMs;
            for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) {
                if (incidentBuffer[i].used && incidentBuffer[i].pendingAck) {
                    std::string incStr = buildIncidentJson(incidentBuffer[i]).dump();
                    for (auto *u : users) u->send_text(incStr);
                }
            }
        }
    }
}

// ================= MAIN HTTP/WS SERVER =================
int main() {
    buzzerBegin();
    loadConfig();
    crow::SimpleApp app;

    CROW_ROUTE(app, "/")([]() {
        std::ifstream file("index.html");
        if (!file.is_open()) return crow::response(404, "index.html not found");
        std::stringstream buffer;
        buffer << file.rdbuf();
        return crow::response(buffer.str()); 
    });

    CROW_WEBSOCKET_ROUTE(app, "/ws")
        .onopen([&](crow::websocket::connection &conn) {
            std::lock_guard<std::mutex> lock(stateMutex);
            users.insert(&conn); 
        })
        .onclose([&](crow::websocket::connection &conn, const std::string &reason) {
            std::lock_guard<std::mutex> lock(stateMutex);
            users.erase(&conn); 
        })
        .onmessage([&](crow::websocket::connection & /*conn*/, const std::string &data, bool is_binary) {
            try {
                auto j = json::parse(data);
                std::lock_guard<std::mutex> lock(stateMutex);
                if (j.contains("cmd")) {
                    std::string cmd = j["cmd"];
                    if (cmd == "incidentAck") {
                        acknowledgeIncident(j["incidentId"].get<uint32_t>());
                    } else if (cmd == "clearLocalStats") {
                        for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) {
                            incidentBuffer[i].used = false;
                            incidentBuffer[i].pendingAck = false;
                        }
                        lostIncidentCount = 0;
                    } else if (cmd == "saveVehicle" || cmd == "saveAllSetup") {
                        if (j.contains("setupCompleted")) brainConfig.setupCompleted = j["setupCompleted"].get<bool>();
                        if (j.contains("vehicleType")) brainConfig.vehicleType = j["vehicleType"].get<int>();
                        if (j.contains("trackWidth_m")) brainConfig.trackWidth_m = j["trackWidth_m"].get<float>();
                        if (j.contains("wheelBase_m")) brainConfig.wheelBase_m = j["wheelBase_m"].get<float>();
                        if (j.contains("vehicleHeight_m")) brainConfig.vehicleHeight_m = j["vehicleHeight_m"].get<float>();
                        if (j.contains("loadCondition")) brainConfig.loadCondition = j["loadCondition"].get<int>();
                        if (j.contains("frontPreset")) brainConfig.frontSensitivityPreset = j["frontPreset"].get<int>();
                        if (j.contains("rearPreset")) brainConfig.rearSensitivityPreset = j["rearPreset"].get<int>();
                        
                        if (j.contains("frontSoundPattern")) brainConfig.frontBuzzerPattern = j["frontSoundPattern"].get<int>();
                        if (j.contains("rearSoundPattern")) brainConfig.rearBuzzerPattern = j["rearSoundPattern"].get<int>();
                        if (j.contains("laneSoundPattern")) brainConfig.laneBuzzerPattern = j["laneSoundPattern"].get<int>();
                        if (j.contains("leanSoundPattern")) brainConfig.leanBuzzerPattern = j["leanSoundPattern"].get<int>();
                        
                        if (j.contains("frontSoundVolume")) brainConfig.frontBuzzerVolume = j["frontSoundVolume"].get<int>();
                        if (j.contains("rearSoundVolume")) brainConfig.rearBuzzerVolume = j["rearSoundVolume"].get<int>();
                        if (j.contains("laneSoundVolume")) brainConfig.laneBuzzerVolume = j["laneSoundVolume"].get<int>();
                        if (j.contains("leanSoundVolume")) brainConfig.leanBuzzerVolume = j["leanSoundVolume"].get<int>();
                        
                        saveConfig(); // <-- Write to disk
                        sendAllConfigs();
                        forceConfigBroadcast = true;
                        
                    } else if (data == "BUZZER_TOGGLE") {
                        buzzerEnabled = !buzzerEnabled;
                        if (!buzzerEnabled) buzzerOff();
                        saveConfig(); // <-- Write to disk
                        forceConfigBroadcast = true;
                        
                    } else if (data == "CAL_CENTER") {
                        centerCalibrationRequested = true;
                        brainConfig.centerCalibrated = false;
                        saveConfig(); // <-- Write to disk
                        forceConfigBroadcast = true;
                    }
            } catch (...) {} 
        });

    std::thread udp(udpListenerThread);
    std::thread can(canListenerThread);
    std::thread broadcast(broadcastThread);
    std::thread buzzer(buzzerThreadLoop);
    udp.detach(); can.detach(); broadcast.detach(); buzzer.detach();

    app.port(80).multithreaded().run();
    gpioTerminate();
}