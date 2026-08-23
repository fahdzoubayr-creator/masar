#!/usr/bin/env python3
import requests, json, sys, io, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

qs = data["academies_eval_bank_data"]["questions"][:5]
user_msg = json.dumps(qs, ensure_ascii=False, indent=2)
system = "You are a Moroccan education expert. Validate questions. Reply with JSON array only."

for model in ["openai/gpt-oss-20b", "openai/gpt-oss-120b", "qwen/qwen3.6-27b", "allam-2-7b"]:
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": "Validate:\n" + user_msg},
        ],
        "temperature": 0.1,
        "max_tokens": 4000,
    }
    try:
        r = requests.post(url, json=body, headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"}, timeout=30)
        d = r.json()
        if "choices" in d:
            print(f"  OK  {model}")
        else:
            err = str(d.get("error", {}))[:80]
            print(f"  FAIL {model}: {err}")
    except Exception as e:
        print(f"  ERR  {model}: {str(e)[:60]}")
    time.sleep(3)
