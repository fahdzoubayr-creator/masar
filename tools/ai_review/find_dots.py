import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

banks = Path(r'D:\masar_app\masar_app\assets\banks')
count = 0
for fp in sorted(banks.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            for o in q.get('options', []):
                if '..' in o or o.strip() in ('.', '...', '…'):
                    ci = q.get('correctIndex', 0)
                    print(f'{fp.name}: subj={subj} ci={ci}')
                    print(f'  Q: {q["text"][:80]}')
                    for idx, opt in enumerate(q.get('options', [])):
                        marker = ' <<<' if idx == ci else ''
                        print(f'  [{idx}] {opt}{marker}')
                    count += 1
                    break
print(f'\nTotal: {count}')
