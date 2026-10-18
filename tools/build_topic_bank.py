# -*- coding: utf-8 -*-
"""يبني بنك أسئلة ثابت لكل محور فرعي من المخرجات المولّدة سابقاً.

لماذا؟ التوليد الحيّ يحتاج حصة LLM (Groq/Gemini) وقد تنفد، فينتظر المستخدم
دقائق. بنك ثابت محلي = كويز فوري ودائم.

المصدر: assets/banks/generated_jobs/*.json  (مخرجات quiz_from_pdf.py)
الربط : source السؤال => اسم الوثيقة => topic من assets/review_files/manifest.json

المخرج: assets/banks/topics.json  { "<عنوان المحور الفرعي>": [سؤال, ...] }
"""
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import quiz_from_pdf as q  # noqa: E402  (نستخدم clean_ar / strip_deictic)
import question_quality as qq  # noqa: E402  (بوابة جودة الأسئلة)

PROJECT = Path(__file__).resolve().parent.parent
JOBS = PROJECT / "assets" / "banks" / "generated_jobs"
MANIFEST = PROJECT / "assets" / "review_files" / "manifest.json"
OUT = PROJECT / "assets" / "banks" / "topics.json"

PAGE_TAIL = re.compile(r"\s*[(\[][^)\]]*(?:صفحة|صفحات|ص|صـ)[^)\]]*[)\]]\s*$")
# لواحق تسيء تسمية المرجع داخل السؤال («الأعلام التربوية - مهم جدا»).
DOC_NOISE = re.compile(
    r"[\s\-–—_]*(?:مهم\s+جدا|مهم\s+جدًّا|\(\s*مهم\s*جدا\s*\)|نسخة\s*\d*"
    r"|\d{4}-\d{2}-\d{2})\s*$"
)
# لاحقة تظهر داخل الشرح لا في اسم الوثيقة نفسه.
EXP_NOISE = re.compile(r"\s*[\-–—]?\s*مهم\s+جدا|«\s*»")
# أسماء وثائق ناقصة المسافة في المصدر القديم.
NAME_FIX = {
    "النمووالتعلم": "النمو والتعلم",
    "الأعلامالتربوية": "الأعلام التربوية",
}


def clean_doc_name(name: str) -> str:
    """اسم وثيقة مقروء: بلا تواريخ ولا لاحقة «مهم جدا» ولا شرطات زائدة."""
    n = re.sub(r"\s+", " ", (name or "").replace("_", " ")).strip()
    n = NAME_FIX.get(n, n)
    prev = None
    while prev != n:
        prev = n
        n = DOC_NOISE.sub("", n).strip()
    return re.sub(r"[\s\-–—]{2,}", " ", n).strip(" -–—،,")


def clean_exp(exp: str) -> str:
    """تعليل بلا ضجيج اسم الوثيقة («- مهم جدا») ولا مرجع فارغ ولا فراغ زائد."""
    e = re.sub(r"\s*[\-–—]\s*مهم\s+جدا\s*", " ", exp or "")
    e = EXP_NOISE.sub("", e)
    for a, b in NAME_FIX.items():
        e = e.replace(a, b)
    e = e.replace("« ", "«").replace(" »", "»")
    return re.sub(r"\s{2,}", " ", e).strip(" ،,")


def norm_key(s: str) -> str:
    """مفتاح مطابقة متسامح: يتجاهل المسافات والتشكيل وصور الهمزة والألف."""
    s = unicodedata.normalize("NFKC", s or "")
    s = re.sub(r"[\u064B-\u0652\u0670\u0640]", "", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    s = re.sub(r"[^\w\u0600-\u06FF]+", "", s)
    return s.lower()


def doc_name(source: str) -> str:
    """اسم الوثيقة من حقل source مع stripping ل/Pages."""
    s = PAGE_TAIL.sub("", (source or "").strip())
    return s.strip(" -–—،,")


def load_name_index():
    """مفاتيح مطابقة => محور.

    ثلاثة مصادر بالترتيب: اسم الوثيقة، ثم عنوان المحور، ثم اسم المجلد
    (أسئلة قديمة سُجّل مصدرها باسم المحور لا بالوثيقة).
    """
    docs, topics, folders = {}, {}, {}
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for folder, entries in data.items():
        per_topic = Counter()
        for e in entries:
            topic = e.get("topic") or folder
            per_topic[topic] += 1
            name = (e.get("name") or "").strip()
            if name:
                docs.setdefault(norm_key(name), topic)
            topics.setdefault(norm_key(topic), topic)
        if per_topic:
            folders.setdefault(norm_key(folder), per_topic.most_common(1)[0][0])
    return docs, topics, folders


def resolve_topic(dn: str, docs, topics, folders):
    k = norm_key(dn)
    if not k:
        return ""
    for table in (docs, topics, folders):
        if k in table:
            return table[k]
    # مطابقة بادئة طويلة: أسماء الوثائق تختلف أحيانًا بشرطة أو لاحقة.
    for table in (docs, topics, folders):
        for key, topic in table.items():
            if len(k) > 18 and (key.startswith(k[:22]) or k.startswith(key[:22])):
                return topic
    return ""


def valid_q(qo: dict) -> bool:
    if not isinstance(qo, dict):
        return False
    text = (qo.get("text") or "").strip()
    opts = qo.get("options")
    ci = qo.get("correctIndex")
    if len(text) < 20 or len(text) > 400:
        return False
    if not isinstance(opts, list) or len(opts) < 3:
        return False
    if not isinstance(ci, int) or not (0 <= ci < len(opts)):
        return False
    if any((o or "").strip() in ("", "...") for o in opts):
        return False
    # لا نحتفظ بعبارات تشير إلى «النص» في أي موضع (لا في نهايته فقط).
    if re.search(r"(?:هذا|هذه)\s+(?:النص|المقتطف|المعطى)\b", text):
        return False
    if re.search(r"(?:النص\s+المرجعي|هذا\s+المقتطف|هذا\s+النص)", text):
        return False
    return True


def main():
    docs, topics, folders = load_name_index()
    buckets = defaultdict(list)
    seen = set()
    unmapped = Counter()
    stats = Counter()

    for f in sorted(JOBS.glob("*.json")):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            stats["bad_file"] += 1
            continue
        for qo in data.get("questions") or []:
            if not valid_q(qo):
                stats["invalid"] += 1
                continue
            dn = clean_doc_name(doc_name(qo.get("source") or ""))
            topic = resolve_topic(dn, docs, topics, folders)
            if not topic:
                unmapped[doc_name(qo.get("source") or "") or "(بلا مصدر)"] += 1
                stats["unmapped"] += 1
                continue
            rec = {
                "subject": topic,
                "situation": qq.fix_typos(
                    q.strip_deictic((qo.get("situation") or "").strip())),
                "text": qq.fix_typos(
                    q.strip_deictic((qo.get("text") or "").strip(), dn)),
                "options": [qq.fix_typos(q.clean_ar(str(o))) for o in qo["options"]],
                "correctIndex": qo["correctIndex"],
                "explanation": clean_exp(q.clean_ar(str(qo.get("explanation") or ""))),
                "source": dn,
            }
            # ===== بوابة الجودة: لا تسريب ولا خيار وصفي ولا سياق غريب =====
            reason = qq.drop_reason(rec, topic)
            if reason:
                stats["qa_" + reason] += 1
                continue
            key = re.sub(r"\s+", " ", rec["text"]).strip().lower()
            if key in seen:
                stats["dup"] += 1
                continue
            seen.add(key)
            buckets[topic].append(rec)
            stats["kept"] += 1

    # تفرّد دلالي داخل المحور: أسئلة مقلوبة المعنى تُحذف (مثال: «ما مبدأ
    # الثالث المرفوع» و«ما المبدأ الذي يصفه» => سؤال واحد فقط).
    for topic, qs in list(buckets.items()):
        kept, kept_toks = [], []
        for rec in qs:
            t = qq.tokens(rec["text"])
            if any(qq.jaccard(t, kt) >= 0.5 for kt in kept_toks):
                stats["qa_semantic_dup"] += 1
                stats["kept"] -= 1
                continue
            kept.append(rec)
            kept_toks.append(t)
        buckets[topic] = kept

    out = {}
    valid_topics = set(topics.values())
    for topic, qs in buckets.items():
        # نحتفظ بمحاور المانيفست فقط، وبما فيه حدّ أدنى من الأسئلة
        if topic not in valid_topics or len(qs) < 10:
            continue
        out[topic] = sorted(qs, key=lambda x: x["text"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=1), encoding="utf-8")

    print("wrote", OUT, "topics=", len(out), "questions=", stats["kept"])
    print("skipped:", {k: v for k, v in stats.items() if k != "kept"})
    print("--- coverage ---")
    for t, qs in sorted(out.items(), key=lambda kv: -len(kv[1])):
        print(f"  {len(qs):5d}  {t}")
    print("--- unmapped sources (top) ---")
    for k, v in unmapped.most_common(10):
        print(f"  {v:5d}  {k!r}")


if __name__ == "__main__":
    main()