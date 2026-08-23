#!/usr/bin/env python3
import requests, json, sys, io, time, re
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

with open(r"D:\masar_app\masar_app\tools\ai_review\filtered_questions.json", "r", encoding="utf-8") as f:
    data = json.load(f)

qs = data["academies_eval_bank_data"]["questions"][:10]
user_msg = json.dumps(qs, ensure_ascii=False, indent=2)

system = "You are a Moroccan education expert. Validate questions. Reply with JSON array only."

body = {
    "model": "openai/gpt-oss-20b",
    "messages": [
        {"role": "system", "content": system},
        {"role": "user", "content": "Validate:\n" + user_msg},
    ],
    "temperature": 0.1,
    "max_tokens": 4000,
}

time.sleep(5)
r = requests.post(url, json=body, headers=headers, timeout=60)
d = r.json()

if "choices" in d:
    content = d["choices"][0]["message"]["content"].strip()
    
    # Strip thinking
    content = re.sub(r'<think>[\s\S]*?</think>', '', content)
    content = re.sub(r'<reasoning>[\s\S]*?</reasoning>', '', content)
    content = re.sub(r'^```\w*\n?', '', content)
    content = re.sub(r'\n?```$', '', content)
    content = content.strip()
    
    # Find JSON array
    arr_match = re.search(r'\[[\s\S]*\]', content, re.DOTALL)
    if arr_match:
        raw_json = arr_match.group(0)
    else:
        raw_json = content
    
    # Show where the error is
    try:
        result = json.loads(raw_json)
        print(f"Direct parse OK: {len(result)} items")
    except json.JSONDecodeError as e:
        print(f"Parse error: {e}")
        # Show context around error
        pos = e.pos
        start = max(0, pos - 50)
        end = min(len(raw_json), pos + 50)
        print(f"Context around error (pos {pos}):")
        print(repr(raw_json[start:end]))
        
        # Try repair
        repaired = re.sub(r'\}\s*\{', '},{', raw_json)
        repaired = re.sub(r',\s*([}\]])', r'\1', repaired)
        try:
            result = json.loads(repaired)
            print(f"\nRepaired parse OK: {len(result)} items")
        except json.JSONDecodeError as e2:
            print(f"\nRepaired also fails: {e2}")
            pos2 = e2.pos
            start2 = max(0, pos2 - 50)
            end2 = min(len(repaired), pos2 + 50)
            print(f"Context: {repr(repaired[start2:end2])}")
else:
    print(f"API error: {d}")
