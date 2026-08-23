#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

# Load actual questions to test with
with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

all_qs = []
for bk, bd in data.items():
    for q in bd["questions"][:3]:
        all_qs.append(q)
        if len(all_qs) >= 5:
            break
    if len(all_qs) >= 5:
        break

user_msg = json.dumps(all_qs, ensure_ascii=False, indent=2)
print(f"User message size: {len(user_msg)} chars")

# Short system prompt for testing
system = "You are a Moroccan education expert. Reply in Arabic."

models = ["qwen/qwen3.6-27b", "openai/gpt-oss-120b", "openai/gpt-oss-20b", "allam-2-7b"]

for model in models:
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": "Here are 5 questions to test:\n" + user_msg[:2000]},
        ],
        "max_tokens": 200,
        "temperature": 0.1,
    }
    try:
        r = requests.post(url, json=body, headers=headers, timeout=30)
        data_r = r.json()
        if "choices" in data_r:
            txt = data_r["choices"][0]["message"]["content"][:80]
            usage = data_r.get("usage", {})
            print(f"  OK  {model} (in={usage.get('prompt_tokens',0)} out={usage.get('completion_tokens',0)})")
        else:
            err = str(data_r.get("error", {}))[:100]
            print(f"  FAIL {model}: {err}")
    except Exception as e:
        print(f"  ERR  {model}: {str(e)[:80]}")
