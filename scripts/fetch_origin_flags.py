"""Refresh bundled country names/flags from https://flagpedia.net/download/api."""
import concurrent.futures
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]

def download(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read()

codes = json.loads(download('https://flagcdn.com/es/codes.json'))
countries = {code.upper(): name for code, name in codes.items()
             if len(code) == 2 and code not in ('eu', 'un')}
countries = dict(sorted(countries.items(), key=lambda item: item[1]))
catalog = ROOT / 'lib/core/models/origin_countries.dart'
catalog.write_text(
    '// Nombres y banderas: https://flagpedia.net/download/api\n'
    '// Catálogo local: no requiere red al completar la procedencia.\n'
    'const originCountries = <String, String>{\n' +
    ''.join(f'  {json.dumps(code)}: {json.dumps(name, ensure_ascii=False)},\n'
            for code, name in countries.items()) + '};\n', encoding='utf-8')
flags = ROOT / 'assets/flags'
flags.mkdir(parents=True, exist_ok=True)

def fetch(code):
    target = flags / f'{code.lower()}.png'
    if not target.exists():
        target.write_bytes(download(f'https://flagcdn.com/w80/{code.lower()}.png'))

with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    list(pool.map(fetch, countries))
print(f'{len(countries)} países y banderas disponibles sin conexión.')
