from flask import Flask, Response
import cv2
import numpy as np
from picamera2 import Picamera2

app = Flask(__name__)

# --- 1. Hardware Initialization ---
picam2 = Picamera2()
config = picam2.create_preview_configuration({"size": (640, 480)})
config['framerate'] = 20  
picam2.configure(config)
picam2.start()
picam2.set_controls({"AfMode": 0, "LensPosition": 0.0}) # Infinity focus locked

# --- 2. The Spatiotemporal State Machine ---
class HybridLaneTracker:
    def __init__(self):
        self.left_line_mem = None
        self.right_line_mem = None
        self.alpha = 0.2  
        
        self.left_missed = 0
        self.right_missed = 0
        self.max_misses = 25  
        
        self.left_breach_counter = 0
        self.right_breach_counter = 0
        self.breach_threshold = 4  
        
        # --- NEW: Spatial Physics Lock ---
        # Maximum horizontal pixels a line can move in 1 frame (0.05 seconds).
        self.max_pixel_jump = 40 

    def filter_and_smooth(self, candidates, previous_mem, missed_count, height):
        if len(candidates) > 0:
            median_slope, median_intercept = np.median(candidates, axis=0)
            
            y1 = height - 10 
            y2 = int(height * 0.65) 
            x1 = int((y1 - median_intercept) / median_slope)
            x2 = int((y2 - median_intercept) / median_slope)
            new_line = np.array([x1, y1, x2, y2])
            
            # --- Delta-X Physics Check ---
            if previous_mem is not None:
                prev_base_x = previous_mem[0] 
                pixel_jump = abs(x1 - prev_base_x)
                
                # If the line jumps across the screen, it's snapping to a different lane.
                # Reject it and force the system to coast on the old memory into the danger zone.
                if pixel_jump > self.max_pixel_jump:
                    missed_count += 1
                    if missed_count > self.max_misses:
                        return None, missed_count
                    return previous_mem, missed_count
            
            # If the jump is physically possible, smoothly blend the new data
            if previous_mem is None:
                smoothed_line = new_line
            else:
                smoothed_line = (self.alpha * new_line) + ((1 - self.alpha) * previous_mem)
                
            return smoothed_line.astype(int), 0  
        else:
            # Coasting State (Faded paint or rejected lines)
            missed_count += 1
            if missed_count > self.max_misses:
                return None, missed_count
            return previous_mem, missed_count

    def update_lanes(self, lines, height):
        left_candidates = []
        right_candidates = []

        if lines is not None:
            for line in lines:
                x1, y1, x2, y2 = line[0]
                if x1 == x2: continue 
                slope = (y2 - y1) / (x2 - x1)
                intercept = y1 - slope * x1
                
                # Slope Constraints
                if -2.5 < slope < -0.3:
                    left_candidates.append((slope, intercept))
                elif 0.3 < slope < 2.5:
                    right_candidates.append((slope, intercept))

        self.left_line_mem, self.left_missed = self.filter_and_smooth(
            left_candidates, self.left_line_mem, self.left_missed, height)
        self.right_line_mem, self.right_missed = self.filter_and_smooth(
            right_candidates, self.right_line_mem, self.right_missed, height)

        return self.left_line_mem, self.right_line_mem

tracker = HybridLaneTracker()

# --- 3. Core Vision Logic ---
def process_frame(frame):
    bgr_frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
    height, width = bgr_frame.shape[:2]
    car_center = width // 2  
    
    # Isolate Lightness Channel & Apply Sobel-X
    hls = cv2.cvtColor(bgr_frame, cv2.COLOR_BGR2HLS)
    l_channel = hls[:, :, 1]
    
    sobelx = cv2.Sobel(l_channel, cv2.CV_64F, 1, 0, ksize=3)
    abs_sobelx = np.absolute(sobelx)
    scaled_sobel = np.uint8(255 * abs_sobelx / np.max(abs_sobelx))
    
    # Binary Threshold
    _, binary_sobel = cv2.threshold(scaled_sobel, 40, 255, cv2.THRESH_BINARY)
    
    # Aggressive ROI Tunnel
    mask = np.zeros_like(binary_sobel)
    polygon = np.array([[
        (80, height),                    
        (width - 80, height),            
        (width - 220, int(height * 0.55)), 
        (220, int(height * 0.55))        
    ]], np.int32)
    cv2.fillPoly(mask, polygon, 255)
    masked_edges = cv2.bitwise_and(binary_sobel, mask)
    
    # Vector Extraction
    lines = cv2.HoughLinesP(masked_edges, 1, np.pi/180, 25, minLineLength=25, maxLineGap=60)
    left_line, right_line = tracker.update_lanes(lines, height)
    
    # --- 4. Departure Logic & UI ---
    CRITICAL_DISTANCE = 90 
    status_text = "SYSTEM ACTIVE"
    status_color = (0, 255, 0)

    if left_line is not None:
        cv2.line(bgr_frame, (left_line[0], left_line[1]), (left_line[2], left_line[3]), (255, 150, 0), 4)
        if car_center - left_line[0] < CRITICAL_DISTANCE:
            tracker.left_breach_counter += 1
        else:
            tracker.left_breach_counter = max(0, tracker.left_breach_counter - 1)
            
    if right_line is not None:
        cv2.line(bgr_frame, (right_line[0], right_line[1]), (right_line[2], right_line[3]), (0, 150, 255), 4)
        if right_line[0] - car_center < CRITICAL_DISTANCE:
            tracker.right_breach_counter += 1
        else:
            tracker.right_breach_counter = max(0, tracker.right_breach_counter - 1)

    # State Machine Trigger
    if tracker.left_breach_counter >= tracker.breach_threshold:
        status_text = "WARN: LEFT DEPARTURE"
        status_color = (0, 140, 255) 
    elif tracker.right_breach_counter >= tracker.breach_threshold:
        status_text = "CRIT: RIGHT DEPARTURE"
        status_color = (0, 0, 255) 

    # Safety Envelope Overlay
    cv2.line(bgr_frame, (car_center - CRITICAL_DISTANCE, height), (car_center - CRITICAL_DISTANCE, height - 30), (255, 255, 255), 1)
    cv2.line(bgr_frame, (car_center + CRITICAL_DISTANCE, height), (car_center + CRITICAL_DISTANCE, height - 30), (255, 255, 255), 1)
    cv2.circle(bgr_frame, (car_center, height - 15), 6, (255, 255, 255), -1) 
    cv2.putText(bgr_frame, status_text, (20, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.8, status_color, 2)

    # --- 5. Diagnostic Split Screen ---
    mask_bgr = cv2.cvtColor(masked_edges, cv2.COLOR_GRAY2BGR)
    cv2.putText(mask_bgr, "SOBEL-X + DELTA-X PHYSICS LOCK", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
    stacked_output = np.vstack((bgr_frame, mask_bgr))
    
    return stacked_output

# --- 6. Server Implementation ---
def generate_video_stream():
    while True:
        raw_frame = picam2.capture_array()
        processed_frame = process_frame(raw_frame)
        ret, buffer = cv2.imencode('.jpg', processed_frame)
        yield (b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')

@app.route('/')
def video_feed():
    return Response(generate_video_stream(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == "__main__":
    print("[ DRIVORA SYSTEM ] Advanced Physics Tracker Online.")
    app.run(host='0.0.0.0', port=5000, debug=False)