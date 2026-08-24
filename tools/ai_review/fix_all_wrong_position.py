"""
Move 'كل الاقتراحات خاطئة' option to position 3 (bottom) in every question that has it.
Fix correctIndex if needed.
"""
import json, sys, io
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')

def is_all_wrong(text):
    t = text.strip().lower()
    return 'خاطئ' in t or 'fausses' in t or 'all wrong' in t

moved = 0
ci_fixed = 0

for fp in sorted(BANKS_DIR.glob('*.json')):
    with open(fp, 'r', encoding='utf-8') as f:
        data = json.load(f)

    changed = 0
    for subj, qs in data.items():
        for q in qs:
            opts = list(q.get('options', []))
            ci = q.get('correctIndex', 0)
            if len(opts) != 4:
                continue

            aw_idx = None
            for i, o in enumerate(opts):
                if is_all_wrong(o):
                    aw_idx = i
                    break

            if aw_idx is None or aw_idx == 3:
                if aw_idx == 3 and ci == 3:
                    ci = 2
                    ci_fixed += 1
                    q['correctIndex'] = ci
                    changed += 1
                continue

            if ci == aw_idx:
                ci = 0
                ci_fixed += 1

            opts[aw_idx], opts[3] = opts[3], opts[aw_idx]
            if ci == 3:
                ci = aw_idx

            q['options'] = opts
            q['correctIndex'] = ci
            changed += 1
            moved += 1

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    if changed:
        print(f'{fp.name}: moved {changed}')

print(f'\nTotal moved: {moved}, ci_fixed: {ci_fixed}')

from collections import Counter
pos = Counter()
ci_dist = Counter()
total_aw = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            ci_dist[ci] += 1
            for i, o in enumerate(opts):
                if is_all_wrong(o):
                    pos[i] += 1
                    total_aw += 1
                    break

print(f'\nAll-wrong position distribution:')
for i in range(4):
    print(f'  Position {i}: {pos[i]}')
print(f'Total with all-wrong: {total_aw} / 5263')
print(f'\ncorrectIndex distribution:')
for i in range(4):
    print(f'  Index {i}: {ci_dist[i]} ({ci_dist[i]/5263*100:.1f}%)')
