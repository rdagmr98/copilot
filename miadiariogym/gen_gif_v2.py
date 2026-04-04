"""
GIF esercizi v2 - corpo umano anatomico con muscolo target evidenziato.
Esempio: Panca Piana (bench press) - vista laterale
Stile: sfondo scuro, corpo 3D con shading, petto evidenziato in gold.
"""
import math
from PIL import Image, ImageDraw, ImageFilter

W, H = 320, 320
FRAMES = 32
DELAY = 55  # ms per frame

BG       = (12, 12, 15)
SKIN     = (210, 170, 130)
SKIN_SH  = (160, 120, 85)     # ombra pelle
MUSCLE   = (255, 200, 40)     # muscolo target (gold/amber)
MUSCLE2  = (255, 140, 20)     # muscolo target ombra
BAR      = (220, 220, 235)    # barra bilanciere
DISC     = (50, 50, 60)       # disco bilanciere
DISC_HL  = (80, 80, 95)
BENCH_C  = (45, 45, 55)
BENCH_HL = (70, 70, 85)
SHORTS   = (40, 60, 110)
SHORTS_S = (25, 40, 80)
SHOE     = (35, 35, 40)

def lerp(a, b, t):
    if isinstance(a, tuple):
        return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(len(a)))
    return a + (b - a) * t

def ease(t):
    # ease in-out (0->1->0 in FRAMES)
    phase = (t * 2) % 2
    raw = phase if phase < 1 else 2 - phase
    return raw * raw * (3 - 2 * raw)

def draw_rounded_rect(d, xy, rx=8, ry=8, fill=None, outline=None, width=1):
    x0,y0,x1,y1 = xy
    if fill:
        d.ellipse([x0, y0, x0+2*rx, y0+2*ry], fill=fill)
        d.ellipse([x1-2*rx, y0, x1, y0+2*ry], fill=fill)
        d.ellipse([x0, y1-2*ry, x0+2*rx, y1], fill=fill)
        d.ellipse([x1-2*rx, y1-2*ry, x1, y1], fill=fill)
        d.rectangle([x0+rx, y0, x1-rx, y1], fill=fill)
        d.rectangle([x0, y0+ry, x1, y1-ry], fill=fill)
    if outline:
        d.arc([x0, y0, x0+2*rx, y0+2*ry], 180, 270, fill=outline, width=width)
        d.arc([x1-2*rx, y0, x1, y0+2*ry], 270, 360, fill=outline, width=width)
        d.arc([x0, y1-2*ry, x0+2*rx, y1], 90, 180, fill=outline, width=width)
        d.arc([x1-2*rx, y1-2*ry, x1, y1], 0, 90, fill=outline, width=width)
        d.line([x0+rx, y0, x1-rx, y0], fill=outline, width=width)
        d.line([x0+rx, y1, x1-rx, y1], fill=outline, width=width)
        d.line([x0, y0+ry, x0, y1-ry], fill=outline, width=width)
        d.line([x1, y0+ry, x1, y1-ry], fill=outline, width=width)

def draw_limb(d, p1, p2, r1, r2, fill, shadow):
    """Disegna un arto come trapezio arrotondato con shading."""
    dx = p2[0]-p1[0]; dy = p2[1]-p1[1]
    length = math.hypot(dx, dy)
    if length < 1: return
    nx, ny = -dy/length, dx/length
    pts = [
        (p1[0]+nx*r1, p1[1]+ny*r1),
        (p1[0]-nx*r1, p1[1]-ny*r1),
        (p2[0]-nx*r2, p2[1]-ny*r2),
        (p2[0]+nx*r2, p2[1]+ny*r2),
    ]
    d.polygon(pts, fill=fill)
    # shading laterale
    shade_pts = [
        (p1[0]+nx*(r1*0.3), p1[1]+ny*(r1*0.3)),
        (p1[0]+nx*r1, p1[1]+ny*r1),
        (p2[0]+nx*r2, p2[1]+ny*r2),
        (p2[0]+nx*(r2*0.3), p2[1]+ny*(r2*0.3)),
    ]
    d.polygon(shade_pts, fill=shadow)
    d.ellipse([p1[0]-r1, p1[1]-r1, p1[0]+r1, p1[1]+r1], fill=fill)
    d.ellipse([p2[0]-r2, p2[1]-r2, p2[0]+r2, p2[1]+r2], fill=fill)

def make_frame(t):
    e = ease(t / FRAMES)  # 0..1..0

    # Quantità di abbassamento barra (0=su, 1=giù)
    press_depth = e

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # ─── PANCA ─────────────────────────────────────────────────────────────
    bx0, by0, bx1, by1 = 30, 175, 280, 195
    draw_rounded_rect(d, [bx0, by0, bx1, by1], rx=6, ry=6, fill=BENCH_HL)
    draw_rounded_rect(d, [bx0+2, by0+5, bx1-2, by1], rx=4, ry=4, fill=BENCH_C)
    # gambe panca
    for lx in [55, 255]:
        d.rectangle([lx-5, by1, lx+5, by1+30], fill=BENCH_C)
        d.rectangle([lx-12, by1+26, lx+12, by1+32], fill=BENCH_C)

    # ─── CORPO SDRAIATO ────────────────────────────────────────────────────
    body_y = 162  # y centro corpo

    # Gambe (distese, leggermente piegate)
    hip = (215, body_y)
    knee = (255, body_y - 8)
    foot = (278, body_y + 12)
    draw_limb(d, hip, knee, 16, 13, SHORTS, SHORTS_S)
    draw_limb(d, knee, foot, 13, 9, SKIN, SKIN_SH)
    # scarpa
    d.ellipse([foot[0]-12, foot[1]-6, foot[0]+12, foot[1]+6], fill=SHOE)

    # Torso (rettangolo con curvatura)
    torso_x0, torso_x1 = 95, 218
    torso_top = body_y - 20
    torso_bot = body_y + 18
    draw_rounded_rect(d, [torso_x0, torso_top, torso_x1, torso_bot],
                      rx=10, ry=10, fill=SKIN)
    # addome linee
    for ax in [135, 155, 175]:
        d.line([(ax, torso_top+8), (ax, torso_bot-8)],
               fill=(170,130,95), width=1)

    # PETTO (muscolo target) — evidenziato amber
    chest_col = MUSCLE
    chest_shadow = MUSCLE2
    # petto sinistro (lato visibile)
    d.ellipse([torso_x0+2, torso_top+2, torso_x0+52, torso_top+32],
              fill=chest_shadow)
    d.ellipse([torso_x0+4, torso_top+3, torso_x0+50, torso_top+28],
              fill=chest_col)
    # petto destro
    d.ellipse([torso_x0+50, torso_top+2, torso_x0+104, torso_top+32],
              fill=chest_shadow)
    d.ellipse([torso_x0+52, torso_top+3, torso_x0+102, torso_top+28],
              fill=chest_col)
    # highlight petto
    d.ellipse([torso_x0+12, torso_top+5, torso_x0+32, torso_top+16],
              fill=(255,230,120))
    d.ellipse([torso_x0+62, torso_top+5, torso_x0+82, torso_top+16],
              fill=(255,230,120))

    # Spalle
    sh_l = (torso_x0 + 6, body_y - 14)
    sh_r = (torso_x1 - 6, body_y - 14)
    d.ellipse([sh_l[0]-18, sh_l[1]-18, sh_l[0]+18, sh_l[1]+18], fill=SKIN_SH)
    d.ellipse([sh_l[0]-16, sh_l[1]-16, sh_l[0]+16, sh_l[1]+16], fill=SKIN)
    d.ellipse([sh_r[0]-18, sh_r[1]-18, sh_r[0]+18, sh_r[1]+18], fill=SKIN_SH)
    d.ellipse([sh_r[0]-16, sh_r[1]-16, sh_r[0]+16, sh_r[1]+16], fill=SKIN)

    # ─── BRACCIO ANIMATO ───────────────────────────────────────────────────
    # Braccio sinistro (vicino a noi)
    elbow_y_top  = body_y - 52
    elbow_y_bot  = body_y - 26
    hand_y_top   = body_y - 74
    hand_y_bot   = body_y - 38

    elbow_y = lerp(elbow_y_top, elbow_y_bot, press_depth)
    hand_y  = lerp(hand_y_top,  hand_y_bot,  press_depth)
    elbow_x = sh_l[0] + 4
    hand_x  = sh_l[0] + 8

    draw_limb(d, sh_l, (elbow_x, elbow_y), 11, 9, SKIN, SKIN_SH)
    draw_limb(d, (elbow_x, elbow_y), (hand_x, hand_y), 9, 7, SKIN, SKIN_SH)

    # Braccio destro (di fondo, più piccolo)
    sh_r2 = (sh_r[0] - 4, sh_r[1] + 2)
    el2_y = lerp(elbow_y_top+2, elbow_y_bot+2, press_depth)
    h2_y  = lerp(hand_y_top+2,  hand_y_bot+2,  press_depth)
    draw_limb(d, sh_r2, (sh_r[0]+4, el2_y), 10, 8, SKIN_SH, (130,95,65))
    draw_limb(d, (sh_r[0]+4, el2_y), (sh_r[0]+8, h2_y), 8, 6, SKIN_SH, (130,95,65))

    # ─── BILANCIERE ────────────────────────────────────────────────────────
    bar_y = lerp(hand_y_top, hand_y_bot, press_depth)
    bar_center_x = (hand_x + sh_r[0] + 8) // 2
    bar_l = 260
    bx0_b = bar_center_x - bar_l // 2
    bx1_b = bar_center_x + bar_l // 2

    # Barra centrale
    d.rectangle([bx0_b+30, int(bar_y)-4, bx1_b-30, int(bar_y)+4], fill=BAR)
    d.rectangle([bx0_b+30, int(bar_y)-3, bx1_b-30, int(bar_y)+2],
                fill=(240,240,255))  # riflesso

    # Disco sinistro
    d.ellipse([bx0_b, int(bar_y)-18, bx0_b+28, int(bar_y)+18], fill=DISC_HL)
    d.ellipse([bx0_b+2, int(bar_y)-16, bx0_b+26, int(bar_y)+16], fill=DISC)
    d.ellipse([bx0_b+6, int(bar_y)-10, bx0_b+20, int(bar_y)+10], fill=DISC_HL)
    # Disco destro
    d.ellipse([bx1_b-28, int(bar_y)-18, bx1_b, int(bar_y)+18], fill=DISC_HL)
    d.ellipse([bx1_b-26, int(bar_y)-16, bx1_b-2, int(bar_y)+16], fill=DISC)
    d.ellipse([bx1_b-20, int(bar_y)-10, bx1_b-6, int(bar_y)+10], fill=DISC_HL)

    # ─── TESTA ─────────────────────────────────────────────────────────────
    head_x = 67
    head_y = body_y - 2
    # collo
    d.ellipse([head_x-8, head_y-8, head_x+8, head_y+8], fill=SKIN)
    # testa
    d.ellipse([head_x-20, head_y-32, head_x+20, head_y+4], fill=SKIN_SH)
    d.ellipse([head_x-18, head_y-30, head_x+18, head_y+2], fill=SKIN)
    # capelli
    d.ellipse([head_x-19, head_y-31, head_x+19, head_y-12], fill=(50,35,25))
    # occhio
    d.ellipse([head_x+4, head_y-20, head_x+10, head_y-14], fill=(30,20,15))
    # highlight occhio
    d.ellipse([head_x+6, head_y-19, head_x+9, head_y-16], fill=(250,240,230))

    # ─── LABEL MUSCOLO ─────────────────────────────────────────────────────
    # piccolo indicatore "PETTO" con freccia
    label_x, label_y = 48, 138
    d.polygon([(label_x+50, label_y), (label_x+50, label_y+2),
               (torso_x0+30, body_y-12)],
              fill=(255,200,40,120))
    d.text((label_x, label_y-10), "PETTO", fill=(255,200,40))

    return img

frames = [make_frame(i) for i in range(FRAMES)]

out = r"C:\Users\Gianmarco\app\miadiariogym\panca_piana_v2.gif"
frames[0].save(
    out,
    save_all=True,
    append_images=frames[1:],
    loop=0,
    duration=DELAY,
    optimize=False,
)
print(f"Salvata: {out}  ({FRAMES} frames, {W}x{H})")
