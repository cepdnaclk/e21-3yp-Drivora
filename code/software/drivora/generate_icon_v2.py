#!/usr/bin/env python3
"""
Drivora App Icon v2 — Premium side-profile 3D car.
Metallic paint, specular highlight strip, glowing headlight/taillight,
ground reflection, dramatic dark background.
Renders at 2048px (SSAA), outputs 1024px PNG.
Requires: Pillow  numpy  scipy
"""
import math, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

# ── constants ────────────────────────────────────────────────────────────────
R   = 2048        # render resolution
OUT = 1024        # output resolution
CX  = CY = R // 2
S   = 2           # scale factor: coords below are at 1024, multiply by S

def p(*pts):
    """Scale 1024-space coords to render space."""
    if len(pts) == 2 and isinstance(pts[0], (int, float)):
        return (int(pts[0] * S), int(pts[1] * S))
    return [(int(x * S), int(y * S)) for x, y in pts]

# ── bezier helpers ────────────────────────────────────────────────────────────
def cubic(p0, p1, p2, p3, n=120):
    t  = np.linspace(0, 1, n)
    mt = 1 - t
    xs = mt**3*p0[0] + 3*mt**2*t*p1[0] + 3*mt*t**2*p2[0] + t**3*p3[0]
    ys = mt**3*p0[1] + 3*mt**2*t*p1[1] + 3*mt*t**2*p2[1] + t**3*p3[1]
    return list(zip(xs.tolist(), ys.tolist()))

def quad(p0, p1, p2, n=80):
    t  = np.linspace(0, 1, n)
    mt = 1 - t
    xs = mt**2*p0[0] + 2*mt*t*p1[0] + t**2*p2[0]
    ys = mt**2*p0[1] + 2*mt*t*p1[1] + t**2*p2[1]
    return list(zip(xs.tolist(), ys.tolist()))

def sp(pts):
    """Scale a list of raw (x,y) tuples from 1024 to 2048 space."""
    return [(x * S, y * S) for x, y in pts]

# ── car outline (designed at 1024×1024) ───────────────────────────────────────
# Left-facing sports sedan.  Wheel centres: front=(255,715) rear=(780,715) r=110
def car_outline():
    pts = []
    # Front bumper lower nose
    pts += quad((75,672),(62,610),(68,540))
    # Lower grille / bumper face
    pts += quad((68,540),(72,474),(90,438))
    # Hood front edge upward
    pts += quad((90,438),(100,418),(115,405))
    # Hood sweeping back
    pts += cubic((115,405),(210,372),(360,347),(485,338))
    # Windshield base
    pts += [(485,338)]
    # A-pillar (steep rake)
    pts += cubic((485,338),(510,330),(540,300),(572,262))
    # Roof leading edge
    pts += cubic((572,262),(595,244),(628,236),(680,232))
    # Flat roofline
    pts += cubic((680,232),(740,228),(810,228),(878,234))
    # C-pillar / rear window
    pts += cubic((878,234),(916,242),(950,270),(968,328))
    # Trunk lid
    pts += cubic((968,328),(978,380),(980,432),(975,474))
    # Rear bumper upper face
    pts += cubic((975,474),(972,528),(970,585),(965,638))
    # Rear bumper lower curve
    pts += quad((965,638),(960,668),(942,688))
    # Boot bottom / sill to rear wheel
    pts += quad((942,688),(900,698),(850,700))
    # rear wheel well (rear)
    pts += quad((850,700),(828,705),(810,712))
    # skip wheel — continue at front of rear well
    pts += quad((650,712),(632,705),(610,700))
    # rocker panel centre
    pts += [(400,700)]
    # front wheel well (rear edge)
    pts += quad((400,700),(380,705),(362,712))
    # skip wheel — continue at rear of front well
    pts += quad((148,712),(130,705),(112,695))
    # front lower sill back to bumper base
    pts += quad((112,695),(88,688),(75,672))
    return pts

# ── helper to fill a shape with a numpy gradient ──────────────────────────────
def gradient_fill(size, shape_pts, color_fn):
    """
    Draw filled polygon then apply color_fn per-pixel (vectorised).
    color_fn(xx, yy) -> (R,G,B) arrays of float32.
    Returns RGBA Image.
    """
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).polygon(shape_pts, fill=255)
    arr  = np.frombuffer(mask.tobytes(), np.uint8).reshape(size, size)
    yy, xx = np.mgrid[:size, :size]
    r, g, b = color_fn(xx.astype(np.float32), yy.astype(np.float32))
    rgba = np.zeros((size, size, 4), np.uint8)
    rgba[:,:,0] = np.clip(r, 0, 255).astype(np.uint8)
    rgba[:,:,1] = np.clip(g, 0, 255).astype(np.uint8)
    rgba[:,:,2] = np.clip(b, 0, 255).astype(np.uint8)
    rgba[:,:,3] = arr
    return Image.fromarray(rgba, 'RGBA')

def composite(base, *layers):
    out = base.copy()
    for L in layers:
        out = Image.alpha_composite(out, L)
    return out

def glow(img, radius, scale=1.0):
    b = img.filter(ImageFilter.GaussianBlur(radius))
    if scale != 1.0:
        r,g,b2,a = b.split()
        a = a.point(lambda v: int(v * scale))
        b = Image.merge('RGBA', (r,g,b2,a))
    return b

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  LAYER FUNCTIONS                                                          ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

def make_background():
    y, x = np.mgrid[:R, :R]
    d = np.sqrt((x-CX)**2 + (y-CY)**2) / (R*0.52)
    d = np.clip(d, 0, 1) ** 0.65
    arr = np.zeros((R, R, 4), np.float32)
    # deep navy centre → near-black edge
    arr[:,:,0] = 9  * (1-d) + 3  * d
    arr[:,:,1] = 13 * (1-d) + 4  * d
    arr[:,:,2] = 24 * (1-d) + 9  * d
    arr[:,:,3] = 255
    return Image.fromarray(arr.clip(0,255).astype(np.uint8), 'RGBA')


def make_floor_glow(car_bottom_y):
    """Soft elliptical light pool under the car."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)
    cy    = car_bottom_y * S
    rx, ry = int(R*0.40), int(R*0.05)
    draw.ellipse([CX-rx, cy-ry, CX+rx, cy+ry], fill=(0,200,255,18))
    return layer.filter(ImageFilter.GaussianBlur(int(R*0.04)))


def make_ground_reflection(car_pts_scaled, car_bottom_y, flip_height=160):
    """Mirror the car body below the ground line, faded out."""
    # Draw car silhouette
    sil = Image.new('RGBA', (R, R), (0,0,0,0))
    ImageDraw.Draw(sil).polygon(car_pts_scaled, fill=(14,45,90, 160))

    base_y = car_bottom_y * S
    # Flip vertically around base_y
    cropped = sil.crop((0, 0, R, base_y))
    flipped = cropped.transpose(Image.FLIP_TOP_BOTTOM)
    ref = Image.new('RGBA', (R, R), (0,0,0,0))
    ref.paste(flipped, (0, base_y))

    # Fade to transparent going downward
    fade_arr = np.zeros((R, R, 4), np.float32)
    y_idx = np.arange(R, dtype=np.float32)
    fade_t = np.clip((y_idx - base_y) / (flip_height * S), 0, 1)
    fade_mask = (1 - fade_t) ** 2.5  # ramp
    r2,g2,b2,a2 = ref.split()
    a2_arr = np.frombuffer(a2.tobytes(), np.uint8).reshape(R, R).astype(np.float32)
    a2_arr = (a2_arr * fade_mask[:, None] * 0.35).clip(0, 255).astype(np.uint8)
    ref = Image.merge('RGBA', (r2, g2, b2, Image.fromarray(a2_arr, 'L')))
    return ref.filter(ImageFilter.GaussianBlur(4))


def make_car_body(car_pts_scaled):
    """
    Metallic deep-blue paint with vertical gradient.
    Bottom dark, middle-upper medium, a crisp specular 'light-sweep' near top.
    """
    # ── mask ──────────────────────────────────────────────────────────────────
    mask_img = Image.new('L', (R, R), 0)
    ImageDraw.Draw(mask_img).polygon(car_pts_scaled, fill=255)
    mask = np.frombuffer(mask_img.tobytes(), np.uint8).reshape(R, R)

    y_idx, x_idx = np.mgrid[:R, :R]

    # ── vertical gradient (base paint) ─────────────────────────────────────
    # car vertical span roughly y=464..1400 at 2048 scale
    y_norm = np.clip((y_idx - 464) / (1400 - 464), 0, 1)   # 0=top 1=bottom

    # base colour: dark navy at bottom, richer blue towards top
    base_r = 8  + 18 * (1 - y_norm)
    base_g = 18 + 38 * (1 - y_norm)
    base_b = 38 + 80 * (1 - y_norm)

    # mid-body reflective band (slightly lighter, simulating environmental light)
    # peaks around y_norm = 0.35
    mid_t = np.exp(-((y_norm - 0.35) ** 2) / 0.025) * 0.5
    base_r += mid_t * 22
    base_g += mid_t * 50
    base_b += mid_t * 100

    # ── specular highlight stripe ───────────────────────────────────────────
    # A narrow bright band running diagonally along the upper body crease.
    # Modelled as a thin band in (rotated) car-space:
    # In screen space, the highlight runs roughly from
    #   front-upper (130,860) to rear-upper (1760,468).
    # We parameterise distance from that line.
    # Line direction: dx=1630, dy=-392  → normal: (392, 1630)/|...|
    lx0, ly0 = 130 * S, 860 * S   # front point
    lx1, ly1 = 1760* S, 468 * S   # rear point
    ldx, ldy = lx1 - lx0, ly1 - ly0
    llen = math.sqrt(ldx**2 + ldy**2)
    nx, ny = -ldy / llen, ldx / llen   # unit normal (pointing 'up' from line)

    # signed distance of each pixel from the highlight line
    dist_spec = (x_idx - lx0) * nx + (y_idx - ly0) * ny

    # Primary specular: width ~35px at render scale
    spec1 = np.exp(-(dist_spec ** 2) / (35 * S)**2)
    # Secondary softer rim
    spec2 = np.exp(-((dist_spec - 28*S) ** 2) / (55 * S)**2) * 0.3

    spec = (spec1 + spec2).clip(0, 1)

    # Only apply specular within the car mask
    spec_r = base_r + spec * 190
    spec_g = base_g + spec * 210
    spec_b = base_b + spec * 235

    # ── build RGBA ─────────────────────────────────────────────────────────
    arr = np.zeros((R, R, 4), np.float32)
    arr[:,:,0] = spec_r
    arr[:,:,1] = spec_g
    arr[:,:,2] = spec_b
    arr[:,:,3] = mask.astype(np.float32)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), 'RGBA')


def make_windows(car_pts_scaled, car_bottom_y):
    """Dark tinted glass panels with a subtle sky reflection line."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)

    # Windshield polygon (1024 coords → scale)
    ws = p((485,338),(572,262),(680,232),(680,350),(580,365),(530,360),(490,355))
    draw.polygon(ws, fill=(8,16,28,220))

    # Side window (between A/B/C pillars) — approximated as a polygon
    sw = p((572,262),(878,234),(968,328),(960,345),(868,255),(580,265))
    draw.polygon(sw, fill=(6,13,24,210))

    # Quarter window (small rear triangle)
    qw = p((878,234),(920,252),(968,328),(960,345),(868,255))
    draw.polygon(qw, fill=(5,11,22,220))

    # Glass highlight (sky reflection — thin bright line near top of windshield)
    wsh_pts = p((495,345),(548,296),(590,268),(628,252))
    for i in range(len(wsh_pts)-1):
        draw.line([wsh_pts[i], wsh_pts[i+1]], fill=(160,200,240,55), width=max(2, R//320))

    return layer


def make_car_outline_stroke(car_pts_scaled):
    """Thin dark outline so the car reads crisply against the background."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)
    draw.polygon(car_pts_scaled, outline=(2,8,18,200), width=max(3, R//340))
    return layer


def make_wheels(fw_cx, fw_cy, rw_cx, rw_cy, radius):
    """Each wheel: dark tyre → chrome rim → dark hub → cyan centre dot."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)

    for cx, cy in [(fw_cx*S, fw_cy*S), (rw_cx*S, rw_cy*S)]:
        r  = radius * S
        # Tyre shadow (ellipse slightly taller for 3D tilt illusion)
        draw.ellipse([cx-r-3, cy-r*0.92, cx+r+3, cy+r*1.08],
                     fill=(4, 6, 10, 230))
        # Tyre body
        draw.ellipse([cx-r, cy-r*0.90, cx+r, cy+r*1.05],
                     fill=(14, 16, 20, 255))
        # Tyre highlight (top subtle shine)
        th = int(r * 0.18)
        draw.ellipse([cx - int(r*0.7), cy - int(r*0.82),
                      cx + int(r*0.7), cy - int(r*0.82) + th*2],
                     fill=(42, 48, 56, 90))
        # Rim outer ring (chrome)
        ri = int(r * 0.73)
        draw.ellipse([cx-ri, cy-int(ri*0.88), cx+ri, cy+int(ri*1.02)],
                     fill=(148, 162, 178, 255))
        # Rim mid ring
        rm = int(r * 0.60)
        draw.ellipse([cx-rm, cy-int(rm*0.88), cx+rm, cy+int(rm*1.02)],
                     fill=(22, 28, 38, 255))

        # 5-spoke pattern (rotated ellipses → approximated as thin rects)
        spoke_r  = int(r * 0.64)
        spoke_w  = max(4, int(r * 0.12))
        spoke_h  = int(spoke_r * 1.80)
        for angle_deg in range(0, 360, 72):
            ang = math.radians(angle_deg)
            sx  = cx + int(spoke_r * 0.45 * math.sin(ang))
            sy  = cy + int(spoke_r * 0.45 * math.cos(ang) * 0.88)
            spoke_img = Image.new('RGBA', (R, R), (0,0,0,0))
            sd = ImageDraw.Draw(spoke_img)
            sd.rectangle([sx - spoke_w//2, sy - spoke_h//2,
                           sx + spoke_w//2, sy + spoke_h//2],
                          fill=(142, 158, 172, 255))
            spoke_rot = spoke_img.rotate(-angle_deg, center=(cx, cy))
            # Clip to rim circle
            rim_mask = Image.new('L', (R, R), 0)
            ImageDraw.Draw(rim_mask).ellipse([cx-ri, cy-int(ri*0.88),
                                              cx+ri, cy+int(ri*1.02)], fill=255)
            layer = Image.alpha_composite(layer,
                     Image.composite(spoke_rot, Image.new('RGBA',(R,R),(0,0,0,0)), rim_mask))

        # Hub cap (chrome centre circle)
        hc = int(r * 0.22)
        draw.ellipse([cx-hc, cy-int(hc*0.88), cx+hc, cy+int(hc*1.02)],
                     fill=(180, 195, 210, 255))
        # Hub centre dot (cyan)
        hd = int(r * 0.08)
        draw.ellipse([cx-hd, cy-hd, cx+hd, cy+hd], fill=(0, 229, 255, 255))

    return layer


def make_headlight(x, y, width, height):
    """DRL/LED strip headlight — bright cyan."""
    layer  = Image.new('RGBA', (R, R), (0,0,0,0))
    draw   = ImageDraw.Draw(layer)
    # Housing (dark recess)
    draw.rounded_rectangle(
        [x*S-10, y*S-8, (x+width)*S+10, (y+height)*S+8],
        radius=int(height*S*0.4), fill=(6, 10, 18, 220))
    # LED strip
    draw.rounded_rectangle(
        [x*S, y*S, (x+width)*S, (y+height)*S],
        radius=int(height*S*0.35), fill=(0, 229, 255, 255))
    # Inner bright core
    draw.rounded_rectangle(
        [x*S + height*S//2, y*S+2, (x+width)*S - height*S//2, (y+height)*S-2],
        radius=4, fill=(210, 245, 255, 255))
    return layer


def make_taillight(x, y, width, height):
    """Thin LED tail-light in red."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)
    draw.rounded_rectangle(
        [x*S-6, y*S-6, (x+width)*S+6, (y+height)*S+6],
        radius=int(height*S*0.4), fill=(8, 4, 4, 200))
    draw.rounded_rectangle(
        [x*S, y*S, (x+width)*S, (y+height)*S],
        radius=int(height*S*0.35), fill=(220, 20, 20, 255))
    # core
    draw.rounded_rectangle(
        [x*S+6, y*S+2, (x+width)*S-6, (y+height)*S-2],
        radius=4, fill=(255, 130, 130, 255))
    return layer


def make_door_lines(car_pts_scaled):
    """Subtle door gap / character line details."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)
    # Door gap (vertical line ~2/5 from front)
    draw.line([p(448,395), p(444,698)],
              fill=(3,8,18,130), width=max(2, R//600))
    # Character line (the horizontal crease across doors)
    crease = p((140,530),(250,510),(445,502),(640,508),(850,518),(970,545))
    for i in range(len(crease)-1):
        draw.line([crease[i], crease[i+1]], fill=(3,8,18,90), width=max(2, R//500))
    # Sill / rocker panel
    sill = p((112,685),(850,685))
    draw.line(sill, fill=(4,10,20,120), width=max(3, R//450))
    return layer


def make_grille(x, y, w, h):
    """Hexagonal mesh grille on the front bumper."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    draw  = ImageDraw.Draw(layer)
    # Outer bezel
    draw.rounded_rectangle(
        [x*S, y*S, (x+w)*S, (y+h)*S],
        radius=int(h*S*0.2), fill=(6, 10, 18, 200))
    # Horizontal bars
    bar_col = (18, 28, 48, 200)
    n_bars  = 5
    for i in range(1, n_bars):
        by = y*S + int(h*S * i / n_bars)
        draw.line([(x*S+4, by), ((x+w)*S-4, by)], fill=bar_col, width=max(1, R//800))
    # Chrome frame
    draw.rounded_rectangle(
        [x*S, y*S, (x+w)*S, (y+h)*S],
        radius=int(h*S*0.2), outline=(80, 100, 130, 180), width=max(2, R//600))
    return layer


def make_ambient_glow():
    """Soft cyan bloom to the front of the car (headlight spill)."""
    layer = Image.new('RGBA', (R, R), (0,0,0,0))
    arr   = np.zeros((R, R, 4), np.float32)
    y_idx, x_idx = np.mgrid[:R, :R]
    # glow centred around headlight area: x≈140, y≈620 at 1024 → ×2
    gx, gy = 140*S, 555*S
    dist   = np.sqrt((x_idx-gx)**2 + (y_idx-gy)**2) / (R * 0.26)
    falloff= np.exp(-3.5 * dist ** 1.4).clip(0,1)
    arr[:,:,0] = 0   * falloff
    arr[:,:,1] = 160 * falloff
    arr[:,:,2] = 220 * falloff
    arr[:,:,3] = (45 * falloff).clip(0, 45)
    return Image.fromarray(arr.clip(0,255).astype(np.uint8),'RGBA')


def make_vignette(strength=0.60):
    y_idx, x_idx = np.mgrid[:R, :R]
    dist = np.sqrt((x_idx-CX)**2 + (y_idx-CY)**2) / (R*0.5)
    dist = np.clip(dist-0.42, 0, 1) / 0.58
    arr  = np.zeros((R, R, 4), np.float32)
    arr[:,:,3] = (strength * 255 * dist**2).clip(0, 255)
    return Image.fromarray(arr.clip(0,255).astype(np.uint8),'RGBA')


# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  MAIN COMPOSITION                                                         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

def generate(out_path='assets/app_icon.png'):
    print("Building car outline ...")
    raw_pts = car_outline()
    car_pts = sp(raw_pts)

    # Wheel geometry (1024 space)
    fw_cx, fw_cy, fw_r  = 255, 715, 110    # front wheel
    rw_cx, rw_cy, rw_r  = 780, 715, 110    # rear wheel
    car_bottom_y        = 718               # floor level (1024)

    print("Rendering layers ...")
    bg       = make_background()
    floor_g  = make_floor_glow(car_bottom_y)
    refl     = make_ground_reflection(car_pts, car_bottom_y)
    body     = make_car_body(car_pts)
    windows  = make_windows(car_pts, car_bottom_y)
    outline  = make_car_outline_stroke(car_pts)
    door     = make_door_lines(car_pts)
    wheels   = make_wheels(fw_cx, fw_cy, rw_cx, rw_cy, fw_r)
    # Headlight: a slim DRL strip just above the bumper front corner
    hl       = make_headlight(78, 488, 28, 11)
    # Taillight: slim strip at rear
    tl       = make_taillight(958, 472, 16, 55)
    grille   = make_grille(68, 518, 24, 90)
    amb      = make_ambient_glow()
    vign     = make_vignette()

    # Glow layers
    hl_glow  = glow(hl, R//22, 0.70)
    tl_glow  = glow(tl, R//28, 0.55)
    body_aura= glow(body, R//55, 0.30)

    print("Compositing ...")
    final = composite(
        bg,
        floor_g,
        refl,
        body_aura,     # soft aura around body
        body,
        door,
        windows,
        outline,
        grille,
        amb,           # headlight ambient spill (under hl)
        hl_glow,
        hl,
        tl_glow,
        tl,
        wheels,
        vign,
    )

    print(f"Downsampling {R} -> {OUT} ...")
    out_img = final.resize((OUT, OUT), Image.LANCZOS)

    # Save flat RGB for Play Store / mipmap
    bg_solid = Image.new('RGB', (OUT, OUT), (5, 7, 14))
    bg_solid.paste(out_img, mask=out_img.split()[3])
    bg_solid.save(out_path, 'PNG', optimize=True)
    print(f"[OK] Saved {out_path}")

    # Foreground (transparent bg) for adaptive icon
    fg_path = out_path.replace('app_icon', 'app_icon_foreground')
    out_img.save(fg_path, 'PNG', optimize=True)
    print(f"[OK] Saved {fg_path}")

    # Background layer (solid gradient)
    bg_img = make_background().resize((OUT, OUT), Image.LANCZOS).convert('RGB')
    bg_path = out_path.replace('app_icon', 'app_icon_background')
    bg_img.save(bg_path, 'PNG', optimize=True)
    print(f"[OK] Saved {bg_path}")

    print("Done! Re-run flutter_launcher_icons to install.")

if __name__ == '__main__':
    import os
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    generate('assets/app_icon.png')
