#!/usr/bin/env python3
import json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
with open(r"D:\masar_app\masar_app\tools\ai_review\validated_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)
qs = data["banks"]["academies_eval_bank_data"]["questions"]
for q in qs[:5]:
    v = q.get("_verdict", "?")
    c = q.get("_changes", [])
    t = q.get("text", "")[:120]
    opts = len(q.get("options", []))
    ci = q.get("correctIndex")
    ex = q.get("explanation", "")[:100]
    print(f"Verdict: {v}")
    print(f"Changes: {c}")
    print(f"Text: {t}")
    print(f"Options({opts}): correctIndex={ci}")
    print(f"Expl: {ex}")
    print("---")
