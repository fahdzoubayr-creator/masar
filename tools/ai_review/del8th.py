import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

fp = Path(r'D:\masar_app\masar_app\assets\banks\popular_bank.json')
data = json.load(open(fp, 'r', encoding='utf-8'))
for subj, qs in data.items():
    for i, q in enumerate(qs):
        if 'بيداغوجيا المشروع' in q.get('text', ''):
            print(f'{subj} | idx={i}')
            print(f'  text: {q["text"][:100]}')
            removed = qs.pop(i)
            print('DELETED')
            with open(fp, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            sys.exit(0)
print('NOT FOUND')
