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

for model in ["openai/gpt-oss-120b", "openai/gpt-oss-20b"]:
    for batch_size in [15, 20, 25, 30]:
        time.sleep(15)
        batch = qs[:batch_size]
        user_msg = json.dumps(batch, ensure_ascii=False, indent=2)
        body = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": "Validate " + str(batch_size) + " questions:\n" + user_msg},
            ],
            "temperature": 0.1,
            "max_tokens": 4000,
        }
        body_bytes = len(json.dumps(body))
        try:
            r = requests.post(url, json=body, headers=headers, timeout=60)
            d = r.json()
            if "choices" in d:
                print(f"  OK  {model} batch={batch_size} ({body_bytes}b)")
            else:
                err = str(d.get("error", {}))[:120]
                is_rate = "rate" in err.lower()
                is_size = "too large" in err.lower()
                label = "RATE" if is_rate else ("SIZE" if is_size else "ERROR")
                print(f"  {label} {model} batch={batch_size} ({body_bytes}b)")
        except Exception as e:
            print(f"  ERR  {model} batch={batch_size}: {str(e)[:80]}")
