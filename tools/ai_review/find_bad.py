import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

targets = [
    'ال يكون التقويم وظيفيا عندما',
    'يعرف القانون الإطار39-13',
    'هيدافوجيا',
    'مطالب النمو في مرحلة المراهقة تشمل',
    'ZPD',
    'في المراهقة المبكرة، تظهر النزعة',
    'الكتابة الإبداعية في التعبير الكتابي',
    'نادي الصحة',
]

banks = Path(r'D:\masar_app\masar_app\assets\banks')
for fp in sorted(banks.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for i, q in enumerate(qs):
            text = q.get('text', '')
            for t in targets:
                if t in text:
                    opts = q.get('options', [])
                    print(f'{fp.name} | {subj} | idx={i}')
                    print(f'  text: {text[:150]}')
                    for j, o in enumerate(opts):
                        print(f'    [{j}] {o[:100]}')
                    print()
