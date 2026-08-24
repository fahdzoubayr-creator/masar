import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BROKEN_PATTERNS = [
    'الخيارات المعدلة',
    'الخيارات المُحدّثة',
    'الخيارات الخاطئة',
    'خيارات خاطئة مفصلة',
    'خيارات خاطئة مفصّلة',
    'ثلاثة خيارات خاطئة',
    'ثلاث خيارات خاطئة',
    'خيار خاطئ أول',
    'لا توجد إجابة صحيحة من بين الخيارات المتبقية',
    'لا يوجد جواب صحيح بين الخيارات الأربع الأولى',
    'الخيارات المُعاد صياغتها',
]

banks = Path(r'D:\masar_app\masar_app\assets\banks')
count = 0
for fp in sorted(banks.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            for i, o in enumerate(opts):
                for pat in BROKEN_PATTERNS:
                    if pat in o:
                        count += 1
                        print(f'#{count} {fp.name} ci={ci}')
                        print(f'  Q: {q["text"][:80]}')
                        for idx, opt in enumerate(opts):
                            m = ' <<<' if idx == ci else ''
                            print(f'  [{idx}] {opt[:100]}{m}')
                        print()
                        break
                else:
                    continue
                break

print(f'Total broken: {count}')
