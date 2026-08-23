#!/usr/bin/env python3
import json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

with open(r"D:\masar_app\masar_app\tools\ai_review\rejected_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

targets = ["french_didactics_bank_4_data", "education_sciences_all_bank_data", "french_didactics_bank_all"]
for bank_key in targets:
    if bank_key not in data:
        continue
    bank_data = data[bank_key]
    rejected = bank_data["rejected"]
    print(f"=== {bank_key} ({len(rejected)} rejected) ===")
    reasons_summary = {}
    for r in rejected:
        for reason in r["reasons"]:
            base = reason.split("_")[0] if reason[0].isdigit() else reason
            reasons_summary[base] = reasons_summary.get(base, 0) + 1
    print(f"  Reason breakdown: {reasons_summary}")
    for r in rejected[:3]:
        q = r["question"]
        print(f"  text: {q['text'][:70]}")
        print(f"  opts({len(q['options'])}): {q['options'][:3]}")
        print(f"  idx: {q['correctIndex']}")
        print(f"  reasons: {r['reasons']}")
        print()
    print()
