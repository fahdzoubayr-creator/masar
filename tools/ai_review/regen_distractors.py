"""
Regenerate bad distractors for corrupted questions using Groq API.
Only processes questions with bad options (long, meta-narrative, etc).
Keeps question text + correct answer, generates 3 new short distractors.
"""
import json, subprocess, sys, io, time, re, random
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
PROGRESS_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\regen_progress.json')
GROQ_KEY = "***REMOVED***"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "allam-2-7b"

AW_EXACT = {'جميع الاختيارات خاطئة', 'كل الاقتراحات خاطئة', 'جميع الخيارات الأخرى خاطئة'}

BATCH_SIZE = 5
SLEEP = 3.0

def is_bad(text):
    t = text.strip()
    if t in AW_EXACT:
        return False
    if len(t) > 80:
        return True
    if t.endswith(':') or t.endswith('،'):
        return True
    bad_starts = ['بالرغم', 'بينما', 'على الرغم', 'يعتبر', 'تشمل', 'بأن', 'إلا', 'قد ت', 'يمكن أن']
    for bs in bad_starts:
        if t.startswith(bs):
            return True
    if '\n' in t:
        return True
    return False

def call_groq(prompt, retries=5):
    payload = json.dumps({
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
        "max_tokens": 2048,
    }, ensure_ascii=False)

    for attempt in range(retries):
        try:
            r = subprocess.run(
                ["curl.exe", "-s", "-w", "\\n%{http_code}",
                 "-X", "POST", GROQ_URL,
                 "-H", "Content-Type: application/json",
                 "-H", f"Authorization: Bearer {GROQ_KEY}",
                 "-d", payload],
                capture_output=True, timeout=90,
            )
            out = r.stdout.decode("utf-8", errors="replace").strip()
            lines = out.rsplit("\n", 1)
            body = lines[0] if len(lines) > 1 else ""
            code = lines[-1] if len(lines) > 1 else "0"

            if code == "429":
                wait = 15 * (attempt + 1)
                time.sleep(wait)
                continue
            if code != "200":
                time.sleep(3)
                continue

            data = json.loads(body)
            return data["choices"][0]["message"]["content"]
        except Exception as e:
            time.sleep(3)
    return None

def build_prompt(questions):
    q_block = ""
    for i, q in enumerate(questions):
        correct = q['options'][q['correctIndex']]
        q_block += f'[{i}] السؤال: {q["text"]}\nالجواب الصحيح: {correct}\n\n'

    return f"""أنت خبير تربية مغربي. ولّد 3 خيارات خاطئة (بدائل) لكل سؤال.

القواعد الصارمة:
- كل خيار قصير ومباشر (3 إلى 10 كلمات فقط)
- ممنوع استخدام: لأن، بالرغم، بينما، يعتبر، تشمل، على الرغم
- ممنوع الشرح أو التبرير — خيار واحد فقط ومباشر
- الخيارات الخاطئة يجب أن تكون مغرية لكن خاطئة
- لا تكرر الخيار الصحيح

الأسئلة:
{q_block}
أرجع JSON فقط:
{{"answers":[{{"i":0,"w":["خ1","خ2","خ3"]}},{{"i":1,"w":["خ1","خ2","خ3"]}}]}}
"""

def main():
    all_q = []
    for fp in sorted(BANKS_DIR.glob('*.json')):
        with open(fp, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for subj, qs in data.items():
            for qi, q in enumerate(qs):
                opts = q.get('options', [])
                ci = q.get('correctIndex', 0)
                if len(opts) != 4:
                    continue
                needs_regen = False
                for i, o in enumerate(opts):
                    if i != ci and is_bad(o):
                        needs_regen = True
                        break
                if needs_regen:
                    all_q.append({
                        '_file': fp.name, '_subj': subj, '_qi': qi,
                        'text': q['text'], 'options': list(opts),
                        'correctIndex': ci,
                    })

    print(f"Questions needing regen: {len(all_q)}")

    done = set()
    if PROGRESS_PATH.exists():
        done = set(json.loads(PROGRESS_PATH.read_text("utf-8")))

    num_batches = (len(all_q) + BATCH_SIZE - 1) // BATCH_SIZE
    fixed = 0

    for bi in range(num_batches):
        batch_id = f"b{bi}"
        if batch_id in done:
            continue

        start = bi * BATCH_SIZE
        batch = all_q[start:start + BATCH_SIZE]
        print(f"[{bi+1}/{num_batches}] Q{start}-{start+len(batch)-1}...", end=" ", flush=True)

        prompt = build_prompt(batch)
        response = call_groq(prompt)

        if response is None:
            print("FAILED")
            done.add(batch_id)
            PROGRESS_PATH.write_text(json.dumps(sorted(done)), "utf-8")
            continue

        try:
            m = re.search(r'\{[\s\S]*\}', response)
            result = json.loads(m.group()) if m else {"answers": []}

            for ans in result.get("answers", []):
                idx = ans.get("i", -1)
                wrongs = ans.get("w", [])
                if 0 <= idx < len(batch) and len(wrongs) >= 3:
                    bq = batch[idx]
                    fp_path = BANKS_DIR / bq['_file']
                    with open(fp_path, 'r', encoding='utf-8') as f:
                        bank_data = json.load(f)

                    qs = bank_data[bq['_subj']]
                    real_q = qs[bq['_qi']]

                    ci = real_q['correctIndex']
                    correct_text = real_q['options'][ci]

                    new_wrongs = []
                    for w in wrongs[:3]:
                        w = w.strip()
                        if len(w) > 80:
                            words = w.split()
                            w = ' '.join(words[:10])
                        if w.endswith(':') or w.endswith('،'):
                            w = w[:-1].strip()
                        if len(w) < 5:
                            continue
                        new_wrongs.append(w)

                    while len(new_wrongs) < 3:
                        new_wrongs.append("لا توجد إجابة صحيحة أخرى")

                    new_opts = [correct_text, new_wrongs[0], new_wrongs[1], new_wrongs[2]]
                    random.shuffle(new_opts)
                    new_ci = new_opts.index(correct_text)

                    real_q['options'] = new_opts
                    real_q['correctIndex'] = new_ci

                    with open(fp_path, 'w', encoding='utf-8') as f:
                        json.dump(bank_data, f, ensure_ascii=False, indent=2)

                    fixed += 1

            print("OK")

        except (json.JSONDecodeError, KeyError) as e:
            print(f"PARSE: {e}")

        done.add(batch_id)
        PROGRESS_PATH.write_text(json.dumps(sorted(done)), "utf-8")
        time.sleep(SLEEP)

        if len(done) % 20 == 0:
            print(f"  >> Checkpoint: {fixed} fixed so far")

    print(f"\nDONE: {fixed} questions regenerated out of {len(all_q)}")

    from collections import Counter
    ci_dist = Counter()
    total = 0
    for fp in sorted(BANKS_DIR.glob('*.json')):
        data = json.load(open(fp, 'r', encoding='utf-8'))
        for subj, qs in data.items():
            for q in qs:
                ci_dist[q.get('correctIndex', 0)] += 1
                total += 1
    print(f"\ncorrectIndex distribution:")
    for i in range(4):
        print(f"  {i}: {ci_dist[i]} ({ci_dist[i]/total*100:.1f}%)")

if __name__ == "__main__":
    main()
