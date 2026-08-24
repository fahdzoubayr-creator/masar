"""
Phase 1: Remove ALL corrupted options. Replace with placeholder.
Phase 2: Regen script will regenerate clean ones.
"""
import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')

BLACKLIST = [
    'بدائل أخرى خاطئة',
    'خيارات خاطئة مفصلة',
    'خيارات خاطئة مفصّلة',
    'الخيارات المعدلة',
    'الخيارات المُحدّثة',
    'الخيارات الخاطئة',
    'ثلاثة خيارات خاطئة',
    'ثلاث خيارات خاطئة',
    'خيار خاطئ أول',
    'لا توجد إجابة صحيحة من بين الخيارات المتبقية',
    'لا يوجد جواب صحيح بين الخيارات الأربع الأولى',
    'الخيارات المُعاد صياغتها',
    'لا شيء مما سبق',
    'غير ذلك',
]

def is_bad(text):
    t = text.strip()
    for pat in BLACKLIST:
        if t.startswith(pat):
            return True
    if len(t) > 80:
        return True
    if t.endswith(':') and len(t) < 30:
        return True
    bad_starts = ['بالرغم', 'بينما', 'على الرغم', 'يعتبر هذا', 'تشمل:', 'بأنه', 'إلا أن', 'يمكن أن ي']
    for bs in bad_starts:
        if t.startswith(bs):
            return True
    if '\n' in t:
        return True
    return False

total_bad = 0
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
                if i != ci and is_bad(o):
                    opts[i] = '__NEED_REGEN__'
                    q['options'] = opts
                    changed += 1
                    total_bad += 1

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    if changed:
        print(f'{fp.name}: {changed} marked')

print(f'\nTotal marked for regen: {total_bad}')
