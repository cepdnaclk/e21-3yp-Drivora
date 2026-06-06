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

// (For brevity, assume LeanData, FrontData, RearData, and BrainConfig 
// are pasted here exactly as they were in your ESP32 code).

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