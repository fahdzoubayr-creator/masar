# -*- coding: utf-8 -*-
"""يبني بنك أسئلة لكل محور فرعي: assets/banks/topics/<مفتاح>.json

القرار: **لا توليد حيّ نهائياً**. محتوى الكويزات كله بنوك مُؤلَّفة ومراجَعة.
لذلك المصدر الأساسي هو assets/banks/manual/<مفتاح>.json (كتابة يدوية)،
والمولَّد لم يعد يُستدعى إلا بت:--harvested (لأغراض أرشيفية/بحثية فقط).

لماذا ملف لكل محور؟ لأن عناوين المحاور ليست فريدة: «ديداكتيك» محور في
«ديداكتيك اللغة العربية» و«ديداكتيك النشاط العلمي» معاً. فبنك واحد باسم
العنوان يخلط مادتين. لذلك المفتاح = المجلد + المحور.

المخرجات:
  assets/banks/topics/<مفتاح>.json — أسئلة ذلك المحور (يدوي أولاً)
  assets/banks/topics_index.json     — فهرس: مفتاح ← {folder, topic, file, count}
  assets/banks/topic_report.txt      — جدول التغطية لكل محاور المانيفست
"""
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import quiz_from_pdf as q  # noqa: E402
import question_quality as qq  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
BANKS = PROJECT / "assets" / "banks"
JOBS = BANKS / "generated_jobs"
GEN = BANKS / "generated"
MANUAL = BANKS / "manual"
TOPICS_DIR = BANKS / "topics"
INDEX = BANKS / "topics_index.json"
REPORT = BANKS / "topic_report.txt"
MANIFEST = PROJECT / "assets" / "review_files" / "manifest.json"

PAGE_TAIL = re.compile(r"\s*[(\[][^)\]]*(?:صفحة|صفحات|ص|صـ)[^)\]]*[)\]]\s*$")
DOC_NOISE = re.compile(
    r"[\s\-–—_]*(?:مهم\s+جدا|مهم\s+جدًّا|\(\s*مهم\s*جدا\s*\)|نسخة\s*\d*"
    r"|\d{4}-\d{2}-\d{2})\s*$"
)
EXP_NOISE = re.compile(r"\s*[\-–—]?\s*مهم\s+جدا|«\s*»")
NAME_FIX = {
    "النمووالتعلم": "النمو والتعلم",
    "الأعلامالتربوية": "الأعلام التربوية",
}


def norm_key(s):
    s = unicodedata.normalize("NFKC", s or "")
    s = re.sub(r"[\u064B-\u0652\u0670\u0640]", "", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    s = re.sub(r"[^\w\u0600-\u06FF]+", " ", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def slug(folder, topic):
    """مفتاح ملف آمن وفريد للمجلد+المحور."""
    raw = f"{folder}__{topic}"
    s = unicodedata.normalize("NFKC", raw)
    s = re.sub(r"[\s\-–—_/\\]+", "-", s.strip())
    s = re.sub(r"[^\w\u0600-\u06FF\-]", "", s)
    s = re.sub(r"-{2,}", "-", s).strip("-")
    return s or "bank"


def clean_doc_name(name):
    n = re.sub(r"\s+", " ", (name or "").replace("_", " ")).strip()
    n = NAME_FIX.get(n, n)
    prev = None
    while prev != n:
        prev = n
        n = DOC_NOISE.sub("", n).strip()
    return re.sub(r"[\s\-–—]{2,}", " ", n).strip(" -–—،,")


def clean_exp(exp):
    e = re.sub(r"\s*[\-–—]\s*مهم\s+جدا\s*", " ", exp or "")
    e = EXP_NOISE.sub("", e)
    for a, b in NAME_FIX.items():
        e = e.replace(a, b)
    e = e.replace("« ", "«").replace(" »", "»")
    return re.sub(r"\s{2,}", " ", e).strip(" ،,")


def valid_q(qo):
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
    return True


def load_index():
    """name => (folder, topic) من المانيفست، بعدة مستويات."""
    doc, top, fold = {}, {}, {}
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for folder, entries in data.items():
        per_topic = Counter()
        for e in entries:
            topic = e.get("topic") or folder
            per_topic[topic] += 1
            name = (e.get("name") or "").strip()
            if name:
                doc.setdefault(norm_key(name), (folder, topic))
            top.setdefault(norm_key(topic), (folder, topic))
        if per_topic:
            fold.setdefault(norm_key(folder), (folder,
                                             per_topic.most_common(1)[0][0]))
    return doc, top, fold


def resolve(name, doc, top, fold):
    """اسم (مصدر أو subject) => (مجلد، محور) أو None."""
    k = norm_key(name)
    if not k:
        return None
    for table in (top, fold, doc):
        if k in table:
            return table[k]
    for table in (top, fold, doc):
        for key, val in table.items():
            if len(k) > 18 and (key.startswith(k[:20]) or k.startswith(key[:20])):
                return val
    return None


def load_manual():
    """الأسئلة المؤلَّفة يدوياً: (مجلد، محور) => [سؤال، ...] بترتيبها."""
    out = defaultdict(list)
    if not MANUAL.is_dir():
        return out
    for f in sorted(MANUAL.glob("*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception as ex:
            print(f"manual: {f.name} غير صالح: {ex}")
            continue
        folder = (d.get("folder") or "").strip()
        topic = (d.get("topic") or "").strip()
        if not folder or not topic:
            print(f"manual: {f.name} بلا folder/topic")
            continue
        for qo in d.get("questions") or []:
            if not valid_q(qo):
                print(f"manual: {f.name} سؤال غير صالح: "
                      f"{str(qo.get('text'))[:50]}")
                continue
            rec = {
                "subject": topic,
                "folder": folder,
                "situation": qq.fix_typos((qo.get("situation") or "").strip()),
                "text": qq.fix_typos((qo.get("text") or "").strip()),
                "options": [qq.fix_typos(q.clean_ar(str(o)))
                            for o in qo["options"]],
                "correctIndex": qo["correctIndex"],
                "explanation": clean_exp(
                    q.clean_ar(str(qo.get("explanation") or ""))),
                "source": (qo.get("source") or topic).strip(),
                "manual": True,
            }
            # بنك يدوي: نكتفي بالفحص البنيوي، لا ببوابة التوليد التقديرية.
            if any(qq.CATCH_ALL.search(o)
                   for i, o in enumerate(rec["options"])
                   if i != rec["correctIndex"]):
                print(f"manual: {f.name} خيار وصفي في: {rec['text'][:40]}")
                continue
            if qq.DEICTIC_ANY.search(rec["text"]):
                print(f"manual: {f.name} إحالة إشارية: {rec['text'][:40]}")
                continue
            out[(folder, topic)].append(rec)
    return out


def iter_source_questions():
    """(سؤال, أصل) من المخرجات المولَّدة — للأرشفة فقط (--harvested)."""
    for f in sorted(JOBS.glob("*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            continue
        for qo in d.get("questions") or []:
            yield qo, "jobs"
    for f in sorted(GEN.glob("*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            continue
        qs = d.get("questions") if isinstance(d, dict) else d
        for qo in qs or []:
            yield qo, "generated"
    for f in sorted(BANKS.glob("rag_*.json")):
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception:
            continue
        qs = d.get("questions") if isinstance(d, dict) else d
        if isinstance(d, dict) and not isinstance(d.get("questions"), list):
            qs = [x for v in d.values() if isinstance(v, list) for x in v]
        for qo in qs or []:
            yield qo, "rag"


def main():
    doc, top, fold = load_index()
    buckets = defaultdict(list)
    seen = defaultdict(set)
    stats = Counter()
    unmapped = Counter()
    routed_by = Counter()
    with_harvested = "--harvested" in sys.argv

    # ===== 1) البنوك المؤلَّفة يدوياً: هي المصدر المعتمد للتطبيق =====
    manual = load_manual()
    for key, qs in manual.items():
        for rec in qs:
            k = norm_key(rec["text"])
            if k in seen[key]:
                print(f"manual: مكرر في {key[1]}: {rec['text'][:40]}")
                continue
            seen[key].add(k)
            buckets[key].append(rec)

    # ===== 2) المخرجات المولَّدة: أرشيف فقط، و--harvested لتجربتها =====
    for qo, origin in iter_source_questions():
        if not valid_q(qo):
            stats["invalid"] += 1
            continue
        src = clean_doc_name(PAGE_TAIL.sub("", (qo.get("source") or "").strip()))
        subj = (qo.get("subject") or "").strip()
        where = resolve(subj, doc, top, fold)
        how = "subject"
        if where is None and src:
            where = resolve(src, doc, top, fold)
            how = "source"
        if where is None:
            unmapped[src or subj or "(بلا مصدر)"] += 1
            stats["unmapped"] += 1
            continue
        folder, topic = where
        routed_by[how] += 1
        rec = {
            "subject": topic,
            "folder": folder,
            "situation": qq.fix_typos(
                q.strip_deictic((qo.get("situation") or "").strip())),
            "text": qq.fix_typos(q.strip_deictic((qo.get("text") or "").strip(),
                                                 src or topic)),
            "options": [qq.fix_typos(q.clean_ar(str(o))) for o in qo["options"]],
            "correctIndex": qo["correctIndex"],
            "explanation": clean_exp(q.clean_ar(str(qo.get("explanation") or ""))),
            "source": src or topic,
        }
        reason = qq.drop_reason(rec, topic)
        if reason:
            stats["qa_" + reason] += 1
            continue
        key = norm_key(rec["text"])
        if key in seen[(folder, topic)]:
            stats["dup"] += 1
            continue
        if not with_harvested:
            # التطبيق لا يعرض إلا ما كُتب ومراجَع يدوياً.
            stats["harvested_skipped"] += 1
            continue
        seen[(folder, topic)].add(key)
        buckets[(folder, topic)].append(rec)
        stats["kept"] += 1

    # تفرّد دلالي داخل المحور الواحد (للمولَّد فقط؛ اليدوي يبقى بترتيبه).
    for key, qs in list(buckets.items()):
        if not with_harvested:
            continue
        kept, kept_toks = [], []
        for rec in qs:
            if rec.get("manual"):
                kept.append(rec)
                kept_toks.append(qq.tokens(rec["text"]))
                continue
            t = qq.tokens(rec["text"])
            if any(qq.jaccard(t, kt) >= 0.5 for kt in kept_toks):
                stats["qa_semantic_dup"] += 1
                stats["kept"] -= 1
                continue
            kept.append(rec)
            kept_toks.append(t)
        buckets[key] = kept

    # ترتيب: اليدوي بترتيبه أولاً، ثم المولَّد (ذات الوضعية، ثم أبجدياً).
    for qs in buckets.values():
        manual_qs = [r for r in qs if r.get("manual")]
        rest = [r for r in qs if not r.get("manual")]
        rest.sort(key=lambda r: (0 if (r.get("situation") or "").strip() else 1,
                                 r["text"]))
        qs[:] = manual_qs + rest

    TOPICS_DIR.mkdir(parents=True, exist_ok=True)
    for old in TOPICS_DIR.glob("*.json"):
        old.unlink()

    # أسماء الملفات قصيرة بحروف لاتينية (t01.json …) لا بالعربية:
    # Flutter يشفّر أسماء الأصول في الويب، فيصير الاسم العربي الطويل
    # متجاوزاً حدّ مسار ويندوز (errno 123) ويفشل البناء. الترتيب ثابت
    # حسب المفتاح، فالاسم ثابت بين كل بناء وآخر.
    entries = []
    for i, ((folder, topic), qs) in enumerate(sorted(buckets.items()), 1):
        name = f"t{i:03d}.json"
        (TOPICS_DIR / name).write_text(
            json.dumps(qs, ensure_ascii=False, indent=1), encoding="utf-8")
        entries.append({
            "key": f"{folder}::{topic}",
            "folder": folder,
            "topic": topic,
            "file": f"topics/{name}",
            "count": len(qs),
        })

    INDEX.write_text(json.dumps({"version": 1, "topics": entries},
                                ensure_ascii=False, indent=1),
                     encoding="utf-8")

    # جدول التغطية: كل محاور المانيفست بما فيها الفارغة.
    all_topics = sorted({(f, t) for f, t in list(top.values()) + list(fold.values())})
    lines = [f"topics_in_index={len(entries)}  questions={sum(e['count'] for e in entries)}",
             f"routed_by={dict(routed_by)}",
             "skipped=" + json.dumps({k: v for k, v in stats.items()
                                      if k != "kept"}, ensure_ascii=False),
             "", "--- coverage (كل محاور المانيفست) ---"]
    have = {(e["folder"], e["topic"]): e["count"] for e in entries}
    for folder, topic in all_topics:
        n = have.get((folder, topic), 0)
        lines.append(f"{n:5d}  {topic}  [{folder}]")
    empty = [f"{t} [{f}]" for f, t in all_topics if have.get((f, t), 0) == 0]
    lines += ["", f"--- بدون بنك ({len(empty)}) ---"] + empty
    lines += ["", "--- مصادر غير موحّدة (top) ---"]
    lines += [f"  {v:5d}  {k!r}" for k, v in unmapped.most_common(12)]
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines[:6]))
    print(f"wrote {INDEX} and {len(entries)} topic files")
    print(f"report: {REPORT}")


if __name__ == "__main__":
    main()