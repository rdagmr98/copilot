"""
GIF esempio singolo - stile LIFTA-inspired
Corpo muscoloso anatomico con muscolo target evidenziato in gold.
Esercizio: Panca Piana (bench press) - vista laterale
"""
import math
from PIL import Image, ImageDraw

W, H = 320, 320
FRAMES = 28
DELAY = 55

BG         = (12, 12, 15)
BODY       = (160, 160, 175)
BODY_SH    = (95, 95, 110)
BODY_HI    = (200, 200, 215)
ACTIVE     = (255, 185, 30)
ACTIVE_SH  = (200, 130, 15)
ACTIVE_HI  = (255, 220, 100)
BENCH_C    = (50, 50, 62)
BENCH_HL   = (75, 75, 90)
BAR        = (215, 215, 230)
DISC_C     = (55, 55, 68)
DISC_HL    = (85, 85, 100)
SHORTS     = (35, 55, 100)
SHOE       = (32, 32, 38)

def ease_inout(t):
    # smooth 0→1→0
    phase = (t * 2) % 2
    r = phase if phase < 1.0 else 2.0 - phase
    return r * r * (3 - 2 * r)

def lerp(a, b, t):
    if isinstance(a, tuple):
        return tuple(int(a[i] + (b[i]-a[i])*t) for i in range(len(a)))
    return a + (b-a)*t

def draw_seg(d, cx, cy, rx, ry, base, shadow, highlight, angle_deg=0):
    """Ellisse muscolosa con shading 3D."""
    # ombra (leggermente offset in basso-destra)
    d.ellipse([cx-rx+3, cy-ry+3, cx+rx+3, cy+ry+3], fill=shadow)
    # corpo
    d.ellipse([cx-rx, cy-ry, cx+rx, cy+ry], fill=base)
    # highlight (quarto in alto-sinistra, più piccolo)
    hx, hy = int(rx*0.4), int(ry*0.4)
    d.ellipse([cx-hx, cy-hy-int(ry*0.25),
               cx+hx, cy+hy-int(ry*0.25)], fill=highlight)

def draw_limb_seg(d, x1,y1, x2,y2, r1, r2, base, shadow):
    """Arto come trapezio con shading."""
    dx = x2-x1; dy = y2-y1
    L = math.hypot(dx, dy)
    if L < 1: return
    nx, ny = -dy/L, dx/L
    pts = [(x1+nx*r1, y1+ny*r1),(x1-nx*r1, y1-ny*r1),
           (x2-nx*r2, y2-ny*r2),(x2+nx*r2, y2+ny*r2)]
    d.polygon(pts, fill=base)
    # shading lato
    shade = [(x1+nx*r1*0.2, y1+ny*r1*0.2),(x1+nx*r1, y1+ny*r1),
             (x2+nx*r2, y2+ny*r2),(x2+nx*r2*0.2, y2+ny*r2*0.2)]
    d.polygon(shade, fill=shadow)
    d.ellipse([x1-r1,y1-r1,x1+r1,y1+r1], fill=base)
    d.ellipse([x2-r2,y2-r2,x2+r2,y2+r2], fill=base)

def make_frame(i):
    t = i / FRAMES
    e = ease_inout(t)  # 0=barra su, 1=barra giù

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # ── PANCA ─────────────────────────────────────────
    bx0, by0, bx1, by1 = 38, 182, 282, 198
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=6, fill=BENCH_HL)
    d.rounded_rectangle([bx0+2, by0+5, bx1-2, by1], radius=4, fill=BENCH_C)
    for lx in [62, 258]:
        d.rectangle([lx-6, by1, lx+6, by1+28], fill=BENCH_C)
        d.rectangle([lx-14, by1+24, lx+14, by1+32], fill=BENCH_C)

    # ── GAMBE ─────────────────────────────────────────
    body_y = 175
    hip = (220, body_y+2)
    knee = (258, body_y-6)
    foot = (280, body_y+14)
    draw_limb_seg(d, *hip, *knee, 17, 14, SHORTS, (20,35,75))
    draw_limb_seg(d, *knee, *foot, 13, 9, BODY, BODY_SH)
    d.ellipse([foot[0]-13, foot[1]-7, foot[0]+13, foot[1]+7], fill=SHOE)

    # ── TORSO ─────────────────────────────────────────
    tx0, tx1 = 102, 222
    ttop, tbot = body_y-22, body_y+20
    d.rounded_rectangle([tx0, ttop, tx1, tbot], radius=12, fill=BODY_SH)
    d.rounded_rectangle([tx0, ttop, tx1-6, tbot-4], radius=12, fill=BODY)
    # addome
    for ax in range(tx0+28, tx1-20, 18):
        d.rectangle([ax, ttop+8, ax+2, tbot-8], fill=BODY_SH)

    # PETTO EVIDENZIATO (muscolo target)
    # pettorale sinistro (vicino)
    d.ellipse([tx0, ttop, tx0+58, ttop+36], fill=ACTIVE_SH)
    d.ellipse([tx0+2, ttop+1, tx0+56, ttop+34], fill=ACTIVE)
    d.ellipse([tx0+10, ttop+4, tx0+36, ttop+18], fill=ACTIVE_HI)
    # pettorale destro
    d.ellipse([tx0+54, ttop, tx0+112, ttop+36], fill=ACTIVE_SH)
    d.ellipse([tx0+56, ttop+1, tx0+110, ttop+34], fill=ACTIVE)
    d.ellipse([tx0+64, ttop+4, tx0+90, ttop+18], fill=ACTIVE_HI)

    # ── SPALLE ─────────────────────────────────────────
    sh_l = (tx0+10, body_y-16)
    sh_r = (tx1-10, body_y-16)
    for sh in [sh_l, sh_r]:
        d.ellipse([sh[0]-19, sh[1]-19, sh[0]+19, sh[1]+19], fill=BODY_SH)
        d.ellipse([sh[0]-17, sh[1]-17, sh[0]+17, sh[1]+17], fill=BODY)
        d.ellipse([sh[0]-9, sh[1]-12, sh[0]+6, sh[1]+2], fill=BODY_HI)

    # ── BRACCIO ANIMATO ─────────────────────────────────
    # Braccio sinistro (primo piano)
    elbow_y = lerp(body_y-60, body_y-28, e)
    hand_y  = lerp(body_y-86, body_y-42, e)
    el_x    = sh_l[0] + 5
    h_x     = sh_l[0] + 10
    draw_limb_seg(d, sh_l[0], sh_l[1], el_x, elbow_y, 12, 10, BODY, BODY_SH)
    draw_limb_seg(d, el_x, elbow_y, h_x, hand_y, 10, 8, BODY, BODY_SH)
    # Braccio destro (sfondo, più scuro)
    el2_y = lerp(body_y-58, body_y-26, e)
    h2_y  = lerp(body_y-82, body_y-38, e)
    draw_limb_seg(d, sh_r[0]-4, sh_r[1]+2, sh_r[0]+6, el2_y, 11, 9, BODY_SH, (70,70,85))
    draw_limb_seg(d, sh_r[0]+6, el2_y, sh_r[0]+10, h2_y, 9, 7, BODY_SH, (70,70,85))

    # ── BILANCIERE ──────────────────────────────────────
    bar_y  = lerp(hand_y - 4, hand_y, e)
    bar_cx = int((h_x + sh_r[0] + 10) / 2)
    half   = 138
    bx0_b  = bar_cx - half
    bx1_b  = bar_cx + half

    # Disco sx
    d.ellipse([bx0_b,    int(bar_y)-20, bx0_b+30, int(bar_y)+20], fill=DISC_HL)
    d.ellipse([bx0_b+2,  int(bar_y)-18, bx0_b+28, int(bar_y)+18], fill=DISC_C)
    d.ellipse([bx0_b+7,  int(bar_y)-11, bx0_b+21, int(bar_y)+11], fill=DISC_HL)
    # Barra
    d.rectangle([bx0_b+28, int(bar_y)-5, bx1_b-28, int(bar_y)+5], fill=BAR)
    d.rectangle([bx0_b+28, int(bar_y)-4, bx1_b-28, int(bar_y)-1], fill=(240,240,255))
    # Disco dx
    d.ellipse([bx1_b-30, int(bar_y)-20, bx1_b,    int(bar_y)+20], fill=DISC_HL)
    d.ellipse([bx1_b-28, int(bar_y)-18, bx1_b-2,  int(bar_y)+18], fill=DISC_C)
    d.ellipse([bx1_b-21, int(bar_y)-11, bx1_b-7,  int(bar_y)+11], fill=DISC_HL)

    # ── TESTA ────────────────────────────────────────────
    hx, hy = 68, body_y - 2
    # collo
    d.rounded_rectangle([hx-8, hy-6, hx+8, hy+10], radius=4, fill=BODY)
    # testa
    d.ellipse([hx-21, hy-38, hx+21, hy+4],  fill=BODY_SH)
    d.ellipse([hx-20, hy-37, hx+19, hy+2],  fill=(185,155,120))
    # capelli
    d.ellipse([hx-21, hy-38, hx+21, hy-12], fill=(45,32,22))
    # occhio
    d.ellipse([hx+4,  hy-22, hx+11, hy-14], fill=(28,18,12))
    d.ellipse([hx+5,  hy-21, hx+8,  hy-17], fill=(240,230,215))
    # orecchio
    d.ellipse([hx-22, hy-18, hx-13, hy-8],  fill=(170,140,105))

    # ── LABEL ────────────────────────────────────────────
    d.rectangle([90, 296, 230, 316], fill=(30,30,35))
    d.text((100, 299), "PETTO  ●  PANCA PIANA", fill=ACTIVE)

    return img

frames = [make_frame(i) for i in range(FRAMES)]
out = r"C:\Users\Gianmarco\app\miadiariogym\esempio_stile.gif"
frames[0].save(out, save_all=True, append_images=frames[1:],
               loop=0, duration=DELAY, optimize=False)
print(f"Salvato: {out}")
