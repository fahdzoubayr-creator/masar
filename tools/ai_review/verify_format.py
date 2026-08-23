import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
ALL_WRONG_AR = "كل الاقتراحات خاطئة"
ALL_WRONG_FR = "Toutes les réponses ci-dessus sont fausses."

total = 0
errors = 0
dupes = 0
for fp in sorted(BANKS_DIR.glob("*.json")):
    with open(fp, "r", encoding="utf-8") as f:
        data = json.load(f)
    for s, qs in data.items():
        for i, q in enumerate(qs):
            total += 1
            opts = q.get("options", [])
            ci = q.get("correctIndex", 0)
            if len(opts) != 4:
                print(f"OPT_COUNT: {fp.name} {s} Q{i}: {len(opts)} options")
                errors += 1
            if ci < 0 or ci > 3:
                print(f"BAD_CI: {fp.name} {s} Q{i}: correctIndex={ci}")
                errors += 1
            # Check for duplicates
            seen = set()
            for o in opts:
                if o in seen and o not in (ALL_WRONG_AR, ALL_WRONG_FR):
                    dupes += 1
                    break
                seen.add(o)

print(f"\nTotal: {total} questions")
print(f"Errors: {errors}")
print(f"Questions with duplicate options: {dupes}")
