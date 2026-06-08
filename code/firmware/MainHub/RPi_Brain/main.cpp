#include "crow.h"
#include <nlohmann/json.hpp>
#include <iostream>
#include <fstream>
#include <sstream>
#include <thread>
#include <mutex>
#include <chrono>
#include <unordered_set>

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
std::unordered_set<crow::websocket::connection*> users;

// Structs remain identical to your ESP32 architecture
struct LaneData {
    bool online = false;
    uint8_t state = 0;
    unsigned long lastUpdateMs = 0;
};
LaneData laneData;

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

// Helper: Find oldest or empty slot
int findIncidentSlot() {
    for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) {
        if (!incidentBuffer[i].used) return i;
    }
    for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) {
        if (!incidentBuffer[i].pendingAck) return i;
    }
    int oldest = 0;
    for (int i = 1; i < INCIDENT_BUFFER_SIZE; i++) {
        if (incidentBuffer[i].timestampMs < incidentBuffer[oldest].timestampMs) {
            oldest = i;
        }
    }
    lostIncidentCount++;
    return oldest;
}

// Helper: Acknowledge from UI
void acknowledgeIncident(uint32_t id) {
    std::lock_guard<std::mutex> lock(stateMutex);
    for (int i = 0; i < INCIDENT_BUFFER_SIZE; i++) {
        if (incidentBuffer[i].used && incidentBuffer[i].id == id) {
            incidentBuffer[i].used = false;
            incidentBuffer[i].pendingAck = false;
            std::cout << "INCIDENT ACK | id=" << id << "\n";
            return;
        }
    }
}

// Timing helpers
unsigned long getMillis() {
    return std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::system_clock::now().time_since_epoch()
    ).count();
}

// ================= HARDWARE THREADS =================

// 1. UDP Listener (Replaces receiveLaneUART)
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
            } catch (...) {
                // Ignore malformed JSON packets
            }
        }
    }
}

// 2. SocketCAN Listener (Replaces TWAI loop)
void canListenerThread() {
    int s = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    ifreq ifr;
    strcpy(ifr.ifr_name, "can0");
    ioctl(s, SIOCGIFINDEX, &ifr);
    
    sockaddr_can addr{};
    addr.can_family = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;
    bind(s, (sockaddr *)&addr, sizeof(addr));

    can_frame frame;
    while (true) {
        int nbytes = read(s, &frame, sizeof(can_frame));
        if (nbytes > 0) {
            std::lock_guard<std::mutex> lock(stateMutex);
            unsigned long nowMs = getMillis();
            
            // Example conversion of your ESP32 TWAI parser:
            // if (frame.can_id == LEAN_MAIN_ID) {
            //     leanData.riskLevel = frame.data[0];
            //     leanData.lastUpdateMs = nowMs;
            // }
            // (Implement the rest of your CAN IDs here)
        }
    }
}

// ================= HYSTERESIS TIMERS =================
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
const unsigned long REAR_CRITICAL_CONFIRM_MS  = 700;
const unsigned long LEAN_CRITICAL_CONFIRM_MS  = 500;
const unsigned long LANE_CRITICAL_CONFIRM_MS  = 500;
const unsigned long MULTI_HAZARD_CONFIRM_MS   = 500;
const unsigned long INCIDENT_COOLDOWN_MS      = 5000;

// Helper: Get nearest rear distance
float nearestRearDistanceForIncident() {
    float best = -1.0f;
    if (rearData.leftFilteredDistanceCm >= 0.0f) best = rearData.leftFilteredDistanceCm;
    if (rearData.centerFilteredDistanceCm >= 0.0f && (best < 0.0f || rearData.centerFilteredDistanceCm < best)) best = rearData.centerFilteredDistanceCm;
    if (rearData.rightFilteredDistanceCm >= 0.0f && (best < 0.0f || rearData.rightFilteredDistanceCm < best)) best = rearData.rightFilteredDistanceCm;
    return best;
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
    
    std::cout << "INCIDENT STORED | id=" << incidentBuffer[slot].id << " type=" << eventType << "\n";
}

void updateIncidentLatch(bool active, unsigned long confirmMs, unsigned long& startMs, bool& logged, unsigned long& lastIncidentMs, unsigned long nowMs, std::string eventType, uint8_t severity, std::string sourceUnit, std::string title, std::string message) {
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
    // (Assume isOffline functions are defined above this)
    bool frontCritical = frontData.online && frontData.state == 3;
    bool rearCritical  = rearData.online && rearData.overallState == 3;
    bool leanCritical  = leanData.online && leanData.riskLevel == 2;
    bool laneCritical  = laneData.online && laneData.state != 0;

    updateIncidentLatch(frontCritical, FRONT_CRITICAL_CONFIRM_MS, frontCriticalStartMs, frontCriticalLogged, lastFrontIncidentMs, nowMs, "FRONT_CRITICAL", 3, "front", "Front Collision Risk", "A critical front collision warning was detected.");
    updateIncidentLatch(rearCritical, REAR_CRITICAL_CONFIRM_MS, rearCriticalStartMs, rearCriticalLogged, lastRearIncidentMs, nowMs, "REAR_CRITICAL", 3, "rear", "Rear Blindspot Risk", "A critical rear blindspot warning was detected.");
    updateIncidentLatch(leanCritical, LEAN_CRITICAL_CONFIRM_MS, leanCriticalStartMs, leanCriticalLogged, lastLeanIncidentMs, nowMs, "LEAN_CRITICAL", 3, "center", "High Lean Risk", "A critical vehicle lean condition was detected.");
    
    std::string laneStr = (laneData.state == 1) ? "LANE_LEFT_CRITICAL" : "LANE_RIGHT_CRITICAL";
    std::string laneTitle = (laneData.state == 1) ? "Left Lane Departure" : "Right Lane Departure";
    updateIncidentLatch(laneCritical, LANE_CRITICAL_CONFIRM_MS, laneCriticalStartMs, laneCriticalLogged, lastLaneIncidentMs, nowMs, laneStr, 2, "lane", laneTitle, "A lane departure warning was detected.");

    uint8_t seriousCount = 0;
    if (frontCritical) seriousCount++;
    if (rearCritical) seriousCount++;
    if (leanCritical) seriousCount++;
    if (laneCritical) seriousCount++;

    updateIncidentLatch(seriousCount >= 2, MULTI_HAZARD_CONFIRM_MS, multiHazardStartMs, multiHazardLogged, lastMultiIncidentMs, nowMs, "MULTI_HAZARD", 3, "multiple", "Multiple Safety Warnings", "Multiple critical safety warnings were active at the same time.");
}

// 3. The 50ms Broadcaster Loop
void broadcastThread() {
    while (true) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        
        std::lock_guard<std::mutex> lock(stateMutex);
        if (users.empty()) continue;

        unsigned long nowMs = getMillis();
        json payload;

        // Construct payload cleanly using nlohmann/json
        payload["lane"]["online"] = laneData.online ? 1 : 0;
        payload["lane"]["state"] = laneData.state;
        
        // (Add your fused logic and other structs here exactly as before)
        
        std::string payloadStr = payload.dump();
        for (auto* u : users) {
            u->send_text(payloadStr);
        }
    }
}

// ================= MAIN HTTP/WS SERVER =================
int main() {
    crow::SimpleApp app;

    // Load your index.html dynamically
    CROW_ROUTE(app, "/")([]() {
        std::ifstream file("index.html");
        if (!file.is_open()) return crow::response(404, "index.html not found");
        std::stringstream buffer;
        buffer << file.rdbuf();
        return crow::response(buffer.str());
    });

    // Handle WebSocket Connections
    CROW_WEBSOCKET_ROUTE(app, "/ws")
      .onopen([&](crow::websocket::connection& conn){
          std::lock_guard<std::mutex> lock(stateMutex);
          users.insert(&conn);
      })
      .onclose([&](crow::websocket::connection& conn, const std::string& reason){
          std::lock_guard<std::mutex> lock(stateMutex);
          users.erase(&conn);
      })
      .onmessage([&](crow::websocket::connection& /*conn*/, const std::string& data, bool is_binary){
          // Parse incoming settings commands exactly like handleIncomingCommand()
      });

    // Launch background hardware threads
    std::thread udp(udpListenerThread);
    std::thread can(canListenerThread);
    std::thread broadcast(broadcastThread);
    udp.detach(); can.detach(); broadcast.detach();

    // Start the Crow server on port 80
    app.port(80).multithreaded().run();
}