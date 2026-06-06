from flask import Flask, Response
import cv2
import numpy as np
from picamera2 import Picamera2

app = Flask(__name__)

# ── 1. Hardware Initialization ─────────────────────────────────────────────────
picam2 = Picamera2()
config  = picam2.create_preview_configuration({"size": (640, 480)})
config['framerate'] = 20
picam2.configure(config)
picam2.start()
picam2.set_controls({"AfMode": 0, "LensPosition": 0.0})

FRAME_W, FRAME_H = 640, 480

# ── Nearsighted anchor y-levels ────────────────────────────────────────────────
Y_NEAR = FRAME_H - 10           # 470 px (Bottom of screen)
Y_FAR  = int(FRAME_H * 0.65)    # 312 px (Shortened lookahead distance)

# ── 2. Short-Range Spatiotemporal Tracker ──────────────────────────────────────
class ShortRangeLaneTracker:
    MAX_PIXEL_JUMP   = 25    
    ALPHA            = 0.20  
    MAX_MISSES       = 25    
    BREACH_THRESHOLD = 4     

    def __init__(self):
        self.left_anchors  = None
        self.right_anchors = None
        self.left_missed   = 0
        self.right_missed  = 0
        self.left_breach   = 0
        self.right_breach  = 0

    @staticmethod
    def _robust_fit_si(points: list):
        """Robust line fitting using Huber distance to ignore outlier shadows."""
        if len(points) < 2:
            return None
        
        pts_arr = np.array(points, dtype=np.int32)
        
        try:
            [vx, vy, x0, y0] = cv2.fitLine(pts_arr, cv2.DIST_HUBER, 0, 0.01, 0.01)
        except Exception:
            return None
            
        vx, vy, x0, y0 = float(vx[0]), float(vy[0]), float(x0[0]), float(y0[0])
        
        if abs(vx) < 1e-5:
            return None
            
        slope = vy / vx
        intercept = y0 - (slope * x0)
        return (slope, intercept)

    @staticmethod
    def _x_at_y(si: tuple, y: float):
        s, b = si
        return float((y - b) / s) if abs(s) > 1e-5 else None

    def _build_anchors(self, pts) -> np.ndarray | None:
        """Builds a simple 2-point straight line array."""
        si = self._robust_fit_si(pts)
        if si is None:
            return None          

        x_near = self._x_at_y(si, Y_NEAR)
        x_far  = self._x_at_y(si, Y_FAR)

        if None in (x_near, x_far):
            return None

        clamp = lambda v: float(np.clip(v, 0, FRAME_W))
        return np.array([[clamp(x_near), Y_NEAR],
                         [clamp(x_far),  Y_FAR]], dtype=np.float32)

    def _gate_and_smooth(self, new_anch, stored, missed):
        if new_anch is None:
            missed += 1
            return (None, missed) if missed > self.MAX_MISSES else (stored, missed)

        if stored is not None:
            jump = abs(new_anch[0, 0] - stored[0, 0])
            if jump > self.MAX_PIXEL_JUMP:
                missed += 1
                return (None, missed) if missed > self.MAX_MISSES else (stored, missed)

        if stored is None:
            return new_anch.copy(), 0
            
        blended = (1.0 - self.ALPHA) * stored + self.ALPHA * new_anch
        return blended.astype(np.float32), 0

    def update(self, lines):
        """Sorts raw coordinates purely by left/right slope."""
        l_pts, r_pts = [], []

        if lines is not None:
            for seg in lines:
                x1, y1, x2, y2 = seg[0]
                if x1 == x2: continue
                
                slope = (y2 - y1) / (x2 - x1)

                if -2.5 < slope < -0.3:
                    l_pts.extend([(x1, y1), (x2, y2)])
                elif 0.3 < slope < 2.5:
                    r_pts.extend([(x1, y1), (x2, y2)])

        l_new = self._build_anchors(l_pts)
        r_new = self._build_anchors(r_pts)

        self.left_anchors,  self.left_missed  = self._gate_and_smooth(l_new, self.left_anchors,  self.left_missed)
        self.right_anchors, self.right_missed = self._gate_and_smooth(r_new, self.right_anchors, self.right_missed)

        return self.left_anchors, self.right_anchors

tracker = ShortRangeLaneTracker()

# ── 3. ROI mask ───────────────────────────────────────────────────────────────
# Adjusted the trapezoid to match the new shortened Y_FAR distance.
_roi_mask = np.zeros((FRAME_H, FRAME_W), np.uint8)
cv2.fillPoly(_roi_mask, [np.array([
    (80,          FRAME_H),
    (FRAME_W-80,  FRAME_H),
    (FRAME_W-160, Y_FAR),
    (160,         Y_FAR),
], np.int32)], 255)

# ── 4. Core Vision ────────────────────────────────────────────────────────────
def process_frame(frame):
    bgr    = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    height, width = bgr.shape[:2]
    car_cx = width // 2

    hls    = cv2.cvtColor(bgr, cv2.COLOR_BGR2HLS)
    l_ch   = hls[:, :, 1]
    sobelx = np.absolute(cv2.Sobel(l_ch, cv2.CV_64F, 1, 0, ksize=3))
    peak   = sobelx.max()
    
    scaled = np.uint8(255.0 * sobelx / peak) if peak > 0 else np.zeros_like(l_ch)
    _, binary = cv2.threshold(scaled, 40, 255, cv2.THRESH_BINARY)
    masked    = cv2.bitwise_and(binary, _roi_mask)

    lines = cv2.HoughLinesP(masked, 1, np.pi/180, 25, minLineLength=25, maxLineGap=60)
    
    # Notice we no longer pass 'height' since Y_FAR is globally defined
    l_anch, r_anch = tracker.update(lines) 

    # ── 5. Departure Logic ────────────────────────────────────────────────────
    CRITICAL_DISTANCE = 90
    status_text  = "ON THE LANE"
    status_color = (0, 220, 0)

    if l_anch is not None:
        pts = l_anch.astype(int)
        left_base_x = pts[0, 0] 

        # Drawing a single, thick, short line
        cv2.line(bgr, tuple(pts[0]), tuple(pts[1]), (255, 150, 0), 4, cv2.LINE_AA)

        if car_cx - left_base_x < CRITICAL_DISTANCE:
            tracker.left_breach += 1
        else:
            tracker.left_breach = max(0, tracker.left_breach - 1)

    if r_anch is not None:
        pts = r_anch.astype(int)
        right_base_x = pts[0, 0]

        # Drawing a single, thick, short line
        cv2.line(bgr, tuple(pts[0]), tuple(pts[1]), (0, 150, 255), 4, cv2.LINE_AA)

        if right_base_x - car_cx < CRITICAL_DISTANCE:
            tracker.right_breach += 1
        else:
            tracker.right_breach = max(0, tracker.right_breach - 1)

    if tracker.left_breach >= tracker.BREACH_THRESHOLD:
        status_text  = "WARN: LEFT DEPARTURE"
        status_color = (0, 140, 255)
    elif tracker.right_breach >= tracker.BREACH_THRESHOLD:
        status_text  = "CRIT: RIGHT DEPARTURE"
        status_color = (0, 0, 255)

    cv2.line(bgr, (car_cx - CRITICAL_DISTANCE, height),
                  (car_cx - CRITICAL_DISTANCE, height - 30), (200, 200, 200), 1)
    cv2.line(bgr, (car_cx + CRITICAL_DISTANCE, height),
                  (car_cx + CRITICAL_DISTANCE, height - 30), (200, 200, 200), 1)
    cv2.circle(bgr, (car_cx, height - 15), 6, (200, 200, 200), -1)
    cv2.putText(bgr, status_text, (20, 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, status_color, 2, cv2.LINE_AA)

    # ── 6. Diagnostic Split-Screen ────────────────────────────────────────────
    mask_bgr = cv2.cvtColor(masked, cv2.COLOR_GRAY2BGR)
    cv2.putText(mask_bgr, "SOBEL-X  |  SHORT-RANGE RANSAC  |  PHYSICS GATE", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 1, cv2.LINE_AA)
    
    # Draw the new cutoff line on the diagnostic screen so you can visualize the boundary
    cv2.line(mask_bgr, (0, Y_FAR), (FRAME_W, Y_FAR), (0, 0, 255), 1, cv2.LINE_AA)
    cv2.putText(mask_bgr, "NEARSIGHTED CUTOFF", (10, Y_FAR - 5), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 255), 1)
    
    return np.vstack((bgr, mask_bgr))

# ── 7. Streaming Server ───────────────────────────────────────────────────────
def generate_video_stream():
    while True:
        raw = picam2.capture_array()
        out = process_frame(raw)
        _, buf = cv2.imencode('.jpg', out)
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n'
               + buf.tobytes()
               + b'\r\n')

@app.route('/')
def video_feed():
    return Response(generate_video_stream(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    print("[ DRIVORA SYSTEM ] Short-Range RANSAC Lane Tracker Online.")
    app.run(host='0.0.0.0', port=5000, debug=False)