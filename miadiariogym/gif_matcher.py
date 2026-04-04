#!/usr/bin/env python3
"""
GIF Matcher interattivo per gli esercizi della gym app.

USO:
  python gif_matcher.py --download    # scarica TUTTE le GIF da fitnessprogramer.com
  python gif_matcher.py               # abbina esercizi -> GIF interattivamente
  python gif_matcher.py --apply       # applica il mapping salvato alle app

Il mapping viene salvato in gif_mapping.json
"""

import os
import sys
import json
import time
import re
import shutil
import urllib.request
import urllib.error
from pathlib import Path

# ── Percorsi ─────────────────────────────────────────────────────────────────
BASE       = Path(__file__).parent
ALL_GIFS   = BASE / "all_gifs"          # tutte le GIF scaricate
MAPPING    = BASE / "gif_mapping.json"  # {exercise_name: gif_filename}
APP_CLIENT = BASE / "app_cliente" / "assets" / "gif"
APP_PT     = BASE / "app_pt"     / "assets" / "gif"

# ── Esercizi del catalogo (nome IT, gifSlug atteso) ──────────────────────────
def gif_slug(name: str) -> str:
    s = name.lower()
    for old, new in [('è','e'),('é','e'),('à','a'),('á','a'),
                     ('ì','i'),('í','i'),('ò','o'),('ó','o'),
                     ('ù','u'),('ú','u')]:
        s = s.replace(old, new)
    s = s.replace("'","").replace("(","").replace(")","").replace(" ","_")
    return s

EXERCISES = [
    "Panca Piana", "Distensioni con Manubri", "Croci ai Cavi",
    "Panca Inclinata", "Croci con Manubri", "Push-Up", "Dip alle Parallele",
    "Stacchi da Terra", "Trazioni alla Sbarra", "Lat Machine",
    "Rematore con Bilanciere", "Rematore con Manubrio", "Lento Avanti",
    "Alzate Laterali", "Alzate Frontali", "Alzate Posteriori",
    "Curl con Bilanciere", "Curl con Manubri Alternati", "Curl Martello",
    "Curl al Cavo Basso", "French Press", "Tricipiti ai Cavi",
    "Dip ai Tricipiti", "Squat con Bilanciere", "Leg Press", "Affondi",
    "Leg Extension", "Leg Curl", "Romanian Deadlift", "Hip Thrust",
    "Glute Kickback", "Calf Raises", "Plank", "Crunch", "Russian Twist",
    "Leg Raise", "Clean and Press", "Kettlebell Swing", "Face Pull",
    "Panca Declinata", "Peck Deck", "Pull Over", "Chest Press Macchina",
    "Pulley Basso", "Trazioni Presa Neutra", "Back Extension", "Good Morning",
    "Arnold Press", "Shoulder Press Macchina", "Alzate di Spalle",
    "Push Up Diamante", "Concentration Curl", "Scott Curl",
    "Overhead Tricep Extension", "Hip Abductor", "Donkey Kick",
    "Bulgarian Split Squat", "Goblet Squat", "Sumo Deadlift", "Step Up",
    "Plank Laterale", "Mountain Climber",
]

# ── Utility ──────────────────────────────────────────────────────────────────
def clear():
    os.system("cls" if os.name == "nt" else "clear")

def header(txt: str):
    w = 70
    print("=" * w)
    print(f"  {txt}")
    print("=" * w)

def download_file(url: str, dest: Path, timeout: int = 15) -> bool:
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 Chrome/120 Safari/537.36"
        })
        with urllib.request.urlopen(req, timeout=timeout) as r, \
             open(dest, "wb") as f:
            f.write(r.read())
        return True
    except Exception:
        return False

# ── DOWNLOAD ─────────────────────────────────────────────────────────────────
def cmd_download():
    """Scarica tutte le GIF da fitnessprogramer.com"""
    ALL_GIFS.mkdir(exist_ok=True)
    print("Scaricando la sitemap indice da fitnessprogramer.com...")

    def get(url):
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 Chrome/120 Safari/537.36"
        })
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.read().decode("utf-8", errors="replace")

    # Legge la sitemap indice e trova le sotto-sitemap degli esercizi
    try:
        idx_xml = get("https://fitnessprogramer.com/sitemap_index.xml")
    except Exception as e:
        print(f"Errore sitemap indice: {e}")
        return

    all_sub = re.findall(r"<loc>(https://fitnessprogramer\.com/[^<]+\.xml)</loc>", idx_xml)
    exercise_sitemaps = [u for u in all_sub if "winner_exercise-sitemap" in u]
    print(f"Trovate {len(exercise_sitemaps)} sitemap degli esercizi")

    # Raccoglie tutti gli URL degli esercizi
    exercise_urls = []
    for sm_url in exercise_sitemaps:
        try:
            sm_xml = get(sm_url)
            urls = re.findall(r"<loc>([^<]+)</loc>", sm_xml)
            exercise_urls.extend(urls)
        except Exception:
            pass
    print(f"Totale pagine esercizio: {len(exercise_urls)}")

    downloaded = 0
    skipped    = 0

    for i, url in enumerate(exercise_urls):
        slug = url.rstrip("/").split("/")[-1]
        dest = ALL_GIFS / f"{slug}.gif"

        if dest.exists() and dest.stat().st_size > 5000:
            skipped += 1
            if (i + 1) % 100 == 0:
                print(f"  [{i+1}/{len(exercise_urls)}] {downloaded} scaricate, {skipped} skip")
            continue

        # Visita la pagina e cerca il tag img con .gif
        try:
            html = get(url)
        except Exception:
            continue

        gif_urls = re.findall(
            r"https://fitnessprogramer\.com/wp-content/uploads/[^\s\"']+\.gif",
            html
        )
        if not gif_urls:
            continue

        gif_url = gif_urls[0]
        if download_file(gif_url, dest):
            downloaded += 1
            size_kb = dest.stat().st_size // 1024
            if downloaded % 10 == 0 or size_kb > 500:
                print(f"  [{i+1}/{len(exercise_urls)}] ✓ {slug}.gif  ({size_kb} KB)")
        else:
            if dest.exists():
                dest.unlink()

        time.sleep(0.25)

    print(f"\nCompletato: {downloaded} scaricate, {skipped} già presenti")
    print(f"GIF totali in all_gifs/: {len(list(ALL_GIFS.glob('*.gif')))}")


# ── MATCH INTERATTIVO ─────────────────────────────────────────────────────────
def cmd_match():
    """Abbina esercizi → GIF interattivamente"""
    # Raccoglie GIF disponibili (prima da all_gifs, poi da assets)
    gifs: list[Path] = sorted(ALL_GIFS.glob("*.gif")) if ALL_GIFS.exists() else []
    if not gifs:
        # fallback: usa le GIF già nell'app
        gifs = sorted(APP_CLIENT.glob("*.gif"))
    if not gifs:
        print("Nessuna GIF trovata. Esegui prima: python gif_matcher.py --download")
        return

    # Carica mapping esistente
    mapping: dict = {}
    if MAPPING.exists():
        with open(MAPPING, encoding="utf-8") as f:
            mapping = json.load(f)

    gif_names = [g.name for g in gifs]
    total     = len(EXERCISES)

    for idx, ex in enumerate(EXERCISES):
        slug        = gif_slug(ex)
        current_gif = mapping.get(ex, f"{slug}.gif")
        current_ok  = any(g.name == current_gif for g in gifs)

        clear()
        header(f"ESERCIZIO {idx+1}/{total}: {ex}")
        print(f"  Slug atteso:  {slug}.gif")
        print(f"  GIF corrente: {current_gif}  ({'✓ esiste' if current_ok else '✗ non trovata'})")
        print()

        # Mostra GIF disponibili filtrate per somiglianza (priorità)
        ex_words = set(ex.lower().replace("-"," ").split())
        def score(name: str) -> int:
            n = name.lower().replace("-"," ").replace("_"," ")
            return sum(1 for w in ex_words if w in n)

        sorted_gifs = sorted(gif_names, key=lambda n: -score(n))
        page_size   = 30

        # Mostra prime page_size GIF (le più rilevanti)
        shown = sorted_gifs[:page_size]
        for i, name in enumerate(shown, 1):
            marker = " ◀" if name == current_gif else ""
            print(f"  {i:3}. {name}{marker}")
        if len(sorted_gifs) > page_size:
            print(f"  ... e altre {len(sorted_gifs)-page_size} (scrivi 'cerca <parola>' per filtrare)")

        print()
        print("  Comandi:")
        print("    <numero>        → seleziona GIF dalla lista")
        print("    cerca <parola>  → filtra GIF per nome")
        print("    s               → salta (mantieni corrente)")
        print("    q               → salva ed esci")

        while True:
            try:
                inp = input("\n  Scelta: ").strip().lower()
            except (EOFError, KeyboardInterrupt):
                print("\nInterrotto. Salvando...")
                _save_mapping(mapping)
                return

            if inp == "q":
                _save_mapping(mapping)
                return
            if inp == "s" or inp == "":
                break  # mantieni corrente
            if inp.startswith("cerca "):
                keyword = inp[6:].strip()
                filtered = [n for n in gif_names if keyword in n.lower()]
                print(f"\n  Risultati per '{keyword}':")
                for i, name in enumerate(filtered[:50], 1):
                    print(f"    {i:3}. {name}")
                # Ri-chiedi scelta da questa lista
                try:
                    inp2 = input("  Numero (o Enter per tornare): ").strip()
                except (EOFError, KeyboardInterrupt):
                    break
                if inp2.isdigit():
                    n = int(inp2) - 1
                    if 0 <= n < len(filtered):
                        mapping[ex] = filtered[n]
                        print(f"  → Abbinato: {filtered[n]}")
                        time.sleep(0.5)
                        break
                continue
            if inp.isdigit():
                n = int(inp) - 1
                if 0 <= n < len(shown):
                    mapping[ex] = shown[n]
                    print(f"  → Abbinato: {shown[n]}")
                    time.sleep(0.5)
                    break
                else:
                    print(f"  Numero non valido (1-{len(shown)})")
                    continue

    _save_mapping(mapping)
    print(f"\n✓ Mapping salvato in {MAPPING}")
    print("  Ora esegui: python gif_matcher.py --apply")


def _save_mapping(mapping: dict):
    with open(MAPPING, "w", encoding="utf-8") as f:
        json.dump(mapping, f, ensure_ascii=False, indent=2)


# ── APPLY ────────────────────────────────────────────────────────────────────
def cmd_apply():
    """Copia le GIF scelte con il nome gifSlug nelle cartelle delle app"""
    if not MAPPING.exists():
        print("Nessun mapping trovato. Esegui prima: python gif_matcher.py")
        return

    with open(MAPPING, encoding="utf-8") as f:
        mapping = json.load(f)

    # Dove cercare le GIF sorgente
    search_dirs = [ALL_GIFS, APP_CLIENT]

    ok = 0
    missing = []

    for ex, gif_name in mapping.items():
        slug = gif_slug(ex)
        dest_name = f"{slug}.gif"

        # Trova la sorgente
        src = None
        for d in search_dirs:
            candidate = d / gif_name
            if candidate.exists():
                src = candidate
                break

        if src is None:
            missing.append(gif_name)
            continue

        for dest_dir in [APP_CLIENT, APP_PT]:
            dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dest_dir / dest_name)

        print(f"  ✓ {ex:35s} → {dest_name}")
        ok += 1

    print(f"\n✓ {ok} GIF copiate nelle cartelle app")
    if missing:
        print(f"✗ {len(missing)} GIF non trovate: {missing[:5]}{'...' if len(missing)>5 else ''}")


# ── MAIN ─────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if "--download" in sys.argv:
        cmd_download()
    elif "--apply" in sys.argv:
        cmd_apply()
    else:
        cmd_match()
