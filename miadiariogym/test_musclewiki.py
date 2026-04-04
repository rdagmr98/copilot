import urllib.request

headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0',
    'Accept': 'image/*,*/*',
    'Referer': 'https://musclewiki.com/',
}

# Muscle Wiki CDN patterns (they have 3D-style exercise GIFs)
test_urls = [
    # MuscleWiki CDN (Cloudfront)
    'https://d2wvdrxmr8qmuf.cloudfront.net/exercises/male/images/bench-press/male-bench-press-animation.gif',
    'https://d2wvdrxmr8qmuf.cloudfront.net/exercises/male/images/bench-press/animation.gif',
    'https://d2wvdrxmr8qmuf.cloudfront.net/exercises/male/gifs/bench-press.gif',
    # Jefit CDN
    'https://www.jefit.com/images/exercises/db_images/exercise_1081_animated.gif',
    'https://cdn.jefit.com/exercise/images/1081.gif',
    'https://www.jefit.com/images/exercises/1081.gif',
    # WorkoutDB or ExerciceDB alternatives
    'https://fitnessprogramer.com/wp-content/uploads/2021/02/Barbell-Bench-Press.gif',
    'https://www.inspireusafoundation.org/wp-content/uploads/2021/08/flat-barbell-bench-press-2.gif',
    # Popular fitness blog GIF CDNs
    'https://static.strengthlevel.com/images/illustrations/bench-press/bench-press-illustration-1000.jpg',
]

for url in test_urls:
    try:
        req = urllib.request.Request(url, headers=headers)
        res = urllib.request.urlopen(req, timeout=8)
        body = res.read(200)
        ct = res.headers.get('Content-Type', '?')
        is_gif = b'GIF8' in body[:4]
        is_img = is_gif or b'\x89PNG' in body[:4] or b'\xff\xd8' in body[:3]
        tag = 'GIF ' if is_gif else ('IMG ' if is_img else 'OK  ')
        print(f'{tag} {url[:70]} | {ct[:25]}')
        if is_img:
            # Download to test
            req2 = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req2, timeout=8) as r:
                data = r.read()
            with open(f'C:/Users/Gianmarco/app/miadiariogym/test_sample.{"gif" if is_gif else "jpg"}', 'wb') as f:
                f.write(data)
            print(f'  --> Downloaded {len(data)} bytes')
    except urllib.request.HTTPError as e:
        print(f'HTTP{e.code} {url[:70]}')
    except Exception as e:
        print(f'ERR  {url[:70]}: {str(e)[:50]}')
