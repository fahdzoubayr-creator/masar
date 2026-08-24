"""
Scan all banks for corrupted distractor patterns.
Returns list of questions needing regeneration.
"""
import json, sys, io, re
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
AW_EXACT = {'جميع الاختيارات خاطئة', 'كل الاقتراحات خاطئة', 'جميع الخيارات الأخرى خاطئة'}

def is_bad_option(text):
    t = text.strip()
    if t in AW_EXACT:
        return False
    if len(t) > 80:
        return True
    if t.endswith(':') or t.endswith('،'):
        return True
    bad_starts = ['بالرغم', 'بينما', 'على الرغم', 'يعتبر', 'تشمل', 'بأن', 'إلا', 'قد ت', 'يمكن أن']
    for bs in bad_starts:
        if t.startswith(bs):
            return True
    if ':\n' in t or '\n' in t:
        return True
    return False

total = 0
bad = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            total += 1
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            has_bad = False
            for i, o in enumerate(opts):
                if i != ci and is_bad_option(o):
                    has_bad = True
                    break
            if has_bad:
                bad += 1

print(f'Total: {total}')
print(f'Need regeneration: {bad} ({bad/total*100:.1f}%)')
print(f'Clean: {total - bad} ({(total-bad)/total*100:.1f}%)')
