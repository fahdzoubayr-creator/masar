#!/usr/bin/env python3
"""
Generate meaningful 4th options using Groq API for questions with dash padding.
Replaces '—' placeholders with plausible distractors.
Uses curl since Python urllib gets blocked by Groq's User-Agent filter.
"""

import json
import sys
import io
import time
import re
import subprocess
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(r"D:\masar_app\masar_app\assets\banks")
GROQ_API_KEY = "***REMOVED***"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

DASH = "—"
ALL_WRONG_AR = "كل الاقتراحات خاطئة"
ALL_WRONG_FR = "Toutes les réponses ci-dessus sont fausses."

PROGRESS_FILE = BANKS_DIR.parent.parent / "tools" / "ai_review" / "_progress.json"


def load_progress():
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"processed": {}}


def save_progress(progress):
    with open(PROGRESS_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False)


def find_dash_questions():
    """Find all questions with dash padding across all bank files."""
    progress = load_progress()
    dash_questions = []
    for fp in sorted(BANKS_DIR.glob("*.json")):
        with open(fp, "r", encoding="utf-8") as f:
            data = json.load(f)
        for subject, questions in data.items():
            for i, q in enumerate(questions):
                opts = q.get("options", [])
                dash_count = sum(1 for o in opts if o == DASH)
                if dash_count > 0:
                    key = f"{fp.name}:{subject}:{i}"
                    # Check if we already processed ALL dashes for this question
                    prev = progress.get("processed", {}).get(key)
                    if prev is None or prev == "__FAILED__":
                        dash_questions.append({
                            "file": fp.name,
                            "subject": subject,
                            "index": i,
                            "question": q,
                            "dash_count": dash_count,
                        })
    return dash_questions


def call_groq(prompt, max_retries=2):
    """Call Groq API using curl (urllib gets blocked by Groq)."""
    payload = json.dumps({
        "model": "allam-2-7b",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.7,
        "max_tokens": 500,
    })

    for attempt in range(max_retries):
        try:
            result = subprocess.run(
                ["curl.exe", "-s", "-X", "POST", GROQ_URL,
                 "-H", "Authorization: Bearer " + GROQ_API_KEY,
                 "-H", "Content-Type: application/json",
                 "-d", payload],
                capture_output=True, text=True, timeout=30,
                encoding="utf-8"
            )
            if result.returncode != 0:
                raise Exception(f"curl failed: {result.stderr}")
            resp = json.loads(result.stdout)
            if "error" in resp:
                err = resp["error"]
                if "rate_limit" in str(err).lower() or err.get("code") == "rate_limit_exceeded":
                    wait = 10 * (attempt + 1)
                    print(f"    Rate limited, waiting {wait}s...")
                    time.sleep(wait)
                    continue
                raise Exception(f"API error: {err}")
            return resp["choices"][0]["message"]["content"].strip()
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(3 * (attempt + 1))
            else:
                print(f"    API call failed after {max_retries} retries: {e}")
                return None
    return None


def generate_option(q):
    """Generate a plausible distractor option for a question."""
    text = q.get("text", "")
    opts = q.get("options", [])
    explanation = q.get("explanation", "")
    subject = q.get("subject", "")

    real_opts = [o for o in opts if o.strip() and o != DASH and o not in (ALL_WRONG_AR, ALL_WRONG_FR)]

    prompt = f"""/no_think
أنت خبير في التربية والتعليم المغربي. أكمل بناء سؤال اختبار متعدد الخيارات.

السؤال: {text}
الموضوع: {subject}
الخيارات الموجودة:
{chr(10).join(f'- {o}' for o in real_opts)}

التوضيح: {explanation}

مهمتك: اختر خياراً رابعاً (جديداً) لا يتطابق مع أي من الخيارات الموجودة أعلاه، ويكون:
1. مرتبطاً بموضوع السؤال
2. خاطئاً (ليس الإجابة الصحيحة)
3. يبدو مقنعاً كخيار اختبار

أجب فقط بنص الخيار الجديد، بدون أي شرح أو تنسيق إضافي."""

    result = call_groq(prompt)
    if result:
        # Strip Qwen thinking blocks (<think>...</think> or incomplete)
        result = re.sub(r'<think>.*?</think>', '', result, flags=re.DOTALL).strip()
        # Also strip incomplete thinking (if truncated before </think>)
        result = re.sub(r'<think>.*$', '', result, flags=re.DOTALL).strip()
        result = result.strip().strip('"').strip("'")
        result = re.sub(r'^\d+[\.\)]\s*', '', result)
        result = re.sub(r'^[-•]\s*', '', result)
        result = result.strip()
        # Take only first line (in case model outputs multiple lines)
        if '\n' in result:
            result = result.split('\n')[0].strip()
        if result and result not in real_opts and len(result) > 3:
            return result
    return None


def main():
    dash_questions = find_dash_questions()
    total = len(dash_questions)
    print(f"Found {total} questions with dash padding (excluding already processed)")

    if not total:
        print("Nothing to do!")
        return

    progress = load_progress()
    by_file = {}
    for item in dash_questions:
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

            # Replace ALL dashes in this question
            opts = q["options"]
            dashes_replaced = 0
            for dash_i, o in enumerate(opts):
                if o == DASH:
                    # Regenerate fresh context each time (existing options change after each replacement)
                    real_opts = [x for x in opts if x.strip() and x != DASH and x not in (ALL_WRONG_AR, ALL_WRONG_FR)]
                    # Generate a unique option that's not already in real_opts
                    generated = generate_option(q)
                    if generated:
                        opts[dash_i] = generated
                        dashes_replaced += 1
                    else:
                        break  # Stop if generation fails
                    time.sleep(1.0)

            q["options"] = opts
            if dashes_replaced > 0:
                success += dashes_replaced
                file_success += dashes_replaced
                progress.setdefault("processed", {})[key] = f"replaced_{dashes_replaced}"
                print(f"OK: {dashes_replaced} dashes replaced")
            else:
                failed += 1
                file_failed += 1
                progress.setdefault("processed", {})[key] = "__FAILED__"
                print("FAIL")

            # Save progress every 10 questions
            if processed % 10 == 0:
                save_progress(progress)

        # Save file after all questions in this file
        with open(fp, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        print(f"  Saved {fname}: {file_success} ok, {file_failed} failed")

    save_progress(progress)
    print(f"\n=== DONE: {success} generated, {failed} failed out of {total} ===")


if __name__ == "__main__":
    main()
