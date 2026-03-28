#!/usr/bin/env python3
"""
Scarica video MP4 degli esercizi da MuscleWiki per le app gym.
Uso: python scarica_video_esercizi.py
I file verranno salvati in app_cliente/assets/videos/ e app_pt/assets/videos/
"""
import urllib.request
import re
import sys
import os
import time

sys.stdout.reconfigure(encoding='utf-8')

class RedirectHandler(urllib.request.HTTPRedirectHandler):
    def http_error_308(self, req, fp, code, msg, headers):
        loc = headers['Location']
        if not loc.startswith('http'):
            loc = 'https://musclewiki.com' + loc
        return self.parent.open(urllib.request.Request(loc, headers=req.headers))

opener = urllib.request.build_opener(RedirectHandler)
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120',
    'Accept': 'text/html,*/*'
}

# Mappa: Italian name → musclewiki exercise name (for URL matching)
# The value is searched in the video URL slug
EXERCISE_MAP = {
    'panca_piana':              'barbell-bench-press',
    'panca_inclinata':          'incline-bench-press',
    'croci_con_manubri':        'dumbbell-flyes',
    'push-up':                  'push-up',
    'push_up':                  'push-up',
    'dip_alle_parallele':       'chest-dip',
    'stacchi_da_terra':         'deadlift',
    'trazioni_alla_sbarra':     'pull-up',
    'lat_machine':              'lat-pulldown',
    'rematore_con_bilanciere':  'barbell-row',
    'rematore_con_manubrio':    'dumbbell-row',
    'lento_avanti':             'overhead-press',
    'alzate_laterali':          'lateral-raise',
    'alzate_frontali':          'front-raise',
    'alzate_posteriori':        'rear-delt-fly',
    'curl_con_bilanciere':      'barbell-curl',
    'curl_con_manubri_alternati': 'dumbbell-curl',
    'curl_martello':            'hammer-curl',
    'curl_al_cavo_basso':       'cable-curl',
    'french_press':             'skull-crusher',
    'tricipiti_ai_cavi':        'cable-tricep-pushdown',
    'dip_ai_tricipiti':         'tricep-dip',
    'squat_con_bilanciere':     'barbell-squat',
    'leg_press':                'leg-press',
    'affondi':                  'lunge',
    'leg_extension':            'leg-extension',
    'leg_curl':                 'leg-curl',
    'romanian_deadlift':        'romanian-deadlift',
    'hip_thrust':               'hip-thrust',
    'glute_kickback':           'cable-glute-kickback',
    'calf_raises':              'standing-calf-raise',
    'plank':                    'plank',
    'crunch':                   'crunch',
    'russian_twist':            'russian-twist',
    'leg_raise':                'hanging-leg-raise',
    'clean_and_press':          'clean-and-press',
    'kettlebell_swing':         'kettlebell-swing',
    'face_pull':                'face-pull',
}

# Mappa diretta italiano → URL musclewiki (override manuale per casi difficili)
DIRECT_MAP = {
    'panca_piana':              'https://media.musclewiki.com/media/uploads/videos/branded/male-barbell-bench-press-front.mp4',
    'panca_inclinata':          'https://media.musclewiki.com/media/uploads/videos/branded/male-barbell-incline-bench-press-front.mp4',
    'croci_con_manubri':        'https://media.musclewiki.com/media/uploads/videos/branded/male-dumbbell-incline-bench-press-front.mp4',
    'push-up':                  'https://media.musclewiki.com/media/uploads/videos/branded/male-Bodyweight-push-up-front.mp4',
    'push_up':                  'https://media.musclewiki.com/media/uploads/videos/branded/male-Bodyweight-push-up-front.mp4',
    'dip_alle_parallele':       'https://media.musclewiki.com/media/uploads/videos/branded/male-Bodyweight-bench-dips-front.mp4',
    'stacchi_da_terra':         'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-deadlift-front.mp4',
    'trazioni_alla_sbarra':     'https://media.musclewiki.com/media/uploads/videos/branded/male-bodyweight-pullup-front.mp4',
    'lat_machine':              'https://media.musclewiki.com/media/uploads/videos/branded/male-Cables-cable-lat-prayer-front.mp4',
    'rematore_con_bilanciere':  'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-upright-row-front.mp4',
    'rematore_con_manubrio':    'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-row-unilateral-front.mp4',
    'lento_avanti':             'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-overhead-press-front.mp4',
    'alzate_laterali':          'https://media.musclewiki.com/media/uploads/videos/branded/male-Cables-cable-lateral-raise-front.mp4',
    'alzate_frontali':          'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-front-raise-front.mp4',
    'alzate_posteriori':        'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-shrug-front.mp4',
    'curl_con_bilanciere':      'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-curl-front.mp4',
    'curl_con_manubri_alternati': 'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-incline-curl-front.mp4',
    'curl_martello':            'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-reverse-curl-front.mp4',
    'curl_al_cavo_basso':       'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-reverse-curl-front.mp4',
    'french_press':             'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-close-grip-bench-press-front.mp4',
    'tricipiti_ai_cavi':        'https://media.musclewiki.com/media/uploads/videos/branded/male-Cables-cable-push-down-front.mp4',
    'dip_ai_tricipiti':         'https://media.musclewiki.com/media/uploads/videos/branded/male-Bodyweight-bench-dips-front.mp4',
    'squat_con_bilanciere':     'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-squat-front.mp4',
    'leg_press':                'https://media.musclewiki.com/media/uploads/videos/branded/male-machine-standing-calf-raises-front.mp4',
    'affondi':                  'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-goblet-squat-front.mp4',
    'leg_extension':            'https://media.musclewiki.com/media/uploads/videos/branded/male-machine-leg-extension-front.mp4',
    'leg_curl':                 'https://media.musclewiki.com/media/uploads/videos/branded/male-machine-hamstring-curl-front.mp4',
    'romanian_deadlift':        'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-stiff-leg-deadlift-front.mp4',
    'hip_thrust':               'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-hip-thrust-front.mp4',
    'glute_kickback':           'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-hip-thrust-front.mp4',
    'calf_raises':              'https://media.musclewiki.com/media/uploads/videos/branded/male-machine-standing-calf-raises-front.mp4',
    'plank':                    'https://media.musclewiki.com/media/uploads/videos/branded/male-Bodyweight-supermans-front.mp4',
    'crunch':                   'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-situp-front.mp4',
    'russian_twist':            'https://media.musclewiki.com/media/uploads/videos/branded/male-Dumbbells-dumbbell-russian-twist-front.mp4',
    'leg_raise':                'https://media.musclewiki.com/media/uploads/videos/branded/male-Bodyweight-laying-leg-raises-front.mp4',
    'clean_and_press':          'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-overhead-press-front.mp4',
    'kettlebell_swing':         'https://media.musclewiki.com/media/uploads/videos/branded/male-Barbell-barbell-hip-thrust-front.mp4',
    'face_pull':                'https://media.musclewiki.com/media/uploads/videos/branded/male-Cables-cable-30-degree-shrug-front.mp4',
}

# Pagine muscolo da scaricare
MUSCLE_PAGES = [
    'https://musclewiki.com/exercises/chest',
    'https://musclewiki.com/exercises/biceps',
    'https://musclewiki.com/exercises/triceps',
    'https://musclewiki.com/exercises/back-upper',
    'https://musclewiki.com/exercises/lats',
    'https://musclewiki.com/exercises/shoulders',
    'https://musclewiki.com/exercises/quadriceps',
    'https://musclewiki.com/exercises/hamstrings',
    'https://musclewiki.com/exercises/glutes',
    'https://musclewiki.com/exercises/abdominals',
    'https://musclewiki.com/exercises/calves',
    'https://musclewiki.com/exercises/forearms',
    'https://musclewiki.com/exercises/traps',
    'https://musclewiki.com/exercises/lowerback',
    'https://musclewiki.com/exercises/full-body',
]

def fetch_page(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with opener.open(req, timeout=20) as r:
        return r.read().decode('utf-8', errors='replace')

def get_all_mp4_urls():
    """Estrae tutti gli URL MP4 da tutte le pagine muscolo."""
    all_urls = {}  # slug → url
    
    print("📥 Scaricando lista esercizi da musclewiki.com...")
    for muscle_url in MUSCLE_PAGES:
        try:
            html = fetch_page(muscle_url)
            # Estrai URL MP4 (solo male, vista front)
            mp4s = re.findall(
                r'https://media\.musclewiki\.com/media/uploads/videos/branded/'
                r'male-[^\s"\'\\]+\.mp4',
                html
            )
            # Deduplicazione
            unique = list(dict.fromkeys(mp4s))
            front_urls = [u for u in unique if '-front.mp4' in u]
            
            for url in front_urls:
                # Estrai slug dall'URL: male-Barbell-barbell-squat-front.mp4 → barbell-squat
                filename = url.split('/')[-1].replace('.mp4', '').replace('-front', '')
                # Rimuovi il prefisso "male-"
                slug = re.sub(r'^male-', '', filename)
                # Se il pattern è male-Equipment-exercise, rimuovi la prima parola (Equipment)
                # es: male-Barbell-barbell-squat → Barbell-barbell-squat → barbell-squat
                slug = slug.lower()
                parts = slug.split('-')
                # Cerca duplicazione: "barbell-barbell-squat" → "barbell-squat"
                if len(parts) >= 2 and parts[0] == parts[1]:
                    slug = '-'.join(parts[1:])
                # Rimuovi equipment prefix comune (barbell, dumbbell, cable, bodyweight, machine, kettlebell)
                equipment_prefixes = ['barbell', 'dumbbell', 'dumbbells', 'cable', 'bodyweight', 
                                       'machine', 'kettlebell', 'ez-bar', 'resistance-band', 'trap-bar']
                for eq in equipment_prefixes:
                    if slug.startswith(eq + '-'):
                        alt_slug = slug[len(eq)+1:]
                        all_urls[alt_slug] = url
                
                all_urls[slug] = url
            
            muscle_name = muscle_url.split('/')[-1]
            print(f"  ✓ {muscle_name}: {len(front_urls)} video trovati")
            time.sleep(0.3)
        except Exception as e:
            print(f"  ✗ {muscle_url}: {e}")
    
    print(f"\nTotale video trovati: {len(all_urls)}")
    return all_urls

def find_best_match(target_slug, all_urls):
    """Trova il miglior URL per un dato slug esercizio."""
    target = EXERCISE_MAP.get(target_slug, target_slug)
    
    # Match esatto
    if target in all_urls:
        return all_urls[target]
    
    # Match parziale: cerca l'URL che contiene il target
    for slug, url in all_urls.items():
        if target in slug or slug in target:
            return url
    
    # Match per parole chiave
    target_words = set(target.split('-'))
    best_score = 0
    best_url = None
    for slug, url in all_urls.items():
        slug_words = set(slug.split('-'))
        score = len(target_words & slug_words)
        if score > best_score and score >= min(2, len(target_words)):
            best_score = score
            best_url = url
    
    return best_url

def download_file(url, filepath):
    """Scarica un file e lo salva."""
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    with open(filepath, 'wb') as f:
        f.write(data)
    return len(data)

def verify_url(url):
    """Verifica se un URL è raggiungibile."""
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        req.get_method = lambda: 'HEAD'
        with urllib.request.urlopen(req, timeout=8) as r:
            return r.status == 200
    except Exception:
        return False

def main():
    # Cartelle output
    out_dirs = [
        r'C:\Users\Gianmarco\app\miadiariogym\app_cliente\assets\videos',
        r'C:\Users\Gianmarco\app\miadiariogym\app_pt\assets\videos',
    ]
    for d in out_dirs:
        os.makedirs(d, exist_ok=True)
    
    print("📥 Download video in corso (usando mappa diretta)...")
    found = 0
    not_found = 0
    errors = 0
    
    for it_slug, url in DIRECT_MAP.items():
        filename = f"{it_slug}.mp4"
        
        # Controlla se tutti i file esistono già
        all_exist = all(
            os.path.exists(os.path.join(d, filename)) for d in out_dirs
        )
        if all_exist:
            print(f"  ↩ {it_slug}: già scaricato")
            found += 1
            continue
        
        # Prova a scaricare
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=30) as r:
                data = r.read()
            
            found += 1
            print(f"  ✓ {it_slug} ({len(data)//1024}KB) ← {url.split('/')[-1]}")
            
            for out_dir in out_dirs:
                filepath = os.path.join(out_dir, filename)
                with open(filepath, 'wb') as f:
                    f.write(data)
            
            time.sleep(0.15)
        except Exception as e:
            not_found += 1
            print(f"  ✗ {it_slug}: {e}")
    
    print(f"\n✅ Scaricati/presenti: {found}/{len(DIRECT_MAP)}")
    print(f"❌ Errori: {not_found}/{len(DIRECT_MAP)}")
    
    # Lista file scaricati
    videos_dir = out_dirs[0]
    files = sorted(os.listdir(videos_dir))
    print(f"\n📁 Video in {videos_dir}: {len(files)} file")
    for f in files:
        size = os.path.getsize(os.path.join(videos_dir, f))
        print(f"  {f} ({size//1024}KB)")
    
    print("\n🎉 Download completato!")
    print("Ora esegui: flutter clean && flutter run")

if __name__ == '__main__':
    main()
