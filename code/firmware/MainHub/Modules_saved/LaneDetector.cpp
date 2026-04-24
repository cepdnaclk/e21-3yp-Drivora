#include "../include/LaneDetector.h"

LaneDetector::LaneDetector() {
    // Calibration parameters - these will likely need tuning once mounted on the car
    whiteThreshold = 180;  // 180 out of 255 (fairly bright white/yellow)
    scanLineOffset = 20;   // Scan 20 pixels up from the bottom edge
    driftTolerance = 15;   // Allow 15 pixels of drift before warning
}

int LaneDetector::processFrame(const uint8_t* frameBuffer, int width, int height) {
    // 1. Define our Region of Interest (ROI) Y-coordinate
    int scanY = height - scanLineOffset;
    
    // 2. Define the exact center of our camera frame (the hood of the car)
    int frameCenter = width / 2;
    
    int leftLaneX = -1;
    int rightLaneX = -1;

    // 3. Scan Leftward from the center to find the left lane marker
    for (int x = frameCenter; x > 0; x--) {
        // Pointer arithmetic to find the exact byte in the 1D array
        int pixelIndex = (scanY * width) + x; 
        
        if (frameBuffer[pixelIndex] >= whiteThreshold) {
            leftLaneX = x;
            break; // Found the line, stop scanning
        }
    }

    // 4. Scan Rightward from the center to find the right lane marker
    for (int x = frameCenter; x < width; x++) {
        int pixelIndex = (scanY * width) + x;
        
        if (frameBuffer[pixelIndex] >= whiteThreshold) {
            rightLaneX = x;
            break;
        }
    }

    // 5. Calculate the vehicle's position relative to the lanes
    if (leftLaneX != -1 && rightLaneX != -1) {
        int laneCenter = (leftLaneX + rightLaneX) / 2;
        int drift = laneCenter - frameCenter; // Positive = drifted right, Negative = drifted left
        
        // 6. Evaluate against our safety tolerance
        if (drift > driftTolerance) {
            return 1; // Drifting dangerously to the right
        } else if (drift < -driftTolerance) {
            return -1; // Drifting dangerously to the left
        }
    }
    
    // If we only see one line, or we are safely in the middle
    return 0; 
}