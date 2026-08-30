# -*- coding: utf-8 -*-
"""
توليد كويز QCM (70 سؤالاً) من ملف PDF واحد عبر Groq، بأسلوب امتحانات
الكفاءة المهنية لأساتذة التعليم الابتدائي بالمغرب.

النمط: لكل سؤال 4 خيارات حقيقية (عبارة صحيحة + 3 خاطئة) تُخلط آلياً،
بدون أي خيار من نوع «كل الاقتراحات السابقة خاطئة».

الاستخدام:
  python tools/quiz_from_pdf.py --pdf <مسار الملف> --subject <المادة> --out <json>
"""
import argparse
import io
import json
import os
import random
import re
import sys
from datetime import datetime
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

PROJECT = Path(r"D:\masar_app\masar_app")
PHRASE = "كل الاقتراحات السابقة خاطئة"
TARGET_DEFAULT = 70
PHRASE_CORRECT_DEFAULT = 15

MODEL_PREF = [
    "openai/gpt-oss-20b",
    "openai/gpt-oss-120b",
    "llama-3.3-70b-versatile",
    "llama-3.3-70b",
]
CHUNK_WORDS = 300
PER_CALL = 12         # أسئلة مطلوبة في كل استدعاء
MAX_CALLS = 18        # سقف استدعاءات لملف واحد
PARALLEL = 3          # استدعاءات متزامنة (تخفيف الضغط على حصة Groq)
PLAN_MARGIN = 6       # استدعاءات إضافية احتياطية لتعويض المكررات والمرفوضات
DEAD_MODELS = set()   # نماذج ثبت عدم توفرها (404) تُتخطى فوراً
FORBIDDEN = [
    PHRASE,
    "جميع الإجابات",
    "جميع ما سبق",
    "كل ما سبق",
    "لا شيء مما سبق",
    "placeholder",
    "OPTIONS:",
    "CORRECT:",
]

STYLE = (
    "أسلوب امتحانات الكفاءة المهنية لأساتذة التعليم الابتدائي بالمغرب: "
    "ديداكتيك المواد الدراسية، علوم التربية والتكوين، المستجدات البيداغوجية "
    "والمنهاج المغربي، وتحليل الوضعيات المهنية داخل الفصل الدراسي."
)

PROMPT = """اقرأ مقتطف الدرس التالي وولّد {n} أسئلة اختيار من متعدد (QCM) منه حصراً.

النمط المطلوب: {style}
لغة الأسئلة: نفس لغة المقتطف (العربية غالباً).

لكل سؤال أخرج بالضبط هذه الحقول:
  q         : نص السؤال (10 كلمات على الأقل).
  situation : سياق مهني/صفّي قصير يسبق السؤال، أو "" إن لم يكن ضرورياً.
  t         : العبارة الصحيحة الوحيدة (إجابة صحيحة، 2 إلى 12 كلمة).
  f1,f2,f3  : ثلاث عبارات خاطئة لكنها مقبولة ومنطقية (2 إلى 12 كلمة لكل منها).

شروط صارمة:
 - كل المعلومات مستمدة من المقتطف فقط، ولا معرفة خارجية.
 - لا تستخدم إطلاقاً عبارات مثل «كل ما سبق خاطئ»، «كل الاقتراحات السابقة خاطئة»، «جميع الاختيارات خاطئة» أو ما يشابهها — لن يُضاف أي خيار آلياً.
 - العبارات الأربع مختلفة نصياً ومفهوماً.
 - أعد مصفوفة JSON فقط دون أي شرح قبله أو بعده.

المقتطف:
{text}

صيغة الإخراج:
[{{"q":"...","situation":"...","t":"...","f1":"...","f2":"...","f3":"..."}}]"""


def resolve_key() -> str:
    k = os.environ.get("GROQ_API_KEY", "").strip()
    if k:
        return k
    for f in [PROJECT / "tools" / "ai_review" / "run_pipeline.ps1"] + list(
        (PROJECT / "tools" / "ai_review").glob("rag_generate*.py")
    ):
        try:
            m = re.search(r"gsk_[A-Za-z0-9]+", f.read_text(encoding="utf-8"))
            if m:
                return m.group(0)
        except OSError:
            pass
    raise SystemExit("NO_GROQ_KEY")


def pick_models(client):
    """????? ??????? ??????? ?????? ???? ??????? ? ???? GROQ_MODELS ????? ?????."""
    env = os.environ.get("GROQ_MODELS", "").strip()
    if env:
        return [m.strip() for m in env.split(",") if m.strip()]
    try:
        ids = [m.id for m in client.models.list()]
    except Exception:
        return list(MODEL_PREF)

    def score(mid: str) -> int:
        if mid in MODEL_PREF:
            return MODEL_PREF.index(mid)
        low = mid.lower()
        if "gpt-oss" in low:
            return 100
        if "70b" in low:
            return 200
        if "llama" in low or "qwen" in low:
            return 300
        return 400

    return sorted(ids, key=score)


def extract_pages(pdf_path=None, pdf_bytes=None) -> list:
    """استخراج نصوص الصفحات مع الاحتفاظ بترقيم كل صفحة (1-based)."""
    import fitz  # pymupdf

    doc = (fitz.open(stream=pdf_bytes, filetype="pdf")
           if pdf_bytes else fitz.open(str(pdf_path)))
    pages = []
    for i, page in enumerate(doc, start=1):
        t = page.get_text("text")
        t = re.sub(r"[ \t]+", " ", t)
        t = re.sub(r"\n{2,}", "\n", t).strip()
        pages.append((i, t))
    doc.close()
    return pages


def chunk_pages(pages: list, size: int = CHUNK_WORDS):
    """تقطيع نصوص الصفحات إلى مقاطع تحتفظ بنطاق أرقام الصفحات لكل مقطع."""
    toks = []  # (word, page_no)
    for pno, text in pages:
        for w in text.split():
            toks.append((w, pno))
    chunks = []
    step = max(1, int(size * 0.85))  # تداخل بسيط بين المقاطع
    for i in range(0, len(toks), step):
        sel = toks[i : i + size]
        if len(sel) >= 60:
            text = " ".join(w for w, _ in sel)
            pgs = sorted({p for _, p in sel})
            chunks.append((text, pgs))
        if i + size >= len(toks):
            break
    if chunks:
        return chunks
    plain = "\n".join(t for _, t in pages).strip()
    return [(
        plain[:4000] if plain else "",
        sorted({p for p, _ in pages}) or [1],
    )] if plain else []


def page_label(pgs) -> str:
    """تسمية مرجعية عربية لنطاق صفحات: «صفحة 3» أو «صفحات 4–7»."""
    pgs = sorted(set(int(p or 0) for p in pgs))
    if not pgs:
        return ""
    if len(pgs) == 1:
        return f"صفحة {pgs[0]}"
    return f"صفحات {pgs[0]}–{pgs[-1]}"


def clean_json_array(raw: str):
    s = raw.find("[")
    e = raw.rfind("]")
    if s < 0 or e <= s:
        return None
    try:
        return json.loads(raw[s : e + 1])
    except json.JSONDecodeError:
        try:
            fixed = re.sub(r",\s*([\]}])", r"\1", raw[s : e + 1])
            return json.loads(fixed)
        except json.JSONDecodeError:
            return None


def valid_item(it) -> bool:
    if not isinstance(it, dict):
        return False
    keys = ("q", "t", "f1", "f2", "f3")
    if not all(isinstance(it.get(k), str) for k in keys):
        return False
    vals = {it["q"], it["t"], it["f1"], it["f2"], it["f3"]}
    if len(vals) != 5:
        return False
    if any(not v.strip() for v in (it["t"], it["f1"], it["f2"], it["f3"])):
        return False
    if len(it["q"].split()) < 6:
        return False
    blob = " ".join([it["q"], it["t"], it["f1"], it["f2"], it["f3"]])
    for f in FORBIDDEN:
        if f in blob:
            return False
    for opt in (it["t"], it["f1"], it["f2"], it["f3"]):
        if len(opt.split()) > 15:
            return False
    return True


AR_CLITICS = "و ف ب ك ل س ه"
AR_PREFIXES = ("ال", "الم", "الل", "لأ", "لإ", "أل", "وأل")


def clean_ar(t: str) -> str:
    """تنظيف العربية: تشكيل، كلمات مقطّعة (ك كلمة -> ككلمة)، فراغات، Bidi."""
    s = re.sub(r"[\u064B-\u0652\u0670\u0640\u200c\u200f\u202a-\u202e]+", "", t)
    s = re.sub(r"[ \t]+", " ", s).strip()
    s = WORDS_RE.sub(lambda m: m.group(1) + m.group(2), s)
    s = re.sub(r"\s+([?!؟.,:،؛])", r"\1", s)
    return s.replace(" ؟", "؟").strip()


WORDS_RE = re.compile(
    r"(?:\s|^)((?:[" + AR_CLITICS + r"]|ال|الم|لأ|لإ)\s+)([^\s])"
)


def norm_item(it) -> dict:
    sit = it.get("situation") or ""
    if not isinstance(sit, str):
        sit = ""
    return {
        "q": clean_ar(it["q"]),
        "situation": clean_ar(sit),
        "t": clean_ar(it["t"]),
        "f1": clean_ar(it["f1"]),
        "f2": clean_ar(it["f2"]),
        "f3": clean_ar(it["f3"]),
    }


def ask(client, model: str, prompt: str):
    resp = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "system",
                "content": "أنت مولّد أسئلة امتحانات مهنية مغربية دقيق. تُخرج JSON فقط.",
            },
            {"role": "user", "content": prompt},
        ],
        temperature=0.65,
        max_tokens=4096,
    )
    return resp.choices[0].message.content or ""


def gen_one(client, models, excerpt, n, worker_idx=0, pages=None):
    """استدعاء واحد: يُرجع قائمة عناصر صالحة (قد تكون فارغة)."""
    import time as _t

    _t.sleep(worker_idx * 1.5)  # إزاحة بدء العمال لتلطيف حدود الطلب/الدقيقة
    prompt = PROMPT.format(n=n, style=STYLE, text=excerpt, phrase=PHRASE)
    raw = None
    for model in [m for m in models if m not in DEAD_MODELS]:
        for attempt in range(3):
            try:
                raw = ask(client, model, prompt)
                break
            except Exception as ex:
                msg = str(ex)
                print(f"MODEL_FAIL {model}: {msg[:120]}", file=sys.stderr)
                if "404" in msg or "does not exist" in msg:
                    DEAD_MODELS.add(model)
                    break
                transient = "429" in msg or "Rate limit" in msg or "503" in msg
                if transient and attempt < 2:
                    wait = 15 * (attempt + 1)
                    mra = re.search(r"try again in ([\d.]+)(ms|s|m)", msg)
                    if mra:
                        val = float(mra.group(1))
                        wait = max(wait, val / 1000 if mra.group(2) == "ms" else val * 60 if mra.group(2) == "m" else val)
                    _t.sleep(min(wait, 45))
                    continue
                break
        if raw:
            break
    if not raw:
        return []
    arr = clean_json_array(raw)
    if not isinstance(arr, list):
        return []
    items = [norm_item(it) for it in arr if valid_item(it)]
    if pages and items:
        lbl = page_label(pages)
        for nit in items:
            nit["p"] = lbl
    return items


def compose(items, subject, rng, source_doc="ملف الدرس"):
    """تركيب: 4 خيارات حقيقية مخلوطة، بدون عبارة «كل ما سبق»."""
    questions = []
    for it in items:
        opts = [it["t"], it["f1"], it["f2"], it["f3"]]
        rng.shuffle(opts)
        correct_index = opts.index(it["t"])
        pg = it.get("p") or ""
        page_txt = f" — {pg}" if pg else ""
        q = {
            "subject": subject,
            "text": it["q"],
            "options": opts,
            "correctIndex": correct_index,
            "explanation": f"{it['t']} (وردت في «{source_doc}»{page_txt})",
            "source": f"{source_doc} ({pg})" if pg else source_doc,
        }
        if it["situation"]:
            q["situation"] = it["situation"]
        questions.append(q)
    return questions


def write_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf", default="")
    ap.add_argument("--url", default="")
    ap.add_argument("--source-name", default="",
                    help="اسم الملف المُفضّل للمصدر في تعليل الإجابة")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--subject", default="")
    ap.add_argument("--count", type=int, default=TARGET_DEFAULT)
    ap.add_argument("--phrase-correct", type=int, default=PHRASE_CORRECT_DEFAULT)
    ap.add_argument("--first-count", type=int, default=0,
                    help="التوليد المتدرج: عدد أسئلة الدفعة الفورية")
    ap.add_argument("--out-first", default="", help="ملف الدفعة الفورية")
    ap.add_argument("--out-rest", default="", help="ملف أسئلة ما بعد الدفعة الأولى")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    progressive = args.first_count > 0 and args.out_first

    rng_seed = args.seed
    rng = random.Random(rng_seed)
    pdf_bytes = None
    if args.url:
        import requests as _rq
        rr = _rq.get(args.url, timeout=60, headers={"User-Agent": "masar-quizgen"})
        rr.raise_for_status()
        pdf_bytes = rr.content
    pdf_path = Path(args.pdf) if args.pdf else None
    if pdf_bytes is None and (pdf_path is None or not pdf_path.is_file()):
        print("PDF_NOT_FOUND")
        return 2

    text = "\n".join(t for _, t in extract_pages(pdf_path, pdf_bytes))
    if len(text.split()) < 120:
        print("PDF_TEXT_TOO_SHORT")
        return 2

    from groq import Groq

    client = Groq(api_key=resolve_key())
    models = pick_models(client)
    print("models:", ",".join(models[:6]), file=sys.stderr)
    chunks = chunk_pages(extract_pages(pdf_path, pdf_bytes))
    source_doc = (args.source_name.strip() if args.source_name.strip()
                  else (pdf_path.name if pdf_path
                        else args.url.rsplit("/", 1)[-1]).rsplit(".", 1)[0])
    seen_q = set()
    items = []
    first_count_done = 0

    if progressive:
        # ===== الدفعة الفورية: استدعاء واحد سريع ثم كتابة فورية =====
        fb = gen_one(client, models, chunks[0][0], args.first_count + 1,
                     pages=chunks[0][1])
        uniq = []
        fseen = set()
        for nit in fb:
            k = re.sub(r"\s+", " ", nit["q"]).lower()
            if k not in fseen:
                fseen.add(k)
                uniq.append(nit)
        fb = uniq[: args.first_count]
        if len(fb) < args.first_count:
            print("FIRST_FAILED got=%d" % len(fb))
            return 4
        sp_idx = set()
        first_questions = compose(fb, args.subject, rng, source_doc)
        write_json(Path(args.out_first), {
            "generatedAt": datetime.now().isoformat(timespec="seconds"),
            "pdf": pdf_path.name if pdf_path else args.url.rsplit("/", 1)[-1],
            "seed": args.seed,
            "count": len(first_questions),
            "phraseCorrectCount": 0,
            "questions": first_questions,
        })
        first_count_done = len(fb)
        for nit in fb:
            keyq = re.sub(r"\s+", " ", nit["q"]).lower()
            seen_q.add(keyq)
            items.append(nit)
        print(f"FIRST_READY n={first_count_done}", flush=True)

    from concurrent.futures import ThreadPoolExecutor, as_completed

    plan = min(MAX_CALLS, -(-args.count // PER_CALL) + PLAN_MARGIN)
    jobs = [
        (k, chunks[k % len(chunks)][0], chunks[k % len(chunks)][1], PER_CALL)
        for k in range(plan)
    ]

    done_calls = 0
    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        futs = {
            pool.submit(gen_one, client, models, ex, n, k % PARALLEL, pg): (k, n)
            for k, ex, pg, n in jobs
        }
        for fut in as_completed(futs):
            done_calls += 1
            try:
                got = fut.result()
            except Exception as ex:  # شبكة/أخرى
                print(f"CALL_FAIL {futs[fut]}: {str(ex)[:120]}", file=sys.stderr)
                got = []
            added = 0
            for nit in got:
                if len(items) >= args.count:
                    break
                keyq = re.sub(r"\s+", " ", nit["q"]).lower()
                if keyq in seen_q:
                    continue
                seen_q.add(keyq)
                items.append(nit)
                added += 1
            print(
                f"call#{done_calls}/{plan} added={added} total={len(items)}",
                file=sys.stderr,
            )
            if len(items) >= args.count:
                for f in futs:
                    f.cancel()
                break

    if len(items) < args.count:
        if progressive and len(items) >= first_count_done + 8:
            pass  # توليد جزئي مقبول في النمط المتدرج
        else:
            print(f"NOT_ENOUGH_QUESTIONS got={len(items)} need={args.count}")
            return 2

    # ===== التركيب: 4 خيارات حقيقية مخلوطة =====
    total_n = min(args.count, len(items))
    rng.shuffle(items)
    items = items[:total_n]
    questions = compose(items, args.subject, rng, source_doc)

    if progressive and args.out_rest:
        rest_q = questions[first_count_done:]
        write_json(Path(args.out_rest), {
            "state": "done",
            "count": len(rest_q),
            "questions": rest_q,
        })

    out = {
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
        "pdf": pdf_path.name if pdf_path else args.url.rsplit("/", 1)[-1],
        "model_style": "moroccan_professional_exam",
        "seed": args.seed,
        "count": len(questions),
        "phraseCorrectCount": args.phrase_correct,
        "firstCount": first_count_done,
        "questions": questions,
    }
    write_json(Path(args.out), out)
    print(f"GEN_OK count={len(questions)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
