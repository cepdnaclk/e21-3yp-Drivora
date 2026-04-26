#include "LaneClassifier.h"

LaneClassifier::LaneClassifier() {
    minLW = 3;
    maxLW = 38;
    histIdx        = 0;
    lastL          = -1;
    lastR          = -1;
    leftAlarmCnt   = 0;
    rightAlarmCnt  = 0;
    lostFrames     = 0;
    calibrated     = false;
    calibCount     = 0;
    calibSumL      = 0;
    calibSumR      = 0;
    calibPrevL     = -1;
    calibPrevR     = -1;
    baselineL      = -1;
    baselineR      = -1;
    leftThresh     = -1;
    rightThresh    = -1;

    for (int i = 0; i < HISTORY_SIZE; i++) {
        leftHist[i]  = -1;
        rightHist[i] = -1;
    }
}

// ─────────────────────────────────────────────────────────────────
// Scan one full row left→right, collect all valid white blobs.
// Returns blob count. Blobs sorted left→right naturally.
// ─────────────────────────────────────────────────────────────────
int LaneClassifier::findBlobs(const uint8_t* buf, int width, int y,
                               uint8_t thr, Blob* blobs) {
    int count = 0, runW = 0, runStart = 0;

    for (int x = 0; x <= width; x++) {
        // x==width acts as a forced end-of-row sentinel
        bool white = (x < width) && (buf[y * width + x] > thr);

        if (white) {
            if (runW == 0) runStart = x;
            runW++;
        } else {
            if (runW >= minLW && runW <= maxLW && count < MAX_BLOBS) {
                blobs[count].cx = runStart + runW / 2;
                blobs[count].w  = runW;
                count++;
            }
            runW = 0;
        }
    }
    return count;
}

// ─────────────────────────────────────────────────────────────────
// Reject positions that jump too far in one frame.
// Vehicles and glare appear instantly — real lines move gradually.
// ─────────────────────────────────────────────────────────────────
int LaneClassifier::plausible(int newPos, int lastPos) {
    if (newPos  == -1) return -1;       // No detection — propagate miss
    if (lastPos == -1) return newPos;   // No history yet — accept freely
    if (abs(newPos - lastPos) > MAX_JUMP) return lastPos; // Suspicious jump
    return newPos;
}

// ─────────────────────────────────────────────────────────────────
// Running average over HISTORY_SIZE frames. Skips -1 (miss) slots.
// ─────────────────────────────────────────────────────────────────
int LaneClassifier::smooth(int* hist, int newVal) {
    hist[histIdx % HISTORY_SIZE] = newVal;
    int sum = 0, cnt = 0;
    for (int i = 0; i < HISTORY_SIZE; i++) {
        if (hist[i] != -1) { sum += hist[i]; cnt++; }
    }
    return (cnt > 0) ? sum / cnt : -1;
}

// ─────────────────────────────────────────────────────────────────
// MAIN ENTRY POINT — call once per frame
// ─────────────────────────────────────────────────────────────────
String LaneClassifier::processFrame(const uint8_t* buf, int width, int height) {
    const int fc = width / 2; // 80 for QQVGA

    // ── ADAPTIVE THRESHOLD ──────────────────────────────────────
    // Mean brightness of primary scan row + offset.
    // Handles sun, shadow, tunnels automatically.
    int primY  = height - 45;
    long rSum  = 0;
    for (int x = 0; x < width; x++) rSum += buf[primY * width + x];
    uint8_t thr = (uint8_t)constrain((int)(rSum / width) + 58, 150, 240);

    // ── MULTI-ROW BLOB SCAN ─────────────────────────────────────
    int scanYs[SCAN_ROWS] = { height - 28, height - 45, height - 62 };
    int sumL = 0, cntL = 0, sumR = 0, cntR = 0;
    Blob blobs[MAX_BLOBS];

    for (int r = 0; r < SCAN_ROWS; r++) {
        int y = scanYs[r];
        if (y < 0 || y >= height) continue;

        int n = findBlobs(buf, width, y, thr, blobs);

        // ── CORRECT ASSIGNMENT RULE ───────────────────────────
        // LEFT line  = blob with smallest distance to center
        //              from the LEFT side (cx < fc)
        // RIGHT line = blob with smallest distance to center
        //              from the RIGHT side (cx >= fc)
        //
        // This is geometrically correct at ANY drift amount.
        // It is impossible to swap left/right with this rule.
        int bL = -1, bLd = 9999;
        int bR = -1, bRd = 9999;

        for (int b = 0; b < n; b++) {
            int cx = blobs[b].cx;
            if (cx < fc) {
                int d = fc - cx;
                if (d < bLd) { bLd = d; bL = cx; }
            } else {
                int d = cx - fc;
                if (d < bRd) { bRd = d; bR = cx; }
            }
        }

        if (bL != -1) { sumL += bL; cntL++; }
        if (bR != -1) { sumR += bR; cntR++; }
    }

    // Row-average (only rows that found something contribute)
    int rawL = (cntL > 0) ? sumL / cntL : -1;
    int rawR = (cntR > 0) ? sumR / cntR : -1;

    // ── PLAUSIBILITY ────────────────────────────────────────────
    int filtL = plausible(rawL, lastL);
    int filtR = plausible(rawR, lastR);

    // ── LANE WIDTH SANITY ───────────────────────────────────────
    // Both detections must form a believable lane.
    // If not: adjacent vehicle / glare blob → hold last known.
    if (filtL != -1 && filtR != -1) {
        int w = filtR - filtL;
        if (w < MIN_LANE_WIDTH || w > MAX_LANE_WIDTH) {
            filtL = lastL;
            filtR = lastR;
        }
    }

    // ── TEMPORAL SMOOTHING ──────────────────────────────────────
    int smL = smooth(leftHist,  filtL);
    int smR = smooth(rightHist, filtR);
    histIdx++;

    if (filtL != -1) lastL = filtL;
    if (filtR != -1) lastR = filtR;

    // ── TOTAL LOSS CHECK ────────────────────────────────────────
    // Both lines gone for too long → recalibrate from scratch.
    if (smL == -1 && smR == -1) {
        lostFrames++;
        if (lostFrames >= LOST_RESET_FRAMES) {
            calibrated  = false;
            calibCount  = 0;
            calibSumL   = calibSumR = 0;
            calibPrevL  = calibPrevR = -1;
            lostFrames  = 0;
            leftAlarmCnt = rightAlarmCnt = 0;
            return "RECALIBRATING...";
        }
        leftAlarmCnt = rightAlarmCnt = 0;
        return "";
    }
    lostFrames = 0;

    // ═══════════════════════════════════════════════════════════
    // CALIBRATION PHASE
    // Runs on startup (and after recalibration trigger).
    // Requires CALIB_FRAMES_NEEDED consecutive frames where BOTH
    // lines are visible and positions are stable (not jittering).
    // Builds the baseline "safe" positions for each line.
    // ═══════════════════════════════════════════════════════════
    if (!calibrated) {
        // Need both lines for a valid calibration frame
        if (smL == -1 || smR == -1) {
            return "CAL: Need both lines... (" +
                   String(calibCount) + "/" +
                   String(CALIB_FRAMES_NEEDED) + ")";
        }

        // Lane width must be plausible
        int w = smR - smL;
        if (w < MIN_LANE_WIDTH || w > MAX_LANE_WIDTH) {
            return "CAL: Bad lane width=" + String(w) + ", skipping";
        }

        // Stability check: positions must not jump from last calib frame
        bool stable = true;
        if (calibPrevL != -1) {
            if (abs(smL - calibPrevL) > CALIB_STABILITY_PX ||
                abs(smR - calibPrevR) > CALIB_STABILITY_PX) {
                stable = false;
                // Unstable frame: reset accumulator to avoid bad baseline
                calibCount = 0;
                calibSumL  = calibSumR = 0;
            }
        }

        if (stable) {
            calibSumL += smL;
            calibSumR += smR;
            calibCount++;
        }

        calibPrevL = smL;
        calibPrevR = smR;

        if (calibCount >= CALIB_FRAMES_NEEDED) {
            // Baseline established
            baselineL   = (int)(calibSumL / calibCount);
            baselineR   = (int)(calibSumR / calibCount);

            // Alarm threshold: line must move INWARD by ALARM_INWARD_PX
            // LEFT  line moving RIGHT (increasing) = drifting left
            // RIGHT line moving LEFT  (decreasing) = drifting right
            leftThresh  = baselineL + ALARM_INWARD_PX;
            rightThresh = baselineR - ALARM_INWARD_PX;
            calibrated  = true;

            return ">>> CALIBRATED <<< BL=" + String(baselineL) +
                   " BR="  + String(baselineR) +
                   " LT="  + String(leftThresh) +
                   " RT="  + String(rightThresh);
        }

        return "CAL: " + String(calibCount) + "/" +
               String(CALIB_FRAMES_NEEDED) +
               " L=" + String(smL) + " R=" + String(smR);
    }

    // ═══════════════════════════════════════════════════════════
    // ALARM LOGIC (post-calibration)
    //
    // PHYSICAL MEANING:
    //   smL > leftThresh  → left line has moved RIGHT into frame
    //                     → vehicle has drifted LEFT toward left line
    //                     → LEFT DEPARTURE
    //
    //   smR < rightThresh → right line has moved LEFT into frame
    //                     → vehicle has drifted RIGHT toward right line
    //                     → RIGHT DEPARTURE
    //
    // Only ONE direction can be active at a time.
    // Requires ALARM_FRAMES consecutive frames before firing.
    // ═══════════════════════════════════════════════════════════
    bool deptLeft  = (smL != -1 && smL > leftThresh);
    bool deptRight = (smR != -1 && smR < rightThresh);

    // Mutual exclusion: only count the active direction
    if (deptLeft && !deptRight) {
        leftAlarmCnt++;
        rightAlarmCnt = 0;
    } else if (deptRight && !deptLeft) {
        rightAlarmCnt++;
        leftAlarmCnt = 0;
    } else {
        // Safe or ambiguous (both or neither) → reset both
        leftAlarmCnt  = 0;
        rightAlarmCnt = 0;
    }

    if (leftAlarmCnt  >= ALARM_FRAMES) return "!!! ALARM: DEPARTING LEFT !!!";
    if (rightAlarmCnt >= ALARM_FRAMES) return "!!! ALARM: DEPARTING RIGHT !!!";

    // ── SAFE STATE OUTPUT ───────────────────────────────────────
    String out = "SAFE";
    if (smL != -1) out += " L=" + String(smL) +
                          "(T=" + String(leftThresh) + ")";
    if (smR != -1) out += " R=" + String(smR) +
                          "(T=" + String(rightThresh) + ")";
    out += " thr=" + String(thr);
    return out;
}