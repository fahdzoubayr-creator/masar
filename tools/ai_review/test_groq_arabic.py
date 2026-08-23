#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
url = "https://api.groq.com/openai/v1/chat/completions"
headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}

models = ["qwen/qwen3.6-27b", "openai/gpt-oss-120b", "openai/gpt-oss-20b"]

for model in models:
    body = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a Moroccan education expert. Reply in Arabic."},
            {"role": "user", "content": "ما هو المبدأ الأساسي لنظرية الجشطالت في التعلم؟ اختار واحد من 4 خيارات وأعطني الجواب فقط."}
        ],
        "max_tokens": 200,
        "temperature": 0.1,
    }
    try:
        r = requests.post(url, json=body, headers=headers, timeout=30)
        data = r.json()
        if "choices" in data:
            txt = data["choices"][0]["message"]["content"][:150]
            usage = data.get("usage", {})
            print(f"  OK  {model}")
            print(f"      Response: {txt}")
            print(f"      Tokens: in={usage.get('prompt_tokens',0)} out={usage.get('completion_tokens',0)}")
            print()
        else:
            err = str(data.get("error", {}))[:80]
            print(f"  FAIL {model}: {err}")
            print()
    except Exception as e:
        print(f"  ERR  {model}: {str(e)[:80]}")
        print()
