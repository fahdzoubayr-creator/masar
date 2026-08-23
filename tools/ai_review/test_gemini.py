#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"

# Test different model names
models = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-3-flash-preview", "gemini-3.1-flash-lite", "gemini-flash-latest"]

for model in models:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
    body = {"contents": [{"parts": [{"text": "Say hello in 3 words"}]}]}
    try:
        r = requests.post(url, json=body, timeout=30)
        data = r.json()
        if "candidates" in data:
            text = data["candidates"][0]["content"]["parts"][0]["text"]
            print(f"  {model}: OK - {text[:50]}")
        else:
            err = str(data.get("error", {}))[:80]
            print(f"  {model}: FAIL ({r.status_code}) - {err}")
    except Exception as e:
        print(f"  {model}: ERROR - {str(e)[:80]}")
