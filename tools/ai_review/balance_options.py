import json, sys, io, time, subprocess
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(r"D:\masar_app\masar_app\assets\banks")
GROQ_API_KEY = "***REMOVED***"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
ALL_WRONG_AR = "كل الاقتراحات خاطئة"
ALL_WRONG_FR = "Toutes les reponses ci-dessus sont fausses."
PROGRESS_FILE = BANKS_DIR.parent.parent / "tools" / "ai_review" / "_balance_progress.json"


def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"processed": {}}


def save_progress(progress):
    with open(PROGRESS_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False)


def call_groq(prompt, max_retries=2):
    payload = json.dumps({
        "model": "allam-2-7b",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.8,
        "max_tokens": 200,
    })
    for attempt in range(max_retries):
        try:
            result = subprocess.run(
                ["curl.exe", "-s", "-X", "POST", GROQ_URL,
                 "-H", "Authorization: Bearer " + GROQ_API_KEY,
                 "-H", "Content-Type: application/json",
                 "-d", payload],
                capture_output=True, text=True, timeout=30, encoding="utf-8"
            )
            resp = json.loads(result.stdout)
            if "error" in resp:
                err = resp["error"]
                if "rate_limit" in str(err).lower():
                    time.sleep(10 * (attempt + 1))
                    continue
                return None
            return resp["choices"][0]["message"]["content"].strip()
        except Exception:
            time.sleep(3 * (attempt + 1))
    return None


def find_imbalanced():
    progress = load_progress()
    questions = []
    for fp in sorted(BANKS_DIR.glob("*.json")):
        with open(fp, "r", encoding="utf-8") as f:
            data = json.load(f)
        for s, qs in data.items():
            for i, q in enumerate(qs):
                key = f"{fp.name}:{s}:{i}"
                if key in progress.get("processed", {}):
                    continue
                opts = q.get("options", [])
                ci = q.get("correctIndex", 0)
                if len(opts) != 5 or ci < 0 or ci > 3:
                    continue
                correct = opts[ci]
                wrong = [opts[j] for j in range(4) if j != ci and opts[j] not in (ALL_WRONG_AR, ALL_WRONG_FR)]
                if not wrong:
                    continue
                avg_wrong_len = sum(len(w) for w in wrong) / len(wrong)
                ratio = len(correct) / max(avg_wrong_len, 1)
                if ratio > 2.0 and len(correct) > 40:
                    questions.append({"file": fp.name, "subject": s, "index": i, "question": q})
    return questions


def build_enriched_prompt(q):
    opts = q.get("options", [])
    ci = q.get("correctIndex", 0)
    text = q.get("text", "")
    correct = opts[ci]
    wrong_entries = []
    for j in range(4):
        if j != ci:
            wrong_entries.append(f"  الخيار {j+1}: {opts[j]}")

    prompt = f"""أنت خبير في صناعة أسئلة الاختبارات التربوية بالمغرب.
السؤال: {text}
الإجابة الصحيحة: {correct}
الخيارات الخاطئة الحالية (قصيرة جداً):
{chr(10).join(wrong_entries)}

مهمتك: أعد صياغة الخيارات الخاطئة الثلاثة لتكون بنفس طول الإجابة الصحيحة وبنفس مستوى التفصيل، مع بقاءها خاطئة.
أعد فقط 3 خيارات خاطئة مفصّلة، كل خيار في سطر منفصل، بدون أرقام أو تنسيق إضافي."""
    return prompt


def enrich_wrong_options(q):
    opts = q["options"]
    ci = q["correctIndex"]
    correct = opts[ci]
    correct_len = len(correct)
    wrong_indices = [j for j in range(4) if j != ci]

    prompt = build_enriched_prompt(q)
    raw = call_groq(prompt)
    if not raw:
        return False

    lines = [l.strip() for l in raw.strip().split("\n") if l.strip()]
    new_wrong = []
    for line in lines:
        line = line.strip()
        for prefix in ["الخيار 1:", "الخيار 2:", "الخيار 3:", "1.", "2.", "3.", "-", "•"]:
            if line.startswith(prefix):
                line = line[len(prefix):].strip()
        if line and len(line) > 3 and line != correct and line not in (ALL_WRONG_AR, ALL_WRONG_FR):
            new_wrong.append(line)

    if len(new_wrong) < 3:
        return False

    for idx, wrong_idx in enumerate(wrong_indices):
        opts[wrong_idx] = new_wrong[idx]

    q["options"] = opts
    return True


def main():
    questions = find_imbalanced()
    total = len(questions)
    print(f"Found {total} questions with imbalanced options")

    if not total:
        print("Nothing to do!")
        return

    progress = load_progress()
    by_file = {}
    for item in questions:
        fname = item["file"]
        if fname not in by_file:
            by_file[fname] = []
        by_file[fname].append(item)

    success = 0
    failed = 0
    processed = 0

    for fname, items in by_file.items():
        fp = BANKS_DIR / fname
        with open(fp, "r", encoding="utf-8") as f:
            data = json.load(f)

        file_success = 0
        file_failed = 0

        for item in items:
            subject = item["subject"]
            idx = item["index"]
            q = data[subject][idx]
            key = f"{fname}:{subject}:{idx}"
            processed += 1

            pct = (processed / total) * 100
            print(f"[{processed}/{total} {pct:.0f}%] {fname} {subject} Q{idx}...", end=" ", flush=True)

            ok = enrich_wrong_options(q)
            if ok:
                success += 1
                file_success += 1
                progress.setdefault("processed", {})[key] = "done"
                ci = q["correctIndex"]
                avg_wrong = sum(len(q["options"][j]) for j in range(4) if j != ci) / 3
                print(f"OK (correct={len(q['options'][ci])}, avg_wrong={avg_wrong:.0f})")
            else:
                failed += 1
                file_failed += 1
                progress.setdefault("processed", {})[key] = "FAIL"
                print("FAIL")

            time.sleep(1.0)

        with open(fp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        if processed % 10 == 0:
            save_progress(progress)

        print(f"  Saved {fname}: {file_success} ok, {file_failed} failed")

    save_progress(progress)
    print(f"\n=== DONE: {success} enriched, {failed} failed out of {total} ===")


if __name__ == "__main__":
    main()
