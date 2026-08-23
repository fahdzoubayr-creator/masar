import json, sys, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
ALL_WRONG_AR = "كل الاقتراحات خاطئة"
ALL_WRONG_FR = "Toutes les reponses ci-dessus sont fausses."

long_correct = []
for fp in sorted(BANKS_DIR.glob("*.json")):
    with open(fp, "r", encoding="utf-8") as f:
        data = json.load(f)
    for s, qs in data.items():
        for i, q in enumerate(qs):
            opts = q.get("options", [])
            ci = q.get("correctIndex", 0)
            if len(opts) != 5 or ci < 0 or ci > 3:
                continue
            correct = opts[ci]
            wrong = [opts[j] for j in range(4) if j != ci and opts[j] not in (ALL_WRONG_AR, ALL_WRONG_FR)]
            if not wrong:
                continue
            avg_wrong_len = sum(len(w) for w in wrong) / len(wrong)
            ratio = len(correct) / max(avg_wrong_len, 1)
            if ratio > 2.5 and len(correct) > 40:
                long_correct.append({
                    "file": fp.name,
                    "subject": s,
                    "index": i,
                    "correct_len": len(correct),
                    "avg_wrong_len": round(avg_wrong_len),
                    "ratio": round(ratio, 1),
                    "correct": correct[:100],
                    "question": q.get("text", "")[:100],
                })

long_correct.sort(key=lambda x: x["ratio"], reverse=True)
print("Found {} questions where correct answer is too obviously long\n".format(len(long_correct)))
for item in long_correct[:50]:
    print("{}/{} Q{}".format(item["file"], item["subject"], item["index"]))
    print("  Q: {}".format(item["question"]))
    print("  Correct ({} chars): {}".format(item["correct_len"], item["correct"]))
    print("  Avg wrong ({} chars), ratio: {}x".format(item["avg_wrong_len"], item["ratio"]))
    print()
