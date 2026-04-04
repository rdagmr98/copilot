import urllib.request

API_KEY = '50cf82af7fmsh2941740978c31e0p15a252jsn401fda1ad63d'
headers = {'X-RapidAPI-Key': API_KEY, 'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com'}

# Try GitHub mirrors of the ExerciseDB dataset (which had GIFs in v1)
test_urls = [
    # ExerciseDB GitHub raw GIFs
    'https://raw.githubusercontent.com/exercisedb/exercisedb/main/exercises/0025/animated.gif',
    'https://raw.githubusercontent.com/exercisedb/exercisedb/main/0025.gif',
    # Unofficial mirrors
    'https://raw.githubusercontent.com/ebarthur/exercisedb-json/main/exercises/0025.gif',
    # ExerciseDB CDN with different path
    'https://v2.exercisedb.io/image/exercises/0025.gif',
    # Try with user-agent spoofing
]
browser_headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'image/gif,image/*,*/*',
}
for url in test_urls:
    try:
        req = urllib.request.Request(url, headers=browser_headers)
        res = urllib.request.urlopen(req, timeout=8)
        body = res.read()
        ct = res.headers.get('Content-Type', '?')
        print(f'OK {url[:60]} - {ct} Size:{len(body)}')
    except Exception as e:
        print(f'FAIL {url[:60]}: {str(e)[:60]}')
