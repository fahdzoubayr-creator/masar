"""
Fix duplicate options by replacing duplicates with unique short distractors.
"""
import json, sys, io, random
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
random.seed(42)

FIXES = [
    "لا توجد إجابة صحيحة أخرى",
    "جميع الخيارات خاطئة",
    "لا شيء مما سبق",
    "غير ذلك",
]

fixed = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    with open(fp, 'r', encoding='utf-8') as f:
        data = json.load(f)

    changed = 0
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            if len(opts) != 4:
                continue

            seen = {}
            need_fix = False
            for i, o in enumerate(opts):
                if i == ci:
                    continue
                if o in seen:
                    need_fix = True
                    break
                seen[o] = i

            if not need_fix:
                continue

            for i, o in enumerate(opts):
                if i == ci:
                    continue
                opts[i] = f"بدائل أخرى خاطئة ({i+1})"

            q['options'] = opts
            changed += 1
            fixed += 1

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    if changed:
        print(f'{fp.name}: fixed {changed} duplicates')

print(f'\nTotal duplicate fixes: {fixed}')
