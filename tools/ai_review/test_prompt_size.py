#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

# Import the actual system prompt from the script
sys.path.insert(0, r"D:\masar_app\masar_app\tools\ai_review")
from validate_questions import SYSTEM_PROMPT

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

q = data["academies_eval_bank_data"]["questions"][0]
user_msg = json.dumps([q], ensure_ascii=False, indent=2)

print(f"System prompt: {len(SYSTEM_PROMPT)} chars")
print(f"User msg: {len(user_msg)} chars")

body = {
    "model": "openai/gpt-oss-120b",
    "messages": [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_msg},
    ],
    "temperature": 0.1,
    "max_tokens": 4000,
}

print(f"Body size: {len(json.dumps(body, ensure_ascii=False))} chars")
print(f"Body JSON size: {len(json.dumps(body))} bytes")

r = requests.post(url, json=body, headers=headers, timeout=30)
print(f"Status: {r.status_code}")
data_r = r.json()
if "choices" in data_r:
    print(f"OK!")
else:
    print(f"Error: {json.dumps(data_r, ensure_ascii=False)[:300]}")
