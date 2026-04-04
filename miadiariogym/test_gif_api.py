import urllib.request

API_KEY = '50cf82af7fmsh2941740978c31e0p15a252jsn401fda1ad63d'
headers = {
    'X-RapidAPI-Key': API_KEY,
    'X-RapidAPI-Host': 'exercisedb.p.rapidapi.com'
}

urls = [
    'https://v2.exercisedb.io/image/exercises/0025',
    'https://exercisedb.p.rapidapi.com/exercises/exercise/0025/gif',
    'https://exercisedb.p.rapidapi.com/exercises/gif/0025',
    'https://exercisedb.p.rapidapi.com/image/0025',
]
for url in urls:
    try:
        req = urllib.request.Request(url, headers=headers)
        res = urllib.request.urlopen(req, timeout=8)
        body = res.read()
        ct = res.headers.get('Content-Type', '?')
        print(f'OK {url} - CT:{ct} Size:{len(body)}')
    except Exception as e:
        print(f'FAIL {url}: {str(e)[:90]}')
