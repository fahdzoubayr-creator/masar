"""
Final cleanup: replace remaining __NEED_REGEN__ with short generic distractors.
"""
import json, sys, io, random
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
GENERIC = [
    "لا يوجد ما يبرر هذا الخيار",
    "هذا لا ينطبق على الموضوع",
    "الخيار غير مرتبط بالسياق",
    "لا علاقة له بالموضوع",
    "غير صحيح من الناحية العلمية",
    "خيار مخالف للمنهج التعليمي",
    "لا يستند إلى أي دليل",
    "谬误 None of the above",
    "يعتمد على معلومات غير دقيقة",
    "خاطئ تماماً ومجرد تخمين",
]

REGEN = '__NEED_REGEN__'
fixed = 0

for fp in sorted(BANKS_DIR.glob('*.json')):
    with open(fp, 'r', encoding='utf-8') as f:
        data = json.load(f)

    changed = 0
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            if REGEN not in opts:
                continue

            correct_text = opts[ci]
            pool = [g for g in GENERIC if g != correct_text]
            random.shuffle(pool)
            new_opts = [correct_text, pool[0], pool[1], pool[2]]
            random.shuffle(new_opts)
            new_ci = new_opts.index(correct_text)

            q['options'] = new_opts
            q['correctIndex'] = new_ci
            changed += 1
            fixed += 1

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    if changed:
        print(f'{fp.name}: {changed}')

print(f'\nFinal cleanup: {fixed} questions fixed')
