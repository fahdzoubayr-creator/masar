import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

manifest = json.load(open(r'D:\masar_app\masar_app\assets\review_files\manifest.json', 'r', encoding='utf-8'))
base = Path(r'D:\masar_app\masar_app\assets\review_files')

total_quiz_true = 0
total_quiz_false = 0
total_txt_exists = 0
total_txt_missing = 0
total_chars = 0

for category, files in manifest.items():
    quiz_true = sum(1 for f in files if f.get('quiz') is True or f.get('quiz') == 'true')
    quiz_false = sum(1 for f in files if f.get('quiz') is False or f.get('quiz') == 'false')
    print(f'\n--- {category} ---')
    print(f'  Files: {len(files)} | quiz:true={quiz_true} | quiz:false={quiz_false}')
    
    for f in files:
        if f.get('quiz') is True or f.get('quiz') == 'true':
            total_quiz_true += 1
            txt_path = base / f['txt']
            if txt_path.exists():
                total_txt_exists += 1
                chars = len(txt_path.read_text(encoding='utf-8'))
                total_chars += chars
            else:
                total_txt_missing += 1
        else:
            total_quiz_false += 1

print(f'\n=== TOTAL ===')
print(f'quiz:true: {total_quiz_true} ({total_txt_exists} with .txt, {total_txt_missing} missing)')
print(f'quiz:false: {total_quiz_false}')
print(f'Total chars to process: {total_chars:,} ({total_chars // 1000}K words approx)')
