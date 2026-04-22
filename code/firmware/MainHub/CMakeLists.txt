# Set the minimum required version of CMake
cmake_minimum_required(VERSION 3.10)

# Name our project and specify the language
project(Drivora_MainHub CXX)

# Set C++ standard to C++17 (Industry standard for modern embedded C++)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Find the OpenCV package on the Raspberry Pi
find_package(OpenCV REQUIRED)

# Include OpenCV headers
include_directories(${OpenCV_INCLUDE_DIRS})

# Create the executable named "LaneDeparture" from our main.cpp file
add_executable(LaneDeparture main.cpp)

# Link the OpenCV libraries to our executable
target_link_libraries(LaneDeparture ${OpenCV_LIBS})