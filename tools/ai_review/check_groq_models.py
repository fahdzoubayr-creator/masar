#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
key = "***REMOVED***"
r = requests.get("https://api.groq.com/openai/v1/models", headers={"Authorization": "Bearer " + key}, timeout=15)
data = r.json()
models = [m["id"] for m in data.get("data", [])]
for m in sorted(models):
    print("  " + m)
print()
target = "llama-3.3-70b-versatile"
print("llama-3.3-70b-versatile available: " + str(target in models))

# Also test it
if target in models:
    url = "https://api.groq.com/openai/v1/chat/completions"
    body = {"model": target, "messages": [{"role": "user", "content": "Say hello in 3 words"}], "max_tokens": 20}
    r2 = requests.post(url, json=body, headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"}, timeout=15)
    d2 = r2.json()
    if "choices" in d2:
        print("Test call OK: " + d2["choices"][0]["message"]["content"][:50])
    else:
        print("Test call FAILED: " + json.dumps(d2.get("error", {}))[:100])
