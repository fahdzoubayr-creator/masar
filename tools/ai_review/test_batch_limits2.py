#!/usr/bin/env python3
import requests, json, sys, io, time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

qs = data["animation_bank_data"]["questions"]

system = "You are a Moroccan education expert. Validate questions. Reply with JSON array only."

for batch_size in [10, 15]:
    time.sleep(10)  # generous delay between tests
    batch = qs[:batch_size]
    user_msg = json.dumps(batch, ensure_ascii=False, indent=2)
    body = {
        "model": "openai/gpt-oss-20b",
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": "Validate these " + str(batch_size) + " questions:\n" + user_msg},
        ],
        "temperature": 0.1,
        "max_tokens": 4000,
    }
    try:
        r = requests.post(url, json=body, headers=headers, timeout=60)
        d = r.json()
        if "choices" in d:
            print(f"  OK  batch_size={batch_size}")
        else:
            err = str(d.get("error", {}))[:120]
            print(f"  FAIL batch_size={batch_size}: {err}")
    except Exception as e:
        print(f"  ERR  batch_size={batch_size}: {str(e)[:80]}")
