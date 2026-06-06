cmake_minimum_required(VERSION 3.10)
project(DrivoraBrain)

set(CMAKE_CXX_STANDARD 17)

# Ensure threading is available for Crow and our hardware loops
find_package(Threads REQUIRED)

# We will fetch Crow and JSON dynamically so you don't have to install them manually
include(FetchContent)

FetchContent_Declare(json URL https://github.com/nlohmann/json/releases/download/v3.11.2/json.tar.xz)
FetchContent_MakeAvailable(json)

FetchContent_Declare(crow URL https://github.com/CrowCpp/Crow/releases/download/v1.0+5/crow-v1.0+5.zip)
FetchContent_MakeAvailable(crow)

add_executable(brain_hub main.cpp)
target_link_libraries(brain_hub PRIVATE Threads::Threads nlohmann_json::nlohmann_json Crow::Crow)