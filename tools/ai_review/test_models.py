from pathlib import Path
import json, sys, io
from groq import Groq
import os
import re


def _groq_key() -> str:
    """مفتاح Groq: من البيئة ثم من .env (مستثنى من git). بلا مفاتيح مضمّنة."""
    k = os.environ.get("GROQ_API_KEY", "").strip()
    if k:
        return k
    try:
        root = Path(__file__).resolve().parents[2]
        for line in (root / ".env").read_text(encoding="utf-8").splitlines():
            m = re.match(r"\s*GROQ_API_KEY\s*=\s*(.+)\s*$", line)
            if m:
                v = m.group(1).strip().strip("\"'")
                if v:
                    return v
    except OSError:
        pass
    raise SystemExit("NO_GROQ_KEY")

_out = sys.stdout
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8')
    except Exception:
        pass

client = Groq(api_key="_groq_key()")

# Test with all models
models = ["allam-2-7b", "qwen/qwen3.6-27b", "openai/gpt-oss-120b"]

for model in models:
    _out.write(f"\n--- Testing {model} ---")
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
        _out.write(f"Response ({len(raw)} chars): {raw[:300]}")
    except Exception as e:
        _out.write(f"ERROR: {e}")
