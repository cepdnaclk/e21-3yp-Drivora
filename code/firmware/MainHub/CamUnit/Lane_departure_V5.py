from flask import Flask, Response
import cv2
import numpy as np
from picamera2 import Picamera2

app = Flask(__name__)

# ── 1. Hardware ────────────────────────────────────────────────────────────────
picam2 = Picamera2()
config  = picam2.create_preview_configuration({"size": (640, 480)})
config['framerate'] = 20
picam2.configure(config)
picam2.start()
picam2.set_controls({"AfMode": 0, "LensPosition": 0.0})

FRAME_W, FRAME_H = 640, 480

# ── Piecewise anchor y-levels ─────────────────────────────────────────────────
# Each lane is stored as THREE (x, y) points connecting two line segments.
#   NEAR  →  closest to car   (departure is measured here)
#   MID   →  middle depth
#   FAR   →  farthest visible (ROI top)
Y_NEAR = FRAME_H - 10           # 470 px
Y_MID  = int(FRAME_H * 0.73)   # 350 px
Y_FAR  = int(FRAME_H * 0.55)   # 264 px  ← same as ROI top edge

# Hough segments are classified into depth zones by their midpoint-y.
# Each zone feeds its OWN median slope+intercept, then gets projected
# to its anchor y-level.  If the near and far zones produce different
# x-positions the two segments naturally follow the road curve.
ZONE_NEAR_THRESH = int(FRAME_H * 0.78)   # mid_y > this  → near zone
ZONE_FAR_THRESH  = int(FRAME_H * 0.66)   # mid_y < this  → far  zone
                                          # between       → mid  zone

# ── 2. Piecewise Spatiotemporal Tracker ───────────────────────────────────────
class PiecewiseLaneTracker:
    """
    Stores each lane boundary as an np.float32 array of shape (3, 2):
        row 0: [x_near, Y_NEAR]   ← near  anchor
        row 1: [x_mid,  Y_MID ]   ← mid   anchor
        row 2: [x_far,  Y_FAR ]   ← far   anchor

    Two connected segments (near→mid, mid→far) represent the road curve
    instead of forcing a single straight line through all Hough data.

    ── Physics gate (fix for lane-change false-negative) ────────────────────
    Before any EMA update the new NEAR anchor's x-displacement from the
    stored estimate is checked.

    Why this is the correct fix:
      During a lane change the Hough median jumps 40–120 px in ONE frame as
      it locks onto the adjacent lane's marking.  The gate catches this jump
      and holds the OLD estimate, so the lane-centre offset grows and the
      departure alert fires correctly.

      A genuine road curve moves the line only 2–8 px per frame — well
      below the gate — so normal curve tracking is completely unaffected.

    MAX_PIXEL_JUMP = 25 px (≈ 4% of 640-wide frame) is the critical value.
    The original code used 40 px which was too loose for slow lane changes.
    """

    MAX_PIXEL_JUMP   = 25    # max allowable near-anchor x-shift per frame
    ALPHA            = 0.20  # EMA blend factor (lower = smoother)
    MAX_MISSES       = 25    # frames before cleared estimate resets tracker
    BREACH_THRESHOLD = 4     # consecutive breach frames before alert fires

    def __init__(self):
        self.left_anchors  = None   # np.float32 (3,2) or None
        self.right_anchors = None
        self.left_missed   = 0
        self.right_missed  = 0
        self.left_breach   = 0
        self.right_breach  = 0

    # ── Helpers ───────────────────────────────────────────────────────────────

    @staticmethod
    def _median_si(pairs: list):
        """Median (slope, intercept) from [(slope, intercept), ...].  None if empty."""
        if not pairs:
            return None
        arr = np.array(pairs, dtype=np.float64)
        return float(np.median(arr[:, 0])), float(np.median(arr[:, 1]))

    @staticmethod
    def _x_at_y(si: tuple, y: float):
        """Project x from (slope, intercept) at given y.  Returns float or None."""
        s, b = si
        return float((y - b) / s) if abs(s) > 1e-5 else None

    def _build_anchors(self, near_c, mid_c, far_c) -> np.ndarray | None:
        """
        Build a (3,2) anchor array from three zone candidate lists.

        Fallback chain:
          mid_si ← near_si  if mid zone is empty
          far_si ← mid_si   if far zone is empty
        This means on straight roads (or when far/mid segments are sparse)
        the line gracefully degrades to a straight projection of the near fit,
        rather than failing or hallucinating a bend.
        """
        near_si = self._median_si(near_c)
        if near_si is None:
            return None          # cannot build without at least the near zone

        mid_si = self._median_si(mid_c) or near_si
        far_si = self._median_si(far_c) or mid_si

        x_near = self._x_at_y(near_si, Y_NEAR)
        x_mid  = self._x_at_y(mid_si,  Y_MID)
        x_far  = self._x_at_y(far_si,  Y_FAR)

        if None in (x_near, x_mid, x_far):
            return None

        # Clamp to frame boundaries to prevent off-screen drawing artefacts
        clamp = lambda v: float(np.clip(v, 0, FRAME_W))
        return np.array([[clamp(x_near), Y_NEAR],
                         [clamp(x_mid),  Y_MID],
                         [clamp(x_far),  Y_FAR]], dtype=np.float32)

    def _gate_and_smooth(self, new_anch, stored, missed):
        """
        Apply physics gate, then EMA blend — or count a miss.
        Returns (updated_anchors, updated_missed_count).
        """
        # No detection this frame → coast on stored estimate
        if new_anch is None:
            missed += 1
            return (None, missed) if missed > self.MAX_MISSES else (stored, missed)

        # ── Physics gate ──────────────────────────────────────────────────────
        # Compare the newly detected near-anchor x to the stored near-anchor x.
        # A large sudden jump means the Hough median switched to an adjacent
        # lane line (lane change event).  Reject the update; hold old estimate.
        if stored is not None:
            jump = abs(new_anch[0, 0] - stored[0, 0])
            if jump > self.MAX_PIXEL_JUMP:
                # Reject this frame — the old estimate is deliberately held so
                # the departure alert can fire as the car crosses the boundary.
                missed += 1
                return (None, missed) if missed > self.MAX_MISSES else (stored, missed)

        # ── EMA blend ─────────────────────────────────────────────────────────
        if stored is None:
            return new_anch.copy(), 0
        blended = (1.0 - self.ALPHA) * stored + self.ALPHA * new_anch
        return blended.astype(np.float32), 0

    # ── Public update ──────────────────────────────────────────────────────────

    def update(self, lines, height: int):
        """
        Classify each Hough segment into (left/right) × (near/mid/far) by
        slope sign and midpoint-y, build piecewise anchors, apply gate + EMA.
        """
        l_near, l_mid, l_far = [], [], []
        r_near, r_mid, r_far = [], [], []

        if lines is not None:
            for seg in lines:
                x1, y1, x2, y2 = seg[0]
                if x1 == x2:
                    continue
                slope     = (y2 - y1) / (x2 - x1)
                intercept = y1 - slope * x1
                mid_y     = (y1 + y2) / 2.0

                if -2.5 < slope < -0.3:
                    if mid_y > ZONE_NEAR_THRESH:
                        l_near.append((slope, intercept))
                    elif mid_y < ZONE_FAR_THRESH:
                        l_far.append((slope, intercept))
                    else:
                        l_mid.append((slope, intercept))

                elif 0.3 < slope < 2.5:
                    if mid_y > ZONE_NEAR_THRESH:
                        r_near.append((slope, intercept))
                    elif mid_y < ZONE_FAR_THRESH:
                        r_far.append((slope, intercept))
                    else:
                        r_mid.append((slope, intercept))

        l_new = self._build_anchors(l_near, l_mid, l_far)
        r_new = self._build_anchors(r_near, r_mid, r_far)

        self.left_anchors,  self.left_missed  = \
            self._gate_and_smooth(l_new, self.left_anchors,  self.left_missed)
        self.right_anchors, self.right_missed = \
            self._gate_and_smooth(r_new, self.right_anchors, self.right_missed)

        return self.left_anchors, self.right_anchors


tracker = PiecewiseLaneTracker()


# ── 3. ROI mask (pre-built once) ──────────────────────────────────────────────
# Identical trapezoid to the original code
_roi_mask = np.zeros((FRAME_H, FRAME_W), np.uint8)
cv2.fillPoly(_roi_mask, [np.array([
    (80,          FRAME_H),
    (FRAME_W-80,  FRAME_H),
    (FRAME_W-220, int(FRAME_H * 0.55)),
    (220,         int(FRAME_H * 0.55)),
], np.int32)], 255)


# ── 4. Core Vision ────────────────────────────────────────────────────────────
def process_frame(frame):
    bgr    = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    height, width = bgr.shape[:2]
    car_cx = width // 2

    # Sobel-X on HLS L-channel (same as original — unchanged)
    hls    = cv2.cvtColor(bgr, cv2.COLOR_BGR2HLS)
    l_ch   = hls[:, :, 1]
    sobelx = np.absolute(cv2.Sobel(l_ch, cv2.CV_64F, 1, 0, ksize=3))
    peak   = sobelx.max()
    # FIX: original code divides by max without checking for zero → crash on
    # blank frames.  Guard added here.
    scaled = np.uint8(255.0 * sobelx / peak) if peak > 0 else np.zeros_like(l_ch)
    _, binary = cv2.threshold(scaled, 40, 255, cv2.THRESH_BINARY)
    masked    = cv2.bitwise_and(binary, _roi_mask)

    # Hough line extraction (parameters identical to original)
    lines = cv2.HoughLinesP(masked, 1, np.pi/180, 25,
                             minLineLength=25, maxLineGap=60)
    l_anch, r_anch = tracker.update(lines, height)

    # ── 5. Departure Logic ────────────────────────────────────────────────────
    CRITICAL_DISTANCE = 90
    status_text  = "ON THE LANE"
    status_color = (0, 220, 0)

    if l_anch is not None:
        pts = l_anch.astype(int)
        left_base_x = pts[0, 0]   # near-anchor x — closest to car

        # ── Piecewise drawing: segment 1 (near→mid) then segment 2 (mid→far) ──
        # Thicker near segment (most meaningful), thinner far segment.
        cv2.line(bgr, tuple(pts[0]), tuple(pts[1]), (255, 150, 0), 4, cv2.LINE_AA)
        cv2.line(bgr, tuple(pts[1]), tuple(pts[2]), (255, 150, 0), 2, cv2.LINE_AA)
        # Bend-point dot marks where the two segments join
        cv2.circle(bgr, tuple(pts[1]), 6, (0, 220, 255), -1)

        # Departure: left line's base x is too close to (or right of) car centre
        if car_cx - left_base_x < CRITICAL_DISTANCE:
            tracker.left_breach += 1
        else:
            tracker.left_breach = max(0, tracker.left_breach - 1)

    if r_anch is not None:
        pts = r_anch.astype(int)
        right_base_x = pts[0, 0]

        cv2.line(bgr, tuple(pts[0]), tuple(pts[1]), (0, 150, 255), 4, cv2.LINE_AA)
        cv2.line(bgr, tuple(pts[1]), tuple(pts[2]), (0, 150, 255), 2, cv2.LINE_AA)
        cv2.circle(bgr, tuple(pts[1]), 6, (0, 220, 255), -1)

        if right_base_x - car_cx < CRITICAL_DISTANCE:
            tracker.right_breach += 1
        else:
            tracker.right_breach = max(0, tracker.right_breach - 1)

    # Alert state (identical logic to original)
    if tracker.left_breach >= tracker.BREACH_THRESHOLD:
        status_text  = "WARN: LEFT DEPARTURE"
        status_color = (0, 140, 255)
    elif tracker.right_breach >= tracker.BREACH_THRESHOLD:
        status_text  = "CRIT: RIGHT DEPARTURE"
        status_color = (0, 0, 255)

    # Safety envelope overlay
    cv2.line(bgr, (car_cx - CRITICAL_DISTANCE, height),
                  (car_cx - CRITICAL_DISTANCE, height - 30), (200, 200, 200), 1)
    cv2.line(bgr, (car_cx + CRITICAL_DISTANCE, height),
                  (car_cx + CRITICAL_DISTANCE, height - 30), (200, 200, 200), 1)
    cv2.circle(bgr, (car_cx, height - 15), 6, (200, 200, 200), -1)
    cv2.putText(bgr, status_text, (20, 50),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, status_color, 2, cv2.LINE_AA)

    # ── 6. Diagnostic Split-Screen ────────────────────────────────────────────
    mask_bgr = cv2.cvtColor(masked, cv2.COLOR_GRAY2BGR)
    cv2.putText(mask_bgr, "SOBEL-X  |  PIECEWISE FIT  |  PHYSICS GATE", (10, 30),
                cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0, 255, 0), 1, cv2.LINE_AA)
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
    return Response(generate_video_stream(),
                    mimetype='multipart/x-mixed-replace; boundary=frame')


if __name__ == '__main__':
    print("[ DRIVORA SYSTEM ] Piecewise Physics-Gated Lane Tracker Online.")
    app.run(host='0.0.0.0', port=5000, debug=False)