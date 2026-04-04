"""
Genera una GIF animata stile uniforme per l'esercizio "Panca Piana".
Stile: sfondo scuro, stick figure bianco, bilanciere color ambra/oro.
Output: panca_piana_example.gif (300x300px, 30 frames, loop)
"""
import math
from PIL import Image, ImageDraw

# ─── Palette ───────────────────────────────────────────────
BG      = (14, 14, 16)        # #0E0E10 quasi-nero
BODY    = (230, 230, 230)     # bianco/grigio chiaro
BAR     = (255, 210, 50)      # ambra/oro
BENCH   = (60, 60, 70)        # grigio scuro per la panca
LINE_W  = 4
HEAD_R  = 14

W, H   = 300, 300
FRAMES = 30
DELAY  = 60  # ms per frame → ~16 fps

# ─── Keyframe dati (t=0 braccio disteso in alto, t=0.5 barre abbassate) ─────
# Tutto relativo a centro schermo. La figura è sdraiata → asse lungo X
# Testa sul lato sinistro, gambe a destra
# Corpo orizzontale a h=140
BODY_Y  = 148   # y del busto (sdraiato)
BENCH_Y = 165   # y della panca (sotto il corpo)
HEAD_X  = 70    # centro testa
SHOULDER_X = 100
HIP_X  = 200
KNEE_X = 240
FOOT_X = 275

# Braccio: spalla fissa, gomito + mano si alzano/abbassano
SHOULDER = (SHOULDER_X, BODY_Y - 2)
# In alto (start/end): mano a ~y=60, gomito intermedio
TOP_HAND_Y  = 70
TOP_ELBOW_Y = 90
# In basso (petto): mano a ~y=125, gomito=132
BOT_HAND_Y  = 128
BOT_ELBOW_Y = 135

def lerp(a, b, t): return a + (b - a) * t

def eased(t):
    """Smooth ease-in-out: da 0→1→0"""
    # t in [0,1] → triangolo con smoothstep
    phase = t * 2           # 0‥2
    if phase < 1:
        raw = phase         # 0→1 (abbassare)
    else:
        raw = 2 - phase     # 1→0 (sollevare)
    # smoothstep
    return raw * raw * (3 - 2 * raw)

frames = []
for i in range(FRAMES):
    t = i / FRAMES
    ease = eased(t)

    img = Image.new("RGB", (W, H), BG)
    d   = ImageDraw.Draw(img)

    # ── PANCA ──────────────────────────────────────────────
    # Rettangolo piatto sotto il corpo
    d.rectangle([55, BENCH_Y, 285, BENCH_Y + 14], fill=BENCH)
    # Gamba panca sinistra
    d.rectangle([65, BENCH_Y + 14, 72, BENCH_Y + 40], fill=BENCH)
    # Gamba panca destra
    d.rectangle([270, BENCH_Y + 14, 277, BENCH_Y + 40], fill=BENCH)

    # ── CORPO (sdraiato) ───────────────────────────────────
    # Testa
    d.ellipse(
        [HEAD_X - HEAD_R, BODY_Y - HEAD_R,
         HEAD_X + HEAD_R, BODY_Y + HEAD_R],
        outline=BODY, width=LINE_W
    )
    # Collo → spalla
    d.line([(HEAD_X + HEAD_R, BODY_Y), (SHOULDER_X, BODY_Y)],
           fill=BODY, width=LINE_W)
    # Busto (spalla → anca)
    d.line([(SHOULDER_X, BODY_Y), (HIP_X, BODY_Y)],
           fill=BODY, width=LINE_W)
    # Coscia (anca → ginocchio)
    d.line([(HIP_X, BODY_Y), (KNEE_X, BODY_Y - 10)],
           fill=BODY, width=LINE_W)
    # Gamba (ginocchio → piede) — legg. piegata verso l'alto
    d.line([(KNEE_X, BODY_Y - 10), (FOOT_X, BODY_Y + 5)],
           fill=BODY, width=LINE_W)

    # ── BRACCIO (animato) ──────────────────────────────────
    elbow_y = lerp(TOP_ELBOW_Y, BOT_ELBOW_Y, ease)
    hand_y  = lerp(TOP_HAND_Y,  BOT_HAND_Y,  ease)
    elbow_x = SHOULDER_X + 22
    hand_x  = SHOULDER_X + 12

    # spalla → gomito
    d.line([SHOULDER, (elbow_x, elbow_y)], fill=BODY, width=LINE_W)
    # gomito → mano
    d.line([(elbow_x, elbow_y), (hand_x, hand_y)], fill=BODY, width=LINE_W)

    # ── BILANCIERE ─────────────────────────────────────────
    bar_y = hand_y
    bar_l = 175    # lunghezza totale barra
    bar_x0 = hand_x - bar_l // 2
    bar_x1 = hand_x + bar_l // 2
    # Barra centrale
    d.line([(bar_x0 + 28, bar_y), (bar_x1 - 28, bar_y)], fill=BAR, width=5)
    # Disco sinistro
    d.ellipse([bar_x0, bar_y - 14, bar_x0 + 24, bar_y + 14],
              outline=BAR, width=4)
    # Disco destro
    d.ellipse([bar_x1 - 24, bar_y - 14, bar_x1, bar_y + 14],
              outline=BAR, width=4)

    frames.append(img)

# Salva GIF
out = r"C:\Users\Gianmarco\app\miadiariogym\panca_piana_example.gif"
frames[0].save(
    out,
    save_all=True,
    append_images=frames[1:],
    loop=0,
    duration=DELAY,
    optimize=False,
)
print(f"Salvata: {out}  ({len(frames)} frames, {W}x{H})")
