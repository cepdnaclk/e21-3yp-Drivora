#ifndef LANE_CLASSIFIER_H
#define LANE_CLASSIFIER_H

#include <Arduino.h>

// ── Core Tuning ──────────────────────────────────────────────────
#define HISTORY_SIZE       6    // Smoothing window (frames)
#define SCAN_ROWS          3    // Rows to vote across per frame
#define ALARM_FRAMES       6    // Consecutive bad frames before alarm
#define MIN_LANE_WIDTH     35   // Min believable px gap between L and R
#define MAX_LANE_WIDTH     100  // Max believable px gap
#define MAX_JUMP           18   // Max px a real line moves per frame
#define MAX_BLOBS          10   // Max white blobs tracked per row

// ── Calibration ──────────────────────────────────────────────────
#define CALIB_FRAMES_NEEDED  30  // Stable frames to build baseline
#define CALIB_STABILITY_PX    8  // Max allowed jitter during calibration
#define LOST_RESET_FRAMES    60  // Frames with no lines → recalibrate

// ── Alarm sensitivity ────────────────────────────────────────────
// How many pixels a line must move INWARD from its baseline to alarm.
// Increase to make less sensitive. Decrease to make more sensitive.
#define ALARM_INWARD_PX      15

struct Blob { int cx; int w; };

class LaneClassifier {
public:
    LaneClassifier();
    String processFrame(const uint8_t* buf, int width, int height);

private:
    int minLW, maxLW;

    // Smoothing history
    int  leftHist[HISTORY_SIZE];
    int  rightHist[HISTORY_SIZE];
    int  histIdx;

    // Last accepted positions (plausibility gate)
    int  lastL, lastR;

    // Alarm hysteresis
    int  leftAlarmCnt;
    int  rightAlarmCnt;
    int  lostFrames;

    // Calibration state
    bool calibrated;
    int  calibCount;
    long calibSumL;
    long calibSumR;
    int  calibPrevL;   // Previous calib frame position (stability check)
    int  calibPrevR;
    int  baselineL;    // Learned safe position of left line
    int  baselineR;    // Learned safe position of right line
    int  leftThresh;   // Alarm fires if smL > leftThresh
    int  rightThresh;  // Alarm fires if smR < rightThresh

    // Helpers
    int findBlobs(const uint8_t* buf, int width, int y,
                  uint8_t thr, Blob* blobs);
    int plausible(int newPos, int lastPos);
    int smooth   (int* hist,  int newVal);
};

#endif