"""
Generate animated GIFs for all gym exercises — LIFTA-style:
muscular body silhouette, amber/gold muscle highlight, dark background.
"""

import math, shutil, os
from PIL import Image, ImageDraw

# ─── palette ───────────────────────────────────────────────────────────────
BG          = (14,  14,  16)
BODY        = (170, 170, 190)
BODY_SH     = (100, 100, 115)
ACTIVE      = (255, 185,  30)
ACTIVE_SH   = (200, 130,  15)
BENCH_COL   = ( 80,  60,  40)
BAR_COL     = (200, 200, 210)
WHITE       = (255, 255, 255)
GOLD_TEXT   = (255, 185,  30)

SIZE        = 320
FRAMES      = 28
DURATION    = 55      # ms per frame

# ─── output dirs ───────────────────────────────────────────────────────────
OUT_DIRS = [
    r"C:\Users\Gianmarco\app\miadiariogym\app_cliente\assets\gif",
    r"C:\Users\Gianmarco\app\miadiariogym\app_pt\assets\gif",
]

# ─── muscle → body region (cx, cy, rx, ry) ────────────────────────────────
# Front-view coordinates (standing figure centred in 320x320)
MUSCLE_REGIONS = {
    'chest':      [(155, 128, 32, 20), (165, 128, -32, 20)],
    'back':       [(153, 133, 18, 26), (167, 133, -18, 26)],
    'shoulders':  [(112,  98,  0, 15), (208,  98,   0, 15)],
    'biceps':     [(105, 148,  0, 13), (215, 148,   0, 13)],
    'triceps':    [(104, 150,  0, 13), (216, 150,   0, 13)],
    'quads':      [(137, 228,  0, 17), (183, 228,   0, 17)],
    'hamstrings': [(137, 232,  0, 15), (183, 232,   0, 15)],
    'glutes':     [(148, 198, 12, 18), (172, 198, -12, 18)],
    'calves':     [(138, 274,  0, 11), (182, 274,   0, 11)],
    'abs':        [(160, 160,  0, 30)],
}

# ─── helper: smooth oscillation ────────────────────────────────────────────
def osc(t, lo, hi):
    """Smooth 0→1→0 oscillation between lo and hi."""
    return lo + (hi - lo) * (0.5 - 0.5 * math.cos(t * 2 * math.pi))

# ─── helper: draw a shaded ellipse ─────────────────────────────────────────
def draw_ellipse(d, cx, cy, rx, ry, active=False, angle=0):
    fill  = ACTIVE    if active else BODY
    shade = ACTIVE_SH if active else BODY_SH
    x0, y0, x1, y1 = cx - rx, cy - ry, cx + rx, cy + ry
    d.ellipse([x0, y0, x1, y1], fill=shade)
    shrink = max(2, min(rx, ry) // 3)
    d.ellipse([x0 + shrink, y0 + shrink, x1 - shrink, y1 - shrink], fill=fill)

def draw_rect(d, cx, cy, w, h, active=False):
    fill  = ACTIVE    if active else BODY
    shade = ACTIVE_SH if active else BODY_SH
    x0, y0 = cx - w//2, cy - h//2
    d.rectangle([x0, y0, x0+w, y0+h], fill=shade)
    s = 3
    d.rectangle([x0+s, y0+s, x0+w-s, y0+h-s], fill=fill)

# ─── full standing body (front view) ───────────────────────────────────────
def draw_standing_body(d, muscles, dy=0,
                       l_arm_ang=0, r_arm_ang=0,
                       l_fore_ang=None, r_fore_ang=None,
                       l_leg_ang=0, r_leg_ang=0,
                       l_low_ang=None, r_low_ang=None,
                       squat_t=0.0):
    """
    dy      = vertical shift (for squat)
    *_ang   = angle in degrees from vertical (+ = outward)
    squat_t = 0..1 squat fraction
    """
    act = set(muscles)
    sq  = squat_t

    # --- bench / platform ---------------------------------------------------
    cy_head   = int(70  + dy)
    cy_neck   = int(88  + dy)
    cy_chest  = int(125 + dy)
    cy_belly  = int(155 + dy)
    cy_hips   = int(178 + dy)
    cy_thigh  = int(213 + dy + sq*20)
    cy_knee   = int(238 + dy + sq*30)
    cy_shin   = int(263 + dy + sq*10)
    cy_foot   = int(285 + dy)

    cx = 160

    # legs
    leg_spread = 22
    for side, sx, la, lla in [(-1, cx - leg_spread, l_leg_ang, l_low_ang),
                                ( 1, cx + leg_spread, r_leg_ang, r_low_ang)]:
        ll = lla if lla is not None else la
        lx = int(sx + math.sin(math.radians(la)) * 40)
        # thigh
        active_leg = ('quads' in act) or ('hamstrings' in act) or ('glutes' in act)
        draw_ellipse(d, sx, cy_thigh, 16, 28, active=active_leg)
        # knee
        draw_ellipse(d, lx, cy_knee, 12, 12)
        # shin
        sx2 = int(lx + math.sin(math.radians(ll)) * 30)
        active_calf = 'calves' in act
        draw_ellipse(d, sx2, cy_shin, 11, 22, active=active_calf)
        # foot
        d.ellipse([sx2-14, cy_foot-6, sx2+14, cy_foot+6], fill=BODY_SH)

    # torso
    active_chest  = 'chest'  in act
    active_back   = 'back'   in act
    active_abs    = 'abs'    in act
    active_glutes = 'glutes' in act

    draw_ellipse(d, cx, cy_chest, 38, 32, active=active_chest or active_back)
    draw_ellipse(d, cx, cy_belly, 28, 20, active=active_abs)
    draw_ellipse(d, cx, cy_hips,  32, 18, active=active_glutes)

    # arms
    arm_spread = 38
    for side, ax, ua, ufa in [(-1, cx - arm_spread, l_arm_ang, l_fore_ang),
                                ( 1, cx + arm_spread, r_arm_ang, r_fore_ang)]:
        ufa2 = ufa if ufa is not None else ua
        cy_shoulder = int(99 + dy)
        cy_elbow    = int(cy_shoulder + 42)
        ex = int(ax + math.sin(math.radians(ua)) * 42)
        ey = int(cy_elbow - math.cos(math.radians(ua)) * 5)
        fx = int(ex + math.sin(math.radians(ufa2)) * 35)
        fy = int(ey + 35)

        active_sh  = 'shoulders' in act
        active_bi  = 'biceps'    in act
        active_tri = 'triceps'   in act

        draw_ellipse(d, ax, cy_shoulder, 15, 14, active=active_sh)
        # upper arm
        draw_ellipse(d, ex, ey, 13, 20, active=active_bi or active_tri)
        # forearm
        draw_ellipse(d, fx, fy, 10, 18, active=active_bi)

    # neck + head
    draw_ellipse(d, cx, cy_neck, 10, 9)
    draw_ellipse(d, cx, cy_head, 22, 26)

# ─── new image helper ───────────────────────────────────────────────────────
def new_img():
    img = Image.new('RGB', (SIZE, SIZE), BG)
    return img, ImageDraw.Draw(img)

def label(d, text):
    try:
        from PIL import ImageFont
        font = ImageFont.truetype("arial.ttf", 14)
    except Exception:
        font = None
    if font:
        d.text((SIZE//2, SIZE-18), text, fill=GOLD_TEXT, font=font, anchor="mm")
    else:
        bbox = d.textbbox((0, 0), text)
        tw = bbox[2] - bbox[0]
        d.text(((SIZE-tw)//2, SIZE-22), text, fill=GOLD_TEXT)

# ═══════════════════════════════════════════════════════════════════════════
#  ANIMATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════

def bench_press(t, muscles):
    """Lying figure, arms push barbell up and down."""
    img, d = new_img()
    act = set(muscles)

    # bench
    d.rectangle([60, 180, 260, 200], fill=BENCH_COL)

    # body lying horizontal: head left (~80), feet right (~250)
    cy_body = 168
    # torso
    active_chest = 'chest' in act or 'back' in act
    d.ellipse([95, cy_body-22, 225, cy_body+22], fill=BODY_SH)
    d.ellipse([100, cy_body-18, 220, cy_body+18], fill=ACTIVE if active_chest else BODY)
    # head
    d.ellipse([65, cy_body-18, 97, cy_body+18], fill=BODY_SH)
    d.ellipse([68, cy_body-15, 94, cy_body+15], fill=BODY)
    # hips/legs
    d.ellipse([220, cy_body-16, 260, cy_body+16], fill=BODY_SH)
    d.ellipse([223, cy_body-13, 257, cy_body+13], fill=BODY)
    d.ellipse([252, cy_body-10, 285, cy_body+10], fill=BODY_SH)

    # arms: elbow angle based on t
    arm_ext  = osc(t, 0, 1)   # 0 = down to chest, 1 = extended
    cy_shldr = cy_body - 5
    ax_left  = 115
    ax_right = 205

    for ax in [ax_left, ax_right]:
        # upper arm goes from chest height to up
        elbow_y = int(cy_shldr - arm_ext * 38)
        active_bi  = 'biceps'  in act
        active_tri = 'triceps' in act
        active_sh  = 'shoulders' in act
        d.ellipse([ax-10, cy_shldr-12, ax+10, cy_shldr+12], fill=ACTIVE if active_sh else BODY_SH)
        d.line([ax, cy_shldr, ax, elbow_y], fill=BODY_SH, width=11)
        d.line([ax, cy_shldr, ax, elbow_y], fill=ACTIVE if active_tri else BODY, width=7)
        # forearm horizontal at top
        fore_y = elbow_y
        d.line([ax, fore_y, ax, fore_y - 25], fill=BODY_SH, width=9)
        d.line([ax, fore_y, ax, fore_y - 25], fill=ACTIVE if active_bi else BODY, width=6)

    # barbell
    bar_y = int(cy_shldr - arm_ext * 63 - 25)
    d.rectangle([ax_left-8, bar_y-4, ax_right+8, bar_y+4], fill=BAR_COL)
    d.ellipse([ax_left-18, bar_y-8, ax_left-6, bar_y+8], fill=BAR_COL)
    d.ellipse([ax_right+6, bar_y-8, ax_right+18, bar_y+8], fill=BAR_COL)

    label(d, " / ".join(muscles))
    return img


def overhead_press(t, muscles):
    """Standing front view, barbell press from shoulders to overhead."""
    img, d = new_img()
    act = set(muscles)
    arm_ext = osc(t, 0, 1)   # 0 = at shoulders, 1 = fully extended overhead

    active_sh  = 'shoulders' in act
    active_tri = 'triceps'   in act
    active_bi  = 'biceps'    in act

    # arms from shoulders (~y=98) to overhead
    cy_shldr = 98
    cy_elbow = int(cy_shldr - arm_ext * 50)
    cy_wrist = int(cy_elbow - 38)

    arm_w = 38
    for side, ax in [(-1, 160 - arm_w), (1, 160 + arm_w)]:
        d.ellipse([ax-13, cy_shldr-13, ax+13, cy_shldr+13], fill=ACTIVE if active_sh else BODY_SH)
        d.line([ax, cy_shldr, ax, cy_elbow], fill=BODY_SH, width=11)
        d.line([ax, cy_shldr, ax, cy_elbow], fill=ACTIVE if active_sh else BODY, width=7)
        d.line([ax, cy_elbow, ax, cy_wrist], fill=BODY_SH, width=9)
        d.line([ax, cy_elbow, ax, cy_wrist], fill=ACTIVE if active_tri else BODY, width=6)

    # barbell
    bar_y = cy_wrist - 5
    d.rectangle([160 - arm_w - 10, bar_y-4, 160 + arm_w + 10, bar_y+4], fill=BAR_COL)
    d.ellipse([160 - arm_w - 20, bar_y-8, 160 - arm_w - 8, bar_y+8], fill=BAR_COL)
    d.ellipse([160 + arm_w + 8,  bar_y-8, 160 + arm_w + 20, bar_y+8], fill=BAR_COL)

    draw_standing_body(d, muscles,
                       l_arm_ang=0, r_arm_ang=0,
                       l_fore_ang=-80, r_fore_ang=-80)
    label(d, " / ".join(muscles))
    return img


def pulldown(t, muscles):
    """Seated figure, arms pull bar from overhead to chest."""
    img, d = new_img()
    act = set(muscles)
    pull = osc(t, 0, 1)   # 0 = arms up, 1 = pulled down

    # seat
    d.rectangle([120, 230, 200, 245], fill=BENCH_COL)
    d.rectangle([155, 245, 165, 280], fill=BENCH_COL)

    # body sitting
    cy_head  = 88
    cy_neck  = 105
    cy_chest = 138
    cy_hips  = 175
    cx       = 160

    # legs horizontal
    for lx in [135, 185]:
        d.ellipse([lx-14, cy_hips-10, lx+14, cy_hips+10], fill=BODY_SH)
        d.ellipse([lx-12, cy_hips-8,  lx+12, cy_hips+8],  fill=BODY)
        d.ellipse([lx-12, cy_hips+10, lx+12, cy_hips+35], fill=BODY_SH)
        d.ellipse([lx-10, cy_hips+12, lx+10, cy_hips+33], fill=BODY)

    # torso
    active_chest = 'chest' in act or 'back' in act
    draw_ellipse(d, cx, cy_chest, 36, 30, active=active_chest)
    draw_ellipse(d, cx, cy_hips,  28, 18)
    draw_ellipse(d, cx, cy_neck,   9,  8)
    draw_ellipse(d, cx, cy_head,  20, 24)

    # cable machine bar at top
    bar_y     = int(55 - pull * 0)   # bar stays at ~55
    elbows_y  = int(90  + pull * 45)
    hands_y   = int(bar_y + 5 + pull * 40)

    active_bi  = 'biceps'  in act
    active_sh  = 'shoulders' in act
    active_back = 'back'   in act

    d.rectangle([cx-50, 40, cx+50, 48], fill=BAR_COL)  # overhead bar
    d.line([cx, 0, cx, 40], fill=(80, 80, 90), width=2)  # cable

    arm_spread = 42
    for ax in [cx - arm_spread, cx + arm_spread]:
        ex = int(ax * 0.6 + cx * 0.4 + (ax - cx) * pull * 0.2)
        ey = elbows_y
        # upper arm
        d.line([ax, 90, ex, ey], fill=BODY_SH, width=11)
        d.line([ax, 90, ex, ey], fill=ACTIVE if active_sh else BODY, width=7)
        # forearm to bar
        hx = int(cx + (ax - cx) * 0.7)
        hy = int(bar_y + 5 + pull * 38)
        d.line([ex, ey, hx, hy], fill=BODY_SH, width=9)
        d.line([ex, ey, hx, hy], fill=ACTIVE if active_bi else BODY, width=6)

    label(d, " / ".join(muscles))
    return img


def row(t, muscles):
    """Bent-over row: side view."""
    img, d = new_img()
    act = set(muscles)
    pull = osc(t, 0, 1)  # 0=extended arm, 1=pulled in

    cx, cy = 160, 160

    # bent-over torso (tilted ~45 deg, head left, hips right)
    torso_x0, torso_y0 = 85,  145
    torso_x1, torso_y1 = 210, 178
    active_back = 'back' in act or 'shoulders' in act
    d.ellipse([torso_x0, torso_y0, torso_x1, torso_y1], fill=BODY_SH)
    d.ellipse([torso_x0+4, torso_y0+4, torso_x1-4, torso_y1-4], fill=ACTIVE if active_back else BODY)

    # head
    d.ellipse([60, 128, 96, 160], fill=BODY_SH)
    d.ellipse([63, 131, 93, 157], fill=BODY)

    # legs (standing straight, side view)
    for lx, loff in [(148, 0), (172, 5)]:
        d.ellipse([lx-12, 175, lx+12, 230], fill=BODY_SH)
        d.ellipse([lx-10, 177, lx+10, 228], fill=BODY)
        d.ellipse([lx-10, 228, lx+10, 275], fill=BODY_SH)
        d.ellipse([lx-9,  230, lx+9,  273], fill=BODY)
        d.ellipse([lx-14, 268, lx+18, 282], fill=BODY_SH)

    # pulling arm (below torso)
    arm_ext = osc(t, 0, 1)
    shldr_x = 115; shldr_y = 162
    hand_x  = int(shldr_x - (1 - arm_ext) * 60)
    hand_y  = int(shldr_y + 30)
    elbow_x = int(shldr_x - (1 - arm_ext) * 30)
    elbow_y = int(shldr_y + 18)

    active_bi = 'biceps' in act
    active_sh = 'shoulders' in act
    d.line([shldr_x, shldr_y, elbow_x, elbow_y], fill=BODY_SH, width=12)
    d.line([shldr_x, shldr_y, elbow_x, elbow_y], fill=ACTIVE if active_sh else BODY, width=8)
    d.line([elbow_x, elbow_y, hand_x, hand_y], fill=BODY_SH, width=10)
    d.line([elbow_x, elbow_y, hand_x, hand_y], fill=ACTIVE if active_bi else BODY, width=6)
    # dumbbell
    d.ellipse([hand_x-12, hand_y-5, hand_x+12, hand_y+5], fill=BAR_COL)

    label(d, " / ".join(muscles))
    return img


def squat(t, muscles):
    """Standing figure squats down and up."""
    img, d = new_img()
    sq = osc(t, 0, 1)  # 0=standing, 1=squatting
    dy = int(sq * 32)

    draw_standing_body(d, muscles,
                       l_arm_ang=-18, r_arm_ang=18,
                       l_fore_ang=-18, r_fore_ang=18,
                       l_leg_ang=-8, r_leg_ang=8,
                       squat_t=sq,
                       dy=dy)
    label(d, " / ".join(muscles))
    return img


def curl(t, muscles):
    """Bicep curl: arms curl up from sides."""
    img, d = new_img()
    act = set(muscles)
    curl_t = osc(t, 0, 1)  # 0=down, 1=curled
    fore_ang = int(-curl_t * 120)

    draw_standing_body(d, muscles,
                       l_arm_ang=-5, r_arm_ang=5,
                       l_fore_ang=fore_ang, r_fore_ang=fore_ang)
    label(d, " / ".join(muscles))
    return img


def pushdown(t, muscles):
    """Tricep pushdown: forearms push down."""
    img, d = new_img()
    act = set(muscles)
    push = osc(t, 0, 1)  # 0=up, 1=down
    # forearms: from ~horizontal up to pushed down
    fore_ang = int(-60 + push * 80)  # -60 (up) → +20 (down)

    draw_standing_body(d, muscles,
                       l_arm_ang=10, r_arm_ang=-10,
                       l_fore_ang=fore_ang, r_fore_ang=fore_ang)
    label(d, " / ".join(muscles))
    return img


def deadlift(t, muscles):
    """Side view: figure hinges at hip from bent to standing."""
    img, d = new_img()
    act = set(muscles)
    lift = osc(t, 0, 1)  # 0=bent over, 1=standing

    cx = 155
    spine_angle = int((1 - lift) * 55)  # degrees from vertical

    # --- spine (torso) tilted ---
    spine_len = 70
    top_x = int(cx - math.sin(math.radians(spine_angle)) * spine_len)
    top_y = int(180 - math.cos(math.radians(spine_angle)) * spine_len)

    hips_x, hips_y = cx, 200

    active_back   = 'back'       in act
    active_hams   = 'hamstrings' in act
    active_glutes = 'glutes'     in act

    # torso
    tx0, ty0 = min(top_x, hips_x) - 15, min(top_y, hips_y) - 15
    tx1, ty1 = max(top_x, hips_x) + 15, max(top_y, hips_y) + 15
    d.line([top_x, top_y, hips_x, hips_y], fill=BODY_SH, width=34)
    d.line([top_x, top_y, hips_x, hips_y], fill=ACTIVE if active_back else BODY, width=22)

    # head
    head_x = int(top_x - math.sin(math.radians(spine_angle)) * 28)
    head_y = int(top_y - math.cos(math.radians(spine_angle)) * 28)
    d.ellipse([head_x-18, head_y-18, head_x+18, head_y+18], fill=BODY_SH)
    d.ellipse([head_x-15, head_y-15, head_x+15, head_y+15], fill=BODY)

    # legs (straight down)
    for lx in [hips_x - 12, hips_x + 12]:
        d.ellipse([lx-12, hips_y, lx+12, hips_y+55], fill=BODY_SH)
        d.ellipse([lx-10, hips_y+2, lx+10, hips_y+53], fill=ACTIVE if active_hams or active_glutes else BODY)
        d.ellipse([lx-10, hips_y+55, lx+10, hips_y+100], fill=BODY_SH)
        d.ellipse([lx-9,  hips_y+57, lx+9,  hips_y+98],  fill=BODY)
        d.ellipse([lx-14, hips_y+95, lx+18, hips_y+108], fill=BODY_SH)

    # arms hanging toward floor
    arm_x = int(top_x + math.cos(math.radians(spine_angle)) * 15)
    arm_y = int(top_y + math.sin(math.radians(spine_angle)) * 15)
    hand_x = int(arm_x + math.sin(math.radians(spine_angle)) * 55)
    hand_y = int(arm_y + 55)
    d.line([arm_x, arm_y, hand_x, hand_y], fill=BODY_SH, width=10)
    d.line([arm_x, arm_y, hand_x, hand_y], fill=BODY, width=7)
    # barbell at floor
    bar_y_pos = int(hips_y + 95 + (1-lift)*10)
    d.rectangle([hips_x-55, bar_y_pos, hips_x+55, bar_y_pos+8], fill=BAR_COL)

    label(d, " / ".join(muscles))
    return img


def lateral_raise(t, muscles):
    """Arms raise from sides to shoulder height."""
    img, d = new_img()
    raise_t = osc(t, 0, 1)
    arm_ang = int(raise_t * 80)  # degrees from vertical

    draw_standing_body(d, muscles,
                       l_arm_ang=-arm_ang, r_arm_ang=arm_ang,
                       l_fore_ang=-arm_ang, r_fore_ang=arm_ang)
    label(d, " / ".join(muscles))
    return img


def fly(t, muscles):
    """Cable fly / chest fly: arms open and close."""
    img, d = new_img()
    act = set(muscles)
    open_t = osc(t, 0, 1)  # 0=closed center, 1=open wide
    arm_ang = int(open_t * 75)

    draw_standing_body(d, muscles,
                       l_arm_ang=-arm_ang, r_arm_ang=arm_ang,
                       l_fore_ang=-arm_ang + 10, r_fore_ang=arm_ang - 10)
    label(d, " / ".join(muscles))
    return img


def lunge(t, muscles):
    """Side view, one leg steps forward."""
    img, d = new_img()
    act = set(muscles)
    lunge_t = osc(t, 0, 1)

    cx = 160
    # Standing leg (back)
    hip_y = int(175 + lunge_t * 20)
    cy_head = 82
    cy_neck = 100

    active_q = 'quads' in act or 'glutes' in act

    # torso (upright)
    d.ellipse([cx-30, cy_neck, cx+30, hip_y-10], fill=BODY_SH)
    d.ellipse([cx-26, cy_neck+4, cx+26, hip_y-14], fill=BODY)
    d.ellipse([cx-20, cy_head-20, cx+20, cy_head+20], fill=BODY_SH)
    d.ellipse([cx-17, cy_head-17, cx+17, cy_head+17], fill=BODY)

    # front leg (bent)
    front_knee_x = int(cx + lunge_t * 45)
    front_knee_y = int(hip_y + 35 + lunge_t * 10)
    front_foot_x = int(cx + lunge_t * 65)
    front_foot_y = hip_y + 90

    d.line([cx, hip_y, front_knee_x, front_knee_y], fill=BODY_SH, width=24)
    d.line([cx, hip_y, front_knee_x, front_knee_y], fill=ACTIVE if active_q else BODY, width=16)
    d.line([front_knee_x, front_knee_y, front_foot_x, front_foot_y], fill=BODY_SH, width=20)
    d.line([front_knee_x, front_knee_y, front_foot_x, front_foot_y], fill=ACTIVE if active_q else BODY, width=14)
    d.ellipse([front_foot_x-15, front_foot_y-6, front_foot_x+15, front_foot_y+6], fill=BODY_SH)

    # back leg (straight down)
    back_foot_y = hip_y + 85
    d.line([cx, hip_y, cx - 15, back_foot_y], fill=BODY_SH, width=22)
    d.line([cx, hip_y, cx - 15, back_foot_y], fill=ACTIVE if active_q else BODY, width=15)
    d.ellipse([cx-28, back_foot_y-6, cx+5, back_foot_y+6], fill=BODY_SH)

    # arms (slightly forward)
    for ax, fa in [(cx-28, -20), (cx+28, 20)]:
        d.line([ax, cy_neck+20, ax+fa, cy_neck+60], fill=BODY_SH, width=10)
        d.line([ax, cy_neck+20, ax+fa, cy_neck+60], fill=BODY, width=7)
        d.line([ax+fa, cy_neck+60, ax+fa, cy_neck+95], fill=BODY_SH, width=9)
        d.line([ax+fa, cy_neck+60, ax+fa, cy_neck+95], fill=BODY, width=6)

    label(d, " / ".join(muscles))
    return img


def hip_thrust(t, muscles):
    """Side view: on back, hips push up."""
    img, d = new_img()
    act = set(muscles)
    thrust = osc(t, 0, 1)  # 0=down, 1=hips up

    hip_y = int(220 - thrust * 55)

    # bench/floor
    d.rectangle([50, 225, 270, 240], fill=BENCH_COL)
    # bench back
    d.rectangle([60, 155, 100, 225], fill=BENCH_COL)

    active_glutes = 'glutes' in act or 'hamstrings' in act

    # body (on back, legs bent, hips raised)
    cx = 160
    # upper back against bench
    d.ellipse([65, 168, 105, 222], fill=BODY_SH)
    d.ellipse([68, 171, 102, 219], fill=BODY)
    # torso tilted up from back
    d.line([85, 195, cx, hip_y], fill=BODY_SH, width=34)
    d.line([85, 195, cx, hip_y], fill=ACTIVE if active_glutes else BODY, width=22)

    # legs (bent at knee, feet on floor)
    knee_x = int(cx + 45)
    knee_y = int(hip_y + 35)
    foot_x = int(cx + 50)
    foot_y = 232
    for off in [-10, 10]:
        d.line([cx+off, hip_y, knee_x+off, knee_y], fill=BODY_SH, width=22)
        d.line([cx+off, hip_y, knee_x+off, knee_y], fill=ACTIVE if active_glutes else BODY, width=15)
        d.line([knee_x+off, knee_y, foot_x+off, foot_y], fill=BODY_SH, width=18)
        d.line([knee_x+off, knee_y, foot_x+off, foot_y], fill=BODY, width=12)
        d.ellipse([foot_x+off-14, foot_y-6, foot_x+off+14, foot_y+6], fill=BODY_SH)

    # head on bench
    d.ellipse([60, 148, 98, 178], fill=BODY_SH)
    d.ellipse([63, 151, 95, 175], fill=BODY)

    label(d, " / ".join(muscles))
    return img


def calf_raise(t, muscles):
    """Standing side view, rise up on tiptoes."""
    img, d = new_img()
    act = set(muscles)
    rise = osc(t, 0, 1)
    dy_rise = int(-rise * 18)

    # draw with calf active
    draw_standing_body(d, muscles, dy=dy_rise)
    label(d, " / ".join(muscles))
    return img


def crunch(t, muscles):
    """Lying side view, upper body curls toward knees."""
    img, d = new_img()
    act = set(muscles)
    curl_t = osc(t, 0, 1)  # 0=flat, 1=crunched

    # floor
    d.rectangle([40, 255, 280, 265], fill=BENCH_COL)

    cx = 160
    hip_y = 225

    active_abs = 'abs' in act

    # legs (flat, pointing right)
    for ly in [225, 238]:
        d.ellipse([cx, ly-10, cx+100, ly+10], fill=BODY_SH)
        d.ellipse([cx+2, ly-8, cx+98, ly+8], fill=BODY)

    # lower back/hips
    d.ellipse([cx-15, hip_y-12, cx+15, hip_y+12], fill=BODY_SH)
    d.ellipse([cx-13, hip_y-10, cx+13, hip_y+10], fill=BODY)

    # upper body curling up
    torso_angle = int(curl_t * 45)  # degrees from horizontal
    tlen = 65
    chest_x = int(cx - math.cos(math.radians(torso_angle)) * tlen)
    chest_y = int(hip_y - math.sin(math.radians(torso_angle)) * tlen)

    d.line([cx, hip_y, chest_x, chest_y], fill=BODY_SH, width=34)
    d.line([cx, hip_y, chest_x, chest_y], fill=ACTIVE if active_abs else BODY, width=22)

    # head
    head_x = int(chest_x - math.cos(math.radians(torso_angle)) * 25)
    head_y = int(chest_y - math.sin(math.radians(torso_angle)) * 25)
    d.ellipse([head_x-18, head_y-18, head_x+18, head_y+18], fill=BODY_SH)
    d.ellipse([head_x-15, head_y-15, head_x+15, head_y+15], fill=BODY)

    label(d, " / ".join(muscles))
    return img


def leg_raise(t, muscles):
    """Lying on back, legs raise from horizontal to vertical."""
    img, d = new_img()
    act = set(muscles)
    raise_t = osc(t, 0, 1)  # 0=flat, 1=up

    # floor
    d.rectangle([40, 248, 280, 258], fill=BENCH_COL)

    active_abs = 'abs' in act
    cx = 160
    body_y = 235

    # upper body flat
    d.ellipse([70, body_y-14, cx, body_y+14], fill=BODY_SH)
    d.ellipse([73, body_y-11, cx-2, body_y+11], fill=BODY)
    # head
    d.ellipse([42, body_y-18, 78, body_y+18], fill=BODY_SH)
    d.ellipse([45, body_y-15, 75, body_y+15], fill=BODY)

    # hips
    d.ellipse([cx-16, body_y-12, cx+16, body_y+12], fill=BODY_SH)
    d.ellipse([cx-14, body_y-10, cx+14, body_y+10], fill=ACTIVE if active_abs else BODY)

    # legs rising
    leg_angle = int(raise_t * 85)  # 0=horizontal, 85=near vertical
    for loff in [-10, 10]:
        leg_end_x = int(cx + loff + math.cos(math.radians(leg_angle)) * 80)
        leg_end_y = int(body_y - math.sin(math.radians(leg_angle)) * 80)
        d.line([cx+loff, body_y, leg_end_x, leg_end_y], fill=BODY_SH, width=22)
        d.line([cx+loff, body_y, leg_end_x, leg_end_y], fill=ACTIVE if active_abs else BODY, width=15)
        foot_x = int(leg_end_x + math.cos(math.radians(leg_angle)) * 35)
        foot_y = int(leg_end_y - math.sin(math.radians(leg_angle)) * 35)
        d.line([leg_end_x, leg_end_y, foot_x, foot_y], fill=BODY_SH, width=18)
        d.line([leg_end_x, leg_end_y, foot_x, foot_y], fill=BODY, width=12)

    label(d, " / ".join(muscles))
    return img


def plank(t, muscles):
    """Side view plank with slight breathing/pulsing."""
    img, d = new_img()
    act = set(muscles)
    breath = osc(t, 0, 1)

    # floor
    d.rectangle([40, 255, 280, 265], fill=BENCH_COL)

    active_abs  = 'abs'  in act
    active_back = 'back' in act

    cy = int(230 - breath * 4)

    # body horizontal (side view)
    # feet
    d.ellipse([230, cy-8, 260, cy+8], fill=BODY_SH)
    # lower legs
    d.ellipse([190, cy-10, 235, cy+10], fill=BODY_SH)
    d.ellipse([193, cy-8,  232, cy+8],  fill=BODY)
    # thighs
    d.ellipse([148, cy-12, 195, cy+12], fill=BODY_SH)
    d.ellipse([151, cy-10, 192, cy+10], fill=BODY)
    # torso
    d.ellipse([100, cy-16, 153, cy+16], fill=BODY_SH)
    d.ellipse([103, cy-13, 150, cy+13], fill=ACTIVE if active_abs or active_back else BODY)
    # shoulder/upper arm (arm straight down)
    d.ellipse([90, cy-14, 110, cy+14], fill=BODY_SH)
    d.ellipse([92, cy-12, 108, cy+12], fill=BODY)
    # forearm on floor
    d.ellipse([72, cy+2, 96, cy+20], fill=BODY_SH)
    d.ellipse([74, cy+4, 94, cy+18],  fill=BODY)
    # head
    d.ellipse([60, cy-24, 96, cy+8], fill=BODY_SH)
    d.ellipse([63, cy-21, 93, cy+5], fill=BODY)

    label(d, " / ".join(muscles))
    return img


def glute_kick(t, muscles):
    """Side view on all fours, one leg kicks back/up."""
    img, d = new_img()
    act = set(muscles)
    kick = osc(t, 0, 1)  # 0=tucked in, 1=kicked back

    active_glutes = 'glutes' in act or 'hamstrings' in act

    cx, cy = 150, 185

    # torso (horizontal)
    d.ellipse([cx-50, cy-16, cx+50, cy+16], fill=BODY_SH)
    d.ellipse([cx-47, cy-13, cx+47, cy+13], fill=BODY)

    # head
    d.ellipse([cx-72, cy-20, cx-38, cy+12], fill=BODY_SH)
    d.ellipse([cx-69, cy-17, cx-41, cy+9],  fill=BODY)

    # front arms down
    for ax in [cx-38, cx-22]:
        d.ellipse([ax-8, cy+10, ax+8, cy+48], fill=BODY_SH)
        d.ellipse([ax-6, cy+12, ax+6, cy+46], fill=BODY)

    # stationary back leg (tucked)
    d.ellipse([cx+25, cy+8, cx+45, cy+45], fill=BODY_SH)
    d.ellipse([cx+27, cy+10, cx+43, cy+43], fill=BODY)
    d.ellipse([cx+28, cy+43, cx+48, cy+75], fill=BODY_SH)
    d.ellipse([cx+30, cy+45, cx+46, cy+73], fill=BODY)

    # kicking leg
    kick_angle = int(kick * 50)  # degrees from down, going back
    leg_len = 60
    knee_x = int(cx + 38)
    knee_y = int(cy + 18)
    foot_x = int(knee_x + math.sin(math.radians(kick_angle)) * leg_len)
    foot_y = int(knee_y + math.cos(math.radians(kick_angle)) * leg_len * (1 - kick * 0.6))

    d.line([cx+35, cy+15, foot_x, foot_y], fill=BODY_SH, width=20)
    d.line([cx+35, cy+15, foot_x, foot_y], fill=ACTIVE if active_glutes else BODY, width=13)
    d.ellipse([foot_x-12, foot_y-6, foot_x+12, foot_y+6], fill=BODY_SH)

    label(d, " / ".join(muscles))
    return img


def front_raise(t, muscles):
    """Arms raise forward from sides."""
    img, d = new_img()
    raise_t = osc(t, 0, 1)
    # raise arms forward (in front view, simulate by raising)
    arm_ang = int(-raise_t * 75)  # up toward head

    draw_standing_body(d, muscles,
                       l_arm_ang=arm_ang, r_arm_ang=arm_ang,
                       l_fore_ang=arm_ang, r_fore_ang=arm_ang)
    label(d, " / ".join(muscles))
    return img


def pull_up(t, muscles):
    """Front view: body rises, arms pull from extended to bent."""
    img, d = new_img()
    act = set(muscles)
    pull = osc(t, 0, 1)  # 0=hanging, 1=pulled up

    dy = int(-pull * 45)  # body rises

    # pull-up bar at top
    d.rectangle([90, 38, 230, 48], fill=BAR_COL)
    d.ellipse([82, 30, 98, 56], fill=BAR_COL)
    d.ellipse([222, 30, 238, 56], fill=BAR_COL)

    active_bi   = 'biceps' in act
    active_back = 'back'   in act
    active_sh   = 'shoulders' in act

    cx = 160
    arm_spread = 40
    shldr_y = int(100 + dy)
    elbow_y = int(shldr_y - pull * 55)
    hand_y  = 48  # fixed at bar

    for ax in [cx - arm_spread, cx + arm_spread]:
        # upper arm from shoulder to elbow
        d.line([ax, shldr_y, ax, elbow_y], fill=BODY_SH, width=12)
        d.line([ax, shldr_y, ax, elbow_y], fill=ACTIVE if active_back or active_sh else BODY, width=8)
        # forearm from elbow to bar
        d.line([ax, elbow_y, ax, hand_y], fill=BODY_SH, width=10)
        d.line([ax, elbow_y, ax, hand_y], fill=ACTIVE if active_bi else BODY, width=7)

    draw_standing_body(d, muscles, dy=dy)
    label(d, " / ".join(muscles))
    return img


def shrug(t, muscles):
    """Shoulders shrug up and down."""
    img, d = new_img()
    shrug_t = osc(t, 0, 1)
    dy = int(-shrug_t * 12)

    draw_standing_body(d, muscles, dy=dy)
    label(d, " / ".join(muscles))
    return img


def leg_extension(t, muscles):
    """Seated, lower leg extends forward."""
    img, d = new_img()
    act = set(muscles)
    ext = osc(t, 0, 1)  # 0=bent, 1=extended

    active_q = 'quads' in act

    # seat
    d.rectangle([105, 200, 215, 215], fill=BENCH_COL)
    d.rectangle([150, 215, 170, 270], fill=BENCH_COL)

    cx = 160
    # torso sitting
    d.ellipse([cx-30, 110, cx+30, 205], fill=BODY_SH)
    d.ellipse([cx-27, 113, cx+27, 202], fill=BODY)
    # head
    d.ellipse([cx-22, 68, cx+22, 112], fill=BODY_SH)
    d.ellipse([cx-19, 71, cx+19, 109], fill=BODY)

    # upper legs horizontal on seat
    for lx in [135, 185]:
        d.ellipse([lx-14, 195, lx+14, 215], fill=BODY_SH)
        d.ellipse([lx-12, 197, lx+12, 213], fill=ACTIVE if active_q else BODY)
        # lower leg: goes from hanging (down) to extended (forward)
        knee_y = 213
        foot_y_hang = 268
        foot_y_ext  = 218
        foot_x_ext  = lx + int(ext * 55)
        foot_y = int(knee_y + (1 - ext) * (foot_y_hang - knee_y))
        foot_x = int(lx + ext * 55)
        d.line([lx, knee_y, foot_x, foot_y], fill=BODY_SH, width=20)
        d.line([lx, knee_y, foot_x, foot_y], fill=ACTIVE if active_q else BODY, width=14)
        d.ellipse([foot_x-12, foot_y-6, foot_x+12, foot_y+6], fill=BODY_SH)

    # arms resting on thighs
    for ax in [cx-24, cx+24]:
        d.line([ax, 150, ax, 200], fill=BODY_SH, width=10)
        d.line([ax, 150, ax, 200], fill=BODY, width=7)

    label(d, " / ".join(muscles))
    return img


def leg_curl(t, muscles):
    """Prone or seated leg curl: lower leg curls up."""
    img, d = new_img()
    act = set(muscles)
    curl_t = osc(t, 0, 1)

    active_h = 'hamstrings' in act

    # prone (lying face down)
    cy = 178
    d.rectangle([55, 190, 270, 200], fill=BENCH_COL)

    # body horizontal
    d.ellipse([75, cy-14, 220, cy+14], fill=BODY_SH)
    d.ellipse([78, cy-11, 217, cy+11], fill=BODY)
    # head
    d.ellipse([50, cy-16, 84, cy+16], fill=BODY_SH)
    d.ellipse([53, cy-13, 81, cy+13], fill=BODY)

    # legs
    for lx in [155, 175]:
        # thigh
        d.ellipse([lx-10, cy+5, lx+10, cy+55], fill=BODY_SH)
        d.ellipse([lx-8, cy+7, lx+8, cy+53], fill=ACTIVE if active_h else BODY)
        # lower leg curling up
        knee_y   = cy + 50
        foot_ang = int(curl_t * 110)  # 0=straight, 110=curled up
        foot_x   = int(lx + math.sin(math.radians(-foot_ang)) * 45)
        foot_y   = int(knee_y - math.cos(math.radians(foot_ang)) * 45)
        d.line([lx, knee_y, foot_x, foot_y], fill=BODY_SH, width=18)
        d.line([lx, knee_y, foot_x, foot_y], fill=ACTIVE if active_h else BODY, width=12)
        d.ellipse([foot_x-10, foot_y-5, foot_x+10, foot_y+5], fill=BODY_SH)

    label(d, " / ".join(muscles))
    return img


# ═══════════════════════════════════════════════════════════════════════════
#  EXERCISE REGISTRY
# ═══════════════════════════════════════════════════════════════════════════

ANIM_MAP = {
    'bench_press':    bench_press,
    'overhead_press': overhead_press,
    'pulldown':       pulldown,
    'row':            row,
    'squat':          squat,
    'curl':           curl,
    'pushdown':       pushdown,
    'deadlift':       deadlift,
    'lateral_raise':  lateral_raise,
    'fly':            fly,
    'lunge':          lunge,
    'hip_thrust':     hip_thrust,
    'calf_raise':     calf_raise,
    'crunch':         crunch,
    'leg_raise':      leg_raise,
    'plank':          plank,
    'glute_kick':     glute_kick,
    'front_raise':    front_raise,
    'pull_up':        pull_up,
    'shrug':          shrug,
    'leg_extension':  leg_extension,
    'leg_curl':       leg_curl,
}

EXERCISES = [
    # PETTO
    ('panca_piana',             'bench_press',    ['chest']),
    ('distensioni_con_manubri', 'bench_press',    ['chest']),
    ('croci_ai_cavi',           'fly',            ['chest']),
    ('panca_inclinata',         'bench_press',    ['chest', 'shoulders']),
    ('croci_con_manubri',       'fly',            ['chest']),
    ('push-up',                 'bench_press',    ['chest', 'triceps']),
    ('dip_alle_parallele',      'pushdown',       ['chest', 'triceps']),
    ('panca_declinata',         'bench_press',    ['chest']),
    ('peck_deck',               'fly',            ['chest']),
    ('pull_over',               'pulldown',       ['chest', 'back']),
    ('chest_press_macchina',    'bench_press',    ['chest']),
    # DORSO
    ('stacchi_da_terra',        'deadlift',       ['back', 'glutes']),
    ('trazioni_alla_sbarra',    'pull_up',        ['back', 'biceps']),
    ('lat_machine',             'pulldown',       ['back', 'biceps']),
    ('rematore_con_bilanciere', 'row',            ['back']),
    ('rematore_con_manubrio',   'row',            ['back']),
    ('pulley_basso',            'row',            ['back']),
    ('face_pull',               'row',            ['shoulders', 'back']),
    ('trazioni_presa_neutra',   'pull_up',        ['back', 'biceps']),
    ('back_extension',          'deadlift',       ['back', 'glutes']),
    ('good_morning',            'deadlift',       ['back', 'glutes']),
    # SPALLE
    ('lento_avanti',            'overhead_press', ['shoulders']),
    ('alzate_laterali',         'lateral_raise',  ['shoulders']),
    ('alzate_frontali',         'front_raise',    ['shoulders']),
    ('alzate_di_spalle',        'shrug',          ['shoulders']),
    ('arnold_press',            'overhead_press', ['shoulders']),
    ('shoulder_press_macchina', 'overhead_press', ['shoulders']),
    # BRACCIA
    ('curl_con_bilanciere',         'curl',           ['biceps']),
    ('curl_con_manubri_alternati',  'curl',           ['biceps']),
    ('curl_martello',               'curl',           ['biceps']),
    ('scott_curl',                  'curl',           ['biceps']),
    ('concentration_curl',          'curl',           ['biceps']),
    ('pushdown_corda',              'pushdown',       ['triceps']),
    ('tricipiti_ai_cavi',           'pushdown',       ['triceps']),
    ('french_press',                'overhead_press', ['triceps']),
    ('overhead_tricep_extension',   'overhead_press', ['triceps']),
    ('dip',                         'pushdown',       ['triceps', 'chest']),
    # GAMBE
    ('squat_con_bilanciere',    'squat',          ['quads', 'glutes']),
    ('leg_press',               'squat',          ['quads', 'glutes']),
    ('leg_extension',           'leg_extension',  ['quads']),
    ('leg_curl',                'leg_curl',       ['hamstrings']),
    ('affondi',                 'lunge',          ['quads', 'glutes']),
    ('stacchi_rumeni',          'deadlift',       ['hamstrings', 'glutes']),
    ('romanian_deadlift',       'deadlift',       ['hamstrings', 'glutes']),
    ('bulgarian_split_squat',   'lunge',          ['quads', 'glutes']),
    ('goblet_squat',            'squat',          ['quads', 'glutes']),
    ('sumo_deadlift',           'deadlift',       ['glutes', 'quads']),
    ('step_up',                 'lunge',          ['quads', 'glutes']),
    ('calf_raises',             'calf_raise',     ['calves']),
    # GLUTEI
    ('hip_thrust',              'hip_thrust',     ['glutes']),
    ('donkey_kick',             'glute_kick',     ['glutes']),
    ('hip_abductor',            'lateral_raise',  ['glutes']),
    # CORE
    ('crunch',                  'crunch',         ['abs']),
    ('leg_raise',               'leg_raise',      ['abs']),
    ('plank',                   'plank',          ['abs', 'back']),
    ('russian_twist',           'crunch',         ['abs']),
    ('mountain_climber',        'plank',          ['abs']),
    ('plank_laterale',          'plank',          ['abs']),
    # CARDIO / ALIASES
    ('push_up_diamante',        'bench_press',    ['triceps', 'chest']),
    ('push_up',                 'bench_press',    ['chest']),
    ('squat',                   'squat',          ['quads', 'glutes']),
    ('curl_con_manubri',        'curl',           ['biceps']),
    ('calf_raise',              'calf_raise',     ['calves']),
    ('trazioni',                'pull_up',        ['back']),
    ('tricipiti_alla_fune',     'pushdown',       ['triceps']),
]


# ═══════════════════════════════════════════════════════════════════════════
#  GIF GENERATION
# ═══════════════════════════════════════════════════════════════════════════

def generate_gif(slug, anim_type, muscles):
    anim_fn = ANIM_MAP.get(anim_type)
    if anim_fn is None:
        print(f"  [SKIP] unknown anim type: {anim_type}")
        return None

    frames = []
    for i in range(FRAMES):
        t = i / FRAMES
        try:
            frame = anim_fn(t, muscles)
            frames.append(frame)
        except Exception as e:
            print(f"  [ERR] {slug} frame {i}: {e}")
            return None

    # Build GIF in memory first
    import io
    buf = io.BytesIO()
    frames[0].save(
        buf,
        format='GIF',
        save_all=True,
        append_images=frames[1:],
        duration=DURATION,
        loop=0,
        optimize=False,
    )
    return buf.getvalue()


def main():
    for d in OUT_DIRS:
        os.makedirs(d, exist_ok=True)

    generated = 0
    skipped   = 0
    seen_slugs = set()

    for slug, anim_type, muscles in EXERCISES:
        if slug in seen_slugs:
            print(f"  [DUP] {slug} already generated, copying")
            # file already saved; nothing to do
            continue
        seen_slugs.add(slug)

        print(f"  Generating {slug} ({anim_type}, {muscles}) ...", end=" ", flush=True)
        data = generate_gif(slug, anim_type, muscles)
        if data is None:
            skipped += 1
            print("SKIPPED")
            continue

        fname = f"{slug}.gif"
        for out_dir in OUT_DIRS:
            path = os.path.join(out_dir, fname)
            with open(path, 'wb') as f:
                f.write(data)

        generated += 1
        print(f"OK ({len(data)//1024}KB)")

    print()
    print(f"─── Summary ────────────────────────────────")
    print(f"  Generated : {generated}")
    print(f"  Skipped   : {skipped}")
    print()

    for out_dir in OUT_DIRS:
        gifs = [f for f in os.listdir(out_dir) if f.endswith('.gif')]
        print(f"  {out_dir}")
        print(f"    → {len(gifs)} GIFs present")

    print()
    print("Done!")


if __name__ == '__main__':
    main()
