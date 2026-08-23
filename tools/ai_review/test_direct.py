#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

q = data["academies_eval_bank_data"]["questions"][0]
user_msg = json.dumps([q], ensure_ascii=False, indent=2)

system = "You are a Moroccan education expert. Validate questions. Reply with JSON array only."

body = {
    "model": "openai/gpt-oss-120b",
    "messages": [
        {"role": "system", "content": system},
        {"role": "user", "content": "Validate this question:\n" + user_msg},
    ],
    "temperature": 0.1,
    "max_tokens": 2000,
}

print(f"Request body size: {len(json.dumps(body))} bytes")
print(f"User msg size: {len(user_msg)} chars")

r = requests.post(url, json=body, headers=headers, timeout=30)
print(f"Status: {r.status_code}")
data_r = r.json()
if "choices" in data_r:
    print(f"OK: {data_r['choices'][0]['message']['content'][:200]}")
else:
    print(f"Error: {json.dumps(data_r, ensure_ascii=False)[:300]}")
