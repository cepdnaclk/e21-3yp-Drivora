cmake_minimum_required(VERSION 3.10)
project(Drivora_MainHub CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

find_package(OpenCV REQUIRED)

# Tell CMake where our header files live
include_directories(include ${OpenCV_INCLUDE_DIRS})

# Compile BOTH our main file and our custom class file from the src folder
add_executable(LaneDeparture src/main.cpp src/LaneDetector.cpp)

target_link_libraries(LaneDeparture ${OpenCV_LIBS})