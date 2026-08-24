import json, sys, io
from groq import Groq
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

client = Groq(api_key="***REMOVED***")

from pathlib import Path
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
    print(f"\n=== {model} ===")
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
        print(f"Length: {len(raw)} chars")
        print(f"First 800:\n{raw[:800]}")
        
        # Try parse
        start = raw.find('[')
        end = raw.rfind(']')
        if start >= 0 and end > start:
            arr = json.loads(raw[start:end+1])
            print(f"\nParsed {len(arr)} questions successfully!")
            for q in arr[:2]:
                print(f"  Q: {q.get('question','')[:60]}")
                print(f"  C: {q.get('correct','')[:40]}")
        else:
            # Try object
            start = raw.find('{')
            end = raw.rfind('}')
            if start >= 0 and end > start:
                obj = json.loads(raw[start:end+1])
                print(f"\nParsed object with keys: {list(obj.keys())}")
    except Exception as e:
        print(f"ERROR: {str(e)[:200]}")
