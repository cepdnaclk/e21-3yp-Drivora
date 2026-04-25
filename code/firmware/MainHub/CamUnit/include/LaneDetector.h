#ifndef LANE_DETECTOR_H
#define LANE_DETECTOR_H

#include <Arduino.h>

class LaneDetector {
public:
    LaneDetector();
    
    // Analyzes the frame and returns:
    //  0 = Safe/Centered
    // -1 = Warning: Drifting Left
    //  1 = Warning: Drifting Right
    int processFrame(const uint8_t* frameBuffer, int width, int height);

private:
    uint8_t whiteThreshold; // Brightness level to qualify as a lane marker (0-255)
    int scanLineOffset;     // How far up from the bottom of the frame we scan
    int driftTolerance;     // How many pixels off-center before triggering a warning
};

#endif