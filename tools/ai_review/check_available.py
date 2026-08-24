import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

PROJECT = Path(r'D:\masar_app\masar_app')
BASE = PROJECT / 'assets' / 'review_files'
manifest = json.load(open(BASE / 'manifest.json', 'r', encoding='utf-8'))

count = 0
total_words = 0
for cat, files in manifest.items():
    for f in files:
        if f.get('quiz') is True or f.get('quiz') == 'true':
            txt_path = PROJECT / f['txt']
            if txt_path.exists():
                words = len(txt_path.read_text(encoding='utf-8').split())
                total_words += words
                count += 1
                print(f'OK [{cat}] {f["txt"]} (~{words} words)')

print(f'\nTotal: {count} files, ~{total_words} words')
