#!/usr/bin/env python3
import requests, json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

key = "***REMOVED***"
headers = {"Authorization": f"Bearer {key}"}

# List available models
r = requests.get("https://api.groq.com/openai/v1/models", headers=headers, timeout=15)
data = r.json()
if "data" in data:
    for m in sorted(data["data"], key=lambda x: x["id"]):
        print(f"  {m['id']}")
else:
    print(json.dumps(data, indent=2)[:500])
