# -*- coding: utf-8 -*-
"""يدمج محاور سطح المكتب (أسئلة المحاور) في بنك الأسئلة الرئيسي.

المصدر:  ~/Desktop/أسئلة المحاور/<المحور الرئيسي>/<المحور الفرعي>.txt
الوجهة:  assets/banks/game_challenges.json   (تظهر محاورها في بطاقة «بنك الأسئلة»)

المحاور الموجودة تُترك كما هي، والناقصة تُضاف بأسئلتها.

المحلّل متسامح مع الصيغ المتعددة الموجودة في الملفات:
  1) «الوضعية/السؤال/ A. B. C. D. E. /الإجابة: د /الشرح»  (صيغة التطبيق)
  2) «السؤال 1:» + «أ) ب) ج) د)» + «الإجابة الصحيحة:»
  3) «**السؤال 1:**» (ماركداون) + «* **أ)** …» + وسم «(الإجابة الصحيحة)»
  4) «سؤال 1:» بلا مسافة + « أ)» + «الإجابة: ب»
  5) «السؤال 1:» + «أ. … (الإجابة الصحيحة)» + «الإجابة: أ»
  6) الفرنسية: «**Question 1 :**» + «* **A)** …» + وسم «(Réponse correcte)»

الاستعمال:
    python tools/merge_desktop_axes.py            # دمج
    python tools/merge_desktop_axes.py --dry      # فحص بلا كتابة
"""
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = Path(__file__).resolve().parent.parent
DESK = Path.home() / "Desktop" / "أسئلة المحاور"
BANK = PROJECT / "assets" / "banks" / "game_challenges.json"

# حروف الخيارات العربية واللاتينية
LETTERS = "أإآاٱبتجدذهوزحطيكلمنسفصقرش"
LATIN = "ABCDEabcde"
ANSWER_MAP = {}
for i, ch in enumerate(LETTERS[:9]):
    ANSWER_MAP[ch] = i
for i, ch in enumerate(LATIN[:5]):
    ANSWER_MAP[ch] = i
for i, ch in enumerate("12345"):
    ANSWER_MAP[ch] = i

ANSWER_RE = re.compile(r"^(?:الإجابة\s*الصحيحة|الإجابة|الجواب|Réponse\s*correcte)\s*[:：]\s*(.+)$", re.I)
EXPLAIN_RE = re.compile(r"^(?:الشرح|التعليل|Explication)\s*[:：]\s*(.+)$", re.I)
SITUATION_RE = re.compile(r"^(?:الوضعية\s*المهنية|الوضعية|السياق)\s*[:：]\s*(.+)$")
QSTART_RE = re.compile(r"^[*_\s]*(?:السؤال|سؤال|Question)\s*\d*\s*[:：*_]*\s*(.*)$", re.I)
OPTION_RE = re.compile(
    r"^[*_\s]*(?:\*\*)?\s*([%s%s1-5])[\)\.\:\-]\s*(.+)$" % (LETTERS, LATIN)
)
MARK_CORRECT = ("الإجابة الصحيحة", "Réponse correcte", "Reponse correcte")
SEP_RE = re.compile(r"^\s*[-=_*]{3,}\s*$")
# مجلدات لا تمثل محاور أسئلة (ملفات PDF فقط)
SKIP_DIRS = {"02 - بنك الاسئلة"}

# تحويل اسم محور فرعي على سطح المكتب -> اسم محور في البنك
# (فارغ: كل محور فرعي يُدمج في محوره الرئيسي)
ALIAS = {}


def clean(s):
    s = s.strip()
    s = re.sub(r"^[*_\s]+", "", s)
    s = re.sub(r"[*_\s]+$", "", s)
    s = re.sub(r"^\*\*\s*", "", s)
    s = re.sub(r"\s*\*\*$", "", s)
    return s.strip()


def strip_mark(text):
    for m in MARK_CORRECT:
        text = text.replace("(" + m + ")", "").replace(m, "")
    return re.sub(r"[()（）]", "", text).strip()


def parse_file(raw):
    """يحوّل نص ملف إلى قائمة أسئلة (dict)."""
    questions = []
    cur = None
    pending = []
    state = "idle"

    def flush():
        nonlocal cur, pending, state
        if cur and cur["options"] and cur["text"]:
            questions.append(cur)
        cur = None
        pending = []
        state = "idle"

    for line in raw.splitlines():
        t = line.strip()
        if not t:
            continue
        if SEP_RE.match(t):
            flush()
            continue
        if t.startswith("#"):
            continue

        m = QSTART_RE.match(t)
        if m and not OPTION_RE.match(t):
            flush()
            rest = clean(m.group(1) or "")
            cur = {"text": "", "options": [], "correctIndex": -1,
                   "explanation": "", "situation": "", "marked": -1}
            state = "q"
            if rest:
                pending.append(rest)
            continue

        if cur is None:
            continue

        m = ANSWER_RE.match(t)
        if m:
            v = clean(m.group(1))
            key = v[0] if v else ""
            if key in ANSWER_MAP:
                cur["correctIndex"] = ANSWER_MAP[key]
            elif v in ANSWER_MAP:
                cur["correctIndex"] = ANSWER_MAP[v]
            continue

        m = EXPLAIN_RE.match(t)
        if m:
            cur["explanation"] = clean(m.group(1))
            continue

        m = SITUATION_RE.match(t)
        if m:
            cur["situation"] = clean(m.group(1))
            continue

        m = OPTION_RE.match(t)
        if m:
            letter = m.group(1)
            body = clean(m.group(2))
            if not cur["options"]:
                if pending:
                    cur["text"] = " ".join(pending).strip()
                    pending = []
            if any(k in body for k in MARK_CORRECT):
                cur["marked"] = len(cur["options"])
                body = strip_mark(body)
            cur["options"].append(body)
            state = "opt"
            continue

        if state == "q":
            # الوضعية قد تأتي في سطر مستقل قبل نص السؤال — تُفصل عندها.
            ms = SITUATION_RE.match(t)
            if ms and not cur["situation"]:
                cur["situation"] = clean(ms.group(1))
            else:
                pending.append(clean(t))
        elif state == "opt":
            if cur["options"]:
                cur["options"][-1] = (cur["options"][-1] + " " + clean(t)).strip()

    flush()
    out = []
    for q in questions:
        if len(q["options"]) < 3:
            continue
        if q["correctIndex"] < 0 and q["marked"] >= 0:
            q["correctIndex"] = q["marked"]
        if q["correctIndex"] < 0 or q["correctIndex"] >= len(q["options"]):
            continue
        text = q["text"]
        # إن بقيت الوضعية مدمجة في نص السؤال (نفس السطر) فافصلها.
        if not q["situation"]:
            ms = SITUATION_RE.match(text)
            if ms:
                q["situation"] = clean(ms.group(1))
                text = text[ms.end():].strip()
        q["text"] = text
        if not text:
            continue
        out.append({
            "subject": "",
            "text": text,
            "options": q["options"],
            "correctIndex": q["correctIndex"],
            "explanation": q["explanation"],
            "source": "أسئلة المحاور",
            **({"situation": q["situation"]} if q["situation"] else {}),
        })
    return out


def norm(s):
    s = re.sub(r"[\u064B-\u0652\u0640]", "", str(s or ""))
    s = (s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا")
          .replace("ٱ", "ا").replace("ى", "ي").replace("ؤ", "و")
          .replace("ئ", "ي").replace("ة", "ه").replace("ـ", ""))
    return re.sub(r"[^\w\u0600-\u06FF]+", "", s).lower()


def _key(q):
    """مفتاح تفرّد السؤال: النص + الخيارات (نصٌ واحد بخيارات مختلفة = سؤالان)."""
    text = q.get("text", "").strip()
    opts = "|".join(q.get("options") or [])
    return norm(text) + "##" + norm(opts)


def match_subject(axis, subjects):
    """يربط محور سطح桌面 بمحلور قائم (أو يقترح محوراً جديداً)."""
    na = norm(axis)
    # 1) تطابق تام
    for s in subjects:
        if norm(s) == na:
            return s, True
    # 2) تضمين: «النشاط العلمي» ⊂ «ديداكتيك النشاط العلمي»
    best, best_len = None, 0
    for s in subjects:
        ns = norm(s)
        if ns and (ns in na or na in ns) and len(ns) > best_len:
            best, best_len = s, len(ns)
    if best:
        return best, True
    return axis, False


def main():
    dry = "--dry" in sys.argv
    if not DESK.is_dir():
        print("مجلد سطح المكتب غير موجود:", DESK)
        return 1
    bank = json.loads(BANK.read_text(encoding="utf-8"))
    key = list(bank.keys())[0]
    existing = bank[key]
    subjects = []
    for q in existing:
        if q.get("subject") not in subjects:
            subjects.append(q.get("subject"))
    have_texts = {_key(q) for q in existing}

    axes = {}
    for d in sorted(DESK.iterdir()):
        if not d.is_dir() or d.name in SKIP_DIRS:
            continue
        files = sorted(p for p in d.glob("*.txt") if not p.name.startswith("_"))
        if files:
            axes[d.name] = files

    added_total = 0
    plan = []
    for axis, files in axes.items():
        target, exists = match_subject(axis, subjects)
        if not exists and target not in subjects:
            subjects.append(target)
        plan.append((axis, target, exists, files))

    print("محاور البنك: %d | محاور سطح المكتب: %d" % (len(subjects), len(axes)))
    for axis, target, exists, files in plan:
        n = 0
        for f in files:
            alias = ALIAS.get(f"{axis}/{f.stem}")
            sub = alias or target
            try:
                raw = f.read_text(encoding="utf-8", errors="replace")
            except Exception:
                continue
            for q in parse_file(raw):
                t = q["text"].strip()
                if not t:
                    continue
                k = _key(q)
                if k in have_texts:
                    continue
                q["subject"] = sub
                existing.append(q)
                have_texts.add(k)
                n += 1
        added_total += n
        mark = "موجود" if exists else "جديد"
        print("   %-38s -> %-34s [%s] +%d" % (axis, target, mark, n))

    print("أسئلة مضافة: %d | المجموع: %d | المحاور: %d"
          % (added_total, len(existing), len(subjects)))
    if dry:
        return 0
    bank[key] = existing
    BANK.write_text(json.dumps(bank, ensure_ascii=False, indent=1), encoding="utf-8")
    print("حُدِّث:", BANK)
    return 0


if __name__ == "__main__":
    sys.exit(main())
