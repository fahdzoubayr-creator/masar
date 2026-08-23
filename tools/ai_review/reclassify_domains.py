import json, sys, io, time, re, subprocess
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
GROQ_API_KEY = '***REMOVED***'
GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions'
PROGRESS_FILE = BANKS_DIR.parent.parent / 'tools' / 'ai_review' / '_classify_progress.json'

# Domains
DOMAINS = {
    'didactics_ar': 'ديداكتيك اللغة العربية',
    'didactics_fr': 'ديداكتيك الفرنسية',
    'didactics_math': 'ديداكتيك الرياضيات',
    'didactics_science': 'ديداكتيك النشاط العلمي',
    'didactics_amazigh': 'ديداكتيك اللغة الأمازيغية',
    'pedagogy': 'علوم التربية والبيداغوجيا',
    'psychology': 'سوسيولوجيا وسيكولوجيا التربية',
    'legislation': 'التشريع المدرسي والإداري',
    'school_project': 'مشروع المؤسسة المندمج',
    'school_councils': 'المجالس التعليمية',
    'reform': 'الإصلاح التربوي والسياسة التعليمية',
    'animation': 'التنشيط التربوي',
    'life_skills': 'المهارات الحياتية',
    'wadiaa': 'التخطيط والتدبير لأنشطة التعلم',
    'taRL': 'مؤسسات الريادة — مقاربة TaRL',
    'reject': None,
}

# The correct file for each domain
DOMAIN_FILES = {
    'didactics_ar': 'arabic_didactics.json',
    'didactics_fr': 'french_didactics_all.json',
    'didactics_math': 'math_didactics.json',
    'didactics_science': 'science_activity.json',
    'didactics_amazigh': 'amazigh_didactics.json',
    'pedagogy': 'science_edu.json',
    'psychology': 'socio_psychology.json',
    'legislation': 'science_edu.json',
    'school_project': 'school_project.json',
    'school_councils': 'school_councils.json',
    'reform': 'reform.json',
    'animation': 'animation.json',
    'life_skills': 'life_skills.json',
    'wadiaa': 'wadiaa_bank.json',
    'taRL': 'riyada.json',
    'reject': None,
}


def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {'classified': {}}


def save_progress(progress):
    with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
        json.dump(progress, f, ensure_ascii=False)


def call_groq(prompt, max_retries=2):
    payload = json.dumps({
        'model': 'allam-2-7b',
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.3,
        'max_tokens': 80,
    })
    for attempt in range(max_retries):
        try:
            result = subprocess.run(
                ['curl.exe', '-s', '-X', 'POST', GROQ_URL,
                 '-H', 'Authorization: Bearer ' + GROQ_API_KEY,
                 '-H', 'Content-Type: application/json',
                 '-d', payload],
                capture_output=True, text=True, timeout=30, encoding='utf-8'
            )
            resp = json.loads(result.stdout)
            if 'error' in resp:
                if 'rate_limit' in str(resp['error']).lower():
                    time.sleep(10 * (attempt + 1))
                    continue
                return None
            return resp['choices'][0]['message']['content'].strip()
        except Exception:
            time.sleep(3 * (attempt + 1))
    return None


def classify_with_groq(q):
    text = q.get('text', '')
    prompt = f"""أنت خبير في التصنيف التربوي المغربي. صنّف السؤال التالي في أحد المجالات التالية فقط:
- didactics_ar (ديداكتيك اللغة العربية: تعليم القراءة، الكتابة، النحو، المفردات)
- didactics_fr (ديداكتيك الفرنسية: تعليم اللغة الفرنسية)
- didactics_math (ديداكتيك الرياضيات: تعليم الرياضيات)
- didactics_science (ديداكتيك النشاط العلمي: تعليم العلوم)
- didactics_amazigh (ديداكتيك اللغة الأمازيغية)
- pedagogy (علوم التربية: نظريات التعلم، المقاربات البيداغوجية، أساليب التدريس، التخطيط، التدبير)
- psychology (سيكولوجيا وسوسيولوجيا التربية: النمو، الطفل، الأسرة، المجتمع)
- legislation (التشريع المدرسي: القانون الإطار، الميثاق، المذكرات، النظام الأساسي)
- school_project (مشروع المؤسسة: التخطيط، التدبير، التقويم)
- school_councils (المجالس التعليمية: مجلس المؤسسة)
- reform (الإصلاح التربوي: الرؤية الاستراتيجية، السياسات التعليمية)
- animation (التنشيط التربوي: الأندية، برلمان الطفل)
- life_skills (المهارات الحياتية)
- wadiaa (التخطيط والتدبير لأنشطة التعلم)
- taRL (مؤسسات الريادة، مقاربة TaRL)

السؤال: {text}

أجب بالاسم المختصر فقط (مثلاً: legislation) بدون شرح."""

    raw = call_groq(prompt)
    if not raw:
        return None

    raw = raw.strip().strip('"').strip("'")
    raw = re.sub(r'<think>.*?</think>', '', raw, flags=re.DOTALL).strip()
    raw = re.sub(r'<think>.*$', '', raw, flags=re.DOTALL).strip()

    for domain_key in DOMAINS:
        if domain_key in raw.lower():
            return domain_key

    return None


def find_questions_to_classify():
    """Find all questions that might be in the wrong domain using regex pre-filter."""
    to_classify = []
    regex_pat = re.compile(
        r'(?:مشروع المؤسسة|المجلس التربوي|المجلس التعليمي|القانون الإطار|'
        r'الميثاق|المذكرة|الرؤية الاستراتيجية|حقوق وواجبات|النظام الأساسي|'
        r'التشريع|décret|loi-cadre|charte| projet.*école|conseil.*école|'
        r'تدبير.*إداري|المجلس الأعلى|Helas|دفتر التحملات|_regs)',
        re.I
    )

    didactics_files = {
        'arabic_didactics.json', 'french_didactics_all.json', 'french_didactics_small.json',
        'math_didactics.json', 'math_didactics_small.json', 'science_activity.json',
        'science_didactics.json', 'amazigh_didactics.json', 'french_bank.json',
    }

    for fp in sorted(BANKS_DIR.glob('*.json')):
        if fp.name in didactics_files:
            continue  # skip pure didactics files

        data = json.load(open(fp, 'r', encoding='utf-8'))
        for s, qs in data.items():
            for i, q in enumerate(qs):
                text = q.get('text', '')
                if regex_pat.search(text):
                    to_classify.append({
                        'file': fp.name,
                        'subject': s,
                        'index': i,
                        'question': q,
                        'text_preview': text[:100],
                    })

    return to_classify


def main():
    progress = load_progress()
    to_classify = find_questions_to_classify()
    print(f"Found {len(to_classify)} questions needing Groq classification")

    # Group by file
    by_file = {}
    for item in to_classify:
        fname = item['file']
        if fname not in by_file:
            by_file[fname] = []
        by_file[fname].append(item)

    # Collect all reclassifications
    moves = []  # (from_file, from_subject, from_index, to_domain, question)

    processed = 0
    for fname, items in by_file.items():
        data = json.load(open(BANKS_DIR / fname, 'r', encoding='utf-8'))

        for item in items:
            s = item['subject']
            idx = item['index']
            q = item['question']
            key = f"{fname}:{s}:{idx}"
            processed += 1

            if key in progress.get('classified', {}):
                domain = progress['classified'][key]
            else:
                domain = classify_with_groq(q)
                if domain:
                    progress.setdefault('classified', {})[key] = domain
                else:
                    progress.setdefault('classified', {})[key] = 'pedagogy'
                    domain = 'pedagogy'
                time.sleep(1.0)

            pct = (processed / len(to_classify)) * 100
            print(f"[{processed}/{len(to_classify)} {pct:.0f}%] {fname} {s} Q{idx} -> {domain}: {item['text_preview'][:60]}")

            target_file = DOMAIN_FILES.get(domain)
            target_subject = DOMAINS.get(domain)

            if target_file and target_file != fname:
                moves.append((fname, s, idx, domain, q))

            if processed % 20 == 0:
                save_progress(progress)

    save_progress(progress)

    # Apply moves
    print(f"\n{'='*60}")
    print(f"APPLYING {len(moves)} MOVES")
    print(f"{'='*60}")

    # Load all destination files
    dest_cache = {}
    for move in moves:
        target_file = DOMAIN_FILES.get(move[3])
        if target_file not in dest_cache:
            dest_cache[target_file] = json.load(open(BANKS_DIR / target_file, 'r', encoding='utf-8'))

    # Remove from source files
    remove_keys = {}
    for from_file, from_subject, from_idx, to_domain, q in moves:
        key = (from_file, from_subject, from_idx)
        remove_keys.setdefault(from_file, []).append((from_subject, from_idx))

    # Load and modify source files
    for fname, removals in remove_keys.items():
        data = json.load(open(BANKS_DIR / fname, 'r', encoding='utf-8'))
        for subject, idx in sorted(removals, key=lambda x: x[1], reverse=True):
            if subject in data and idx < len(data[subject]):
                data[subject].pop(idx)
        # Remove empty subjects
        data = {k: v for k, v in data.items() if v}
        with open(BANKS_DIR / fname, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"  Removed {len(removals)} from {fname}")

    # Add to destination files
    for from_file, from_subject, from_idx, to_domain, q in moves:
        target_file = DOMAIN_FILES.get(to_domain)
        target_subject = DOMAINS.get(to_domain)
        if not target_file or not target_subject:
            continue
        dest_data = dest_cache[target_file]
        if target_subject not in dest_data:
            dest_data[target_subject] = []
        # Check for duplicates
        existing_texts = {eq.get('text', '') for eq in dest_data[target_subject]}
        if q.get('text', '') not in existing_texts:
            dest_data[target_subject].append(q)

    # Save destination files
    for fname, data in dest_cache.items():
        with open(BANKS_DIR / fname, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        total_q = sum(len(qs) for qs in data.values())
        print(f"  Saved {fname}: {total_q} total questions")

    print(f"\nDONE: {len(moves)} questions reclassified")


if __name__ == '__main__':
    main()
