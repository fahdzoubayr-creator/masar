import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

AW_EXACT = {'جميع الاختيارات خاطئة', 'كل الاقتراحات خاطئة', 'جميع الخيارات الأخرى خاطئة'}
BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')

moved = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    with open(fp, 'r', encoding='utf-8') as f:
        data = json.load(f)

    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            if len(opts) != 4:
                continue

            aw_idx = None
            for i, o in enumerate(opts):
                if o in AW_EXACT:
                    aw_idx = i
                    break

            if aw_idx is None or aw_idx == 3:
                continue

            aw_text = opts[aw_idx]
            dest_text = opts[3]

            opts[aw_idx] = dest_text
            opts[3] = aw_text

            if ci == aw_idx:
                ci = 3
            elif ci == 3:
                ci = aw_idx

            q['options'] = opts
            q['correctIndex'] = ci
            moved += 1

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

print(f'Fixed: {moved}')

# Verify
from collections import Counter
pos = Counter()
total_aw = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            for o in opts:
                if o in AW_EXACT:
                    i = opts.index(o)
                    pos[i] += 1
                    total_aw += 1
                    break

print(f'\nExact AW option position:')
for i in range(4):
    print(f'  Position {i}: {pos[i]}')
print(f'Total: {total_aw}')
