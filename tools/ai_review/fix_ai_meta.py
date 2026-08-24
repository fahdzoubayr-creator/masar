import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
AW_AR = 'كل الاقتراحات خاطئة'

AI_META = [
    'الخيارات المعدلة لتكون',
    'الخيارات المُحدّثة',
    'الخيارات الخاطئة المفصلة',
    'خيارات خاطئة مفصلة',
    'خيارات خاطئة مفصّلة',
    'ثلاثة خيارات خاطئة',
    'ثلاث خيارات خاطئة',
    'خيار خاطئ أول',
    'الخيارات المُعاد صياغتها',
    'لا توجد إجابة صحيحة من بين الخيارات المتبقية',
    'لا يوجد جواب صحيح بين الخيارات الأربع الأولى',
    'الخيارات المُحدّثة والمفصّلة',
    'بتوفير ثلاثة خيارات خاطئة',
]

def is_ai_meta(text):
    t = text.strip()
    for pat in AI_META:
        if t.startswith(pat) or t == pat:
            return True
    return False

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

            for i, o in enumerate(opts):
                if is_ai_meta(o) and i != 3:
                    opts[i] = AW_AR
                    if ci == i:
                        for alt in range(3):
                            if alt != i and not is_ai_meta(opts[alt]):
                                ci = alt
                                break
                    q['options'] = opts
                    q['correctIndex'] = ci
                    changed += 1
                    break
                elif is_ai_meta(o) and i == 3:
                    opts[i] = AW_AR
                    if ci == i:
                        ci = 0
                    q['options'] = opts
                    q['correctIndex'] = ci
                    changed += 1
                    break

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    if changed:
        print(f'{fp.name}: fixed {changed}')
        fixed += changed

print(f'\nTotal fixed: {fixed}')
