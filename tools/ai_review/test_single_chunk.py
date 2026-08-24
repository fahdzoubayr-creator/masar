import json, sys, io
from groq import Groq
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

client = Groq(api_key="***REMOVED***")

# Read a real chunk from the file
from pathlib import Path
txt = Path(r'D:\masar_app\masar_app\assets\review_files\مؤسسات الريادة\35.txt').read_text(encoding='utf-8')
words = txt.split()
chunk = ' '.join(words[:300])

prompt = f"""اكتب 3 أسئلة MCQ من النص التالي. كل سؤال له 4 خيارات (1 صحيح + 3 خاطئة).
الخيارات 2-8 كلمات. لا شرح.

النص:
{chunk[:2500]}

أرجع JSON فقط بدون شرح."""

for model in ["openai/gpt-oss-120b", "allam-2-7b"]:
    print(f"\n=== {model} ===")
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
        print(f"Length: {len(raw)} chars")
        print(f"First 500: {raw[:500]}")
    except Exception as e:
        print(f"ERROR: {e}")
