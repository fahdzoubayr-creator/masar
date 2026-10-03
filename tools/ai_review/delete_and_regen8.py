"""
Delete 8 corrupted questions and regenerate 8 replacements via Groq.
"""
import json, sys, io, time, random
from pathlib import Path
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

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
GROQ_KEY = "_groq_key()"
MODEL = "openai/gpt-oss-120b"

client = Groq(api_key=GROQ_KEY)

# 8 questions to delete: (file, subject, text_prefix)
DELETES = [
    ("science_edu.json", "علوم التربية والبيداغوجيا", "ال يكون التقويم وظيفيا عندما"),
    ("science_edu.json", "علوم التربية والبيداغوجيا", "يعرف القانون الإطار39-13"),
    ("popular_bank.json", "الرياضيات", "تمثل \"بيداغوجيا المشروع"),
    ("development_psychology.json", "النمو واستراتيجيات اكتساب الفهم", "مطالب النمو في مرحلة المراهقة تشمل"),
    ("science_edu.json", "علوم التربية والبيداغوجيا", "ماذا تعني المنطقة المحادية للنمو"),
    ("development_psychology.json", "النمو واستراتيجيات اكتساب الفهم", "في المراهقة المبكرة، تظهر النزعة"),
    ("arabic_didactics.json", "ديداكتيك اللغة العربية", "الكتابة الإبداعية في التعبير الكتابي"),
    ("socio_psychology.json", "سوسيولوجيا وسيكولوجيا التربية", "نادي الصحة"),
]

# Topics for replacement
REPLACE_TOPICS = [
    ("التقويم الوظيفي وال Blocked", "التقويم التربوي", "علوم التربية والبيداغوجيا"),
    ("الجودة في التربية", "التشريع التربوي", "علوم التربية والبيداغوجيا"),
    ("بيداغوجيا المشروع", "المقاربات البيداغوجية", "علوم التربية والبيداغوجيا"),
    ("النمو في مرحلة المراهقة", "سيكولوجية النمو", "النمو واستراتيجيات اكتساب الفهم"),
    ("منطقة النمو القريب ZPD", "نظريات التعلم", "علوم التربية والبيداغوجيا"),
    ("المراهقة المبكرة", "سيكولوجية النمو", "النمو واستراتيجيات اكتساب الفهم"),
    ("الكتابة الإبداعية", "التعبير الكتابي", "ديداكتيك اللغة العربية"),
    ("نادي الصحة في المدرسة", "الأنشطة المدرسية", "سوسيولوجيا وسيكولوجيا التربية"),
]

# Step 1: Delete the 8 questions
deleted = 0
for fname, subject, text_prefix in DELETES:
    fp = BANKS_DIR / fname
    data = json.load(open(fp, 'r', encoding='utf-8'))
    if subject not in data:
        _out.write(f"WARN: subject '{subject}' not in {fname}")
        continue
    qs = data[subject]
    found = False
    for i, q in enumerate(qs):
        if text_prefix in q.get('text', ''):
            removed = qs.pop(i)
            _out.write(f"DELETED from {fname}/{subject}: {removed['text'][:80]}")
            deleted += 1
            found = True
            break
    if not found:
        _out.write(f"NOT FOUND: {text_prefix} in {fname}/{subject}")
    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

_out.write(f"\nDeleted {deleted} questions")

# Step 2: Generate 8 replacements
def gen_question(subject, topic):
    prompt = f"""أنت خبير في التربية والتعليم المغربي. اكتب سؤالاً واحداً متعدد الخيارات باللغة العربية للمادة: {subject}
الموضوع: {topic}

الشروط:
- السؤال يجب أن يكون واضحاً ومكتملاً
- 4 خيارات فقط، الأولى خاطئة
- لا تستخدم علامات ترقيم في السؤال مثل (،) في نهاية الخيارات
- لا تكتب "جميع الخيارات" أو "كل الاقتراحات" كخيار
- كل خيار يجب أن يكون جملة مفيدة ومختلفة عن الأخرى
- أيقونة Auswahlne خيار يجب أن يكون بطول مماثل للخيار الصحيح

أرجع JSON فقط بدون شرح:
{{"text": "...", "options": ["خيار 1", "خيار 2", "خيار 3", "خيار 4"], "correctIndex": 0, "explanation": "...", "source": "..."
}}
"""
    for attempt in range(3):
        try:
            resp = client.chat.completions.create(
                model=MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.7,
                max_tokens=500,
            )
            raw = resp.choices[0].message.content.strip()
            # Extract JSON
            if '```' in raw:
                raw = raw.split('```')[1]
                if raw.startswith('json'):
                    raw = raw[4:]
            raw = raw.strip()
            q = json.loads(raw)
            opts = q.get('options', [])
            ci = q.get('correctIndex', 0)
            if len(opts) == 4 and 0 <= ci <= 3:
                return q
            _out.write(f"  Bad format attempt {attempt}: {len(opts)} options, ci={ci}")
        except Exception as e:
            _out.write(f"  Error attempt {attempt}: {e}")
        time.sleep(3)
    return None

added = 0
for (fname, orig_subject, text_prefix), (topic, subtopic, new_subject) in zip(DELETES, REPLACE_TOPICS):
    fp = BANKS_DIR / fname
    data = json.load(open(fp, 'r', encoding='utf-8'))
    
    q = gen_question(new_subject, topic)
    if q is None:
        _out.write(f"FAILED to generate for {text_prefix}")
        continue
    
    q['subject'] = new_subject
    if new_subject not in data:
        data[new_subject] = []
    data[new_subject].append(q)
    
    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    _out.write(f"ADDED to {fname}/{new_subject}: {q['text'][:80]}")
    added += 1
    time.sleep(2)

_out.write(f"\nDone: deleted {deleted}, added {added}")
