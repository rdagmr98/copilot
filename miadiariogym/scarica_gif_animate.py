"""
Scarica GIF ANIMATE degli esercizi da ExerciseDB (gratis 500/mese).

SETUP (1 volta):
1. Vai su https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb
2. Clicca "Subscribe to Test" → scegli il piano FREE (500 richieste/mese)
3. Copia la tua API key da "Header value" → X-RapidAPI-Key
4. Incollala qui sotto al posto di YOUR_API_KEY_HERE

USO: python scarica_gif_animate.py
"""

import sys
import urllib.request
import urllib.parse
import json
import os
import time

sys.stdout.reconfigure(encoding='utf-8')

# ── INSERISCI QUI LA TUA API KEY GRATUITA DA RAPIDAPI ──────────────────────
RAPIDAPI_KEY = "YOUR_API_KEY_HERE"
# ───────────────────────────────────────────────────────────────────────────

BASE_URL = "https://exercisedb.p.rapidapi.com"
HEADERS = {
    "X-RapidAPI-Key": RAPIDAPI_KEY,
    "X-RapidAPI-Host": "exercisedb.p.rapidapi.com",
    "User-Agent": "Mozilla/5.0",
}

# Mapping: slug_flutter -> termini di ricerca in inglese (prova in ordine)
ESERCIZI = {
    "panca_piana":              ["bench press", "barbell bench press"],
    "panca_inclinata":          ["incline bench press"],
    "croci_con_manubri":        ["dumbbell fly", "chest fly"],
    "push_up":                  ["push-up", "push up"],
    "peck_deck":                ["chest fly machine", "pec deck"],
    "trazioni":                 ["pull-up", "pullup"],
    "lat_machine":              ["lat pulldown", "cable pulldown"],
    "rematore_con_bilanciere":  ["barbell row", "bent over row"],
    "rematore_con_manubrio":    ["dumbbell row", "one arm row"],
    "pulley_basso":             ["seated cable row", "cable row"],
    "face_pull":                ["face pull", "cable face pull"],
    "lento_avanti":             ["overhead press", "military press"],
    "alzate_laterali":          ["lateral raise", "dumbbell lateral raise"],
    "alzate_frontali":          ["front raise", "dumbbell front raise"],
    "arnold_press":             ["arnold press"],
    "curl_con_bilanciere":      ["barbell curl", "ez-bar curl"],
    "curl_con_manubri":         ["dumbbell curl", "bicep curl"],
    "curl_a_martello":          ["hammer curl"],
    "french_press":             ["skull crusher", "french press"],
    "tricipiti_alla_fune":      ["triceps pushdown", "cable pushdown"],
    "dip":                      ["triceps dip", "chest dip"],
    "squat":                    ["squat", "barbell squat"],
    "leg_press":                ["leg press"],
    "affondi":                  ["lunge", "dumbbell lunge"],
    "leg_extension":            ["leg extension"],
    "leg_curl":                 ["leg curl", "hamstring curl"],
    "stacchi_da_terra":         ["deadlift", "barbell deadlift"],
    "stacchi_rumeni":           ["romanian deadlift", "rdl"],
    "hip_thrust":               ["hip thrust", "glute bridge"],
    "calf_raise":               ["calf raise", "standing calf raise"],
    "donkey_kick":              ["donkey kick", "glute kickback"],
    "plank":                    ["plank"],
    "crunch":                   ["crunch", "ab crunch"],
    "leg_raise":                ["leg raise", "hanging leg raise"],
    "russian_twist":            ["russian twist"],
    "mountain_climber":         ["mountain climber", "climber"],
    "pull_over":                ["pullover", "dumbbell pullover"],
    "chest_press_macchina":     ["chest press machine", "machine chest press"],
    "shoulder_press_macchina":  ["machine shoulder press", "shoulder press machine"],
    "panca_declinata":          ["decline bench press"],
    "good_morning":             ["good morning"],
    "back_extension":           ["back extension", "hyperextension"],
    "hip_abductor":             ["hip abductor", "abductor machine"],
}

OUTPUT_DIRS = [
    r"C:\Users\Gianmarco\app\miadiariogym\app_cliente\assets\gif",
    r"C:\Users\Gianmarco\app\miadiariogym\app_pt\assets\gif",
]


def search_exercise(term):
    encoded = urllib.parse.quote(term)
    url = f"{BASE_URL}/exercises/name/{encoded}?limit=5"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=15) as r:
        results = json.loads(r.read())
    for ex in results:
        gif_url = ex.get("gifUrl", "")
        if gif_url:
            return gif_url
    return None


def download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=20) as r:
        with open(path, "wb") as f:
            f.write(r.read())


def main():
    if RAPIDAPI_KEY == "YOUR_API_KEY_HERE":
        print("ERRORE: Inserisci la tua API key RapidAPI (gratuita)!")
        print("  1. Vai su https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb")
        print("  2. Iscriviti gratis (piano FREE = 500 richieste/mese)")
        print("  3. Copia la chiave X-RapidAPI-Key e incollala nel file")
        return

    for d in OUTPUT_DIRS:
        os.makedirs(d, exist_ok=True)

    ok = 0
    not_found = []
    total = len(ESERCIZI)

    for idx, (slug, search_terms) in enumerate(ESERCIZI.items(), 1):
        print(f"[{idx:02d}/{total}] {slug}...", end=" ", flush=True)

        gif_url = None
        for term in search_terms:
            try:
                gif_url = search_exercise(term)
                if gif_url:
                    break
            except Exception as e:
                pass
            time.sleep(0.3)

        if not gif_url:
            not_found.append(slug)
            print("NON TROVATO")
            continue

        try:
            tmp = os.path.join(OUTPUT_DIRS[0], "__tmp.gif")
            download(gif_url, tmp)
            for d in OUTPUT_DIRS:
                dest = os.path.join(d, f"{slug}.gif")
                with open(tmp, "rb") as src, open(dest, "wb") as dst:
                    dst.write(src.read())
            os.remove(tmp)
            ok += 1
            print("OK (animato)")
        except Exception as e:
            not_found.append(f"{slug} (errore: {e})")
            print(f"ERRORE: {e}")

        time.sleep(0.5)

    print(f"\n{'='*50}")
    print(f"GIF animate scaricate: {ok}/{total}")
    if not_found:
        print("Non trovati:")
        for x in not_found:
            print(f"  - {x}")
    print("\nOra in entrambe le app:")
    print("  flutter clean && flutter run")


if __name__ == "__main__":
    main()
