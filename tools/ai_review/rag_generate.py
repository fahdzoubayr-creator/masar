import os
"""
RAG Quiz Generator: Generate MCQ questions from TXT files using Groq.
Strict structured output, chunk-based, validated.
"""
import json, sys, io, time, re, hashlib, os
from pathlib import Path
from groq import Groq

_out = sys.stdout
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding='utf-8')
    except Exception:
        pass

PROJECT = Path(r'D:\masar_app\masar_app')
BASE = PROJECT / 'assets' / 'review_files'
BANKS = Path(r'D:\masar_app\masar_app\assets\banks')


def _groq_key() -> str:
    """مفتاح Groq: من البيئة ثم من .env (مستثنى من git). بلا مفاتيح مضمّنة."""
    k = os.environ.get("GROQ_API_KEY", "").strip()
    if k:
        return k
    try:
        for line in (PROJECT / ".env").read_text(encoding="utf-8").splitlines():
            m = re.match(r"\s*GROQ_API_KEY\s*=\s*(.+)\s*$", line)
            if m:
                v = m.group(1).strip().strip("\"'")
                if v:
                    return v
    except OSError:
        pass
    raise SystemExit("NO_GROQ_KEY")


GROQ_KEY = _groq_key()
MODEL = "openai/gpt-oss-120b"
CHUNK_SIZE = 500  # words per chunk (reduced for Groq context limits)
QUESTIONS_PER_CHUNK = 5

client = Groq(api_key=GROQ_KEY)

SYSTEM_PROMPT = """أنت خبير بيداغوجي مغربي. ولّد أسئلة MCQ من النص فقط.

الشروط:
- 4 خيارات: 1 صحيح + 3 خاطئة منطقية من نفس النص
- كل خيار 2-8 كلمات
- لا تعليل ولا شرح
- لا عبارات "جميع الخيارات خاطئة"

JSON فقط: {"questions": [{"question": "...", "correct_option": "...", "wrong_options": ["...","...","..."]}]}"""

# Forbidden patterns in generated questions
FORBIDDEN = [
    'بدائل أخرى خاطئة', 'خيارات خاطئة', 'كل الاقتراحات', 'جميع الخيارات',
    'جميع الاختيارات', 'كل ما سبق', 'جميع ما سبق', 'الخيارات الخاطئة',
    'placeholders', 'يجب أن يكون', 'dummy', 'placeholder',
    'OPTIONS:', 'CORRECT:', 'QUESTION:',
]

def chunk_text(text, chunk_size=CHUNK_SIZE):
    words = text.split()
    chunks = []
    for i in range(0, len(words), chunk_size):
        chunk = ' '.join(words[i:i+chunk_size])
        if len(chunk.split()) >= 100:  # skip tiny chunks
            chunks.append(chunk)
    return chunks

def is_valid_question(q):
    if not isinstance(q, dict):
        return False
    text = q.get('question', '')
    correct = q.get('correct_option', '')
    wrongs = q.get('wrong_options', [])
    if not text or not correct or len(wrongs) != 3:
        return False
    if len(text) < 10 or len(correct) < 3:
        return False
    # Check option lengths (2-8 words)
    for opt in [correct] + wrongs:
        if len(opt.split()) > 15:
            return False
    # Check forbidden patterns
    all_text = text + ' ' + correct + ' ' + ' '.join(wrongs)
    for f in FORBIDDEN:
        if f in all_text:
            return False
    # Check no duplicate options
    opts = [correct] + wrongs
    if len(set(opts)) != 4:
        return False
    return True

def generate_from_chunk(chunk_text, file_name, attempt=0):
    # Truncate to ~3000 chars to stay within context
    truncated = ' '.join(chunk_text.split()[:500])
    prompt = f"النص:\n{truncated}\n\nولّد {QUESTIONS_PER_CHUNK} أسئلة MCQ من هذا النص فقط:"
    
    for retry in range(3):
        try:
            resp = client.chat.completions.create(
                model=MODEL,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt},
                ],
                temperature=0.3,
                max_tokens=2000,
            )
            raw = resp.choices[0].message.content.strip()
            if not raw:
                time.sleep(5)
                continue
            
            # Remove think tags if present
            if '<think>' in raw:
                import re
                raw = re.sub(r'<think>.*?</think>', '', raw, flags=re.DOTALL).strip()
            
            # Extract JSON from response
            if '```' in raw:
                raw = raw.split('```')[1]
                if raw.startswith('json'):
                    raw = raw[4:]
                raw = raw.strip()
            
            # Try to find JSON object
            start = raw.find('{')
            end = raw.rfind('}')
            if start >= 0 and end > start:
                raw = raw[start:end+1]
            
            data = json.loads(raw)
            questions = data.get('questions', [])
            return questions
        except json.JSONDecodeError:
            # Try extracting first valid JSON object from line-by-line
            try:
                lines = raw.strip().split('\n')
                for line in lines:
                    line = line.strip().rstrip(',')
                    if line.startswith('{') and line.endswith('}'):
                        data = json.loads(line)
                        if 'questions' in data:
                            return data['questions']
            except Exception:
                pass
            if retry < 2:
                time.sleep(3)
            else:
                _out.write(f"JSON parse failed")
                return []
        except Exception as e:
            if retry < 2:
                time.sleep(5)
            else:
                _out.write(f"  ERROR: {e}")
                return []
    return []

def process_file(txt_path, file_id, topic):
    text = txt_path.read_text(encoding='utf-8')
    if len(text.strip()) < 200:
        _out.write(f"  SKIP: too short ({len(text)} chars)")
        return []
    
    chunks = chunk_text(text)
    _out.write(f"  {len(chunks)} chunks from {len(text.split())} words")
    
    all_questions = []
    for i, chunk in enumerate(chunks):
        _out.write(f"  Chunk {i+1}/{len(chunks)}...", end=' ', flush=True)
        raw_qs = generate_from_chunk(chunk, txt_path.name)
        valid = [q for q in raw_qs if is_valid_question(q)]
        _out.write(f"{len(valid)}/{len(raw_qs)} valid")
        all_questions.extend(valid)
        time.sleep(3)  # rate limit
    
    return all_questions

def save_questions(questions, subject, fname):
    """Save questions in the standard bank JSON format."""
    fp = BANKS / fname
    if fp.exists():
        data = json.load(open(fp, 'r', encoding='utf-8'))
    else:
        data = {}
    
    if subject not in data:
        data[subject] = []
    
    existing_texts = {q['text'] for q in data[subject]}
    added = 0
    
    for q in questions:
        if q['question'] in existing_texts:
            continue
        bank_q = {
            "text": q['question'],
            "options": [q['correct_option']] + q['wrong_options'],
            "correctIndex": 0,
            "explanation": "",
            "source": f"Generated from: {q.get('file_id', 'unknown')}",
            "subject": subject,
        }
        # Shuffle options
        import random
        opts = bank_q['options'][:]
        ci = 0
        correct_text = opts[ci]
        random.shuffle(opts)
        bank_q['options'] = opts
        bank_q['correctIndex'] = opts.index(correct_text)
        
        data[subject].append(bank_q)
        existing_texts.add(q['question'])
        added += 1
    
    with open(fp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    return added

# ============ MAIN ============
manifest = json.load(open(BASE / 'manifest.json', 'r', encoding='utf-8'))

total_generated = 0
total_saved = 0

for category, files in manifest.items():
    quiz_files = [f for f in files if f.get('quiz') is True or f.get('quiz') == 'true']
    if not quiz_files:
        continue
    
    _out.write(f"\n{'='*60}")
    _out.write(f"Category: {category} ({len(quiz_files)} files)")
    _out.write(f"{'='*60}")
    
    for entry in quiz_files:
        txt_path = PROJECT / entry['txt']
        if not txt_path.exists():
            continue
        
        file_id = f"{category}/{txt_path.stem}"
        topic = entry.get('topic', category)
        name = entry.get('name', txt_path.stem)
        
        _out.write(f"\n  File: {name[:60]}")
        questions = process_file(txt_path, file_id, topic)
        
        if questions:
            # Determine bank filename
            safe_name = category.replace(' ', '_').replace('/', '_')
            bank_fname = f"rag_{safe_name}.json"
            saved = save_questions(questions, topic, bank_fname)
            total_generated += len(questions)
            total_saved += saved
            _out.write(f"  => {len(questions)} generated, {saved} saved to {bank_fname}")
        else:
            _out.write(f"  => 0 questions generated")

_out.write(f"\n{'='*60}")
_out.write(f"TOTAL: {total_generated} generated, {total_saved} saved to bank files")
_out.write(f"{'='*60}")