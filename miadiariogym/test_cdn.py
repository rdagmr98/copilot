import urllib.request

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

# Try various fitness app CDNs that have 3D-style exercise GIFs
test_urls = [
    # Jefit CDN (known for 3D-style GIFs)
    'https://cdn.jefit.com/exercise-gif/bench-press.gif',
    'https://media.jefit.com/pics2/1.gif',
    'https://media.jefit.com/pics/1.gif',
    # Hevy app
    'https://api.hevyapp.com/v1/exercises',
    # Bodybuilding.com (has 3D style)
    'https://exercises.evomuscle.com/media/gifs/bench-press.gif',
    # OpenBarbells
    'https://raw.githubusercontent.com/nicholaswilde/openbarbells/main/exercises/bench-press/animation.gif',
    # YuhonaFreeExerciseDB (has images)
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Bench_Press_-_With_Bands/0.jpg',
    # ExerciseDB - try new path format
    'https://v2.exercisedb.io/image/exercises/barbell-bench-press',
    'https://v2.exercisedb.io/exercises/0025/gif',
]

for url in test_urls:
    try:
        req = urllib.request.Request(url, headers=headers)
        res = urllib.request.urlopen(req, timeout=6)
        body = res.read(100)
        ct = res.headers.get('Content-Type', '?')
        is_img = b'GIF' in body[:6] or b'\x89PNG' in body[:4] or b'\xff\xd8' in body[:3]
        print(f'{"IMG " if is_img else "OK  "} {url[:65]} | {ct[:30]}')
    except urllib.request.HTTPError as e:
        print(f'HTTP{e.code} {url[:65]}')
    except Exception as e:
        print(f'ERR  {url[:65]}: {str(e)[:40]}')
