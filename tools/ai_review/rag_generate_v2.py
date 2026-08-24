"""
RAG Quiz Generator v2: Smaller chunks, more robust, rate-limit aware.
"""
import json, sys, io, time, re, random
from pathlib import Path
from groq import Groq

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

PROJECT = Path(r'D:\masar_app\masar_app')
BASE = PROJECT / 'assets' / 'review_files'
BANKS = PROJECT / 'assets' / 'banks'
GROQ_KEY = "***REMOVED***"
MODEL = "openai/gpt-oss-120b"
CHUNK_WORDS = 300
QUESTIONS_PER_CHUNK = 3
BASE_DELAY = 5

client = Groq(api_key=GROQ_KEY)

PROMPT_TEMPLATE = """اكتب {n} أسئلة MCQ من النص التالي. كل سؤال له 4 خيارات (1 صحيح + 3 خاطئة).
الخيارات 2-8 كلمات. لا شرح.

النص:
{text}

أرجع JSON بالشكل التالي:
q array فيه objects فيها t للسؤال و c للخيار الصحيح و w للخيارات الخاطئة"""

FORBIDDEN = [
    'بدائل أخرى خاطئة', 'خيارات خاطئة', 'كل الاقتراحات', 'جميع الخيارات',
    'جميع الاختيارات', 'كل ما سبق', 'الخيارات الخاطئة', 'placeholder',
    'OPTIONS:', 'CORRECT:', 'dummy',
]

def chunk_text(text, size=CHUNK_WORDS):
    words = text.split()
    chunks = []
    for i in range(0, len(words), size):
        c = ' '.join(words[i:i+size])
        if len(c.split()) >= 50:
            chunks.append(c)
    return chunks

def is_valid(q):
    if not isinstance(q, dict): return False
    t = q.get('t', q.get('question', ''))
    c = q.get('c', q.get('correct_option', ''))
    w = q.get('w', q.get('wrong_options', []))
    if not t or not c or len(w) != 3: return False
    if len(t) < 10 or len(c) < 3: return False
    for opt in [c] + w:
        if len(opt.split()) > 15: return False
    all_text = t + ' ' + c + ' ' + ' '.join(w)
    for f in FORBIDDEN:
        if f in all_text: return False
    if len(set([c] + w)) != 4: return False
    return True

def normalize(q):
    """Normalize to standard format."""
    return {
        "question": q.get('t', q.get('question', '')),
        "correct_option": q.get('c', q.get('correct_option', '')),
        "wrong_options": q.get('w', q.get('wrong_options', [])),
    }

def call_groq(text, file_name, attempt=0):
    prompt = PROMPT_TEMPLATE.format(n=QUESTIONS_PER_CHUNK, text=text[:2500])
    for retry in range(3):
        try:
            resp = client.chat.completions.create(
                model=MODEL,
                messages=[
                    {"role": "system", "content": "مصمم اختبارات مغربي. JSON فقط."},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.3,
                max_tokens=1500,
            )
            raw = resp.choices[0].message.content.strip()
            if not raw:
                time.sleep(BASE_DELAY * (retry + 1))
                continue
            
            # Strip think tags
            raw = re.sub(r'<think>.*?</think>', '', raw, flags=re.DOTALL).strip()
            
            # Extract JSON
            if '```' in raw:
                parts = raw.split('```')
                raw = parts[1].strip()
                if raw.startswith('json'): raw = raw[4:].strip()
            
            start = raw.find('{')
            end = raw.rfind('}')
            if start >= 0 and end > start:
                raw = raw[start:end+1]
            
            data = json.loads(raw)
            # Handle both formats
            qs = data.get('q', data.get('questions', []))
            return [normalize(x) for x in qs if is_valid(x)]
        except Exception as e:
            time.sleep(BASE_DELAY * (retry + 1))
    return []

def process_file(txt_path, file_id):
    text = txt_path.read_text(encoding='utf-8')
    if len(text.strip()) < 200:
        return []
    chunks = chunk_text(text)
    print(f"  {len(chunks)} chunks ({len(text.split())} words)", flush=True)
    results = []
    for i, chunk in enumerate(chunks):
        print(f"  [{i+1}/{len(chunks)}]", end=' ', flush=True)
        qs = call_groq(chunk, txt_path.name)
        print(f"{len(qs)} ok", flush=True)
        results.extend(qs)
        time.sleep(BASE_DELAY)
    return results

def save(questions, topic, fname):
    fp = BANKS / fname
    data = json.load(open(fp, 'r', encoding='utf-8')) if fp.exists() else {}
    if topic not in data: data[topic] = []
    existing = {q['text'] for q in data[topic]}
    added = 0
    for q in questions:
        if q['question'] in existing: continue
        opts = [q['correct_option']] + q['wrong_options']
        random.shuffle(opts)
        ci = opts.index(q['correct_option'])
        data[topic].append({
            "text": q['question'],
            "options": opts,
            "correctIndex": ci,
            "explanation": "",
            "source": f"RAG generated",
            "subject": topic,
        })
        existing.add(q['question'])
        added += 1
    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return added

# ============ MAIN ============
manifest = json.load(open(BASE / 'manifest.json', 'r', encoding='utf-8'))
total_gen = 0
total_saved = 0

for category, files in manifest.items():
    quiz_files = [f for f in files if f.get('quiz') is True or f.get('quiz') == 'true']
    if not quiz_files: continue
    
    has_files = [f for f in quiz_files if (PROJECT / f['txt']).exists()]
    if not has_files: continue
    
    print(f"\n{'='*50}")
    print(f"{category} ({len(has_files)} files)")
    print(f"{'='*50}")
    
    for entry in has_files:
        txt_path = PROJECT / entry['txt']
        name = entry.get('name', txt_path.stem)[:50]
        topic = entry.get('topic', category)
        print(f"\n  {name}")
        
        questions = process_file(txt_path, f"{category}/{txt_path.stem}")
        if questions:
            safe = category.replace(' ', '_').replace('/', '_')
            saved = save(questions, topic, f"rag_{safe}.json")
            total_gen += len(questions)
            total_saved += saved
            print(f"  => {len(questions)} gen, {saved} saved")

print(f"\n{'='*50}")
print(f"TOTAL: {total_gen} generated, {total_saved} saved")
