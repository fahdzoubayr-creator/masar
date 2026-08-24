import json, sys, io
from groq import Groq
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

client = Groq(api_key="***REMOVED***")

models = ["allam-2-7b", "qwen/qwen3.6-27b", "openai/gpt-oss-120b", "openai/gpt-oss-20b", "groq/compound-mini"]

for model in models:
    print(f"\n--- {model} ---")
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": "قل 'أهلاً' فقط"}],
            max_tokens=10,
        )
        print(f"OK: {resp.choices[0].message.content[:50]}")
    except Exception as e:
        err = str(e)
        if '429' in err:
            print("RATE LIMITED")
        else:
            print(f"ERROR: {err[:100]}")
