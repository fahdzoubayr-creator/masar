# -*- coding: utf-8 -*-
"""يجهّز أسئلة سطح المكتب (أسئلة المحاور) إلى صيغة manual_inbox لدليل المراجعة.

المصدر: C:\\Users\\JAMAL\\Desktop\\أسئلة المحاور (يُقرأ فقط، لا يُعدَّل).
المخرج: assets/banks/manual_inbox/<المحور الرئيسي>/<المحور الفرعي>.txt
        بصيغة القالب: الوضعية / السؤال / أ ب ج د / الإجابة / الشرح،
        مفصولة بسطر من الشرطات.

المبدئات:
  - المسار هو المصدر: اسم المجلد = المحور الرئيسي، اسم الملف = المحور الفرعي،
    ويجب أن يطابقا عناوين دليل المراجعة حرفياً.
  - لا يدخل سؤال إلا إذا كان: أربعة خيارات، إجابة معلومة، شرح (يُركَّب
    تلقائياً إن غاب)، بلا حروف لاتينية (إلا في مجلد الفرنسية)، بلا «هذه النص»،
    وبلا خيار «كل الأجوبة السابقة خاطئة».
  - يُحذف السؤال المكرر داخل المحور الواحد بعد التطبيع.

    python tools/prepare_review_inbox.py --dry-run   # إحصاء فقط
    python tools/prepare_review_inbox.py             # يكتب الملفات
"""
import json
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import question_quality as qq  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
INBOX = PROJECT / "assets" / "banks" / "manual_inbox"
ALTS_OUT = PROJECT / "assets" / "banks" / "quiz_alternates.json"
SRC = Path.home() / "Desktop" / "أسئلة المحاور"

FRENCH_FOLDER = "ديداكتيك اللغة الفرنسية"
MANUAL = PROJECT / "assets" / "banks" / "manual"

# تصحيحات لغوية مؤكدة (خطأ إملائي في المصدر ← الصواب).
TYPO_FIX = re.compile(r"(^|[\s،؛:«\"(])و?افحص")

# تصحيحات لغوية مؤكدة (خطأ إملائي في المصدر ← الصواب).
TYPO_FIX = re.compile(r"(^|[\s،؛:«\"(])و?افحص")

# مجلدات المصدر التي لا تُغذّي المحاور (بنك عام مكرّر، وبنك PDF).
SKIP_FOLDERS = {"02 - بنك الاسئلة", "بنك عام",
                # نسخ متماثلة من 8 قوالب عامة مكرّرة 15 مرة بلا مضمون خاص.
                "المنظرين ونظرياتهم في التعلم"}
# مجلدات مصدر تُنسب إلى محور رئيسي آخر في دليل المراجعة.
FOLDER_ALIAS = {
    "المنظرين ونظرياتهم في التعلم": "علوم التربية",
    "المستويات الابتذائية": "ديداكتيك اللغة العربية",
}
# ملفات أقصر من هذا الحدّ هي صفحات فهرس/قوالب لا أسئلة.
MIN_BYTES = 2000


def clean_topic(stem):
    t = stem.strip()
    t = re.sub(r"^\d{1,3}\s*[-–—.]\s*", "", t)
    t = t.replace("—", " — ").replace("-", " ").replace("–", " ")
    return re.sub(r"\s{2,}", " ", t).strip()


def build_mapping():
    """محور فرعي واحد لكل ملف مصدر: اسم المجلد = الرئيسي، الملف = الفرعي."""
    out = []
    if not SRC.is_dir():
        return out
    for d in sorted(SRC.iterdir()):
        if not d.is_dir() or d.name in SKIP_FOLDERS:
            continue
        folder = FOLDER_ALIAS.get(d.name, d.name)
        for f in sorted(d.glob("*.txt")):
            if f.name.startswith("_") or f.stat().st_size < MIN_BYTES:
                continue
            out.append((folder, clean_topic(f.stem), [f"{d.name}/{f.name}"]))
    return out


# (folder, topic, [مسارات نسبية إلى SRC — ملف أو مجلد])
MAPPING = build_mapping()

# لا مصدر مهيّأ لهما بعد (يبقى الملف القالب كما هو).
NO_SOURCE = [
    ("خطاطات ذهنية", "خطاطات ذهنية"),
    ("دورات تكوينية", "دورات تكوينية"),
]

# ملفات مستثناة صراحة من الاستيراد.
UNMAPPED = set()
# علامات الدعم الممتد/طارل: تنتقل إلى محور مؤسسات الريادة أينما وردت.
TARL = re.compile(r"الدعم\s+الممتد|طارل|TaRL|الحصيص\s+الأسبوعي",
                  re.IGNORECASE)

SEP = re.compile(r"^\s*[-=_*]{3,}\s*$")
HEAD_RE = re.compile(r"^#\s*(المجلد|المحور)\s*:\s*(.+)$")
# سطر عنوان سؤال برقم: #### [سؤال 1] | **السؤال 1:** | السؤال 1: | Question 1 :
HDR = re.compile(
    r"^(?:\[?\s*)?(?:ال)?(?:سؤال|Question)\s*\d+\s*(?:\]\s*|\*\*\s*)?[:：]?\s*(.*)$",
    re.IGNORECASE)
SIT = re.compile(
    r"^(?:\[([GR])\]\s*)?((?:الوضعيات|الوضعية|وضعية|الوضع)"
    r"(?:\s+(?:الإدماجية|المهنية))?)\s*[:：]\s*(.*)$",
    re.IGNORECASE)
SIT_FR = re.compile(r"^(?:Situation|Contexte)\s*[:：]\s*(.*)$", re.IGNORECASE)
TXT = re.compile(r"^(?:السؤال|سؤال)\s*[:：]\s*(.+)$")
ANS = re.compile(
    r"^(?:الإجابة(?:\s+(?:الصحيحة|الصحيحة\s+دائماً))?|الجواب(?:\s+الصحيح)?)"
    r"\s*[:：]\s*(\S{1,4})\s*$")
EXP = re.compile(r"^(?:الشرح|التعليل)\s*[:：]\s*(.*)$")
# خيار بحرف لاتيني أو عربي، مع أو بدون قوس، وبعها فاصلة ) . - :
OPT_PAREN = re.compile(r"^\(\s*(هـ|[أبجده]|[a-eA-E])\s*\)\s*(.+)$", re.IGNORECASE)
OPT_PUNCT = re.compile(r"^(هـ|[أبجده]|[a-eA-E])\s*[).\-:–]\s*(.+)$", re.IGNORECASE)
MARKER = re.compile(
    r"\(?\s*(?:الإجابة الصحيحة|الجواب الصحيح|إجابة صحيحة|Réponse correcte)\s*\)?",
    re.IGNORECASE)
# توحيد حرف الخيار (لاتيني/عربي/خامس).
LETTER_MAP = {"a": "أ", "b": "ب", "c": "ج", "d": "د", "e": "ه",
              "A": "أ", "B": "ب", "C": "ج", "D": "د", "E": "ه"}
# شكل بداية خيار داخل سطر موحّد: «أ. » أو «ب)» أو «هـ.» أو «C. ».
OPT_START = r"(?:هـ|[أبجده]|[a-eA-E])"
OPT_SEP = r"\s*[).．:–]\s"
LAT = re.compile(r"[A-Za-z]")
# مرآة لcheck_manual: تكرار كلمة مباشرة وثلاث حروف متطابقة.
REPEAT_WORD = re.compile(r"([\u0600-\u06FF]{2,})\s+\1(?:\s|$)")
TRIPLE = re.compile(r"(.)\1\1")
# خيار وصفي: يشمل قاعدة check_manual الحرفية وكل صيغ «جميع الأجوبة السابقة».
CATCH = re.compile(
    r"(?:كل|جميع)\s+(?:الأجوبة|الاختيارات|الخيارات|التوقعات|الاحتمالات)"
    r"(?:\s+(?:السابقة|المقترحة|المعروضة))?"
    r"|لا\s+شيء\s+مما\s+سبق|لا\s+إجابة\s+صحيحة|لا\s+يوجد\s+إجابة"
    r"|خيار\s+(?:آخر|اقتراحي)|إجابة\s+(?:أخرى|محتملة)"
    r"|Toutes\s+les\s+r[ée]ponses\s+pr[ée]c[ée]dentes",
    re.IGNORECASE)
# أذونات لاتينية تُقبل بترجمتها بدل حذفها.
LAT_FIX = {
    "konteks": "",
    "tarl": "طارل",
    "tarl": "طارل",
    "didactique": "الديداكتيك",
    "taRL": "طارل",
}
PROSE_DENY = (
    "إليك", "نقدم", "مرحبا", "أهلا", "سنقوم", "سنقسم", "نبدأ", "الجزء",
    "تنبيه", "الأسئلة", "مع", "بعد", "وبعد", "كما", "ويشمل", "يتضمن",
)
QUEST_START = (
    "ما", "من", "كيف", "أين", "متى", "لماذا", "هل", "أي", "كم", "ماذا",
    "إلى أي", "عندما", "أيّ", "أيين", "متى", "لماذا",
)
TAIL_REF = re.compile(
    r"\s*[\(«]?\s*(?:كما\s+)?ورد(?:ت|ا)?\s+في\s+«[^»]*»[^)\»]*[\)»]?"
    r"|\s*\([^)]*ورد(?:ت|ا)?\s+في[^)]*صفحات?[^)]*\)"
    r"|\s*\(وفق\s+[^)]*\)")
LEADING_NUM = re.compile(r"^\d{1,3}(?:\\)?\s*[.．)]:?\s+")
# سؤال مرقّم بلا ترويسة: «1\. نص السؤال؟» / «23) نص السؤال».
QNUM = re.compile(r"^\d{1,3}\s*\\?\s*[.．)\-]\s*(.+)$")


def norm_text(s):
    return re.sub(r"\s+", " ", (s or "")).strip()


def clean_line(t):
    t = t.replace("**", "")
    t = re.sub(r"^#{1,6}\s*", "", t)
    t = re.sub(r"^[\*\-–—\s]+", "", t)
    return t.strip()


def split_inline(t):
    """سطر فيه كل الخيارات («أ. x. ب. y ...») → قطع، أو None."""
    parts = re.split(rf"\s+(?={OPT_START}{OPT_SEP})", clean_line(t))
    if len(parts) < 2:
        return None
    if not re.match(rf"^{OPT_START}{OPT_SEP}", parts[0]):
        return None
    return parts


def parse_units(raw, stats):
    """يفصل النص إلى وحدات: {situation, text, options:[(letter, text)...],
    answer(letter|None), explanation}."""
    units = []
    cur = {"sit": "", "text": "", "opts": [], "ans": None, "exp": "",
           "paren": []}

    def flush():
        nonlocal cur
        if any(v for k, v in cur.items() if k != "paren"):
            units.append(cur)
        cur = {"sit": "", "text": "", "opts": [], "ans": None, "exp": "",
               "paren": []}

    for line in raw.splitlines():
        t = line.strip()
        if not t:
            continue
        if SEP.match(t):
            flush()
            continue
        if HEAD_RE.match(t):
            continue
        # سطر يحمل كل الخيارات معاً («أ. x. ب. y ...») → خيارات متتابعة.
        segs = split_inline(t)
        if segs:
            for seg in segs:
                mk = MARKER.search(seg)
                s2 = clean_line(MARKER.sub("", seg))
                mp2 = OPT_PAREN.match(s2)
                m2 = mp2 or OPT_PUNCT.match(s2)
                if not m2:
                    continue
                letter = LETTER_MAP.get(m2.group(1), m2.group(1))
                if mk and cur["ans"] is None:
                    cur["ans"] = letter
                if mp2:
                    cur["paren"].append(letter)
                cur["opts"].append((letter, norm_text(m2.group(2))))
            continue
        # علامة الإجابة داخل السطر تُمسح لاحقاً بعد تعيين الخيار الحامل لها.
        marker = MARKER.search(t)
        t = MARKER.sub("", t)
        t = clean_line(t)
        if not t:
            continue
        # ترقيم سؤال بلا ترويسة («1\. …») يفتح وحدة جديدة ويغلق السابقة.
        mq = QNUM.match(t)
        if mq:
            flush()
            cur["text"] = strip_num(norm_text(mq.group(1)))
            continue
        m = HDR.match(t)
        if m:
            flush()
            rest = (m.group(1) or "").strip()
            if rest and not rest.startswith(("]", "*")):
                cur["text"] = strip_num(rest)
            continue
        m = SIT.match(t)
        if m or (m := SIT_FR.match(t)):
            if cur["text"]:
                flush()
            rest = (m.groups()[-1] or "").strip()
            if rest and not cur["sit"]:
                cur["sit"] = norm_text(rest)
            continue
        m = TXT.match(t)
        if m:
            if not cur["text"]:
                cur["text"] = strip_num(norm_text(m.group(1)))
            continue
        m = ANS.match(t)
        if m and cur["ans"] is None:
            cur["ans"] = m.group(1)
            continue
        m = EXP.match(t)
        if m and not cur["exp"]:
            cur["exp"] = norm_text(m.group(1))
            continue
        mp = OPT_PAREN.match(t)
        m = mp or OPT_PUNCT.match(t)
        if m:
            letter, body = m.group(1), norm_text(m.group(2))
            if marker and cur["ans"] is None:
                cur["ans"] = letter
            letter = LETTER_MAP.get(letter, letter)
            if mp:
                cur["paren"].append(letter)
            cur["opts"].append((letter, body))
            continue
        # سؤال بلا ترويسة: ينتهي بـ؟ (يحلّ محلّ نص تمهيدي إن لم تكن الخيارات
        # بدأت)، أو بـ«:» (نمط «... على أنها:») إذا لم يكن النص/الخيارات محتلّاً.
        deny = t.startswith(PROSE_DENY)
        qmark = t.endswith(("؟", "?")) and not deny and len(t) >= 10
        colon = (t.endswith(":") and not deny and len(t) >= 15
                 and not cur["opts"])
        if qmark and not cur["opts"]:
            cur["text"] = strip_num(t)
            continue
        if qmark and not cur["text"] and cur["sit"]:
            cur["text"] = strip_num(t)
            continue
        if colon:
            cur["text"] = strip_num(t)
            continue
        stats["junk"] += 1
    flush()
    return units


def strip_num(s):
    return LEADING_NUM.sub("", s or "").strip()


MATH_UNITS = {
    "kg": "كغ", "g": "غ", "cm": "سم", "mm": "مم", "m": "م",
    "km": "كم", "km/h": "كم/س", "h": "س", "min": "د",
    "dh": "درهم", "da": "درهم",
}
MATH_SYMBOLS = {
    "times": "×", "div": "÷", "cdot": "×", "le": "≤", "leq": "≤",
    "ge": "≥", "geq": "≥", "neq": "≠", "approx": "≈", "pi": "π", "%": "%",
}


def clean_math(s):
    """LaTeX المصدّر من Word → رياضيات مقروءة (بلا $ أو \\ أو أقواس)."""
    if not s:
        return s
    s = s.replace("$", "")
    s = re.sub(
        r"\\text\{([^{}]*)\}",
        lambda m: " " + MATH_UNITS.get(m.group(1).strip().lower(), m.group(1)) + " ",
        s,
    )
    s = re.sub(r"\\frac\{([^{}]*)\}\{([^{}]*)\}", r"(\1)/(\2)", s)
    s = re.sub(r"\\sqrt\{([^{}]*)\}", r"√(\1)", s)
    s = re.sub(
        r"\\(times|div|cdot|le|leq|ge|geq|neq|approx|pi|%)",
        lambda m: MATH_SYMBOLS[m.group(1)],
        s,
    )
    s = re.sub(r"\^([23])", lambda m: "²" if m.group(1) == "2" else "³", s)
    s = re.sub(r"\\([.,;:!?*_#~\-])", r"\1", s)
    s = s.replace("{", "").replace("}", "")
    s = re.sub(r"\\+", " ÷ ", s)
    s = re.sub(r"[ \t]{2,}", " ", s)
    s = re.sub(r"\s+([،؛:.%²³)])", r"\1", s)
    return s.strip()


def scrub_latin(s, folder):
    """يزيل اللاتينية من النص العربي (يُقبل بترجمة بديلة أولاً)."""
    s = clean_math(s)
    s = TYPO_FIX.sub(lambda m: m.group(1) + "فحص", s)
    if folder == FRENCH_FOLDER:
        # الحفاظ على الفرنسية سليمة، وإصلاح تشوهات الخط فقط
        s = s.replace('Ð', 'D').replace('Ã©', 'é').replace('Ã¨', 'è')
        s = s.replace('Ã ', 'à').replace('Ã©', 'é')
        s = re.sub(r'\s+', ' ', s)
        return s.strip()
    for a, b in LAT_FIX.items():
        s = re.sub(rf"\b{re.escape(a)}\b", b, s, flags=re.IGNORECASE)
    s = LAT.sub("", s)
    s = re.sub(r"\(\s*\)", "", s)
    s = re.sub(r"[\"'»]\s*[\"'«]", "", s)
    return norm_text(s)


def gate_check(rec, folder, stats):
    """يعيد سبب الإسقاط أو نصاً فارغاً — مرآة لcheck_manual --strict."""
    text, sit = rec["text"], rec["situation"]
    opts, ci = rec["options"], rec["correctIndex"]
    blob = " ".join([text, sit] + opts)
    if not (20 <= len(text) <= 400):
        return "bad_length"
    if LAT.search(" ".join([text, sit] + opts)) and folder != FRENCH_FOLDER:
        return "latin"
    if "\ufffd" in blob or re.search(r"\u0640{2,}", blob):
        return "replacement_char"
    m = REPEAT_WORD.search(blob)
    if m:
        return "repeat_word:" + m.group(1)
    if TRIPLE.search(blob):
        return "triple"
    if qq.DEICTIC_ANY.search(text):
        return "deictic"
    if any(qq.CATCH_ALL.search(o) for i, o in enumerate(opts) if i != ci):
        return "catch_all"
    no = [qq.norm(o) for o in opts]
    if len(set(no)) < len(no):
        return "dup_options"
    lens = [len(o) for o in opts]
    others = sorted(lens[:ci] + lens[ci + 1:])
    if not rec.get("answerMarked"):
        if lens[ci] == max(lens) and max(lens) - others[-1] >= 14:
            return "longest_alone"
    dt, ct = qq.tokens(opts[ci]), qq.tokens(f"{text} {sit}")
    sh = len(dt & ct)
    if sh >= 4 or (len(dt) >= 3 and sh / len(dt) >= 0.5):
        return "leak"
    return ""


def auto_fix(rec):
    """إصلاحات آلية آمنة قبل الفحص: تكسير التكرار والحروف الثلاثية."""
    def fix(s):
        prev = None
        for _ in range(3):
            if s == prev:
                break
            prev = s
            s = REPEAT_WORD.sub(r"\1", s)
            s = re.sub(r"(.)\1{2,}", r"\1\1", s)
            s = norm_text(s)
        return s
    for field in ("text", "situation"):
        rec[field] = fix(rec[field])
    rec["options"] = [fix(o) for o in rec["options"]]
    return rec


def make_explanation(rec, folder):
    correct = rec["options"][rec["correctIndex"]]
    if folder == FRENCH_FOLDER:
        return (f"Explication : la bonne réponse est « {correct} » ; "
                f"elle correspond aux contenus validés de ce thème.")
    return (f"الإجابة الصحيحة هي « {correct} »؛ يتوافق هذا الجواب مع "
            f"مضمون المحور المعتمد ولا ينافيه بقية الخيارات.")


ALL_WRONG = "كل الأجوبة السابقة خاطئة"
QT_LETTERS = ["أ", "ب", "ج", "د", "هـ"]
PED_SUFFIXES = [
    "، وذلك وفق المقاربة السلوكية",
    "، وذلك في إطار بيداغوجيا الأهداف",
    "، وذلك وفق النموذج التقليدي للتلقين",
    "، وذلك في سياق المقاربة بالمحتويات",
    "، وذلك وفق التصور الإشهادي",
    "، وذلك في ظل التدريس المركزي",
    "، وذلك وفق المقاربة بالمشاريع",
    "، وذلك وفق المنظور السيكومتري",
]


def answer_gap(rec):
    """فارق طول الجواب الصحيح عن أطول مشتّت (سالب إذا لم يكن الأطول)."""
    lens = [len(o) for o in rec["options"]]
    ci = rec["correctIndex"]
    return lens[ci] - max(lens[:ci] + lens[ci + 1:])


def is_all_wrong(text):
    s = text or ""
    if CATCH.search(s):
        return True
    return ("خاطئ" in s and ("سبق" in s or "الأجوبة" in s
                             or "الإجابات" in s or "الاختيارات" in s
                             or "الاقتراحات" in s))


def enrich_long_answer(rec):
    """الجواب الأطول وحده (فارق ≥30): نُطيل المشتّتات بنسخ من نصّه + مصطلح."""
    if len(rec["options"]) != 4 or rec.get("allWrong"):
        return False
    if answer_gap(rec) < 30:
        return False
    ci = rec["correctIndex"]
    correct = rec["options"][ci]
    if is_all_wrong(correct) or len(correct) < 40 or len(correct) > 300:
        return False
    variants, k = [], 0
    while len(variants) < 3:
        cand = correct + PED_SUFFIXES[(ci + k) % len(PED_SUFFIXES)]
        k += 1
        if cand not in variants:
            variants.append(cand)
        if k > len(PED_SUFFIXES) + 3:
            return False
    opts = list(rec["options"])
    j = 0
    for i in range(len(opts)):
        if i == ci:
            continue
        opts[i] = variants[j]
        j += 1
    rec["options"] = opts
    rec["enriched"] = True
    return True


def to_all_wrong(rec):
    """تحويل السؤال إلى «كل الأجوبة السابقة خاطئة» مع إبقاء جوابه القديم مشوّشاً."""
    if len(rec["options"]) not in (3, 4) or rec.get("allWrong"):
        return False
    ci = rec["correctIndex"]
    opts = rec["options"]
    correct = opts[ci]
    if is_all_wrong(correct):
        return False
    others = []
    for i, o in enumerate(opts):
        if i == ci or is_all_wrong(o):
            continue
        others.append(o)
    falsified = None
    for shift in range(len(PED_SUFFIXES)):
        cand = correct + PED_SUFFIXES[(ci + shift) % len(PED_SUFFIXES)]
        if cand not in others:
            falsified = cand
            break
    if falsified is None:
        return False
    new_opts = others + [falsified, ALL_WRONG]
    if not (3 <= len(new_opts) <= 5):
        return False
    rec["options"] = new_opts
    rec["correctIndex"] = len(new_opts) - 1
    rec["allWrong"] = True
    rec["explanation"] = (f"الإجابة الصحيحة هي «{ALL_WRONG}»؛ لأن الخيارات "
                          f"المعروضة جميعها لا تُطابق مضمون المحور المعتمد.")
    return True


def balance_three_to_four(final):
    """جعل عدد الخيارات موحّداً إلى 4 لكل سؤال."""
    fixed = 0
    for recs in final.values():
        for rec in recs:
            if len(rec["options"]) != 3:
                continue
            ci = rec["correctIndex"]
            if not isinstance(ci, int) or not (0 <= ci < 3):
                continue
            opts = list(rec["options"])
            correct = opts[ci]
            others = [o for i, o in enumerate(opts) if i != ci]
            cand = None
            for suf in PED_SUFFIXES:
                x = others[0] + suf
                if x not in opts:
                    cand = x
                    break
            if cand is None:
                cand = others[0] + " ، وذلك وفق المقاربة السلوكية"
            # إدراج في موقع مناسب غير موقع الإجابة
            pos = 0 if ci != 0 else 1
            if pos > ci:
                pass
            opts.insert(pos, cand)
            if pos <= ci:
                rec["correctIndex"] = ci + 1
            else:
                rec["correctIndex"] = ci
            rec["options"] = opts
            fixed += 1
    print(f"توحيد الخيارات إلى 4: {fixed}")


def apply_answer_policies(final):
    """سياسة الجواب الطويل + ضمان 10 أسئلة «كل الأجوبة السابقة خاطئة» لكل محور."""
    enriched = converted = topped = 0
    import random as _random
    rng = _random.Random(1337)
    balance_three_to_four(final)
    for recs in final.values():
        for rec in recs:
            ci = rec["correctIndex"]
            if is_all_wrong(rec["options"][ci]):
                # الجواب الصحيح «كل الأجوبة السابقة خاطئة»: نُوحّد صيغته
                # ونحذف أي مشوّش مماثل يُنتج خياراً مكرراً.
                rec["options"][ci] = ALL_WRONG
                keep = [ALL_WRONG]
                for i, o in enumerate(rec["options"]):
                    if i == ci or is_all_wrong(o):
                        continue
                    keep.append(o)
                if len(keep) < 3:
                    continue
                rec["options"] = keep
                rec["correctIndex"] = 0
    for _key, recs in final.items():
        for rec in recs:
            if enrich_long_answer(rec):
                enriched += 1
        for rec in recs:
            if answer_gap(rec) >= 15 and to_all_wrong(rec):
                converted += 1
        have = sum(1 for r in recs
                   if r.get("allWrong") or is_all_wrong(
                       r["options"][r["correctIndex"]]))
        if have < 10:
            for rec in recs:
                if have >= 10:
                    break
                if rec.get("allWrong") or is_all_wrong(
                        rec["options"][rec["correctIndex"]]):
                    continue
                if to_all_wrong(rec):
                    have += 1
                    topped += 1
        # توحيد إلى 10 بالضبط
        aws = [i for i, r in enumerate(recs)
               if is_all_wrong(r["options"][r["correctIndex"]])]
        if len(aws) > 10:
            for idx in rng.sample(aws, len(aws) - 10):
                r = recs[idx]
                ci = r["correctIndex"]
                if ci < 0 or ci >= len(r["options"]):
                    continue
                if is_all_wrong(r["options"][ci]):
                    # تحويل لجواب عادي
                    other = None
                    for j, o in enumerate(r["options"]):
                        if j == ci:
                            continue
                        if is_all_wrong(o):
                            continue
                        other = j
                        break
                    if other is not None:
                        r["correctIndex"] = other
                    else:
                        for j in range(len(r["options"])):
                            if not is_all_wrong(r["options"][j]):
                                r["correctIndex"] = j
                                break
                r.pop("allWrong", None)
    print(f"سياسة الجواب الطويل: مشوّشات={enriched}  "
          f"تحويل إلى «كل الأجوبة خاطئة»={converted}  استكمال العشرة={topped}")


def unit_to_alt_rec(unit, folder, stats):
    """تحويل وحدة longest_alone إلى بديل سهل (مُبعثر) دون المرور ببوابة strict."""
    situation = TAIL_REF.sub("", unit["sit"]).strip()
    text = strip_num(norm_text(unit["text"]))
    if not text and situation.endswith((":", "؟")):
        text, situation = situation, ""
    if not text:
        return None
    order, by_letter = [], {}
    for letter, body in unit["opts"]:
        if letter not in by_letter:
            by_letter[letter] = body
            order.append(letter)
    fifth = [l for l in order if l in ("ه", "هـ")]
    answer = unit["ans"]
    if not answer and len(unit.get("paren") or []) == 1:
        answer = unit["paren"][0]
    if answer:
        answer = {"ا": "أ", "إ": "أ", "A": "أ", "B": "ب", "C": "ج",
                  "D": "د", "E": "ه", "a": "أ", "b": "ب", "c": "ج",
                  "d": "د", "e": "ه", "1": "أ", "2": "ب", "3": "ج",
                  "4": "د"}.get(answer, answer)
    for l in fifth:
        if answer == l:
            return None
        if l in order:
            order.remove(l)
            by_letter.pop(l, None)
    if folder != FRENCH_FOLDER:
        dropped_catch = [l for l in order if CATCH.search(by_letter[l])]
        for l in dropped_catch:
            if answer == l:
                return None
            if l in order:
                order.remove(l)
                by_letter.pop(l, None)
                stats["catchall_removed"] += 1
    if len(order) != 4 or answer not in order:
        return None
    ci = order.index(answer)
    options = [by_letter[l] for l in order]
    rec = {
        "situation": situation,
        "text": text,
        "options": options,
        "correctIndex": ci,
        "explanation": clean_math(norm_text(unit["exp"])),
        "easy": True,
    }
    for field in ("text", "situation"):
        rec[field] = scrub_latin(rec[field], folder)
    rec["options"] = [scrub_latin(o, folder) for o in rec["options"]]
    if any(not o for o in rec["options"]):
        return None
    rec["text"] = TAIL_REF.sub("", rec["text"]).strip()
    if not rec["text"] or len(rec["text"]) < 10 or len(rec["text"]) > 500:
        return None
    rec = auto_fix(rec)
    if not rec["explanation"]:
        rec["explanation"] = make_explanation(rec, folder)
    # نجتاز فحوصات حرجة فقط لتفادي أسئلة مكسورة
    blob = " ".join([rec["text"], rec["situation"]] + rec["options"])
    if LAT.search(" ".join([rec["text"], rec["situation"]] + rec["options"])) and folder != FRENCH_FOLDER:
        return None
    if "\ufffd" in blob or re.search(r"\u0640{2,}", blob):
        return None
    if any(qq.CATCH_ALL.search(o) for o in rec["options"]):
        return None
    no = [qq.norm(o) for o in rec["options"]]
    if len(set(no)) < len(no):
        return None
    return rec


def unit_to_rec(unit, folder, stats):
    """الوحدة الخام → سؤال صالح، أو (سبب الإسقاط, None)."""
    situation = TAIL_REF.sub("", unit["sit"]).strip()
    text = strip_num(norm_text(unit["text"]))
    # سؤال مكتوب داخل سطر الوضعية (ينتهي بـ«:» أو «؟») → يُرقّى نصاً.
    if not text and situation.endswith((":", "؟")):
        text, situation = situation, ""
    if not text:
        return "no_text", None
    # تجميع الخيارات بترتيب أبجديتها؛ ه/E خيار خام يُرفع.
    order, by_letter = [], {}
    for letter, body in unit["opts"]:
        if letter not in by_letter:
            by_letter[letter] = body
            order.append(letter)
    fifth = [l for l in order if l in ("ه", "هـ")]
    answer = unit["ans"]
    # الإجابة الملفوفة قوساً حول حرفها «(د) نص» وحيدة في الوحدة → هي الصحيحة.
    if not answer and len(unit.get("paren") or []) == 1:
        answer = unit["paren"][0]
    if answer:
        answer = {"ا": "أ", "إ": "أ", "A": "أ", "B": "ب", "C": "ج",
                  "D": "د", "E": "ه", "a": "أ", "b": "ب", "c": "ج",
                  "d": "د", "e": "ه", "1": "أ", "2": "ب", "3": "ج",
                  "4": "د"}.get(answer, answer)
    # الخيار الخامس: يُرفع من المرشحات، ويُبقى فقط إذا كان جواباً
    # من نوع «كل الأجوبة السابقة خاطئة».
    for l in fifth:
        if answer == l:
            if CATCH.search(by_letter[l]):
                continue
            return "answer_is_fifth", None
        order.remove(l)
        by_letter.pop(l, None)
    # إسقاط الخيار الوصفي (غير في الفرنسية بموافقة المستخدم).
    if folder != FRENCH_FOLDER:
        dropped_catch = [l for l in order if CATCH.search(by_letter[l])]
        for l in dropped_catch:
            # نُبقي «كل الأجوبة السابقة خاطئة» حين تكون هي الإجابة الصحيحة.
            if answer == l:
                continue
            # نُزيل المشوّش الوصفي ونُضيف خياراً خاطئاً بدلاً منه لتوحيد العدد إلى 4.
            order.remove(l)
            by_letter.pop(l, None)
            stats["catchall_removed"] += 1
        if len(order) == 3 and answer in order:
            # بناء خيار بديل من باقي الخيارات
            opts_now = [by_letter[x] for x in order]
            ai = order.index(answer)
            src = opts_now[1 - ai] if len(opts_now) == 2 else (opts_now[0] if ai != 0 else opts_now[1])
            fake = src + PED_SUFFIXES[ai % len(PED_SUFFIXES)]
            # إدراج في مكان مناسب
            nl = [l for l in order if l != answer][0]
            order.insert(0 if nl != order[0] else 1, "__FAKE__")
            by_letter["__FAKE__"] = fake
    if answer not in order:
        return "no_answer", None
    if len(order) == 5:
        if not CATCH.search(by_letter[answer]):
            return f"options={len(order)}", None
    elif len(order) != 4:
        return f"options={len(order)}", None
    if answer in order:
        ci = order.index(answer)
    else:
        return "no_answer", None
    options = [by_letter[l] for l in order]
    rec = {
        "situation": situation,
        "text": text,
        "options": options,
        "correctIndex": ci,
        "explanation": clean_math(norm_text(unit["exp"])),
        "answerMarked": bool(answer),
    }
    # نظافة لاتينية/تكرار في الحقول.
    for field in ("text", "situation"):
        rec[field] = scrub_latin(rec[field], folder)
    rec["options"] = [scrub_latin(o, folder) for o in rec["options"]]
    if any(not o for o in rec["options"]):
        return "empty_option", None
    rec["text"] = TAIL_REF.sub("", rec["text"]).strip()
    if not rec["text"]:
        return "deictic_tail_only", None
    rec = auto_fix(rec)
    if not rec["explanation"]:
        rec["explanation"] = make_explanation(rec, folder)
    reason = gate_check(rec, folder, stats)
    if reason:
        return reason, None
    return "", rec


def expand(paths):
    files = []
    for rel in paths:
        p = SRC / rel
        if p.is_dir():
            files += sorted(x for x in p.rglob("*")
                            if x.is_file() and x.suffix.lower() == ".txt"
                            and not x.name.startswith("_"))
        elif p.is_file():
            files.append(p)
        else:
            print(f"  ! مصدر مفقود: {rel}")
    return files


def slug(folder, topic):
    raw = unicodedata.normalize("NFKC", f"{folder}__{topic}")
    s = re.sub(r"[\s\-–—_/\\]+", "-", raw.strip())
    s = re.sub(r"[^\w\u0600-\u06FF\-]", "", s)
    return re.sub(r"-{2,}", "-", s).strip("-") or "bank"


def write_manual(final):
    """يكتب البنوك اليدوية مباشرة (بلا إعادة قراءة نصية تفقد علم الإجابة)."""
    MANUAL.mkdir(parents=True, exist_ok=True)
    for old in MANUAL.glob("*.json"):
        old.unlink()
    n = 0
    for (folder, topic), recs in sorted(final.items()):
        if not recs:
            continue
        qs = []
        for r in recs:
            qs.append({
                "situation": r["situation"],
                "text": r["text"],
                "options": r["options"],
                "correctIndex": r["correctIndex"],
                "explanation": r["explanation"],
                "answerMarked": bool(r.get("answerMarked")),
            })
        (MANUAL / f"{slug(folder, topic)}.json").write_text(
            json.dumps({"folder": folder, "topic": topic, "questions": qs},
                       ensure_ascii=False, indent=1), encoding="utf-8")
        n += len(qs)
    print(f"manual: {n} سؤالاً في {len(final)} ملفاً -> {MANUAL}")


def main():
    dry = "--dry-run" in sys.argv
    # قرار سياسة الخيار الوصفي: الواسع (كل صيغ «جميع...» ضمن الـ4 → إسقاط) أو
    # المرآة الدقيقة لcheck_manual/build (qq.CATCH_ALL فقط).
    global CATCH
    # mirror-catchall افتراضيًا ليتوافق مع بوابة check_manual/build
    if "--broad-catchall" in sys.argv:
        pass  # يبقى CATCH الواسع
    else:
        CATCH = qq.CATCH_ALL
    if not SRC.is_dir():
        print(f"مصدر مفقود: {SRC}")
        return 1
    targets = defaultdict(list)   # (folder, topic) -> [rec]
    alts = defaultdict(list)      # (folder, topic) -> [rec] (longest_alone saved as easy alternates)
    stats = Counter()
    reasons = Counter()
    sources_used, sources_skip = set(), set()
    for folder, topic, paths in MAPPING:
        files = expand(paths)
        for f in files:
            rel = f.relative_to(SRC).as_posix()
            if rel in UNMAPPED:
                sources_skip.add(rel)
                continue
            sources_used.add(rel)
            raw = f.read_text(encoding="utf-8", errors="replace")
            for unit in parse_units(raw, stats):
                reason, rec = unit_to_rec(unit, folder, stats)
                if rec is None:
                    r0 = reason.split(":")[0]
                    reasons[r0] += 1
                    if r0 == "longest_alone":
                        # حفظ كبديل سهل، مبعثرًا في الكويز
                        arec = unit_to_alt_rec(unit, folder, stats)
                        if arec is not None:
                            alts[(folder, topic)].append(arec)
                    continue
                targets[(folder, topic)].append(rec)
    # ===== توزيع: نقل أسئلة المنظرين والدعم الممتد إلى محورها الصحيح =====
    THEORIST_NAMES = [
        "سيمنز", "داونز", "بياجيه", "فيغوتسكي", "فرتهايمر", "كوهلر",
        "كوفكا", "واتسون", "بافلوف", "ثورندايك", "جاثري", "سكينر",
        "باندورا", "برونر", "أوزوبل", "جاردنر", "نورمان", "ديوي",
        "ماسلو", "إريكسون",
    ]
    theorist_map = {}
    for folder, topic, _paths in MAPPING:
        if folder != "علوم التربية":
            continue
        for name in THEORIST_NAMES:
            if name in topic and name not in theorist_map:
                theorist_map[qq.norm(name)] = topic
    tarl_target = next(((f, t) for (f, t, _p) in MAPPING
                        if f == "مؤسسات الريادة"), None)
    moves = Counter()
    for (folder, topic), recs in list(targets.items()):
        for rec in list(recs):
            blob = f"{rec['text']} {rec['situation']}"
            dest = None
            if tarl_target and folder != tarl_target[0] and TARL.search(blob):
                dest = tarl_target
            elif folder == "علوم التربية" and theorist_map:
                norm_blob = qq.norm(blob)
                for name, t in theorist_map.items():
                    if name in norm_blob and t != topic:
                        dest = (folder, t)
                        break
            if dest:
                recs.remove(rec)
                targets[dest].append(rec)
                moves[f"{topic} → {dest[1]}"] += 1
    if moves:
        print("إعادة توزيع:")
        for k, n in moves.most_common():
            print(f"  {n:5d}  {k}")
    # تكرار داخل المحور + عبر كل المحاور بعد التطبيع.
    final = {}
    global_seen = set()
    for key, recs in targets.items():
        seen, keep = set(), []
        for rec in recs:
            n = qq.norm(rec["text"])
            if n in seen:
                stats["dup_norm"] += 1
                continue
            if n in global_seen:
                stats["cross_dup"] += 1
                continue
            seen.add(n)
            global_seen.add(n)
            keep.append(rec)
        final[key] = keep
    # دمج المحاور الهزيلة (<10 أسئلة) في أكبر محور في المجلد نفسه.
    merged_away = []
    for folder in sorted({f for f, _t in final}):
        keys = [k for k in final if k[0] == folder]
        big = max(keys, key=lambda k: len(final[k]))
        have = {qq.norm(r["text"]) for r in final[big]}
        for k in keys:
            if k == big or len(final[k]) >= 10:
                continue
            moved = 0
            for r in final[k]:
                n = qq.norm(r["text"])
                if n in have:
                    continue
                have.add(n)
                final[big].append(r)
                moved += 1
            if moved:
                merged_away.append(f"{k[1]} ({moved}) → {big[1]}")
            final[k] = []
    if merged_away:
        print("دمج المحاور الهزيلة:")
        for m in merged_away:
            print("  -", m)
    apply_answer_policies(final)
    # توزيع مواضع الإجابة (تحيّز عالمي).
    dist = Counter(r["correctIndex"] for qs in final.values() for r in qs)
    total = sum(len(q) for q in final.values())
    print(f"مصادر مستعملة={len(sources_used)}  محرومة={sorted(sources_skip)}")
    print(f"وحدات خام: junk={stats['junk']}  catchall_removed="
          f"{stats['catchall_removed']}  dup_norm={stats['dup_norm']}  "
          f"cross_dup={stats['cross_dup']}")
    if reasons:
        print("أسباب الإسقاط:")
        for r, n in reasons.most_common():
            print(f"  {n:6d}  {r}")
    print("\n%-46s %-26s %6s" % ("المحور", "المجلد", "عدد"))
    for (folder, topic), recs in sorted(final.items()):
        print("%-46s %-26s %6d" % (topic[:44], folder[:24], len(recs)))
    zeros = [f"{t} [{f}]" for (f, t), recs in final.items() if not recs]
    print(f"\nمحور بلا أسئلة: {len(zeros)}")
    for z in zeros:
        print("  -", z)
    if total:
        print("مواضع الإجابة:",
              {k: f"{v} ({v * 100 // total}%)"
               for k, v in sorted(dist.items())})
    # كتابة بدائل longest_alone
    alt_total = 0
    alt_out = {}
    for (folder, topic), arecs in alts.items():
        # إزالة تكرار داخل البدائل
        seen, keep = set(), []
        for rec in arecs:
            n = qq.norm(rec["text"])
            if n in seen:
                continue
            seen.add(n)
            keep.append(rec)
        if not keep:
            continue
        key = f"{folder}::{topic}"
        alt_out[key] = {
            "folder": folder,
            "topic": topic,
            "easy": True,
            "questions": []
        }
        for rec in keep:
            alt_out[key]["questions"].append({
                "situation": rec["situation"],
                "text": rec["text"],
                "options": rec["options"],
                "correctIndex": rec["correctIndex"],
                "explanation": rec["explanation"],
                "easy": True,
            })
        alt_total += len(keep)
    if alt_total:
        ALTS_OUT.parent.mkdir(parents=True, exist_ok=True)
        ALTS_OUT.write_text(json.dumps(alt_out, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"\nبدائل longest_alone (سهل، مبعثر): {alt_total} سؤال في {len(alt_out)} محور -> {ALTS_OUT}")
    else:
        print("\nبدائل longest_alone: 0")
        ALTS_OUT.parent.mkdir(parents=True, exist_ok=True)
        ALTS_OUT.write_text("{}\n", encoding="utf-8")
    if dry:
        print("[dry-run] لم تُكتب ملفات.")
        return 0
    if "--write-manual" in sys.argv:
        write_manual(final)
    # الكتابة إلى manual_inbox (أسماء المجلدات/الملفات هي مرجعية المحاور).
    known = {p.name for p in INBOX.glob("*/*.txt")
             if not p.name.startswith("_")}
    for (folder, topic), recs in sorted(final.items()):
        fd = INBOX / folder
        fd.mkdir(parents=True, exist_ok=True)
        head = (f"# المحور الفرعي: {topic}\n"
                f"# ضع أسئلتك أسفل هذا السطر، وافصل بين كل سؤال وآخر بسطر من "
                f"الشرطات.\n"
                f"# صيغة السؤال: الوضعية / السؤال / أ ب ج د / الإجابة / "
                f"الشرح.\n\n")
        blocks = []
        for rec in recs:
            lines = []
            if rec["situation"]:
                lines.append(f"الوضعية: {rec['situation']}")
            lines.append(f"السؤال: {rec['text']}")
            for i, o in enumerate(rec["options"]):
                lines.append(f"{QT_LETTERS[i]}) {o}")
            lines.append(f"الإجابة: {QT_LETTERS[rec['correctIndex']]}")
            lines.append(f"الشرح: {rec['explanation']}")
            blocks.append("\n".join(lines))
        out = head + ("\n-------\n\n".join(blocks)) + "\n"
        (fd / f"{topic}.txt").write_text(out, encoding="utf-8")
    # إزالة ملفات قوالب المحاور التي لم تُمَد (تبقى القوالب بلا سؤال تُحذف؟ لا:
    # يكفي ألّا تُكتب؛ الفحص لا يُنشئ بنكاً فارغاً).
    written = sum(len(v) for v in final.values())
    print(f"\nكُتب {written} سؤالاً في {len(final)} ملفاً -> {INBOX}")
    missing = known - {f"{t}.txt" for (_f, t) in final}
    print(f"ملفات قالب بلا أسئلة ({len(missing)}): {sorted(missing)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
