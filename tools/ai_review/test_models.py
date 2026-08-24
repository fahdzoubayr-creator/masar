import json, sys, io
from groq import Groq
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

client = Groq(api_key="***REMOVED***")

# Test with all models
models = ["allam-2-7b", "qwen/qwen3.6-27b", "openai/gpt-oss-120b"]

for model in models:
    print(f"\n--- Testing {model} ---")
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "أنت مصمم اختبارات. أرجع JSON فقط."},
                {"role": "user", "content": "ولّد سؤالاً واحداً متعدد الخيارات عن: ما هو القانون الإطار 51.17؟\nأرجع: {\"question\": \"...\", \"correct_option\": \"...\", \"wrong_options\": [\"...\", \"...\", \"...\"]}"},
            ],
            temperature=0.3,
            max_tokens=500,
        )
        raw = resp.choices[0].message.content
        print(f"Response ({len(raw)} chars): {raw[:300]}")
    except Exception as e:
        print(f"ERROR: {e}")
