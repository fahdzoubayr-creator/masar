"""
Phase 2: Regenerate __NEED_REGEN__ options with strict prompt + blacklist validation.
Each question: keep question text + correct answer, generate 3 clean distractors.
"""
import json, subprocess, sys, io, time, re, random
from pathlib import Path
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
PROGRESS_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\regen2_progress.json')
GROQ_KEY = "_groq_key()"
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "allam-2-7b"

BATCH_SIZE = 30
SLEEP = 2.5

REGEN_MARKER = '__NEED_REGEN__'

VALIDATION_BLACKLIST = [
    'بدائل أخرى', 'خيارات خاطئة', 'الخيارات المعدلة', 'الخيارات المُحدّثة',
    'الخيارات الخاطئة', 'ثلاثة خيارات', 'ثلاث خيارات', 'خيار خاطئ',
    'لا توجد إجابة', 'لا يوجد جواب', 'الخيارات المُعاد',
    'كل الاقتراحات', 'جميع الاختيارات', 'جميع الخيارات',
    'لا شيء مما', 'غير ذلك', 'كل ما سبق',
    'يعتبر هذا', 'هذا الخيار', 'يشير إلى',
    'بالرغم من', 'بينما يمكن', 'على الرغم من',
    'تشمل:', 'تتضمن:', 'يتجه نحو:',
    'يُعتبر خاطئاً', 'ليس صحيحاً', 'غير دقيق',
    '__NEED_REGEN__',
]

def validate_option(text):
    t = text.strip()
    if len(t) < 4:
        return False
    if len(t) > 60:
        return False
    for pat in VALIDATION_BLACKLIST:
        if pat in t:
            return False
    if t.endswith(':'):
        return False
    if '\n' in t:
        return False
    return True

def call_groq(prompt, retries=5):
    payload = json.dumps({
        "model": GROQ_MODEL,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.4,
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
                time.sleep(15 * (attempt + 1))
                continue
            if code != "200":
                time.sleep(3)
                continue

            return json.loads(body)["choices"][0]["message"]["content"]
        except Exception:
            time.sleep(3)
    return None

SYSTEM_PROMPT = """أنت خبير تربوي ومصمم اختبارات مغربي.

مهمتك: توليد 3 خيارات خاطئة فقط (بدون أي خيار صحيح) لسؤال متعدد الخيارات.

قواعد صارمة:
1. كل خيار من 2 إلى 8 كلمات فقط — نص مستقل ومباشر
2. ممنوع أي شرح أو تعليل أو تبرير
3. ممنوع أي نصوص برمجية أو تعليمية
4. ممنوع عبارات التمهيد المقطوعة (تتضمن، تشمل، يتجه نحو)
5. ممنوع عبارات الحشو (كل ما سبق، لا شيء مما سبق)
6. ممنوع أي كلمة من: يعتبر، بالرغم، بينما، على الرغم، لأن، يشير، يمكن أن
7. الخيارات يجب أن تكون خاطئة لكن مغرية وذات صلة بالموضوع
8. لغة عربية سليمة بدون أخطاء إملائية"""

def build_prompt(questions):
    q_block = ""
    for i, q in enumerate(questions):
        correct = q['options'][q['correctIndex']]
        q_block += f'[{i}] {q["text"]}\nالجواب الصحيح: {correct}\n\n'

    return f"""{SYSTEM_PROMPT}

الأسئلة:
{q_block}
أرجع JSON فقط:
{{"a":[{{"i":0,"w":["خ1","خ2","خ3"]}},{{"i":1,"w":["خ1","خ2","خ3"]}}]}}"""

def main():
    all_q = []
    for fp in sorted(BANKS_DIR.glob('*.json')):
        with open(fp, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for subj, qs in data.items():
            for qi, q in enumerate(qs):
                opts = q.get('options', [])
                if REGEN_MARKER in opts:
                    all_q.append({
                        '_file': fp.name, '_subj': subj, '_qi': qi,
                        'text': q['text'], 'options': list(opts),
                        'correctIndex': q.get('correctIndex', 0),
                    })

    _out.write(f"Questions needing regen: {len(all_q)}")
    num_batches = (len(all_q) + BATCH_SIZE - 1) // BATCH_SIZE
    _out.write(f"Batches: {num_batches}")

    done = set()
    if PROGRESS_PATH.exists():
        done = set(json.loads(PROGRESS_PATH.read_text("utf-8")))

    fixed = 0
    failed = 0

    for bi in range(num_batches):
        batch_id = f"b{bi}"
        if batch_id in done:
            continue

        start = bi * BATCH_SIZE
        batch = all_q[start:start + BATCH_SIZE]
        _out.write(f"[{bi+1}/{num_batches}] Q{start}-{start+len(batch)-1}...", end=" ", flush=True)

        prompt = build_prompt(batch)
        response = call_groq(prompt)

        if response is None:
            _out.write("FAILED")
            done.add(batch_id)
            PROGRESS_PATH.write_text(json.dumps(sorted(done)), "utf-8")
            failed += len(batch)
            continue

        try:
            m = re.search(r'\{[\s\S]*\}', response)
            result = json.loads(m.group()) if m else {"a": []}

            for ans in result.get("a", []):
                idx = ans.get("i", -1)
                wrongs = ans.get("w", [])
                if 0 <= idx < len(batch):
                    bq = batch[idx]
                    valid_wrongs = [w.strip() for w in wrongs if validate_option(w)]

                    while len(valid_wrongs) < 3:
                        valid_wrongs.append("بديل خاطئ آخر")

                    new_wrongs = valid_wrongs[:3]

                    fp_path = BANKS_DIR / bq['_file']
                    with open(fp_path, 'r', encoding='utf-8') as f:
                        bank_data = json.load(f)

                    real_q = bank_data[bq['_subj']][bq['_qi']]
                    ci = real_q['correctIndex']
                    correct_text = real_q['options'][ci]

                    new_opts = [correct_text, new_wrongs[0], new_wrongs[1], new_wrongs[2]]
                    random.shuffle(new_opts)
                    new_ci = new_opts.index(correct_text)

                    real_q['options'] = new_opts
                    real_q['correctIndex'] = new_ci

                    with open(fp_path, 'w', encoding='utf-8') as f:
                        json.dump(bank_data, f, ensure_ascii=False, indent=2)
                    fixed += 1

            _out.write("OK")

        except (json.JSONDecodeError, KeyError) as e:
            _out.write(f"PARSE: {e}")
            failed += len(batch)

        done.add(batch_id)
        PROGRESS_PATH.write_text(json.dumps(sorted(done)), "utf-8")
        time.sleep(SLEEP)

        if len(done) % 20 == 0:
            _out.write(f"  >> Checkpoint: {fixed} fixed, {failed} failed")

    _out.write(f"\nDONE: {fixed} regenerated, {failed} failed")

    # Final stats
    remaining = 0
    for fp in sorted(BANKS_DIR.glob('*.json')):
        data = json.load(open(fp, 'r', encoding='utf-8'))
        for subj, qs in data.items():
            for q in qs:
                if REGEN_MARKER in q.get('options', []):
                    remaining += 1
    _out.write(f"Remaining __NEED_REGEN__: {remaining}")

if __name__ == "__main__":
    main()
