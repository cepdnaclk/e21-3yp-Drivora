#include "LaneClassifier.h"

LaneClassifier::LaneClassifier() {
    whiteThreshold = 180; 
    minLineWidth = 2;    // Must be at least 2 pixels wide (ignores single-pixel noise)
    maxLineWidth = 15;   // Cannot be wider than 15 pixels (ignores windows, paper, glare)
    historyIndex = 0;
    
    for(int i = 0; i < 5; i++) {
        lineHistory[i] = 0; 
    }
}

String LaneClassifier::processFrame(const uint8_t* frameBuffer, int width, int height) {
    int scanY = height - 30; 
    int centerStartX = (width / 2) - 50; // Widened our viewing angle slightly
    int centerEndX = (width / 2) + 50;   

    int lineCount = 0;
    bool inBrightObject = false;
    int currentObjectWidth = 0;

    // 1. Advanced Geometry Scan
    for (int x = centerStartX; x <= centerEndX; x++) {
        int pixelIndex = (scanY * width) + x;
        
        if (frameBuffer[pixelIndex] > whiteThreshold) {
            // We are looking at something bright
            if (!inBrightObject) {
                inBrightObject = true;
                currentObjectWidth = 1; // Start measuring
            } else {
                currentObjectWidth++;   // Keep measuring width
            }
        } else {
            // We hit a dark spot (asphalt). Let's evaluate the bright object we just passed.
            if (inBrightObject) {
                // FILTER: Is it the correct width for a lane line?
                if (currentObjectWidth >= minLineWidth && currentObjectWidth <= maxLineWidth) {
                    lineCount++; // Valid line detected!
                }
                // Reset for the next object
                inBrightObject = false;
                currentObjectWidth = 0;
            }
        }
    }

    // Edge case: If a line was hitting the absolute right edge of our scan zone
    if (inBrightObject && currentObjectWidth >= minLineWidth && currentObjectWidth <= maxLineWidth) {
        lineCount++;
    }

    // 2. Classify the CURRENT frame
    int currentLineType = 0; 
    if (lineCount == 1) currentLineType = 1; 
    if (lineCount >= 2) currentLineType = 2; 

    // 3. Update our rolling history buffer
    lineHistory[historyIndex] = currentLineType;
    historyIndex = (historyIndex + 1) % 5;

    // 4. Analyze the history over time
    int totalDetections = 0;
    for(int i = 0; i < 5; i++) {
        if(lineHistory[i] > 0) totalDetections++;
    }

    // 5. Final Output
    if (currentLineType == 2) return "DOUBLE LINE DETECTED ||";
    if (totalDetections > 0 && totalDetections < 5) return "DASHED LINE DETECTED - - -";
    if (totalDetections == 5) return "SOLID SINGLE LINE DETECTED |";

    return "NO LINE DETECTED";
}