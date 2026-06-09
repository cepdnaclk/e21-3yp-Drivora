cmake_minimum_required(VERSION 3.10)
project(DrivoraBrain)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 1. Find Threads and RT (Real-time) library
find_package(Threads REQUIRED)
find_library(RT_LIBRARY rt)

# 2. Setup dependency management (Crow and JSON)
include(FetchContent)

FetchContent_Declare(
    json 
    URL https://github.com/nlohmann/json/releases/download/v3.11.2/json.tar.xz
)
FetchContent_MakeAvailable(json)

FetchContent_Declare(
    crow 
    URL https://github.com/CrowCpp/Crow/releases/download/v1.0+5/crow-v1.0+5.zip
)
FetchContent_MakeAvailable(crow)

# 3. Define the executable
add_executable(brain_hub main.cpp)

# 4. Link dependencies
# We link pigpio (the hardware library) and rt (the timing library)
target_link_libraries(brain_hub PRIVATE 
    Threads::Threads 
    nlohmann_json::nlohmann_json 
    Crow::Crow 
    pigpio 
    ${RT_LIBRARY}
)