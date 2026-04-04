import urllib.request, json

API_KEY = '50cf82af7fmsh2941740978c31e0p15a252jsn401fda1ad63d'

# The ExerciseDB CDN returns 403 without auth - try with API key as bearer
test_configs = [
    # Try as Bearer token on the exercisedb CDN directly
    ('https://v2.exercisedb.io/image/exercises/0025', {
        'Authorization': f'Bearer {API_KEY}',
        'User-Agent': 'Mozilla/5.0'
    }),
    # Try with X-Api-Key header
    ('https://v2.exercisedb.io/image/exercises/0025', {
        'X-Api-Key': API_KEY,
        'User-Agent': 'Mozilla/5.0'
    }),
    # Try with RapidAPI headers on the CDN
    ('https://v2.exercisedb.io/image/exercises/0025', {
        'X-RapidAPI-Key': API_KEY,
        'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com',
        'User-Agent': 'Mozilla/5.0'
    }),
    # Try the exercises endpoint with exercise ID as URL param
    ('https://exercisedb.p.rapidapi.com/exercises/exercise/0025', {
        'X-RapidAPI-Key': API_KEY,
        'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com',
    }),
]

for url, hdrs in test_configs:
    try:
        req = urllib.request.Request(url, headers=hdrs)
        res = urllib.request.urlopen(req, timeout=8)
        body = res.read(500)
        ct = res.headers.get('Content-Type', '?')
        print(f'OK {url[-40:]} | {ct} | {len(body)}b')
        if b'GIF' in body[:10] or b'\x89PNG' in body[:10]:
            print('  --> Is an image file!')
        else:
            print(f'  --> Data: {body[:80]}')
    except urllib.request.HTTPError as e:
        print(f'HTTP {e.code} {url[-40:]}')
    except Exception as e:
        print(f'ERR {url[-40:]}: {str(e)[:60]}')
