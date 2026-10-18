# -*- coding: utf-8 -*-
"""بوابة جودة لأسئلة الاختيار من متعدد.

الهدف: إسقاط الأسئلة غير المنطقية أو التي تُحلّ بالنظر إلى صياغتها قبل
إدخالها بنك المحاور الثابت. القواعد كلها حتمية (بلا LLM) وسريعة.

المستخدمون:
  - tools/build_topic_bank.py : بوابة الفلترة عند بناء البنك.
  - test/topic_bank_test.dart  : نسخة Dart من القواعد نفسها تحرس البنك.
"""
import re
import unicodedata

# كلمات وظيفية لا تُحتسب في كشف التشابه أو التسريب.
STOP = {
    "ما", "من", "في", "على", "الى", "عن", "مع", "هذا", "هذه", "ذلك", "التي",
    "الذي", "عند", "كيف", "لماذا", "متى", "اين", "هل", "ثم", "او", "كل",
    "بعض", "غير", "بين", "لدى", "حسب", "كما", "هو", "هي", "هم", "كان", "كانت",
    "يكون", "تكون", "له", "لها", "هناك", "حيث", "ايضا", "فقط", "دون", "بعد",
    "قبل", "عبر", "حول", "نحو", "ضمن", "اذا", "لان", "كي", "ليس", "ليست",
    "مثل", "نفس", "اي", "بناء", "استنادا", "وفق", "ورد",
}

# خيارات وصفية عامة تُفقد السؤال منطقيته.
CATCH_ALL = re.compile(
    r"(?:كل\s+(?:الأجوبة|الخيارات|ما\s+سبق|الاحتمالات)"
    r"|لا\s+شيء\s+مما\s+سبق|لا\s+إجابة\s+صحيحة|لا\s+يوجد\s+إجابة"
    r"|خيار\s+(?:آخر|اقتراحي)|إجابة\s+(?:أخرى|محتملة)\s*\d*)"
)

# نفي يحوّل الإجابة الصحيحة إلى تشتيت مقلوب.
NEG_PREFIX = re.compile(r"^(?:لا|لم|لن|بدون|غير)\s+")

# أي إحالة إشارية في أي موضع من السؤال: تُزال من الذيل، وما يبقى وسط
# السؤال يبقى سؤالاً رديئاً يُحذف.
DEICTIC_ANY = re.compile(
    r"(?:هذا\s+|هذه\s+)?(?:النص|المقتطف|الفقرة|المعطى|المعطيات|السند)"
    r"|المذكور\s+في\s+النص|كما\s+ورد\s+في"
)

# حروف لاتينية طويلة = نص مشوّه (رابط أو خطأ نسخ).
LATIN_JUNK = re.compile(r"[A-Za-z]{6,}")

# بقايا حرف عطف بعد حذف الإحالة الإشارية.
DANGLING = re.compile(r"(?:[بو]|\bفي|\bمن|\bكما|\bورد)\s*—\s*حسب\s*«")

# سؤال منقطع أو يحيل إلى فقرة بلا معطيات.
BROKEN_TAIL = re.compile(
    r"(?:الفقرة|المقروء|المكتوب|الجزء|الجزئية|،|,|؛|\?|؟)\s*$"
)

# سياقات تنتمي إلى مادة أخرى لا علاقة لها بمحور الفلسفة/التربية.
FOREIGN_CONTEXT = (
    "مادة التاريخ", "التاريخ العام", "لغة عربية", "العلوم الطبيعية",
    "الفيزياء", "الكيمياء", "الأحياء", "التشريع",
)

TYPO_FIX = {
    "يعرفب": "يوصف",
    "جيرهوم برونر": "جيروم برونر",
    "ليف فيغوتسكي": "ليف فيجوتسكي",
    "فيغوتسكي": "فيجوتسكي",
    "فيرتيمر": "فيرتيمر",
    "بيرون": "بيير بورديو",
}


def norm(s):
    s = unicodedata.normalize("NFKC", s or "")
    s = re.sub(r"[\u064B-\u0652\u0670\u0640]", "", s)
    s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ٱ", "ا")
    s = s.replace("ى", "ي").replace("ة", "ه")
    return re.sub(r"[^\w\u0600-\u06FF]+", " ", s).strip().lower()


_CLITIC = re.compile(r"^(?:ال|لل|ل|و|ف|ب|ك|س)")


def tokens(s):
    out = set()
    for w in norm(s).split():
        if w in STOP:
            continue
        # «ال» التعريف وسوابق «ل/ب/ك» لا أثر لها في كشف التطابق.
        w = _CLITIC.sub("", w)
        if len(w) <= 2:
            continue
        out.add(w)
    return out


def fix_typos(s):
    out = s or ""
    for a, b in TYPO_FIX.items():
        out = out.replace(a, b)
    return out


def jaccard(a, b):
    if not a or not b:
        return 0.0
    return len(a & b) / len(a | b)


def drop_reason(qo, topic=""):
    """يعيد سبب الإسقاط، أو نصاً فارغاً إذا كان السؤال صالحاً."""
    opts = qo.get("options") or []
    ci = qo.get("correctIndex")
    text = qo.get("text") or ""
    if not isinstance(ci, int) or ci >= len(opts):
        return "bad_index"
    correct = opts[ci]
    distractors = [o for i, o in enumerate(opts) if i != ci]
    sit = qo.get("situation") or ""
    # الوضعية معروضة للتلميذ أيضاً، فتسريب الإجابة إليها تسريب أيضاً.
    stem = (text + " " + sit) if sit else text
    ct, dt = tokens(stem), tokens(correct)

    # 0) نص مشوّه أو ذيل معلّق.
    if DANGLING.search(text):
        return "dangling_tail"
    if LATIN_JUNK.search(text) or any(LATIN_JUNK.search(o or "") for o in opts):
        return "latin_junk"

    # 1) إحالة إشارية باقية في السؤال أو الوضعية أو الخيارات.
    if DEICTIC_ANY.search(stem) or any(DEICTIC_ANY.search(o or "") for o in opts):
        return "deictic_in_text"

    # 2) خيار وصفي عام يُفقد السؤال منطقيته.
    if any(CATCH_ALL.search(o or "") for o in opts):
        return "catch_all_option"

    shared = len(dt & ct)
    # 3) تسريب: الإجابة الصحيحة تكرارٌ لعبارة السؤال، فيُحل بالنظر لا بالفهم.
    if shared >= 4 or (len(dt) >= 3 and shared / len(dt) >= 0.5) or (
            len(dt) == 2 and shared == 2):
        return "leak_in_stem"

    # 4) الإجابة الصحيحة وحدها الأطول بوضوح، فيُكشف طول الخيارات.
    lens = [len(o or "") for o in opts]
    others = sorted(lens[:ci] + lens[ci + 1:])
    if lens[ci] == max(lens) and max(lens) - others[-1] >= 12 and len(text) < 170:
        return "longest_giveaway"

    # 5) تشتيتان تبدآن بنفس الكلمتين، فيُكشف الإجابة بنمط الخيارات.
    heads = [" ".join(norm(o).split()[:2]) for o in distractors]
    if any(h and heads.count(h) >= 2 for h in heads):
        return "pattern_giveaway"

    # 6) تشتيت هو نفي الإجابة الصحيحة نفسها (نفس الكلمات بعد إسقاط النفي).
    cset = tokens(correct)
    for o in distractors:
        if tokens(NEG_PREFIX.sub("", (o or "").strip())) == cset:
            return "negation_duplicate"

    # 7) خيارات متطابقة بعد التطبيع.
    no = [norm(o) for o in opts]
    if len(set(no)) < len(no):
        return "duplicate_options"

    # 8) سؤال منقطع أو يحيل إلى «الفقرة» بلا معطيات.
    if BROKEN_TAIL.search(text.strip()):
        return "broken_tail"

    # 9) سياق ينتمي إلى مادة أخرى مع محور لا علاقة له بها.
    if sit and any(f in sit for f in FOREIGN_CONTEXT):
        if not any(norm(f).split()[0] in norm(topic) for f in FOREIGN_CONTEXT):
            return "foreign_context"

    return ""