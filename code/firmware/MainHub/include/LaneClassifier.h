#ifndef LANE_CLASSIFIER_H
#define LANE_CLASSIFIER_H

#include <Arduino.h>

class LaneClassifier {
public:
    LaneClassifier();
    String processFrame(const uint8_t* frameBuffer, int width, int height);

private:
    uint8_t whiteThreshold; 
    int minLineWidth;  // NEW: Minimum pixel width to be considered a line
    int maxLineWidth;  // NEW: Maximum pixel width to ignore walls/glare
    int lineHistory[5]; 
    int historyIndex;
};

#endif