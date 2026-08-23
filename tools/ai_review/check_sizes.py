#!/usr/bin/env python3
import sys, io, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Check sizes of various batch sizes
for n in [1, 3, 5, 10]:
    qs = data["academies_eval_bank_data"]["questions"][:n]
    user_msg = json.dumps(qs, ensure_ascii=False, indent=2)
    print(f"  {n} questions: {len(user_msg)} chars user msg")

# Check system prompt size
system = "test"
print(f"\n  Actual system prompt in script is compressed version")
