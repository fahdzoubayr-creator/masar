import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def is_all_wrong(text):
    t = text.strip().lower()
    return 'خاطئ' in t or 'fausses' in t or 'all wrong' in t

banks = Path(r'D:\masar_app\masar_app\assets\banks')
for fp in sorted(banks.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            for i, o in enumerate(opts):
                if is_all_wrong(o) and i != 3:
                    print(f'{fp.name}: pos={i} ci={ci} q={q["text"][:60]}')
                    break
