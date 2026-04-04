"""
Download exercise GIFs from fitnessprogramer.com for the Italian gym app.

Strategy:
1. Fetch sitemaps to discover exercise page URLs
2. Scrape each exercise page to find the embedded GIF
3. Build a dict of slug → gif_url
4. Match our exercises and download
"""

import urllib.request
import urllib.error
import re
import time
import os
import shutil
import xml.etree.ElementTree as ET

# ── paths ──────────────────────────────────────────────────────────────────────
DEST_CLIENTE = r"C:\Users\Gianmarco\app\miadiariogym\app_cliente\assets\gif"
DEST_PT      = r"C:\Users\Gianmarco\app\miadiariogym\app_pt\assets\gif"

# ── headers ────────────────────────────────────────────────────────────────────
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                  'Chrome/120.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,'
              'image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Referer': 'https://fitnessprogramer.com/',
}

IMG_HEADERS = dict(HEADERS)
IMG_HEADERS['Accept'] = 'image/gif,image/*,*/*;q=0.8'

# ── exercise list ──────────────────────────────────────────────────────────────
# (slug_for_filename, [search_terms on the site – dash-separated])
EXERCISES = [
    ('panca_piana',               ['Barbell-Bench-Press', 'Bench-Press']),
    ('distensioni_con_manubri',   ['Dumbbell-Bench-Press', 'Dumbbell-Press']),
    ('croci_ai_cavi',             ['Cable-Crossover', 'Cable-Fly', 'Cable-Chest-Fly']),
    ('panca_inclinata',           ['Incline-Bench-Press', 'Incline-Barbell-Press']),
    ('croci_con_manubri',         ['Dumbbell-Fly', 'Dumbbell-Flyes', 'Dumbbell-Chest-Fly']),
    ('push-up',                   ['Push-Up', 'Pushup']),
    ('push_up',                   ['Push-Up', 'Pushup']),
    ('dip_alle_parallele',        ['Parallel-Bar-Dip', 'Chest-Dip', 'Dips']),
    ('dip',                       ['Parallel-Bar-Dip', 'Dips']),
    ('panca_declinata',           ['Decline-Bench-Press', 'Decline-Barbell-Press']),
    ('peck_deck',                 ['Pec-Deck-Fly', 'Peck-Deck', 'Machine-Fly']),
    ('pull_over',                 ['Barbell-Pullover', 'Dumbbell-Pullover']),
    ('chest_press_macchina',      ['Machine-Chest-Press', 'Chest-Press-Machine']),
    ('stacchi_da_terra',          ['Barbell-Deadlift', 'Deadlift']),
    ('trazioni_alla_sbarra',      ['Pull-Up', 'Chin-Up']),
    ('trazioni',                  ['Pull-Up', 'Chin-Up']),
    ('lat_machine',               ['Lat-Pulldown', 'Cable-Lat-Pulldown']),
    ('rematore_con_bilanciere',   ['Barbell-Row', 'Bent-Over-Barbell-Row', 'Bent-Over-Row']),
    ('rematore_con_manubrio',     ['Dumbbell-Row', 'Single-Arm-Dumbbell-Row', 'One-Arm-Row']),
    ('pulley_basso',              ['Seated-Cable-Row', 'Low-Pulley-Row', 'Cable-Row']),
    ('face_pull',                 ['Face-Pull', 'Cable-Face-Pull']),
    ('trazioni_presa_neutra',     ['Neutral-Grip-Pull-Up', 'Close-Grip-Pull-Up']),
    ('back_extension',            ['Back-Extension', 'Hyperextension', 'Back-Hyperextension']),
    ('good_morning',              ['Good-Morning', 'Barbell-Good-Morning']),
    ('lento_avanti',              ['Overhead-Press', 'Military-Press', 'Barbell-Overhead-Press']),
    ('alzate_laterali',           ['Lateral-Raise', 'Dumbbell-Lateral-Raise', 'Side-Lateral-Raise']),
    ('alzate_frontali',           ['Front-Raise', 'Dumbbell-Front-Raise']),
    ('alzate_di_spalle',          ['Shrug', 'Barbell-Shrug', 'Dumbbell-Shrug']),
    ('arnold_press',              ['Arnold-Press', 'Arnold-Dumbbell-Press']),
    ('shoulder_press_macchina',   ['Machine-Shoulder-Press', 'Shoulder-Press-Machine']),
    ('curl_con_bilanciere',       ['Barbell-Curl', 'Bicep-Curl', 'Barbell-Bicep-Curl']),
    ('curl_con_manubri_alternati',['Alternating-Dumbbell-Curl', 'Dumbbell-Curl']),
    ('curl_con_manubri',          ['Dumbbell-Curl', 'Alternating-Dumbbell-Curl']),
    ('curl_martello',             ['Hammer-Curl', 'Dumbbell-Hammer-Curl']),
    ('scott_curl',                ['Preacher-Curl', 'Scott-Curl', 'EZ-Bar-Preacher-Curl']),
    ('concentration_curl',        ['Concentration-Curl', 'Dumbbell-Concentration-Curl']),
    ('tricipiti_ai_cavi',         ['Tricep-Pushdown', 'Cable-Tricep-Pushdown', 'Triceps-Pushdown']),
    ('tricipiti_alla_fune',       ['Rope-Tricep-Pushdown', 'Tricep-Rope-Pushdown']),
    ('french_press',              ['French-Press', 'Skull-Crusher', 'Lying-Tricep-Extension', 'EZ-Bar-Skull-Crusher']),
    ('overhead_tricep_extension', ['Overhead-Tricep-Extension', 'Dumbbell-Overhead-Extension']),
    ('squat_con_bilanciere',      ['Barbell-Squat', 'Back-Squat', 'Squat']),
    ('squat',                     ['Barbell-Squat', 'Back-Squat', 'Squat']),
    ('leg_press',                 ['Leg-Press', '45-Degree-Leg-Press']),
    ('leg_extension',             ['Leg-Extension', 'Machine-Leg-Extension']),
    ('leg_curl',                  ['Leg-Curl', 'Lying-Leg-Curl', 'Machine-Leg-Curl']),
    ('affondi',                   ['Lunge', 'Dumbbell-Lunge', 'Barbell-Lunge', 'Walking-Lunge']),
    ('stacchi_rumeni',            ['Romanian-Deadlift', 'RDL']),
    ('romanian_deadlift',         ['Romanian-Deadlift', 'RDL']),
    ('bulgarian_split_squat',     ['Bulgarian-Split-Squat', 'Split-Squat']),
    ('goblet_squat',              ['Goblet-Squat', 'Dumbbell-Goblet-Squat']),
    ('sumo_deadlift',             ['Sumo-Deadlift', 'Sumo-Barbell-Deadlift']),
    ('step_up',                   ['Step-Up', 'Dumbbell-Step-Up', 'Box-Step-Up']),
    ('calf_raises',               ['Calf-Raise', 'Standing-Calf-Raise', 'Calf-Raises']),
    ('calf_raise',                ['Calf-Raise', 'Standing-Calf-Raise']),
    ('hip_thrust',                ['Hip-Thrust', 'Barbell-Hip-Thrust', 'Glute-Bridge']),
    ('donkey_kick',               ['Donkey-Kick', 'Donkey-Kickback']),
    ('hip_abductor',              ['Hip-Abductor', 'Hip-Abduction', 'Machine-Hip-Abduction']),
    ('crunch',                    ['Crunch', 'Ab-Crunch', 'Crunches']),
    ('leg_raise',                 ['Leg-Raise', 'Lying-Leg-Raise', 'Hanging-Leg-Raise']),
    ('plank',                     ['Plank', 'Front-Plank']),
    ('russian_twist',             ['Russian-Twist', 'Seated-Russian-Twist']),
    ('mountain_climber',          ['Mountain-Climber', 'Mountain-Climbers']),
    ('plank_laterale',            ['Side-Plank', 'Lateral-Plank']),
    ('push_up_diamante',          ['Diamond-Push-Up', 'Close-Grip-Push-Up', 'Triangle-Push-Up']),
]

# ── helpers ────────────────────────────────────────────────────────────────────

def fetch(url, headers=None, timeout=10):
    """Return response bytes or None."""
    try:
        req = urllib.request.Request(url, headers=headers or HEADERS)
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.read()
    except Exception as e:
        return None


def fetch_text(url, timeout=10):
    data = fetch(url, timeout=timeout)
    return data.decode('utf-8', errors='ignore') if data else None


def find_gif_in_html(html):
    """Return first fitnessprogramer wp-content GIF URL found in HTML."""
    hits = re.findall(
        r'https://fitnessprogramer\.com/wp-content/uploads/\d{4}/\d{2}/[^"\'<>\s]+\.gif',
        html
    )
    # Prefer the largest / first one
    return hits[0] if hits else None


def is_real_gif(data):
    """Check that the first bytes look like a GIF."""
    return data is not None and len(data) >= 4 and data[:4] in (b'GIF8', b'GIF9')


# ── step 1: build GIF map from sitemaps ────────────────────────────────────────

def collect_exercise_urls_from_sitemap():
    """Return a list of /exercise/.../ page URLs."""
    print("Fetching sitemap index …")
    exercise_urls = []

    for index_url in [
        'https://fitnessprogramer.com/sitemap_index.xml',
        'https://fitnessprogramer.com/sitemap.xml',
    ]:
        xml_bytes = fetch(index_url)
        if not xml_bytes:
            continue
        text = xml_bytes.decode('utf-8', errors='ignore')

        # Collect child sitemap URLs
        child_sitemaps = re.findall(r'<loc>\s*(https://[^<]+\.xml)\s*</loc>', text)
        print(f"  Found {len(child_sitemaps)} child sitemaps in {index_url}")

        if not child_sitemaps:
            # Maybe it's already a flat sitemap with exercise URLs
            exercise_urls += re.findall(
                r'<loc>\s*(https://fitnessprogramer\.com/exercise/[^<]+/)\s*</loc>', text
            )
        else:
            for sm_url in child_sitemaps:
                if 'exercise' in sm_url or 'post' in sm_url or 'page' in sm_url:
                    print(f"  Parsing child sitemap: {sm_url}")
                    sm_bytes = fetch(sm_url)
                    if not sm_bytes:
                        continue
                    sm_text = sm_bytes.decode('utf-8', errors='ignore')
                    found = re.findall(
                        r'<loc>\s*(https://fitnessprogramer\.com/exercise/[^<]+/)\s*</loc>',
                        sm_text
                    )
                    exercise_urls += found
                    if found:
                        print(f"    → {len(found)} exercise URLs")
                    time.sleep(0.2)

        if exercise_urls:
            break

    return list(dict.fromkeys(exercise_urls))  # deduplicate preserving order


def build_gif_map_from_sitemap():
    """
    Walk exercise URLs from sitemap, scrape each page for its GIF.
    Returns dict: lowercase-slug → gif_url
    """
    exercise_page_urls = collect_exercise_urls_from_sitemap()
    print(f"\nTotal exercise pages found in sitemaps: {len(exercise_page_urls)}")

    gif_map = {}   # slug → url
    total = len(exercise_page_urls)

    for i, page_url in enumerate(exercise_page_urls, 1):
        # Extract slug from URL: .../exercise/barbell-bench-press/ → barbell-bench-press
        m = re.search(r'/exercise/([^/]+)/?$', page_url)
        if not m:
            continue
        slug = m.group(1).lower()

        if i % 50 == 0 or i <= 3:
            print(f"  [{i}/{total}] {slug}")

        html = fetch_text(page_url, timeout=10)
        if not html:
            time.sleep(0.5)
            continue

        gif_url = find_gif_in_html(html)
        if gif_url:
            gif_map[slug] = gif_url

        time.sleep(0.25)

    print(f"GIF map built: {len(gif_map)} entries")
    return gif_map


# ── step 2: fallback – try direct URL guessing ─────────────────────────────────

YEARS  = ['2021', '2022', '2023', '2024']
MONTHS = ['01','02','03','04','05','06','07','08','09','10','11','12']

def try_direct_url(name_variant):
    """Try all year/month combos for the given name variant. Return URL or None."""
    for year in YEARS:
        for month in MONTHS:
            url = (f'https://fitnessprogramer.com/wp-content/uploads/'
                   f'{year}/{month}/{name_variant}.gif')
            data = fetch(url, headers=IMG_HEADERS, timeout=5)
            if is_real_gif(data):
                return url
    return None


def scrape_exercise_page(slug):
    """
    Visit fitnessprogramer.com/exercise/{slug}/ and return the GIF URL found, or None.
    """
    url = f'https://fitnessprogramer.com/exercise/{slug}/'
    html = fetch_text(url, timeout=10)
    if not html:
        return None
    return find_gif_in_html(html)


# ── step 3: find the best GIF URL for each of our exercises ───────────────────

def find_gif_for_exercise(slug, search_terms, gif_map):
    """
    Try (in order):
    1. Exact match in gif_map (slug converted to lowercase-with-dashes)
    2. Substring/alias match in gif_map keys
    3. Scrape the exercise page directly
    4. Direct URL guessing
    Returns gif_url or None.
    """
    # 1. Check gif_map with each search term as a potential page slug
    for term in search_terms:
        key = term.lower()
        if key in gif_map:
            return gif_map[key]

    # 2. Fuzzy: try to find if any gif_map key contains all words of the first term
    for term in search_terms:
        words = term.lower().split('-')
        for key, url in gif_map.items():
            if all(w in key for w in words):
                return url

    # 3. Scrape exercise page for each search term variant
    for term in search_terms:
        page_slug = term.lower()
        url = scrape_exercise_page(page_slug)
        if url:
            return url
        time.sleep(0.3)

    # 4. Direct URL guessing
    for term in search_terms:
        url = try_direct_url(term)
        if url:
            return url

    return None


# ── step 4: download a GIF ─────────────────────────────────────────────────────

def download_gif(gif_url, dest_paths):
    """Download gif_url and save to every path in dest_paths. Return bytes written or 0."""
    data = fetch(gif_url, headers=IMG_HEADERS, timeout=30)
    if not is_real_gif(data):
        return 0
    for path in dest_paths:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(data)
    return len(data)


# ── main ───────────────────────────────────────────────────────────────────────

def main():
    os.makedirs(DEST_CLIENTE, exist_ok=True)
    os.makedirs(DEST_PT,      exist_ok=True)

    # ── Phase 1: build GIF map from sitemaps ─────────────────────────────────
    gif_map = build_gif_map_from_sitemap()

    # If sitemap yielded nothing, try the exercise-list page
    if not gif_map:
        print("\nSitemap approach failed – trying exercise-list page …")
        for listing in ['https://fitnessprogramer.com/exercise-list/',
                        'https://fitnessprogramer.com/exercises/']:
            html = fetch_text(listing)
            if not html:
                continue
            # Grab all exercise page links
            links = re.findall(r'https://fitnessprogramer\.com/exercise/([^/"]+)/', html)
            print(f"  Found {len(links)} exercise links on {listing}")
            for link_slug in dict.fromkeys(links):
                page_html = fetch_text(f'https://fitnessprogramer.com/exercise/{link_slug}/')
                if page_html:
                    gif_url = find_gif_in_html(page_html)
                    if gif_url:
                        gif_map[link_slug.lower()] = gif_url
                time.sleep(0.3)
            if gif_map:
                break

    print(f"\nTotal GIFs discovered: {len(gif_map)}\n")

    # ── Phase 2: match & download ─────────────────────────────────────────────
    downloaded  = []
    not_found   = []
    total_bytes = 0

    # Deduplicate: if the same gif_url will serve multiple slugs,
    # download once and copy the rest.
    url_cache = {}  # gif_url → downloaded bytes

    for slug, search_terms in EXERCISES:
        print(f"[{slug}] searching …", end=' ', flush=True)
        gif_url = find_gif_for_exercise(slug, search_terms, gif_map)

        if not gif_url:
            print("NOT FOUND")
            not_found.append(slug)
            time.sleep(0.1)
            continue

        dest_c = os.path.join(DEST_CLIENTE, f"{slug}.gif")
        dest_p = os.path.join(DEST_PT,      f"{slug}.gif")

        # Use cached data if we already downloaded this URL
        if gif_url in url_cache:
            data = url_cache[gif_url]
            for path in (dest_c, dest_p):
                with open(path, 'wb') as f:
                    f.write(data)
            size = len(data)
        else:
            size = download_gif(gif_url, [dest_c, dest_p])
            if size == 0:
                print(f"DOWNLOAD FAILED ({gif_url})")
                not_found.append(slug)
                time.sleep(0.3)
                continue
            data = open(dest_c, 'rb').read()
            url_cache[gif_url] = data

        total_bytes += size
        downloaded.append((slug, gif_url, size))
        print(f"OK  {size//1024} KB  ← {gif_url}")
        time.sleep(0.3)

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "="*70)
    print(f"Downloaded : {len(downloaded)} / {len(EXERCISES)} exercises")
    print(f"Not found  : {len(not_found)}")
    print(f"Total size : {total_bytes / 1024 / 1024:.1f} MB")
    if not_found:
        print("\nMissing exercises (kept existing GIF):")
        for s in not_found:
            print(f"  - {s}")
    print("="*70)


if __name__ == '__main__':
    main()
