"""
RAG Quiz Generator v3: Proven prompt, dual-model fallback.
"""
import json, sys, io, time, re, random
from pathlib import Path
from groq import Groq

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

PROJECT = Path(r'D:\masar_app\masar_app')
BASE = PROJECT / 'assets' / 'review_files'
BANKS = PROJECT / 'assets' / 'banks'
GROQ_KEY = "***REMOVED***"
MODELS = ["openai/gpt-oss-20b", "allam-2-7b"]
CHUNK_WORDS = 300
QUESTIONS_PER_CHUNK = 3
BASE_DELAY = 4

client = Groq(api_key=GROQ_KEY)

PROMPT_TEMPLATE = """ Read this Arabic educational text and generate {n} MCQ questions from it.
Each question has 1 correct answer and 3 wrong answers (2-8 words each).

TEXT:
{text}

OUTPUT FORMAT (JSON array only, no explanation):
[
  {{"question": "...", "correct": "...", "wrong1": "...", "wrong2": "...", "wrong3": "..."}}
]

IMPORTANT: Return ONLY the JSON array. No text before or after."""

FORBIDDEN = [
    'بدائل أخرى خاطئة', 'خيارات خاطئة', 'كل الاقتراحات', 'جميع الخيارات',
    'جميع الاختيارات', 'كل ما سبق', 'placeholder', 'OPTIONS:', 'CORRECT:',
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
    t = q.get('question', '')
    c = q.get('correct', '')
    w = [q.get('wrong1',''), q.get('wrong2',''), q.get('wrong3','')]
    if not t or not c or not all(w): return False
    if len(t) < 10 or len(c) < 2: return False
    all_text = t + ' ' + c + ' ' + ' '.join(w)
    for f in FORBIDDEN:
        if f in all_text: return False
    if len(set([c] + w)) != 4: return False
    for opt in [c] + w:
        if len(opt.split()) > 15: return False
    return True

def call_groq(text, attempt=0):
    prompt = PROMPT_TEMPLATE.format(n=QUESTIONS_PER_CHUNK, text=text[:2500])
    for model in MODELS:
        for retry in range(2):
            try:
                resp = client.chat.completions.create(
                    model=model,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.3,
                    max_tokens=1500,
                )
                raw = resp.choices[0].message.content.strip()
                if not raw:
                    time.sleep(BASE_DELAY)
                    continue
                raw = re.sub(r'<think>.*?</think>', '', raw, flags=re.DOTALL).strip()
                if '```' in raw:
                    parts = raw.split('```')
                    raw = parts[1].strip()
                    if raw.startswith('json'): raw = raw[4:].strip()
                start = raw.find('[')
                end = raw.rfind(']')
                if start >= 0 and end > start:
                    arr = json.loads(raw[start:end+1])
                    valid = [q for q in arr if is_valid(q)]
                    if valid:
                        return valid
            except Exception as e:
                time.sleep(BASE_DELAY * (retry + 1))
    return []

def process_file(txt_path):
    text = txt_path.read_text(encoding='utf-8')
    if len(text.strip()) < 200:
        return []
    chunks = chunk_text(text)
    print(f"  {len(chunks)} chunks ({len(text.split())} words)", flush=True)
    results = []
    for i, chunk in enumerate(chunks):
        print(f"  [{i+1}/{len(chunks)}]", end=' ', flush=True)
        qs = call_groq(chunk)
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
        opts = [q['correct']] + [q['wrong1'], q['wrong2'], q['wrong3']]
        random.shuffle(opts)
        ci = opts.index(q['correct'])
        data[topic].append({
            "text": q['question'],
            "options": opts,
            "correctIndex": ci,
            "explanation": "",
            "source": "RAG generated",
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
        questions = process_file(txt_path)
        if questions:
            safe = category.replace(' ', '_').replace('/', '_')
            saved = save(questions, topic, f"rag_{safe}.json")
            total_gen += len(questions)
            total_saved += saved
            print(f"  => {len(questions)} gen, {saved} saved")

print(f"\n{'='*50}")
print(f"TOTAL: {total_gen} generated, {total_saved} saved")
