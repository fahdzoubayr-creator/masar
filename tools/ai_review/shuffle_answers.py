"""
Shuffle options in all bank JSONs so correctIndex distributes evenly across 0-3.
Keeps the correct answer text, just moves it to a random position each question.
"""
import json, random, sys, io
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
random.seed(42)

total = 0
for fp in sorted(BANKS_DIR.glob('*.json')):
    with open(fp, 'r', encoding='utf-8') as f:
        data = json.load(f)

    changed = 0
    for subj, qs in data.items():
        for q in qs:
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            if len(opts) != 4 or ci < 0 or ci > 3:
                continue

            correct_text = opts[ci]
            other_indices = [i for i in range(4) if i != ci]
            other_texts = [opts[i] for i in other_indices]

            new_idx = random.randint(0, 3)
            new_opts = [None] * 4
            new_opts[new_idx] = correct_text

            random.shuffle(other_texts)
            oi = 0
            for i in range(4):
                if new_opts[i] is None:
                    new_opts[i] = other_texts[oi]
                    oi += 1

            if new_opts != opts or new_idx != ci:
                q['options'] = new_opts
                q['correctIndex'] = new_idx
                changed += 1
                total += 1

    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f'{fp.name}: shuffled {changed} questions')

print(f'\nTotal shuffled: {total}')

# Verify distribution
from collections import Counter
dist = Counter()
for fp in sorted(BANKS_DIR.glob('*.json')):
    data = json.load(open(fp, 'r', encoding='utf-8'))
    for subj, qs in data.items():
        for q in qs:
            dist[q.get('correctIndex', 0)] += 1

total = sum(dist.values())
for i in range(4):
    pct = dist[i]/total*100
    print(f'correctIndex={i}: {dist[i]} ({pct:.1f}%)')
