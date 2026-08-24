import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

AW_EXACT = {'جميع الاختيارات خاطئة', 'كل الاقتراحات خاطئة', 'جميع الخيارات الأخرى خاطئة'}
banks = Path(r'D:\masar_app\masar_app\assets\banks')
for fp in sorted(banks.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            for i, o in enumerate(opts):
                if o in AW_EXACT and i != 3:
                    ci = q.get('correctIndex', 0)
                    print(f'{fp.name}: subj={subj} pos={i} ci={ci} aw={o}')
                    print(f'  opts: {opts}')
                    print(f'  text: {q["text"][:80]}')
