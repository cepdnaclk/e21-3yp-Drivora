#include <Arduino.h>
#include <WiFi.h>
#include "esp_camera.h"
#include "esp_http_server.h"

// ============================================================
// AI-Thinker ESP32-CAM Pin Definitions
// ============================================================
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

// ============================================================
// Wi-Fi
// ============================================================
const char* ssid = "Thakshila's iPhone";
const char* password = "comeflywithme";

httpd_handle_t stream_httpd = NULL;

// ============================================================
// Thin bottom ROI
// ============================================================
#define ROI_X 20
#define ROI_Y 92
#define ROI_W 120
#define ROI_H 18

// ============================================================
// Tuning
// ============================================================
#define SCAN_ROWS 3
#define MAX_BLOBS 10

#define MIN_BLOB_W 2
#define MAX_BLOB_W 38

#define MIN_LANE_WIDTH 22
#define MAX_LANE_WIDTH 105

#define HISTORY_SIZE 4
#define MAX_JUMP 18

#define DASH_GAP_HOLD_FRAMES 5
#define ROW_AGREE_PX 14

// Center crossing zone
#define CENTER_ZONE_HALF_WIDTH 12

// Re-arm margin so repeated alerts stop after crossing
#define ALERT_RELEASE_MARGIN 4

// Rolling decision window
#define DECISION_WINDOW_FRAMES 10
#define DECISION_TRIGGER_COUNT 2

// Direction logic
#define MOTION_TRIGGER_PX 1
#define INWARD_SCORE_MAX 4

#define PRINT_INTERVAL_MS 250
#define CLASSIFY_INTERVAL_MS 60
#define STREAM_FRAME_DELAY_MS 100
#define ALERT_HOLD_MS 400

struct Blob {
  int cx;
  int w;
};

class LaneDetector {
public:
  LaneDetector() {
    resetAll();
  }

  String processFrame(const uint8_t* roiBuf, int width, int height, unsigned long nowMs) {
    const int fc = width / 2;
    centerX = fc;

    long sum = 0;
    int minV = 255;
    int maxV = 0;

    for (int i = 0; i < width * height; i++) {
      int v = roiBuf[i];
      sum += v;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }

    int meanVal = sum / (width * height);
    int span = maxV - minV;

    int thrBase = meanVal + 18;
    if (span < 30) thrBase -= 4;
    if (span > 90) thrBase += 3;
    uint8_t thr = (uint8_t) constrain(thrBase, 95, 220);
    lastPixelThreshold = thr;

    int scanYs[SCAN_ROWS] = {
      height - 4,
      height - 9,
      height - 14
    };

    int leftCand[SCAN_ROWS];
    int rightCand[SCAN_ROWS];
    for (int i = 0; i < SCAN_ROWS; i++) {
      leftCand[i] = -1;
      rightCand[i] = -1;
    }

    Blob blobs[MAX_BLOBS];

    for (int r = 0; r < SCAN_ROWS; r++) {
      int y = scanYs[r];
      if (y < 0 || y >= height) continue;

      int n = findBlobs(roiBuf, width, y, thr, blobs);

      int bestL = -1, bestLd = 9999;
      int bestR = -1, bestRd = 9999;

      for (int b = 0; b < n; b++) {
        int cx = blobs[b].cx;
        if (cx < fc) {
          int d = fc - cx;
          if (d < bestLd) {
            bestLd = d;
            bestL = cx;
          }
        } else {
          int d = cx - fc;
          if (d < bestRd) {
            bestRd = d;
            bestR = cx;
          }
        }
      }

      leftCand[r] = bestL;
      rightCand[r] = bestR;
    }

    int rawL = agreeAcrossRows(leftCand, lastL);
    int rawR = agreeAcrossRows(rightCand, lastR);

    if (rawL != -1 && rawR != -1) {
      int w = rawR - rawL;
      if (w < MIN_LANE_WIDTH || w > MAX_LANE_WIDTH) {
        rawL = -1;
        rawR = -1;
      }
    }

    rawL = applyGapHold(rawL, lastGoodL, missCountL);
    rawR = applyGapHold(rawR, lastGoodR, missCountR);

    int filtL = plausible(rawL, lastL);
    int filtR = plausible(rawR, lastR);

    int smL = smooth(leftHist, filtL, histIdx);
    int smR = smooth(rightHist, filtR, histIdx);
    histIdx = (histIdx + 1) % HISTORY_SIZE;

    if (filtL != -1) lastL = filtL;
    if (filtR != -1) lastR = filtR;

    updateSideMemory(smL, lastGoodL, missCountL);
    updateSideMemory(smR, lastGoodR, missCountR);

    lastSmoothedL = smL;
    lastSmoothedR = smR;

    bool bothLostNow = (smL == -1 && smR == -1);
    if (bothLostNow) {
      decayDirectionScores();
      pushEvidence(0, 0);
      prevSmL = smL;
      prevSmR = smR;
      return heldAlertOrSafe(nowMs);
    }

    int centerLeftBound  = fc - CENTER_ZONE_HALF_WIDTH;
    int centerRightBound = fc + CENTER_ZONE_HALF_WIDTH;

    // --------------------------------------------------------
    // Re-arm locks after line moves away from center zone
    // --------------------------------------------------------
    if (leftAlertLock) {
      if (smL != -1 && smL < (centerLeftBound - ALERT_RELEASE_MARGIN)) {
        leftAlertLock = false;
      }
    }

    if (rightAlertLock) {
      if (smR != -1 && smR > (centerRightBound + ALERT_RELEASE_MARGIN)) {
        rightAlertLock = false;
      }
    }

    // --------------------------------------------------------
    // Direction scoring
    // --------------------------------------------------------
    int leftDelta = 0;
    int rightDelta = 0;

    if (smL != -1 && prevSmL != -1) {
      leftDelta = smL - prevSmL;   // positive = moving right/inward
    }

    if (smR != -1 && prevSmR != -1) {
      rightDelta = smR - prevSmR;  // negative = moving left/inward
    }

    if (leftDelta >= MOTION_TRIGGER_PX) {
      if (leftInwardScore < INWARD_SCORE_MAX) leftInwardScore++;
    } else if (leftInwardScore > 0) {
      leftInwardScore--;
    }

    if (rightDelta <= -MOTION_TRIGGER_PX) {
      if (rightInwardScore < INWARD_SCORE_MAX) rightInwardScore++;
    } else if (rightInwardScore > 0) {
      rightInwardScore--;
    }

    bool leftDepartureNow = false;
    bool rightDepartureNow = false;

    // Left line crossing toward center means vehicle drifting left
    if (!leftAlertLock &&
        smL != -1 &&
        smL >= centerLeftBound &&
        leftInwardScore >= 1) {
      leftDepartureNow = true;
    }

    // Right line crossing toward center means vehicle drifting right
    if (!rightAlertLock &&
        smR != -1 &&
        smR <= centerRightBound &&
        rightInwardScore >= 1) {
      rightDepartureNow = true;
    }

    // If both trigger together, choose the stronger / more plausible one
    if (leftDepartureNow && rightDepartureNow) {
      int leftDistToCenter = abs(fc - smL);
      int rightDistToCenter = abs(smR - fc);

      if (leftInwardScore > rightInwardScore + 1) {
        rightDepartureNow = false;
      } else if (rightInwardScore > leftInwardScore + 1) {
        leftDepartureNow = false;
      } else if (leftDistToCenter + 1 < rightDistToCenter) {
        rightDepartureNow = false;
      } else if (rightDistToCenter + 1 < leftDistToCenter) {
        leftDepartureNow = false;
      } else {
        leftDepartureNow = false;
        rightDepartureNow = false;
      }
    }

    pushEvidence(leftDepartureNow ? 1 : 0, rightDepartureNow ? 1 : 0);

    int leftVotes = sumEvidence(leftEvidenceHist);
    int rightVotes = sumEvidence(rightEvidenceHist);

    prevSmL = smL;
    prevSmR = smR;

    if (leftVotes >= DECISION_TRIGGER_COUNT && rightVotes >= DECISION_TRIGGER_COUNT) {
      return heldAlertOrSafe(nowMs);
    }

    if (leftVotes >= DECISION_TRIGGER_COUNT) {
      leftAlertLock = true;
      clearEvidence();
      heldAlert = 1;
      heldAlertUntilMs = nowMs + ALERT_HOLD_MS;
      return "LEFT_DEPARTURE";
    }

    if (rightVotes >= DECISION_TRIGGER_COUNT) {
      rightAlertLock = true;
      clearEvidence();
      heldAlert = 2;
      heldAlertUntilMs = nowMs + ALERT_HOLD_MS;
      return "RIGHT_DEPARTURE";
    }

    return heldAlertOrSafe(nowMs);
  }

  int getLastSmoothedL() const { return lastSmoothedL; }
  int getLastSmoothedR() const { return lastSmoothedR; }
  int getPixelThreshold() const { return lastPixelThreshold; }
  int getCenterX() const { return centerX; }
  int getCenterLeftBound() const { return centerX - CENTER_ZONE_HALF_WIDTH; }
  int getCenterRightBound() const { return centerX + CENTER_ZONE_HALF_WIDTH; }

private:
  int leftHist[HISTORY_SIZE];
  int rightHist[HISTORY_SIZE];
  int histIdx = 0;

  int lastL = -1;
  int lastR = -1;

  int lastGoodL = -1;
  int lastGoodR = -1;
  int missCountL = 0;
  int missCountR = 0;

  int lastSmoothedL = -1;
  int lastSmoothedR = -1;
  int prevSmL = -1;
  int prevSmR = -1;
  int lastPixelThreshold = -1;
  int centerX = ROI_W / 2;

  int leftInwardScore = 0;
  int rightInwardScore = 0;

  bool leftAlertLock = false;
  bool rightAlertLock = false;

  int leftEvidenceHist[DECISION_WINDOW_FRAMES];
  int rightEvidenceHist[DECISION_WINDOW_FRAMES];
  int evidenceIdx = 0;

  int heldAlert = 0; // 0 SAFE, 1 LEFT, 2 RIGHT
  unsigned long heldAlertUntilMs = 0;

  void resetAll() {
    for (int i = 0; i < HISTORY_SIZE; i++) {
      leftHist[i] = -1;
      rightHist[i] = -1;
    }

    for (int i = 0; i < DECISION_WINDOW_FRAMES; i++) {
      leftEvidenceHist[i] = 0;
      rightEvidenceHist[i] = 0;
    }

    histIdx = 0;
    evidenceIdx = 0;

    lastL = -1;
    lastR = -1;

    lastGoodL = -1;
    lastGoodR = -1;
    missCountL = 0;
    missCountR = 0;

    lastSmoothedL = -1;
    lastSmoothedR = -1;
    prevSmL = -1;
    prevSmR = -1;
    lastPixelThreshold = -1;
    centerX = ROI_W / 2;

    leftInwardScore = 0;
    rightInwardScore = 0;

    leftAlertLock = false;
    rightAlertLock = false;

    heldAlert = 0;
    heldAlertUntilMs = 0;
  }

  String heldAlertOrSafe(unsigned long nowMs) {
    if (heldAlert != 0 && nowMs < heldAlertUntilMs) {
      return (heldAlert == 1) ? "LEFT_DEPARTURE" : "RIGHT_DEPARTURE";
    }
    heldAlert = 0;
    return "SAFE";
  }

  void decayDirectionScores() {
    if (leftInwardScore > 0) leftInwardScore--;
    if (rightInwardScore > 0) rightInwardScore--;
  }

  void clearEvidence() {
    for (int i = 0; i < DECISION_WINDOW_FRAMES; i++) {
      leftEvidenceHist[i] = 0;
      rightEvidenceHist[i] = 0;
    }
    evidenceIdx = 0;
  }

  void pushEvidence(int leftEv, int rightEv) {
    leftEvidenceHist[evidenceIdx] = leftEv;
    rightEvidenceHist[evidenceIdx] = rightEv;
    evidenceIdx = (evidenceIdx + 1) % DECISION_WINDOW_FRAMES;
  }

  int sumEvidence(const int* hist) {
    int s = 0;
    for (int i = 0; i < DECISION_WINDOW_FRAMES; i++) s += hist[i];
    return s;
  }

  int findBlobs(const uint8_t* buf, int width, int y, uint8_t thr, Blob* blobs) {
    int count = 0;
    int runW = 0;
    int runStart = 0;

    for (int x = 0; x <= width; x++) {
      bool white = (x < width) && (buf[y * width + x] > thr);

      if (white) {
        if (runW == 0) runStart = x;
        runW++;
      } else {
        if (runW >= MIN_BLOB_W && runW <= MAX_BLOB_W && count < MAX_BLOBS) {
          blobs[count].cx = runStart + runW / 2;
          blobs[count].w  = runW;
          count++;
        }
        runW = 0;
      }
    }
    return count;
  }

  int agreeAcrossRows(int* cand, int lastPos) {
    for (int i = 0; i < SCAN_ROWS; i++) {
      if (cand[i] == -1) continue;
      for (int j = i + 1; j < SCAN_ROWS; j++) {
        if (cand[j] == -1) continue;
        if (abs(cand[i] - cand[j]) <= ROW_AGREE_PX) {
          return (cand[i] + cand[j]) / 2;
        }
      }
    }

    for (int i = 0; i < SCAN_ROWS; i++) {
      if (cand[i] == -1) continue;
      if (lastPos == -1 || abs(cand[i] - lastPos) <= MAX_JUMP) {
        return cand[i];
      }
    }

    return -1;
  }

  int applyGapHold(int rawPos, int lastGoodPos, int missCount) {
    if (rawPos != -1) return rawPos;
    if (lastGoodPos != -1 && missCount < DASH_GAP_HOLD_FRAMES) {
      return lastGoodPos;
    }
    return -1;
  }

  void updateSideMemory(int smPos, int &lastGoodPos, int &missCount) {
    if (smPos != -1) {
      lastGoodPos = smPos;
      missCount = 0;
    } else {
      if (missCount < 255) missCount++;
    }
  }

  int plausible(int newPos, int lastPos) {
    if (newPos == -1) return -1;
    if (lastPos == -1) return newPos;
    if (abs(newPos - lastPos) > MAX_JUMP) return lastPos;
    return newPos;
  }

  int smooth(int* hist, int newVal, int idx) {
    hist[idx] = newVal;

    int sum = 0;
    int cnt = 0;
    for (int i = 0; i < HISTORY_SIZE; i++) {
      if (hist[i] != -1) {
        sum += hist[i];
        cnt++;
      }
    }
    return (cnt > 0) ? (sum / cnt) : -1;
  }
};

LaneDetector detector;
String lastPrinted = "";
unsigned long lastPrintMs = 0;
unsigned long lastClassifyMs = 0;

// ============================================================
// Build contrast-stretched ROI
// ============================================================
void buildContrastROI(const uint8_t* src, int srcW, uint8_t* dst) {
  int minV = 255;
  int maxV = 0;

  for (int y = 0; y < ROI_H; y++) {
    int sy = ROI_Y + y;
    for (int x = 0; x < ROI_W; x++) {
      int sx = ROI_X + x;
      uint8_t v = src[sy * srcW + sx];
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
  }

  int span = maxV - minV;
  if (span < 20) span = 20;

  for (int y = 0; y < ROI_H; y++) {
    int sy = ROI_Y + y;
    for (int x = 0; x < ROI_W; x++) {
      int sx = ROI_X + x;
      uint8_t v = src[sy * srcW + sx];

      int out = ((int)(v - minV) * 255) / span;
      if (out < 0) out = 0;
      if (out > 255) out = 255;

      dst[y * ROI_W + x] = (uint8_t)out;
    }
  }
}

// ============================================================
// Draw markers on grayscale ROI
// ============================================================
void drawVerticalLineGray(uint8_t* img, int width, int height, int x, uint8_t v) {
  if (x < 0 || x >= width) return;
  for (int y = 0; y < height; y++) {
    img[y * width + x] = v;
  }
}

void drawMarkersOnROIGray(uint8_t* img) {
  const int centerX = detector.getCenterX();
  int leftGuide  = ROI_W / 3;
  int rightGuide = (ROI_W * 2) / 3;

  drawVerticalLineGray(img, ROI_W, ROI_H, leftGuide, 170);
  drawVerticalLineGray(img, ROI_W, ROI_H, centerX, 255);
  drawVerticalLineGray(img, ROI_W, ROI_H, rightGuide, 170);

  drawVerticalLineGray(img, ROI_W, ROI_H, detector.getCenterLeftBound(), 120);
  drawVerticalLineGray(img, ROI_W, ROI_H, detector.getCenterRightBound(), 120);

  if (detector.getLastSmoothedL() >= 0) {
    drawVerticalLineGray(img, ROI_W, ROI_H, detector.getLastSmoothedL(), 220);
  }
  if (detector.getLastSmoothedR() >= 0) {
    drawVerticalLineGray(img, ROI_W, ROI_H, detector.getLastSmoothedR(), 220);
  }
}

// ============================================================
// Stream handler - ROI only with markers
// ============================================================
esp_err_t stream_handler(httpd_req_t *req) {
  camera_fb_t * fb = NULL;
  esp_err_t res = ESP_OK;
  char part_buf[64];

  static const char* _STREAM_CONTENT_TYPE = "multipart/x-mixed-replace;boundary=123456789000000000000987654321";
  static const char* _STREAM_BOUNDARY = "\r\n--123456789000000000000987654321\r\n";
  static const char* _STREAM_PART = "Content-Type: image/jpeg\r\nContent-Length: %u\r\n\r\n";

  static uint8_t roiGray[ROI_W * ROI_H];

  res = httpd_resp_set_type(req, _STREAM_CONTENT_TYPE);
  if (res != ESP_OK) return res;

  while (true) {
    fb = esp_camera_fb_get();
    if (!fb) {
      Serial.println("Stream capture failed");
      res = ESP_FAIL;
    } else {
      buildContrastROI(fb->buf, fb->width, roiGray);
      drawMarkersOnROIGray(roiGray);

      camera_fb_t roiFb;
      roiFb.width = ROI_W;
      roiFb.height = ROI_H;
      roiFb.format = PIXFORMAT_GRAYSCALE;
      roiFb.buf = roiGray;
      roiFb.len = ROI_W * ROI_H;
      roiFb.timestamp.tv_sec = 0;
      roiFb.timestamp.tv_usec = 0;

      uint8_t *out_buf = NULL;
      size_t out_len = 0;

      bool jpeg_converted = frame2jpg(&roiFb, 35, &out_buf, &out_len);
      esp_camera_fb_return(fb);
      fb = NULL;

      if (jpeg_converted) {
        size_t hlen = snprintf(part_buf, sizeof(part_buf), _STREAM_PART, out_len);

        res = httpd_resp_send_chunk(req, part_buf, hlen);
        if (res == ESP_OK) {
          res = httpd_resp_send_chunk(req, (const char *)out_buf, out_len);
        }
        if (res == ESP_OK) {
          res = httpd_resp_send_chunk(req, _STREAM_BOUNDARY, strlen(_STREAM_BOUNDARY));
        }

        free(out_buf);
      } else {
        Serial.println("ROI JPEG conversion failed");
        res = ESP_FAIL;
      }
    }

    if (res != ESP_OK) break;
    delay(STREAM_FRAME_DELAY_MS);
  }

  return res;
}

void startCameraServer() {
  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = 80;

  httpd_uri_t index_uri = {
    .uri      = "/",
    .method   = HTTP_GET,
    .handler  = stream_handler,
    .user_ctx = NULL
  };

  if (httpd_start(&stream_httpd, &config) == ESP_OK) {
    httpd_register_uri_handler(stream_httpd, &index_uri);
  }
}

// ============================================================
// Setup
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\nBooting Lane Departure Test with Direction-Sensitive Center-Zone Decision...");

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;

  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;

  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;

  config.xclk_freq_hz = 10000000;
  config.pixel_format = PIXFORMAT_GRAYSCALE;
  config.frame_size = FRAMESIZE_QQVGA;
  config.jpeg_quality = 12;
  config.fb_count = 2;

#if defined(CAMERA_GRAB_LATEST)
  config.grab_mode = CAMERA_GRAB_LATEST;
#endif

#if defined(CAMERA_FB_IN_PSRAM)
  config.fb_location = CAMERA_FB_IN_PSRAM;
#endif

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed! err=0x%x\n", err);
    return;
  }

  sensor_t *s = esp_camera_sensor_get();
  if (s) {
    s->set_brightness(s, 0);
    s->set_contrast(s, 2);
    s->set_saturation(s, 0);
    s->set_gain_ctrl(s, 1);
    s->set_exposure_ctrl(s, 1);
    s->set_whitebal(s, 0);
    s->set_hmirror(s, 0);
  }

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);

  Serial.print("Connecting to Wi-Fi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi connected.");

  startCameraServer();

  Serial.print("Open ROI live feed at: http://");
  Serial.println(WiFi.localIP());
  Serial.println("Direction-sensitive center-zone logic active.");
}

// ============================================================
// Loop - classify ROI only
// ============================================================
void loop() {
  unsigned long now = millis();

  if (now - lastClassifyMs < CLASSIFY_INTERVAL_MS) {
    delay(5);
    return;
  }
  lastClassifyMs = now;

  camera_fb_t *fb = esp_camera_fb_get();
  if (!fb) {
    delay(10);
    return;
  }

  static uint8_t roiBuf[ROI_W * ROI_H];
  buildContrastROI(fb->buf, fb->width, roiBuf);

  String result = detector.processFrame(roiBuf, ROI_W, ROI_H, now);

  esp_camera_fb_return(fb);

  if (result.length() > 0) {
    if (result != lastPrinted || (now - lastPrintMs) >= PRINT_INTERVAL_MS) {
      Serial.println(result);
      lastPrinted = result;
      lastPrintMs = now;
    }
  }
}