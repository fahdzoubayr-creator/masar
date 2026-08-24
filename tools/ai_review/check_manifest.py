import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

base = Path(r'D:\masar_app\masar_app\assets\review_files')
manifest = json.load(open(base / 'manifest.json', 'r', encoding='utf-8'))

# Check what manifest says about مؤسسات الريادة
for f in manifest.get('مؤسسات الريادة', []):
    txt_rel = f['txt']
    txt_path = base / txt_rel
    exists = txt_path.exists()
    size = txt_path.stat().st_size if exists else 0
    print(txt_rel, '->', exists, size)
