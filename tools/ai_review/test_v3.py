import os
import json, sys, io, os, re
from pathlib import Path
from groq import Groq
_out = sys.stdout
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8')
    except Exception:
        pass


def _groq_key() -> str:
    """مفتاح Groq: من البيئة ثم من .env (مستثنى من git)."""
    k = os.environ.get("GROQ_API_KEY", "").strip()
    if k:
        return k
    try:
        root = Path(r'D:\masar_app\masar_app')
        for line in (root / ".env").read_text(encoding="utf-8").splitlines():
            m = re.match(r"\s*GROQ_API_KEY\s*=\s*(.+)\s*$", line)
            if m:
                v = m.group(1).strip().strip("\"'")
                if v:
                    return v
    except OSError:
        pass
    raise SystemExit("NO_GROQ_KEY")


client = Groq(api_key=_groq_key())

txt = Path(r'D:\masar_app\masar_app\assets\review_files\مؤسسات الريادة\35.txt').read_text(encoding='utf-8')
words = txt.split()
chunk = ' '.join(words[:300])

prompt = f""" Read this Arabic educational text and generate 3 MCQ questions from it.

TEXT:
{chunk[:2000]}

OUTPUT FORMAT (JSON only, no explanation):
[
  {{"question": "...", "correct": "...", "wrong1": "...", "wrong2": "...", "wrong3": "..."}},
  {{"question": "...", "correct": "...", "wrong1": "...", "wrong2": "...", "wrong3": "..."}},
  {{"question": "...", "correct": "...", "wrong1": "...", "wrong2": "...", "wrong3": "..."}}
]

IMPORTANT: Return ONLY the JSON array. No text before or after."""

for model in ["allam-2-7b", "qwen/qwen3.6-27b", "openai/gpt-oss-20b"]:
    _out.write(f"\n=== {model} ===")
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=1500,
        )
        raw = resp.choices[0].message.content.strip()
        # Strip think tags
        import re
        raw = re.sub(r'<think>.*?</think>', '', raw, flags=re.DOTALL).strip()
        _out.write(f"Length: {len(raw)} chars")
        _out.write(f"First 800:\n{raw[:800]}")
        
        # Try parse
        start = raw.find('[')
        end = raw.rfind(']')
        if start >= 0 and end > start:
            arr = json.loads(raw[start:end+1])
            _out.write(f"\nParsed {len(arr)} questions successfully!")
            for q in arr[:2]:
                _out.write(f"  Q: {q.get('question','')[:60]}")
                _out.write(f"  C: {q.get('correct','')[:40]}")
        else:
            # Try object
            start = raw.find('{')
            end = raw.rfind('}')
            if start >= 0 and end > start:
                obj = json.loads(raw[start:end+1])
                _out.write(f"\nParsed object with keys: {list(obj.keys())}")
    except Exception as e:
        _out.write(f"ERROR: {str(e)[:200]}")