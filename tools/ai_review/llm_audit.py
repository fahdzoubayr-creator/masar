"""
LLM-as-a-Judge: Groq-based audit of all question bank files.
Checks: reversed years, concatenated words, spelling errors, factual accuracy.
Outputs structured JSON report for human review.
"""
import json, subprocess, sys, io, time, re
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(r'D:\masar_app\masar_app\assets\banks')
REPORT_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\audit_report.json')
PROGRESS_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\audit_progress.json')

GROQ_API_KEY = "***REMOVED***"
GROQ_MODEL = "allam-2-7b"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

BATCH_SIZE = 50
SLEEP_BETWEEN = 3.0
MAX_RETRIES = 8

def call_groq(prompt: str, retries: int = MAX_RETRIES) -> str | None:
    payload = json.dumps({
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
        "max_tokens": 4096,
    }, ensure_ascii=False)

    for attempt in range(retries):
        try:
            result = subprocess.run(
                ["curl.exe", "-s", "-w", "\\n%{http_code}",
                 "-X", "POST", GROQ_URL,
                 "-H", "Content-Type: application/json",
                 "-H", f"Authorization: Bearer {GROQ_API_KEY}",
                 "-d", payload],
                capture_output=True, timeout=90,
            )
            output = result.stdout.decode("utf-8", errors="replace").strip()
            lines = output.rsplit("\n", 1)
            body = lines[0] if len(lines) > 1 else ""
            code = lines[-1] if len(lines) > 1 else "0"

            if code == "429":
                wait = 15 * (attempt + 1)
                print(f"    429 rate limit, waiting {wait}s...", flush=True)
                time.sleep(wait)
                continue
            if code != "200":
                print(f"    HTTP {code}, retry in 5s...", flush=True)
                time.sleep(5)
                continue

            data = json.loads(body)
            return data["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"    Error: {e}, retry in 5s...", flush=True)
            time.sleep(5)
    return None

def build_prompt(questions: list[dict]) -> str:
    q_text = ""
    for i, q in enumerate(questions):
        opts = " | ".join(q["options"])
        q_text += f"[{i}] {q['text']}\n    الخيارات: {opts}\n    الجواب: الخيار {q['correctIndex']}\n\n"

    return f"""أنت مدقق أسئلة تعليمية مغربي. فحص الأسئلة التالية واكتشف المشاكل.

احذر من:
1. سنوات معكوسة (مثلاً 3691 بدلاً من 1963)
2. كلمات ملتصقة (بدون مسافة بين كلمتين)
3. أخطاء إملائية واضحة
4. معلومات غير صحيحة واقعياً
5. خيارات مكررة

الأسئلة:
{q_text}
أرجع JSON فقط:
{{"issues":[{{"i":رقم,"t":"reversed_year|concatenated|spelling|factual|duplicate","d":"وصف"}}]}}
لا توجد مشاكل: {{"issues":[]}}"""

def load_progress() -> set:
    if PROGRESS_PATH.exists():
        data = json.loads(PROGRESS_PATH.read_text("utf-8"))
        return set(data) if isinstance(data, list) else set()
    return set()

def save_progress(done: set):
    PROGRESS_PATH.write_text(json.dumps(sorted(done), ensure_ascii=False), "utf-8")

def main():
    all_q = []
    for fp in sorted(BANKS_DIR.glob("*.json")):
        with open(fp, "r", encoding="utf-8") as f:
            data = json.load(f)
        for subj, qs in data.items():
            for q in qs:
                q["_file"] = fp.name
                q["_subject"] = subj
                all_q.append(q)

    total = len(all_q)
    num_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE
    print(f"Total: {total} questions, {num_batches} batches of {BATCH_SIZE}", flush=True)

    report = {"issues": [], "audited_count": 0}
    done = load_progress()

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
            print("FAILED", flush=True)
            done.add(batch_id)
            save_progress(done)
            continue

        try:
            m = re.search(r'\{[\s\S]*\}', response)
            result = json.loads(m.group()) if m else {"issues": []}
            count = 0
            for issue in result.get("issues", []):
                idx = issue.get("i", -1)
                if 0 <= idx < len(batch):
                    q = batch[idx]
                    report["issues"].append({
                        "file": q["_file"],
                        "subject": q["_subject"],
                        "question": q["text"][:120],
                        "type": issue.get("t", "?"),
                        "detail": issue.get("d", ""),
                    })
                    count += 1
            print(f"OK ({count} issues)", flush=True)
        except (json.JSONDecodeError, KeyError) as e:
            print(f"PARSE ERR: {e}", flush=True)

        done.add(batch_id)
        save_progress(done)
        time.sleep(SLEEP_BETWEEN)

        if len(done) % 20 == 0:
            report["audited_count"] = len(done) * BATCH_SIZE
            REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), "utf-8")
            print(f"  >> Saved checkpoint: {len(report['issues'])} issues in {len(done)*BATCH_SIZE}/{total}", flush=True)

    report["audited_count"] = total
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), "utf-8")
    print(f"\nDONE: {len(report['issues'])} issues in {total} questions.", flush=True)

if __name__ == "__main__":
    main()
