import pygame
import serial

PORT = "COM6"   # change this
BAUD = 921600

ser = serial.Serial(PORT, BAUD, timeout=0.01)
ser.reset_input_buffer()

pygame.init()

WIDTH = 980
HEIGHT = 680
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Realtime CoG + Risk Monitor")

font_big = pygame.font.SysFont("arial", 28, bold=True)
font_med = pygame.font.SysFont("arial", 22)
font_small = pygame.font.SysFont("arial", 18)

clock = pygame.time.Clock()

plate_x = 60
plate_y = 70
plate_w = 500
plate_h = 500

center_x = plate_x + plate_w // 2
center_y = plate_y + plate_h // 2

scale = 8.0
dot_x = float(center_x)
dot_y = float(center_y)
visual_alpha = 0.45

pitch = 0.0
roll = 0.0
cogx = 0.0
cogy = 0.0
risk_score = 0.0
risk_code = 0
critical_roll = 30.0
critical_pitch = 20.0
acc_mag = 1.0

def risk_label(code: int) -> str:
    return ["SAFE", "CAUTION", "HIGH", "CRITICAL"][max(0, min(3, code))]

def risk_color(code: int):
    if code == 0:
        return (70, 210, 100)
    if code == 1:
        return (255, 210, 70)
    if code == 2:
        return (255, 140, 60)
    return (255, 70, 70)

running = True

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    while ser.in_waiting:
        try:
            line = ser.readline().decode(errors="ignore").strip()
            parts = line.split(",")

            if len(parts) == 9:
                pitch = float(parts[0])
                roll = float(parts[1])
                cogx = float(parts[2])
                cogy = float(parts[3])
                risk_score = float(parts[4])
                risk_code = int(parts[5])
                critical_roll = float(parts[6])
                critical_pitch = float(parts[7])
                acc_mag = float(parts[8])
        except:
            pass

    target_x = center_x + cogx * scale
    target_y = center_y - cogy * scale

    dot_x = visual_alpha * target_x + (1.0 - visual_alpha) * dot_x
    dot_y = visual_alpha * target_y + (1.0 - visual_alpha) * dot_y

    dot_x = max(plate_x + 12, min(plate_x + plate_w - 12, dot_x))
    dot_y = max(plate_y + 12, min(plate_y + plate_h - 12, dot_y))

    screen.fill((22, 24, 28))

    pygame.draw.rect(screen, (210, 210, 210), (plate_x, plate_y, plate_w, plate_h), 2)
    pygame.draw.line(screen, (80, 80, 80), (center_x, plate_y), (center_x, plate_y + plate_h), 1)
    pygame.draw.line(screen, (80, 80, 80), (plate_x, center_y), (plate_x + plate_w, center_y), 1)
    pygame.draw.circle(screen, (120, 120, 120), (center_x, center_y), 6)

    pygame.draw.circle(screen, (60, 100, 60), (center_x, center_y), 70, 1)
    pygame.draw.circle(screen, (120, 120, 60), (center_x, center_y), 130, 1)
    pygame.draw.circle(screen, (120, 70, 60), (center_x, center_y), 190, 1)

    color = risk_color(risk_code)
    pygame.draw.circle(screen, color, (int(dot_x), int(dot_y)), 14)

    pygame.draw.rect(screen, (38, 42, 48), (590, 50, 330, 570), border_radius=14)

    title = font_big.render("Risk Monitor", True, (235, 235, 235))
    screen.blit(title, (680, 80))

    risk_text = font_big.render(risk_label(risk_code), True, color)
    screen.blit(risk_text, (700, 130))

    items = [
        f"Pitch          : {pitch:7.2f} deg",
        f"Roll           : {roll:7.2f} deg",
        f"Critical pitch : {critical_pitch:7.2f} deg",
        f"Critical roll  : {critical_roll:7.2f} deg",
        f"Risk score     : {risk_score:7.3f}",
        f"Accel magnitude: {acc_mag:7.3f} g",
        f"CoG X          : {cogx:7.2f}",
        f"CoG Y          : {cogy:7.2f}",
    ]

    y = 195
    for item in items:
        txt = font_med.render(item, True, (220, 220, 220))
        screen.blit(txt, (615, y))
        y += 42

    bar_x, bar_y, bar_w, bar_h = 625, 540, 240, 24
    pygame.draw.rect(screen, (70, 70, 70), (bar_x, bar_y, bar_w, bar_h), border_radius=8)
    fill_w = int(bar_w * max(0.0, min(1.0, risk_score)))
    pygame.draw.rect(screen, color, (bar_x, bar_y, fill_w, bar_h), border_radius=8)

    caption = font_small.render("Realtime CoG proxy and IMU-only vehicle tilt-risk prototype", True, (180, 180, 180))
    screen.blit(caption, (60, 590))

    pygame.display.flip()
    clock.tick(240)

pygame.quit()
ser.close()