import json, sys, io
from pathlib import Path
from collections import Counter
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

AW_EXACT = {'جميع الاختيارات خاطئة', 'كل الاقتراحات خاطئة', 'جميع الخيارات الأخرى خاطئة'}
BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')

def is_bad(text):
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
    if '\n' in t:
        return True
    return False

# Check lengths of wrong options
lengths = Counter()
bad_lens = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            for i, o in enumerate(opts):
                if i != ci:
                    l = len(o)
                    if l > 80:
                        bad_lens += 1
                    lengths[min(l // 20, 5)] += 1

print("Wrong option length distribution:")
labels = {'0': '0-20', '1': '21-40', '2': '41-60', '3': '61-80', '4': '81-100', '5': '100+'}
for k in sorted(lengths.keys()):
    print(f"  {labels[str(k)]}: {lengths[k]}")
print(f"Total wrong options >80 chars: {bad_lens}")

# Check for duplicates
dupe_q = 0
total_q = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            total_q += 1
            opts = q.get('options', [])
            if len(opts) != len(set(opts)):
                dupe_q += 1

print(f"\nQuestions with duplicate options: {dupe_q}/{total_q}")
