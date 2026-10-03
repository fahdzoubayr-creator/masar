import json, sys, io
from groq import Groq
_out = sys.stdout
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8')
    except Exception:
        pass

client = Groq(api_key="_groq_key()")

# Read a real chunk from the file
from pathlib import Path
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

txt = Path(r'D:\masar_app\masar_app\assets\review_files\مؤسسات الريادة\35.txt').read_text(encoding='utf-8')
words = txt.split()
chunk = ' '.join(words[:300])

prompt = f"""اكتب 3 أسئلة MCQ من النص التالي. كل سؤال له 4 خيارات (1 صحيح + 3 خاطئة).
الخيارات 2-8 كلمات. لا شرح.

النص:
{chunk[:2500]}

أرجع JSON فقط بدون شرح."""

for model in ["openai/gpt-oss-120b", "allam-2-7b"]:
    _out.write(f"\n=== {model} ===")
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "مصمم اختبارات مغربي. JSON فقط."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
            max_tokens=1500,
        )
        raw = resp.choices[0].message.content
        _out.write(f"Length: {len(raw)} chars")
        _out.write(f"First 500: {raw[:500]}")
    except Exception as e:
        _out.write(f"ERROR: {e}")
