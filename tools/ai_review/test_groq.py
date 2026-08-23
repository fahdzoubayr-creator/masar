#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

models = [
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "llama3-70b-8192",
    "llama3-8b-8192",
    "mixtral-8x7b-32768",
    "gemma2-9b-it",
    "deepseek-r1-distill-llama-70b",
]

for model in models:
    body = {
        "model": model,
        "messages": [{"role": "user", "content": "Say hello"}],
        "max_tokens": 20,
    }
    try:
        r = requests.post(url, json=body, headers=headers, timeout=15)
        data = r.json()
        if "choices" in data:
            txt = data["choices"][0]["message"]["content"][:40]
            print(f"  OK  {model}: {txt}")
        else:
            err = str(data.get("error", {}))[:60]
            print(f"  FAIL {model}: {err}")
    except Exception as e:
        print(f"  ERR  {model}: {str(e)[:60]}")
