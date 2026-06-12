#!/usr/bin/env python3
"""
Drivora App Icon Generator — premium ADAS design.
Renders at 2× for SSAA, outputs 1024 × 1024 PNG.
Requires: pip install Pillow numpy
"""

import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# ── Constants ────────────────────────────────────────────────────────────────
R = 2048          # render size (2× super-sample)
OUT = 1024        # output size
CX = CY = R // 2 # canvas centre

# ── Colours (RGBA tuples) ────────────────────────────────────────────────────
BG_CENTRE  = (10, 14, 22)
BG_EDGE    = ( 4,  6, 10)
CYAN       = (  0, 229, 255)
AMBER      = (255, 176,  32)
CAR_BODY   = (235, 241, 255)
CAR_GLASS  = ( 38,  48,  70)
CAR_WHEEL  = ( 12,  18,  32)
CAR_ROOF   = ( 90, 110, 145)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

def arr2img(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA')


def composite(base: Image.Image, *layers: Image.Image) -> Image.Image:
    result = base.copy()
    for layer in layers:
        result = Image.alpha_composite(result, layer)
    return result


def glow_of(layer: Image.Image, radius: int, alpha_scale: float = 1.0) -> Image.Image:
    """Gaussian-blur a layer to make a glow copy."""
    blurred = layer.filter(ImageFilter.GaussianBlur(radius))
    if alpha_scale != 1.0:
        r, g, b, a = blurred.split()
        a = a.point(lambda x: int(x * alpha_scale))
        blurred = Image.merge('RGBA', (r, g, b, a))
    return blurred


# ═══════════════════════════════════════════════════════════════════════════════
# LAYER GENERATORS
# ═══════════════════════════════════════════════════════════════════════════════

def make_background() -> Image.Image:
    """Smooth radial dark-navy gradient."""
    y_idx, x_idx = np.mgrid[:R, :R]
    dist = np.sqrt((x_idx - CX) ** 2 + (y_idx - CY) ** 2) / (R * 0.5)
    dist = np.clip(dist, 0, 1)
    t = dist ** 0.6  # softer falloff

    arr = np.zeros((R, R, 4), dtype=np.float32)
    for ch, (c, e) in enumerate(zip(BG_CENTRE, BG_EDGE)):
        arr[:, :, ch] = c + (e - c) * t
    arr[:, :, 3] = 255
    return arr2img(arr)


def make_centre_glow() -> Image.Image:
    """Soft cyan radial glow pulsing from centre."""
    y_idx, x_idx = np.mgrid[:R, :R]
    dist = np.sqrt((x_idx - CX) ** 2 + (y_idx - CY) ** 2) / (R * 0.38)
    dist = np.clip(dist, 0, 1)
    falloff = np.exp(-2.8 * dist ** 1.4)

    arr = np.zeros((R, R, 4), dtype=np.float32)
    arr[:, :, 0] = 0
    arr[:, :, 1] = 120 * falloff
    arr[:, :, 2] = 180 * falloff
    arr[:, :, 3] = (55 * falloff).clip(0, 55)
    return arr2img(arr)


def make_circuit_traces() -> Image.Image:
    """Very subtle PCB-style traces in the four corners."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)
    col   = (*CYAN, 16)
    dot   = (*CYAN, 24)
    lw    = max(2, R // 400)

    margin = R // 6
    arm    = R // 11
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx = CX + sx * margin
            by = CY + sy * margin
            # horizontal arm
            draw.line([(bx, by), (bx + sx * arm, by)], fill=col, width=lw)
            # vertical arm
            draw.line([(bx + sx * arm, by), (bx + sx * arm, by + sy * arm)],
                      fill=col, width=lw)
            # extra branch
            mid_y = by + sy * arm // 2
            draw.line([(bx + sx * arm, mid_y), (bx + sx * arm + sx * arm // 2, mid_y)],
                      fill=col, width=lw)
            # terminal dot
            r = max(3, R // 170)
            px = bx + sx * arm
            py = by + sy * arm
            draw.ellipse([px - r, py - r, px + r, py + r], fill=dot)
            px2 = px + sx * arm // 2
            draw.ellipse([px2 - r, py - r - r // 2, px2 + r, py + r - r // 2], fill=dot)
    return layer


def make_hex_ring(radius_frac: float = 0.455, alpha: int = 45) -> Image.Image:
    """Thin hexagonal outline ring."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)
    rad   = int(R * radius_frac)
    lw    = max(3, R // 300)
    pts   = []
    for i in range(6):
        angle = math.radians(i * 60)  # pointy-top
        pts.append((CX + rad * math.cos(angle), CY + rad * math.sin(angle)))
    draw.polygon(pts, outline=(*CYAN, alpha), width=lw)
    return layer


def make_scanline_grid() -> Image.Image:
    """Extremely subtle diagonal scan-line grid filling the background."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)
    spacing = R // 38
    col = (*CYAN, 7)
    lw  = max(1, R // 1200)
    # Diagonal lines (45°)
    for i in range(-R, R * 2, spacing):
        draw.line([(i, 0), (i + R, R)], fill=col, width=lw)
    return layer


def make_outer_ring(radius_frac: float = 0.48, alpha: int = 55) -> Image.Image:
    """Thin perfect circle border."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)
    rad   = int(R * radius_frac)
    lw    = max(3, R // 280)
    draw.ellipse([CX - rad, CY - rad, CX + rad, CY + rad],
                 outline=(*CYAN, alpha), width=lw)
    return layer


def make_radar_arcs(front_y: int) -> Image.Image:
    """Three concentric forward-facing radar arcs."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)

    # arc parameters: (radius, alpha, line-width-factor)
    arcs = [
        (int(R * 0.125), 230, 5.0),  # closest — brightest
        (int(R * 0.205), 150, 3.5),
        (int(R * 0.295), 80,  2.5),
        (int(R * 0.390), 38,  2.0),
    ]
    # Sweep upward from car front: ~225° -> 315° (through 270° = north)
    start_a, end_a = 215, 325

    for radius, alpha, lw_f in arcs:
        r = radius
        lw = max(2, int(R / 480 * lw_f))
        x0, y0 = CX - r, front_y - r
        x1, y1 = CX + r, front_y + r
        draw.arc([x0, y0, x1, y1], start=start_a, end=end_a,
                 fill=(*CYAN, alpha), width=lw)
    return layer


def make_rear_glow(rear_y: int) -> Image.Image:
    """Soft amber elliptical glow behind the car."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)
    rw = int(R * 0.11)
    rh = int(R * 0.055)
    draw.ellipse([CX - rw, rear_y - rh // 2, CX + rw, rear_y + rh],
                 fill=(*AMBER, 80))
    return layer.filter(ImageFilter.GaussianBlur(int(R * 0.04)))


def make_car(car_cx: int, car_cy: int, cw: int, ch: int) -> Image.Image:
    """Clean, sharp top-view car silhouette."""
    layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    draw  = ImageDraw.Draw(layer)

    x0 = car_cx - cw // 2
    y0 = car_cy - ch // 2
    x1 = car_cx + cw // 2
    y1 = car_cy + ch // 2

    body_r   = max(5, cw // 7)
    hood_h   = int(ch * 0.18)
    trunk_h  = int(ch * 0.14)
    ws_h     = int(ch * 0.12)
    rw_h     = int(ch * 0.10)
    ws_inset = int(cw * 0.18)

    # ── Main body ────────────────────────────────────────────────────────────
    draw.rounded_rectangle(
        [x0, y0 + hood_h, x1, y1 - trunk_h],
        radius=body_r,
        fill=(*CAR_BODY, 235),
    )

    # ── Hood (tapered front) ────────────────────────────────────────────────
    hood_taper = cw // 5
    draw.polygon([
        (x0 + hood_taper,      y0),
        (x1 - hood_taper,      y0),
        (x1,                   y0 + hood_h),
        (x0,                   y0 + hood_h),
    ], fill=(*CAR_BODY, 210))

    # ── Trunk ───────────────────────────────────────────────────────────────
    trunk_taper = cw // 6
    draw.polygon([
        (x0 + trunk_taper,     y1),
        (x1 - trunk_taper,     y1),
        (x1,                   y1 - trunk_h),
        (x0,                   y1 - trunk_h),
    ], fill=(*CAR_BODY, 195))

    # ── Windshield ──────────────────────────────────────────────────────────
    draw.polygon([
        (x0 + ws_inset + cw // 14, y0 + hood_h),
        (x1 - ws_inset - cw // 14, y0 + hood_h),
        (x1 - ws_inset,            y0 + hood_h + ws_h),
        (x0 + ws_inset,            y0 + hood_h + ws_h),
    ], fill=(*CAR_GLASS, 215))

    # ── Rear window ─────────────────────────────────────────────────────────
    rw_top = y1 - trunk_h - rw_h
    draw.polygon([
        (x0 + ws_inset,            rw_top),
        (x1 - ws_inset,            rw_top),
        (x1 - ws_inset - cw // 14, rw_top + rw_h),
        (x0 + ws_inset + cw // 14, rw_top + rw_h),
    ], fill=(*CAR_GLASS, 215))

    # ── Roof panel (centre cabin) ────────────────────────────────────────────
    roof_y0 = y0 + hood_h + ws_h
    roof_y1 = rw_top
    roof_inset = int(cw * 0.22)
    draw.rounded_rectangle(
        [x0 + roof_inset, roof_y0, x1 - roof_inset, roof_y1],
        radius=max(3, cw // 12),
        fill=(*CAR_ROOF, 180),
    )

    # ── Wheels (4 corners) ──────────────────────────────────────────────────
    ww = int(cw * 0.30)
    wh = int(ch * 0.12)
    wheel_r = max(3, ww // 4)
    # offsets so wheels "bite" into body sides
    wx_off = cw // 2 - ww // 3
    wy_t   = y0 + int(ch * 0.20) - wh // 2   # front axle
    wy_b   = y1 - int(ch * 0.20) - wh // 2   # rear axle

    for wx in (car_cx - wx_off - ww // 2, car_cx + wx_off - ww // 2):
        for wy in (wy_t, wy_b):
            draw.rounded_rectangle(
                [wx, wy, wx + ww, wy + wh],
                radius=wheel_r,
                fill=(*CAR_WHEEL, 230),
            )
            # Tyre highlight
            hi_col = (60, 75, 100, 100)
            hw = ww // 4
            draw.rounded_rectangle(
                [wx + ww // 2 - hw // 2, wy + 2, wx + ww // 2 + hw // 2, wy + wh - 2],
                radius=max(2, hw // 3),
                fill=hi_col,
            )

    # ── Centre roof accent line ──────────────────────────────────────────────
    draw.line(
        [(car_cx, roof_y0 + (roof_y1 - roof_y0) // 4),
         (car_cx, roof_y1 - (roof_y1 - roof_y0) // 4)],
        fill=(170, 195, 240, 90), width=max(1, R // 700),
    )

    # ── Front badge dot ──────────────────────────────────────────────────────
    bd = max(4, cw // 10)
    badge_y = y0 + hood_h // 3
    draw.ellipse([car_cx - bd, badge_y - bd, car_cx + bd, badge_y + bd],
                 fill=(*CYAN, 200))
    # glow for badge
    glow_layer = Image.new('RGBA', (R, R), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    gd.ellipse([car_cx - bd, badge_y - bd, car_cx + bd, badge_y + bd],
               fill=(*CYAN, 130))
    layer = Image.alpha_composite(layer, glow_layer.filter(ImageFilter.GaussianBlur(bd * 3)))
    layer_draw = ImageDraw.Draw(layer)
    layer_draw.ellipse([car_cx - bd, badge_y - bd, car_cx + bd, badge_y + bd],
                       fill=(*CYAN, 200))

    return layer


def make_vignette(strength: float = 0.55) -> Image.Image:
    """Dark circular vignette to polish the edges."""
    y_idx, x_idx = np.mgrid[:R, :R]
    dist = np.sqrt((x_idx - CX) ** 2 + (y_idx - CY) ** 2) / (R * 0.5)
    dist = np.clip(dist - 0.45, 0, 1) / 0.55
    arr  = np.zeros((R, R, 4), dtype=np.float32)
    arr[:, :, 3] = (strength * 255 * dist ** 1.8).clip(0, 255)
    return arr2img(arr)


def make_top_highlight() -> Image.Image:
    """Subtle cool-blue directional rim light from the top."""
    arr = np.zeros((R, R, 4), dtype=np.float32)
    y_idx, _ = np.mgrid[:R, :R]
    t = np.clip(1.0 - y_idx / (R * 0.55), 0, 1) ** 3
    arr[:, :, 0] = 0
    arr[:, :, 1] = 35 * t
    arr[:, :, 2] = 80 * t
    arr[:, :, 3] = (28 * t).clip(0, 28)
    return arr2img(arr)


# ═══════════════════════════════════════════════════════════════════════════════
# COMPOSITION
# ═══════════════════════════════════════════════════════════════════════════════

def generate(output_path: str = 'assets/app_icon.png'):
    # ── Geometry ──────────────────────────────────────────────────────────────
    car_w     = int(R * 0.135)    # car width
    car_h     = int(R * 0.285)    # car height
    car_cx    = CX
    car_cy    = CY + int(R * 0.055)    # slightly below centre
    front_y   = car_cy - car_h // 2
    rear_y    = car_cy + car_h // 2

    print("Generating layers...")

    # ── Build layers ──────────────────────────────────────────────────────────
    bg         = make_background()
    ctr_glow   = make_centre_glow()
    grid       = make_scanline_grid()
    circuit    = make_circuit_traces()
    outer_ring = make_outer_ring()
    hex_ring   = make_hex_ring()
    rear_glow  = make_rear_glow(rear_y)
    arcs       = make_radar_arcs(front_y)
    car        = make_car(car_cx, car_cy, car_w, car_h)
    vignette   = make_vignette()
    highlight  = make_top_highlight()

    # ── Glow passes ───────────────────────────────────────────────────────────
    arcs_glow  = glow_of(arcs, R // 22, alpha_scale=0.55)
    car_glow   = glow_of(car,  R // 50, alpha_scale=0.45)
    ring_glow  = glow_of(outer_ring, R // 30, alpha_scale=0.60)
    hex_glow   = glow_of(hex_ring,   R // 28, alpha_scale=0.50)

    print("Compositing...")

    # ── Composite (back -> front) ───────────────────────────────────────────────
    final = composite(
        bg,
        ctr_glow,      # subtle centre warmth
        grid,          # faint scan lines
        circuit,       # corner PCB traces
        ring_glow,     # outer ring soft glow
        outer_ring,    # outer ring crisp
        hex_glow,      # hex soft glow
        hex_ring,      # hex crisp
        rear_glow,     # amber rear zone
        arcs_glow,     # radar soft glow
        arcs,          # radar arcs crisp
        car_glow,      # car soft aura
        car,           # car crisp
        highlight,     # directional rim light
        vignette,      # edge darkening
    )

    # ── Downsample 2× -> 1× for SSAA ──────────────────────────────────────────
    print(f"Downsampling {R}->{OUT}...")
    final_out = final.resize((OUT, OUT), Image.LANCZOS)

    # ── Convert to RGB for Play Store / launcher (no alpha needed) ────────────
    bg_solid = Image.new('RGB', (OUT, OUT), (4, 6, 10))
    bg_solid.paste(final_out, mask=final_out.split()[3])
    bg_solid.save(output_path, 'PNG', optimize=True)
    print(f"[OK]  Icon saved -> {output_path}")

    # ── Also save transparent foreground for adaptive icon ────────────────────
    fg_path = output_path.replace('app_icon', 'app_icon_foreground')
    final_out.save(fg_path, 'PNG', optimize=True)
    print(f"[OK]  Foreground saved -> {fg_path}")

    # ── Adaptive background (solid dark gradient, no elements) ────────────────
    bg_img = make_background().resize((OUT, OUT), Image.LANCZOS)
    bg_path = output_path.replace('app_icon', 'app_icon_background')
    bg_rgb = Image.new('RGB', (OUT, OUT))
    bg_rgb.paste(bg_img.convert('RGB'))
    bg_rgb.save(bg_path, 'PNG', optimize=True)
    print(f"[OK]  Background saved -> {bg_path}")


if __name__ == '__main__':
    import os, sys
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate('assets/app_icon.png')
    print("\nAll done! Run flutter_launcher_icons next.")
