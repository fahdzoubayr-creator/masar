"""
LLM-as-a-Judge: Groq-based audit of all question bank files.
Checks: reversed years, concatenated words, spelling errors, factual accuracy.
Outputs structured JSON report for human review.
"""
import json, subprocess, sys, io, time, re, os
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
REPORT_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\audit_report.json')
PROGRESS_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\audit_progress.json')

GROQ_API_KEY = "***REMOVED***"
GROQ_MODEL = "allam-2-7b"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

BATCH_SIZE = 30
SLEEP_BETWEEN = 2.0

def call_groq(prompt: str, retries: int = 5) -> str | None:
    """Call Groq API via curl (urllib gets 403)."""
    payload = json.dumps({
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
        "max_tokens": 4096,
    }, ensure_ascii=False)

    for attempt in range(retries):
        try:
            result = subprocess.run(
                [
                    "curl.exe", "-s", "-w", "\\n%{http_code}",
                    "-X", "POST", GROQ_URL,
                    "-H", "Content-Type: application/json",
                    "-H", f"Authorization: Bearer {GROQ_API_KEY}",
                    "-d", payload,
                ],
                capture_output=True, timeout=60,
            )
            output = result.stdout.decode("utf-8", errors="replace").strip()
            lines = output.rsplit("\n", 1)
            body = lines[0] if len(lines) > 1 else ""
            code = lines[-1] if len(lines) > 1 else "0"

            if code == "429":
                wait = 10 * (attempt + 1)
                print(f"  Rate limited, waiting {wait}s...")
                time.sleep(wait)
                continue
            if code != "200":
                print(f"  HTTP {code}: {body[:200]}")
                time.sleep(2)
                continue

            data = json.loads(body)
            return data["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"  Error: {e}")
            time.sleep(2)
    return None

def build_audit_prompt(questions: list[dict]) -> str:
    """Build prompt for batch of questions."""
    q_text = ""
    for i, q in enumerate(questions):
        opts_str = " | ".join(q["options"])
        q_text += f"[{i}] {q['text']}\n    الخيارات: {opts_str}\n    الجواب: الخيار {q['correctIndex']}\n"

    return f"""أنت مدقق أسئلة تعليمية مغربي. فحص الأسئلة التالية واكتشف المشاكل فقط.

احذر من:
1. سنوات معكوسة (مثلاً 3691 بدلاً من 1963، أو 1002 بدلاً من 2001)
2. كلمات ملتصقة (بدون مسافة)
3. أخطاء إملائية واضحة
4. معلومات غير صحيحة واقعياً (حقائق خاطئة)
5. خيارات مكررة (نفس الخيار مرتين في سؤال واحد)

الأسئلة:
{q_text}

أرجع JSON فقط (بدون نص آخر):
{{
  "issues": [
    {{
      "index": رقم_السؤال,
      "type": "reversed_year|concatenated|spelling|factual|duplicate",
      "detail": "وصف دقيق للمشكلة"
    }}
  ]
}}

إذا لا توجد مشاكل: {{"issues": []}}"""

def load_progress() -> set:
    if PROGRESS_PATH.exists():
        return set(json.loads(PROGRESS_PATH.read_text("utf-8")))
    return set()

def save_progress(done: set):
    PROGRESS_PATH.write_text(json.dumps(list(done), ensure_ascii=False), "utf-8")

def main():
    all_questions = []
    for fp in sorted(BANKS_DIR.glob("*.json")):
        with open(fp, "r", encoding="utf-8") as f:
            data = json.load(f)
        for subject, qs in data.items():
            for q in qs:
                q["_file"] = fp.name
                q["_subject"] = subject
                all_questions.append(q)

    print(f"Total questions: {len(all_questions)}")

    # Load existing report if resuming
    report = {"issues": [], "audited_count": 0}
    if REPORT_PATH.exists():
        report = json.loads(REPORT_PATH.read_text("utf-8"))

    done = load_progress()
    batches = []
    for i in range(0, len(all_questions), BATCH_SIZE):
        batch_id = f"batch_{i}"
        if batch_id not in done:
            batches.append((batch_id, i, all_questions[i:i+BATCH_SIZE]))

    print(f"Remaining batches: {len(batches)}")

    for bi, (batch_id, start_idx, batch) in enumerate(batches):
        print(f"[{bi+1}/{len(batches)}] Auditing questions {start_idx}-{start_idx+len(batch)-1}...")
        prompt = build_audit_prompt(batch)
        response = call_groq(prompt)

        if response is None:
            print(f"  FAILED after retries, skipping batch")
            done.add(batch_id)
            save_progress(done)
            continue

        # Extract JSON from response
        try:
            # Try to find JSON in the response
            json_match = re.search(r'\{[\s\S]*\}', response)
            if json_match:
                result = json.loads(json_match.group())
            else:
                result = {"issues": []}

            for issue in result.get("issues", []):
                idx = issue.get("index", 0)
                if 0 <= idx < len(batch):
                    q = batch[idx]
                    report["issues"].append({
                        "file": q["_file"],
                        "subject": q["_subject"],
                        "question": q["text"][:100],
                        "type": issue.get("type", "unknown"),
                        "detail": issue.get("detail", ""),
                    })
        except json.JSONDecodeError as e:
            print(f"  JSON parse error: {e}")
            print(f"  Raw: {response[:200]}")

        report["audited_count"] = len(done) * BATCH_SIZE
        done.add(batch_id)
        save_progress(done)

        # Save report periodically
        if (bi + 1) % 10 == 0:
            REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), "utf-8")
            print(f"  Saved report ({len(report['issues'])} issues so far)")

        time.sleep(SLEEP_BETWEEN)

    # Final save
    report["audited_count"] = len(all_questions)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), "utf-8")
    print(f"\nDone! {len(report['issues'])} issues found in {len(all_questions)} questions.")
    print(f"Report saved to: {REPORT_PATH}")

if __name__ == "__main__":
    main()
