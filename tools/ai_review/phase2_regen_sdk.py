"""
Phase 2: Regenerate __NEED_REGEN__ options with Groq SDK (openai/gpt-oss-120b)
Structured JSON output + exponential backoff + blacklist validation.
"""
import json, sys, io, time, random
from pathlib import Path
from groq import Groq
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
PROGRESS_PATH = Path(r'D:\masar_app\masar_app\tools\ai_review\regen3_progress.json')
REGEN_MARKER = '__NEED_REGEN__'

client = Groq(api_key="_groq_key()")
MODEL = "openai/gpt-oss-120b"
BATCH_SIZE = 10
BASE_DELAY = 5

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

SYSTEM_PROMPT = """أنت خبير تربوي ومصمم اختبارات مغربي.

مهمتك: توليد 3 خيارات خاطئة فقط لسؤال متعدد الخيارات. أرجع النتيجة بصيغة JSON.

قواعد صارمة:
1. كل خيار من 2 إلى 8 كلمات فقط — نص مستقل ومباشر
2. ممنوع أي شرح أو تعليل أو تبرير
3. ممنوع أي نصوص برمجية أو تعليمية
4. ممنوع عبارات التمهيد المقطوعة (تتضمن، تشمل، يتجه نحو)
5. ممنوع عبارات الحشو (كل ما سبق، لا شيء مما سبق)
6. ممنوع أي كلمة من: يعتبر، بالرغم، بينما، على الرغم، لأن، يشير، يمكن أن
7. الخيارات يجب أن تكون خاطئة لكن مغرية وذات صلة بالموضوع
8. لغة عربية سليمة بدون أخطاء إملائية"""

SCHEMA = {
    "type": "object",
    "properties": {
        "answers": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "i": {"type": "integer"},
                    "w": {"type": "array", "items": {"type": "string"}, "minItems": 3, "maxItems": 3}
                },
                "required": ["i", "w"]
            }
        }
    },
    "required": ["answers"]
}


def validate_option(text):
    t = text.strip()
    if len(t) < 4 or len(t) > 60:
        return False
    for pat in VALIDATION_BLACKLIST:
        if pat in t:
            return False
    if t.endswith(':') or '\n' in t:
        return False
    return True


def call_groq_batch(prompt, max_retries=5):
    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model=MODEL,
                messages=[
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": prompt}
                ],
                response_format={"type": "json_object", "schema": SCHEMA},
                temperature=0.2,
                timeout=60.0,
            )
            return json.loads(response.choices[0].message.content)
        except Exception as e:
            if "429" in str(e) or "rate_limit" in str(e).lower():
                sleep_time = BASE_DELAY * (2 ** attempt)
                _out.write(f"  [429] wait {sleep_time}s (try {attempt+1}/{max_retries})", flush=True)
                time.sleep(sleep_time)
            else:
                _out.write(f"  [ERR] {e}", flush=True)
                time.sleep(5)
    return None


def build_prompt(questions):
    q_block = ""
    for i, q in enumerate(questions):
        correct = q['options'][q['correctIndex']]
        q_block += f'[{i}] السؤال: {q["text"]}\nالجواب الصحيح: {correct}\n\n'
    return q_block


def parse_answers(result, batch_size):
    """Parse response in multiple possible formats."""
    answers = []

    if not isinstance(result, dict):
        return answers

    # Format 1: {"answers": [{"i": 0, "w": [...]}]}
    if "answers" in result and isinstance(result["answers"], list):
        for a in result["answers"]:
            if isinstance(a, dict) and "i" in a:
                w = a.get("w", a.get("wrong_options", []))
                answers.append((int(a["i"]), w))

    # Format 2: {"0": [...], "1": [...], ...}
    if not answers:
        for k, v in result.items():
            if str(k).isdigit() and isinstance(v, list):
                answers.append((int(k), v))

    # Format 3: {"wrong_options": [...]} single question
    if not answers and "wrong_options" in result:
        answers.append((0, result["wrong_options"]))

    # Format 4: {"options": [...]} single question
    if not answers and "options" in result:
        answers.append((0, result["options"]))

    return answers


def main():
    all_q = []
    for fp in sorted(BANKS_DIR.glob('*.json')):
        with open(fp, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for subj, qs in data.items():
            for qi, q in enumerate(qs):
                if REGEN_MARKER in q.get('options', []):
                    all_q.append({
                        '_file': fp.name, '_subj': subj, '_qi': qi,
                        'text': q['text'], 'options': list(q.get('options', [])),
                        'correctIndex': q.get('correctIndex', 0),
                    })

    total = len(all_q)
    num_batches = (total + BATCH_SIZE - 1) // BATCH_SIZE
    _out.write(f"Need regen: {total} questions in {num_batches} batches of {BATCH_SIZE}", flush=True)

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
        result = call_groq_batch(prompt)

        if result is None:
            _out.write("FAILED", flush=True)
            done.add(batch_id)
            PROGRESS_PATH.write_text(json.dumps(sorted(done)), "utf-8")
            failed += len(batch)
            continue

        try:
            answers = parse_answers(result, len(batch))
            batch_fixed = 0

            for idx, wrongs_raw in answers:
                if idx < 0 or idx >= len(batch):
                    continue

                bq = batch[idx]
                valid = [w.strip() for w in wrongs_raw if w and validate_option(w)]

                if len(valid) < 3:
                    _out.write(f"(Q{start+idx}:{len(valid)}v)", end=" ", flush=True)

                while len(valid) < 3:
                    valid.append("بديل خاطئ آخر")

                new_wrongs = valid[:3]
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
                batch_fixed += 1

            fixed += batch_fixed
            _out.write(f"OK ({batch_fixed})", flush=True)

        except (json.JSONDecodeError, KeyError, TypeError) as e:
            _out.write(f"PARSE: {e}", flush=True)
            failed += len(batch)

        done.add(batch_id)
        PROGRESS_PATH.write_text(json.dumps(sorted(done)), "utf-8")
        time.sleep(1.0)

        if len(done) % 10 == 0:
            _out.write(f"  >> Checkpoint: {fixed}/{total} fixed, {failed} failed", flush=True)

    _out.write(f"\nDONE: {fixed} regenerated, {failed} failed out of {total}", flush=True)

    remaining = 0
    for fp in sorted(BANKS_DIR.glob('*.json')):
        data = json.load(open(fp, 'r', encoding='utf-8'))
        for subj, qs in data.items():
            for q in qs:
                if REGEN_MARKER in q.get('options', []):
                    remaining += 1
    _out.write(f"Remaining __NEED_REGEN__: {remaining}", flush=True)


if __name__ == "__main__":
    main()
