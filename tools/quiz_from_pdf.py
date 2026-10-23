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
    # النماذج المتاحة فعليًا على حساب Groq الحالي (تم التحقق 2026-10-04).
    # الترتيب: الأعلى جودة أولاً (gpt-oss-120b)، ثم الأسرع (allam-2-7b) احتياطاً.
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "qwen/qwen3.8-27b",
    "allam-2-7b",
]
# نماذج لم تعد متاحة على الحساب — تُستبعد من الترشيح.
RETIRED_MODELS = {
    "llama-3.3-70b-versatile",
    "llama-3.3-70b",
    "llama-3.1-70b-versatile",
    "mixtral-8x7b-32768",
    "gemma2-9b-it",
}

# ===== مزوّدون متعدّدون، كلهم OpenAI-compatible =====
# المفتاح يأتي من متغير البيئة ثم .env. المزوّد بلا مفتاح يُتجاهل تلقائيًا.
# عند 429 (نفاد الحصة) ينتقل التوليد للمزوّد التالي فورًا بدل الانتظار.
PROVIDERS = [
    {
        # Gemini أولًا: حدوده أوسع بكثير وحصته وفية، والأفضل للعربية.
        "id": "gemini",
        "key_env": "GEMINI_API_KEY",
        "base": "https://generativelanguage.googleapis.com/v1beta/openai/",
        "concurrency": 2,     # ثلاثة طلبات متوازية تسبب 429/503 على المجاني
        "models_env": "GEMINI_MODELS",
        "models": [
            "gemini-3.6-flash",
            "gemini-3.5-flash",
        ],
    },
    {
        "id": "groq",
        "key_env": "GROQ_API_KEY",
        "base": None,  # Groq SDK/endpoint الافتراضي
        "max_tokens": 4096,  # Groq يرفض ما فوق هذا الحد
        # طلبان متوازيان: النموذج سريع، والدفعة الواحدة تستهلك ~900 توكن
        # فتبقى ضمن نافذة 6000 توكن/دقيقة مع حصاد أسرع.
        "concurrency": 2,
        "models_env": "GROQ_MODELS",
        "models": list(MODEL_PREF),
    },
]

CHUNK_WORDS = 240     # سقف حجم المقطع (يُصغَّر تلقائياً للملفات القصيرة)
CHUNK_TARGET = 8      # عدد المقاطع المستهدف: يضمن تنوّع السياق ولو كان الملف قصيراً
CHUNK_MIN = 80        # أصغر حجم مقطع مقبول
PER_CALL = 6          # أسئلة في كل استدعاء (6 ≈ 1800 توكن: لا بتر في الردّ)
MAX_CALLS = 34        # سقف استدعاءات لملف واحد
PARALLEL = 3          # خيوط عاملة؛ groq محدود المعدّل فالزيادة تُربكه بـ429
PLAN_MARGIN = 10       # استدعاءات إضافية احتياطية لتعويض المكررات والمرفوضات
AVOID_N = 18          # عدد الأسئلة السابقة التي نُدرجها لمنع التكرار
DEAD_MODELS = set()   # نماذج ثبت عدم توفرها (404) تُتخطى فوراً
QUOTA_DEAD = {}       # مزوّد نفدت حصته: معرّف -> وقت monotonic تنتهي التهدئة
_SLOTS = {}           # مزوّد -> إشارة تحكم بعدد الطلبات المتزامنة المسموحة
NONE_PHRASE = "كل الأجوبة السابقة خاطئة"

# زوايا متغيّرة تُوزَّع على الاستدعاءات، فيولّد النموذج أسئلة مختلفة حتى من
# المقطع نفسه بدل إعادة صياغة الأسئلة ذاتها (سبب توقّف العدد سابقاً).
FOCUS_ANGLES = [
    "تحليل وضعية مهنية واقعية داخل الفصل",
    "تخطيط وتدبير التعلمات",
    "التقويم والدعم والمعالجة",
    "تعريف المفاهيم والمصطلحات الأساسية",
    "مقارنة المقاربات والنظريات التربوية",
    "الحالات الخاصة وصعوبات التعلم",
    "العلاقة بالأسرة والمحيط المدرسي",
    "المستجدات والمنهاج والوثائق التربوية",
    "أنواع الأنشطة وطرائق التنشيط",
    "أهداف التعلم والكفايات المستهدفة",
]

FORBIDDEN = [
    PHRASE,
    NONE_PHRASE,
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

SUB_AXES = [
    "علوم التربية",
    "مستجدات المنهاج",
    "الديداكتيك الخاص بالمواد",
    "المستجدات الوطنية كمدارس الريادة",
    "سيكولوجية النمو",
]

PROMPT = """اقرأ مقتطف الدرس التالي، ولّد {n} أسئلة اختبارية متعددة الخيارات
(QCM) معتمدة على تحليل وضعية مهنية أو ديداكتيكية، وموجّهة للمحور الفرعي: {sub}
وزاوية التركيز المطلوبة في هذه الدفعة: {focus}
المرجع/السند الذي استُخرج منه المحتوى: {source}

النمط المطلوب: {style}

بنية السؤال الإجبارية، وتبقى كما هي:
  وضعية : سياق مهني/ديداكتيكي بمعطيات واقعية (مشهد داخل الفصل، مشكل تربوي،
           تحليل ممارسة، أو وضعية تخطيط/تدبير/تقويم).
  سؤال   : سؤال مباشر دقيق يستدعي الفهم والتحليل لا الحفظ البصري.

لكل سؤال أخرج هذه الحقول بالضبط:
  q           : نص السؤال (8 كلمات على الأقل) دون أي إحالة إشارية إلى
                «هذا النص» أو «هذا المقتطف» أو «النص المرجعي».
  situation   : الوضعية (12 إلى 28 كلمة) تذكر المعطيات وتمهّد للسؤال.
  t           : الإجابة الصحيحة (2 إلى 12 كلمة).
  f1,f2,f3    : ثلاث عبارات خاطئة مقبولة ومنطقية (2 إلى 12 كلمة لكل واحدة).
  explanation : تعليل مختصر للإجابة الصحيحة (سطر واحد، 8 إلى 22 كلمة).

شروط صارمة:
  - كل المعلومات من المقتطف فقط. أجب عن المعطى ولا تضف معرفة خارجية.
  - المعطيات في الوضعية مرتبطة مباشرة بالمعطى في السؤال.
  - الوضعية (situation) ملزمة وغير فارغة، وتمهّد للسؤال وتستمد من المعطى المرجعي.
  - ممنوع منعاً باتاً استخدام العبارات الإشارية: «هذا النص»، «هذا المقتطف»،
    «النص المرجعي»، «ورد في المعطى»، «حسب هذا النص». وعند الحاجة إلى الإحالة
    على المصدر، اذكر اسمه صراحة في نهاية السؤال هكذا: «حسب «{source}»».
  - الخيارات الأربعة كلّها عبارات واقعية مرتبطة بالمعطى. ممنوع منعاً باتاً
    وضع «كل الأجوبة السابقة خاطئة» أو «لا شيء مما سبق» أو «لم يرد في النص»
    أو «خيار آخر» ضمن f1 أو f2 أو f3.
  - إن كانت الإجابة الصحيحة هي «لا شيء مما سبق» فاجعل t مساوياً لها تماماً،
    أي أن الخيارات الثلاثة الأخرى خاطئة فعلاً.
- لا تكرّر صياغة السؤال داخل الإجابة الصحيحة: لا يجوز أن تكون الإجابة
    الصحيحة تكراراً حرفياً لعبارة وردت في نص السؤال، وإلا حُلّ السؤال
    بالنظر إلى الكلمات دون الفهم.
  - الخيارات الأربعة متوازنة، متقاربة في الطول، ومحددة علمياً وتربوياً،
    ولا يكون أي منها صحيحاً جزئياً أو ناقصاً أو زائداً عن الصحيح. ولا يجوز أن
    تكون الإجابة الصحيحة وحدها الأطول وضوحاً أو التفصيلاً.
  - استخدم لغة تربوية رسمية مطابقة للغة امتحانات الكفاءة المهنية.
  - أعد مصفوفة JSON فقط دون شرح قبله أو بعده.
{avoid}
المقتطف:
{text}

صيغة الإخراج:
[{{"q":"...","situation":"...","t":"...","f1":"...","f2":"...","f3":"...","explanation":"..."}}]"""


def read_env_file() -> dict:
    """يقرأ .env مرة واحدة ويعيد dict (المتغير الحقيقي له الأولوية)."""
    vals = {}
    try:
        for line in (PROJECT / ".env").read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            v = v.strip().strip("\"'")
            if k.strip():
                vals[k.strip()] = v
    except OSError:
        pass
    for k, v in vals.items():
        if v and not os.environ.get(k, "").strip():
            os.environ[k] = v
    return vals


def env_value(name: str) -> str:
    """قيمة متغير بيئة بعد تحميل .env."""
    if not os.environ.get(name, "").strip():
        read_env_file()
    return os.environ.get(name, "").strip()


def build_providers():
    """يبني (provider, client, models) لكل مزوّد لديه مفتاح."""
    from openai import OpenAI

    read_env_file()
    out = []
    for p in PROVIDERS:
        key = os.environ.get(p["key_env"], "").strip()
        if not key:
            continue
        models_env = os.environ.get(p.get("models_env", ""), "").strip()
        models = ([m.strip() for m in models_env.split(",") if m.strip()]
                  if models_env else list(p["models"]))
        try:
            if p["base"]:
                client = OpenAI(api_key=key, base_url=p["base"], timeout=120.0)
            else:
                client = OpenAI(
                    api_key=key,
                    base_url="https://api.groq.com/openai/v1",
                    timeout=120.0,
                )
        except Exception as ex:  # pragma: no cover - تهيئة عميل
            print(f"PROVIDER_INIT_FAIL {p['id']}: {str(ex)[:100]}",
                  file=sys.stderr)
            continue
        out.append((p, client, models))
    return out


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


def chunk_pages(pages: list, size: int = 0):
    """تقطيع نصوص الصفحات إلى مقاطع تحتفظ بنطاق أرقام الصفحات لكل مقطع.

    الحجم تكيّفي: يُصغَّر في الملفات القصيرة حتى لا ننحصر في مقطع واحد
    (وهو ما كان يمنع تنوّع الأسئلة ويتوقّف عند ~27).
    """
    toks = []  # (word, page_no)
    for pno, text in pages:
        for w in text.split():
            toks.append((w, pno))
    total = len(toks)
    if not size:
        size = (max(CHUNK_MIN, min(CHUNK_WORDS, total // CHUNK_TARGET))
                if total else CHUNK_WORDS)
    chunks = []
    step = max(1, int(size * 0.8))  # تداخل بسيط بين المقاطع
    floor = max(40, size // 2)
    for i in range(0, total, step):
        sel = toks[i : i + size]
        if len(sel) >= floor:
            text = " ".join(w for w, _ in sel)
            pgs = sorted({p for _, p in sel})
            chunks.append((text, pgs))
        if i + size >= total:
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


def _salvage_objects(body: str) -> list:
    """يستخرج الكائنات الكاملة من مصفوفة JSON مبتورة عند حد التوكنز."""
    out, depth, start, in_str, esc = [], 0, None, False, False
    for i, ch in enumerate(body):
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == "{":
            if depth == 0:
                start = i
            depth += 1
        elif ch == "}" and depth:
            depth -= 1
            if depth == 0 and start is not None:
                try:
                    out.append(json.loads(body[start : i + 1]))
                except json.JSONDecodeError:
                    pass
                start = None
    return out


def clean_json_array(raw: str):
    s = raw.find("[")
    e = raw.rfind("]")
    seg = raw[s : e + 1] if s >= 0 and e > s else (raw[s:] if s >= 0 else "")
    if not seg.strip():
        return None
    for candidate in (seg, re.sub(r",\s*([\]}])", r"\1", seg)):
        try:
            got = json.loads(candidate)
            if isinstance(got, list) and got:
                return got
        except json.JSONDecodeError:
            pass
    # رد مبتور: نُنقذ الأسئلة المكتملة منه بدل إهدار الجداء كلها.
    return _salvage_objects(seg) or None


def _is_none(opt: str) -> bool:
    """هل العبارة هي «كل الأجوبة السابقة خاطئة»؟"""
    norm = re.sub(r"[^\u0600-\u06FFa-zA-Z ]", " ", opt)
    norm = re.sub(r"\s+", " ", norm).strip()
    target = re.sub(r"\s+", " ", NONE_PHRASE).strip()
    return target in norm or norm in target


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
    # لا تسرّب عبارة «كل الأجوبة السابقة خاطئة» إلى الخيارات الثلاثة
    if any(_is_none(it[k]) for k in ("f1", "f2", "f3")):
        return False
    # الوضعية والتعليل إلزاميان في الصيغة الجديدة
    sit = it.get("situation")
    if not isinstance(sit, str) or len(sit.split()) < 6:
        return False
    # الوضعية جملة تربوية قصيرة واحدة، وليست فقرة ولا مقتطفاً مُقتبَساً.
    if len(sit.split()) > 30:
        return False
    exp = it.get("explanation")
    if not isinstance(exp, str) or len(exp.split()) < 5:
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
    exp = it.get("explanation") or ""
    if not isinstance(exp, str):
        exp = ""
    return {
        "q": clean_ar(it["q"]),
        "situation": clean_ar(sit),
        "t": clean_ar(it["t"]),
        "f1": clean_ar(it["f1"]),
        "f2": clean_ar(it["f2"]),
        "f3": clean_ar(it["f3"]),
        "explanation": clean_ar(exp),
    }


def ask(client, model: str, prompt: str, max_tokens: int = 8192):
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
        max_tokens=max_tokens,
    )
    return resp.choices[0].message.content or ""


def _is_billing_quota(msg: str) -> bool:
    """نفاد حصة الخطة (لا حدّ معدّل): يستوجب تهدئة طويلة."""
    low = msg.lower()
    return ("exceeded your current quota" in low or "check your plan" in low)


def _is_too_large(msg: str) -> bool:
    """«Request too large»: تجاوز حدّ النموذج نفسه، لا نفاد حصة.

    خطأ في النموذج لا في الحساب، فنتخطّى هذا النموذج ولا نُهدئ المزوّد.
    """
    return "request too large" in msg.lower()


def _is_rate_limit(msg: str) -> bool:
    if _is_too_large(msg):
        return False
    low = msg.lower()
    return ("429" in msg or "rate limit" in low or "resource_exhausted"
            in low or "quota" in low or "too many requests" in low
            or "503" in msg or "overloaded" in low or "high demand" in low)


def _is_quota(msg: str) -> bool:
    """نفاد حصة/معدّل (429) — يستدعي تهدئة قصيرة للمزوّد، بخلاف 503 العابر."""
    if _is_too_large(msg):
        return False
    low = msg.lower()
    return ("429" in msg or "rate limit" in low or "resource_exhausted" in low
            or "quota" in low or "too many requests" in low)


def _is_missing_model(msg: str) -> bool:
    low = msg.lower()
    return ("404" in msg or "does not exist" in low or "not found" in low
            or "unknown model" in low or "unsupported" in low)


def _slot(prov):
    """إشارة تحدّ الطلبات المتزامنة لكل مزوّد."""
    import threading

    pid = prov["id"]
    sem = _SLOTS.get(pid)
    if sem is None:
        sem = _SLOTS[pid] = threading.Semaphore(
            max(1, int(prov.get("concurrency") or 1)))
    return sem


def gen_one(providers, excerpt, n, worker_idx=0, pages=None, sub="",
            focus="", avoid=None, source=""):
    """استدعاء واحد: يمرّ على المزوّدين بالترتيب ويجمع ما يمكن.

    ينتقل للمزوّد التالي فورًا عند 429/الخلل، ويُكمل الناقص من مزوّد آخر
    إذا أعطى الأول ردًّا مبتورًا أو أقل من المطلوب.

    providers: قائمة (provider_dict, client, models) من build_providers().
    يعيد قائمة عناصر صالحة (قد تكون فارغة).
    """
    import time as _t

    _t.sleep(worker_idx * 1.5)  # إزاحة بدء العمال لتلطيف حدود الطلب/الدقيقة
    avoid_block = ""
    if avoid:
        lines = "\n".join("- " + s for s in avoid if s and s.strip())
        if lines:
            avoid_block = (
                "\nتنبيه: الأسئلة التالية وُلّدت سابقاً من نفس المقتطف؛ لا تُعِدها "
                "ولا تصوغ سؤالاً قريباً منها في المعنى أو الصياغة، وقدّم أسئلة "
                "جديدة مختلفة عنها:\n" + lines + "\n")
    prompt = PROMPT.format(n=n, style=STYLE, text=excerpt,
                           sub=sub or "المحاور العامة",
                           focus=focus or "تحليل وضعية مهنية",
                           source=source or "المرجع التربوي",
                           avoid=avoid_block)

    items, seen = [], set()
    for prov, client, models in providers:
        pid = prov["id"]
        # مزوّد نفدت حصته: نتخطاه بقية التشغيل بدل إهدار الطلبات.
        if QUOTA_DEAD.get(pid, 0.0) > _t.monotonic():
            continue
        cap = int(prov.get("max_tokens") or 8192)
        saw_limit, saw_quota, saw_billing, got = False, False, False, 0
        for model in [m for m in models if m not in DEAD_MODELS]:
            raw = None
            for attempt in range(2):
                try:
                    with _slot(prov):
                        raw = ask(client, model, prompt, cap)
                    break
                except Exception as ex:
                    msg = str(ex)
                    print(f"MODEL_FAIL {pid}/{model}: {msg[:120]}",
                          file=sys.stderr)
                    if _is_missing_model(msg):
                        DEAD_MODELS.add(model)
                        break
                    if _is_too_large(msg):
                        # النموذج لا يحتمل هذا الطلب: نتخطاه فوراً بلا تهدئة.
                        break
                    if _is_rate_limit(msg):
                        saw_limit = True
                        if _is_quota(msg):
                            saw_quota = True
                            if _is_billing_quota(msg):
                                saw_billing = True
                        mra = re.search(r"try again in ([\d.]+)(ms|s|m)", msg)
                        if mra and attempt == 0:
                            # لا ننتظر طويلًا: النموذج التالي ثم المزوّد التالي.
                            val = float(mra.group(1))
                            wait = (val / 1000 if mra.group(2) == "ms"
                                    else val * 60 if mra.group(2) == "m"
                                    else val)
                            if wait <= 3:
                                _t.sleep(wait)
                            elif wait > 60:
                                # نافذة يومية/مزدوجة: الانتظار لا يفيد داخل
                                # الكويز، فنتخطّى المزوّد بقية التشغيل.
                                QUOTA_DEAD[pid] = _t.monotonic() + min(wait, 3600)
                                print(f"QUOTA_LONG {pid} {wait:.0f}s",
                                      file=sys.stderr)
                        break
                    break
            if not raw:
                continue
            arr = clean_json_array(raw)
            if not isinstance(arr, list):
                continue
            for it in arr:
                if not valid_item(it):
                    continue
                nit = norm_item(it)
                key = re.sub(r"\s+", " ", nit["q"]).lower()
                if key in seen:
                    continue
                seen.add(key)
                items.append(nit)
                got += 1
            if got:
                print(f"PROVIDER_OK {pid}/{model} +{got} (target {n})",
                      file=sys.stderr)
            break
        if saw_quota and not got:
            # نفاد حصة: تهدئة طويلة عند نفاد حصة الخطة نفسها، وقصيرة عند
            # مجرد حدّ معدّل — التهدئة الطويلة كانت توقف التوليد لدقائق.
            if saw_billing:
                hold, tag = 900, "15min"
            else:
                hold, tag = 20, "20s"
            QUOTA_DEAD[pid] = _t.monotonic() + hold
            print(f"QUOTA_HOLD {pid} for {tag}", file=sys.stderr)
            continue
        if got and not saw_quota:
            QUOTA_DEAD.pop(pid, None)
        if len(items) >= n:
            break

    if not items:
        return []
    if pages:
        lbl = page_label(pages)
        for nit in items:
            nit["p"] = lbl
    return items


def _fill_options(correct, distractors, rng, want=4):
    """الخيار الصحيح + حتى ثلاثة تشتيتات حقيقية من النموذج.

    لا نُدرج «كل الأجوبة السابقة خاطئة» إلا اضطراراً (نقص التشتيتات)، لأنه
    خيار يُضعف السؤال ويُفقده منطقيته. يعيد (الخيارات، فهرس الصحيح).
    """
    seen = {correct}
    clean = []
    for d in distractors:
        d = (d or "").strip()
        if not d or d in seen or _is_none(d):
            continue
        seen.add(d)
        clean.append(d)
    clean = clean[: want - 1]
    if len(clean) < want - 1:
        # نُكمل بـ«لا شيء مما سبق» مرة واحدة فقط، ثم بحقول بديلة.
        clean.append(NONE_PHRASE)
        seen.add(NONE_PHRASE)
    slots = [correct] + clean
    guard = 1
    while len(slots) < want:
        g = ("إجابة محتملة %d" % guard)
        guard += 1
        if g not in seen:
            seen.add(g)
            slots.append(g)
    rng.shuffle(slots)
    return slots, slots.index(correct)


_DEICTIC_TAIL = re.compile(
    r"\s*(?:في|حسب|وفق|كما\s+ورد|ورد\s+في|بناء\s*على|بناءً\s*على|"
    r"استناداً?\s*إلى|حسبما\s+ورد\s*في|المذكور\s+في)\s*(?:هذا\s+|هذه\s+)?"
    r"(?:النص|المقتطف|مقتطف|النص\s+المرجعي|المعطى|المعطيات|"
    r"معطيات(?:\s+النص)?|المقتطف\s+المرجعي|النص\s+السابق|الوثيقة|السند|"
    r"الفقرة|المقروء|المكتوب|الجزء|الجزئية)"
    r"(?:\s+(?:المرجعي|السابق|المذكور|أعلاه|التالي))?\s*[.،؛؟\u061f?!]*\s*$"
)

# مؤشرات لا تحمل اسم مرجع حقيقياً: تُحذف بلا إضافة «حسب «...»».
_VAGUE_REF = re.compile(r"(?:الفقرة|المقروء|المكتوب|الجزء|الجزئية)")


# حروف تتركها إزالة الإحالة معلّقة في آخر السؤال.
def strip_deictic(text: str, ref: str = "") -> str:
    """يحذف الإحالات الإشارية في نهاية السؤال، ويثبّت اسم المرجع صراحةً."""
    if not text:
        return text
    stripped = text.strip()
    m = _DEICTIC_TAIL.search(stripped)
    out, n = _DEICTIC_TAIL.subn("", stripped)
    if n:
        # «... ب — حسب «x»» => «...» : نزيل كلمات معلّقة قبل المرجع.
        # ملاحظة: الكلمة تُحذف كاملةً فقط، فلا نبتلع «و» آخر كلمة (أرسطو).
        prev = None
        while prev != out:
            prev = out
            out = re.sub(
                r"(?:^|\s)(?:ب|و|في|من|إلى|كي|كما|ورد)\s*$", "", out)
    out = out.rstrip(" .،؛؟!")
    if n and ref and m and not _VAGUE_REF.search(m.group(0)):
        return f"{out} — حسب «{ref}»"
    return out


def compose(items, subject, rng, source_doc="ملف الدرس"):
    """وضعية + سؤال + 4 خيارات حقيقية (الصحيحة وثلاثة تشتيتات من النموذج)."""
    questions = []
    for it in items:
        t = (it["t"] or "").strip()
        none_is_correct = _is_none(t)
        # إن كانت الإجابة «لا شيء مما سبق» فهي الخيار الصحيح، وتشتّتات
        # النموذج الثلاثة هي الباقي.
        anchor = t if not none_is_correct else NONE_PHRASE
        opts, correct_index = _fill_options(
            anchor, [it["f1"], it["f2"], it["f3"]], rng)
        pg = it.get("p") or ""
        page_txt = f" \u2014 {pg}" if pg else ""
        exp = (it.get("explanation") or "").strip()
        if none_is_correct:
            base = "لا تنطبق أي من العبارات السابقة على المعطى"
        else:
            base = t
        if not exp:
            exp = f"{base} (ورد في «{source_doc}»{page_txt})"
        else:
            exp = f"{exp} (ورد في «{source_doc}»{page_txt})"
        questions.append({
            "subject": subject,
            "situation": strip_deictic(it.get("situation") or ""),
            "text": strip_deictic(it["q"], source_doc),
            "options": opts,
            "correctIndex": correct_index,
            "explanation": exp,
            "source": f"{source_doc} ({pg})" if pg else source_doc,
        })
    return questions


def write_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    tmp.replace(path)


def recent_stems(items, n=AVOID_N):
    """آخر أسئلة وُلّدت (نصوصها) لتمريرها للنموذج ومنع التكرار."""
    out = []
    for it in list(items)[-n:]:
        q = it.get("q") if isinstance(it, dict) else ""
        if isinstance(q, str) and q.strip():
            out.append(re.sub(r"\s+", " ", q).strip())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf", default="")
    ap.add_argument("--url", default="")
    ap.add_argument("--source-name", default="",
                    help="اسم الملف المُفضّل للمصدر في تعليل الإجابة")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--subject", default="")
    ap.add_argument("--sub", default="",
                    help="المحور الفرعي المستهدف")
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

    providers = build_providers()
    if not providers:
        print("NO_PROVIDER_KEY (GROQ_API_KEY / GEMINI_API_KEY / GITHUB_TOKEN)")
        return 3
    for prov, _c, models in providers:
        print(f"provider {prov['id']}: {','.join(models[:4])}", file=sys.stderr)
    chunks = chunk_pages(extract_pages(pdf_path, pdf_bytes))
    source_doc = (args.source_name.strip() if args.source_name.strip()
                  else (pdf_path.name if pdf_path
                        else args.url.rsplit("/", 1)[-1]).rsplit(".", 1)[0])
    seen_q = set()
    items = []
    first_count_done = 0

    if progressive:
        # ===== الدفعة الفورية: حتى 3 محاولات بطلب متناقص لتفادي رد مبتور =====
        uniq = []
        fseen = set()
        for attempt in range(3):
            need = args.first_count - len(uniq)
            if need <= 0:
                break
            ask_n = args.first_count + 1 if not attempt else need
            for nit in gen_one(providers, chunks[0][0], ask_n,
                               pages=chunks[0][1], sub=args.sub,
                               source=source_doc):
                k = re.sub(r"\s+", " ", nit["q"]).lower()
                if k not in fseen:
                    fseen.add(k)
                    uniq.append(nit)
        fb = uniq[: args.first_count]
        if not fb:
            print("FIRST_FAILED got=0", file=sys.stderr)
            return 4
        if len(fb) < args.first_count:
            print("FIRST_PARTIAL got=%d of %d" % (len(fb), args.first_count),
                  file=sys.stderr)
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
    # ندور على كل المقاطع مع إزاحة لكل نداء، فلا يتكرّر نداءٌ على مقطع واحد
    # ولا تبقى بقية المستند بلا تغطية (السبب في توقّف التوليد عند 15).
    n_chunks = max(1, len(chunks))
    span = max(1, int(n_chunks / max(1, plan)))
    jobs = []
    for k in range(plan):
        ci = (k * span + (k // n_chunks)) % n_chunks
        text, pgs = chunks[ci]
        focus = FOCUS_ANGLES[k % len(FOCUS_ANGLES)]
        jobs.append((k, text, pgs, PER_CALL, focus))

    # مسار البثّ التدريجي: يُكتب بعد كل نداء مكتمل ليراه السيرفر فوراً.
    prog_path = None
    if progressive and args.out_rest:
        prog_path = Path(args.out_rest).with_suffix(".progress.json")

    def flush_progress(collected, done_n):
        """يكتب ما جُمِع حتى الآن بشكل ذرّي (يبقى الملف صالحاً دائماً)."""
        if prog_path is None:
            return
        try:
            snap = list(collected)
            r2 = random.Random(args.seed if args.seed is not None else 0)
            r2.shuffle(snap)
            part = compose(snap, args.subject, r2, source_doc)
            write_json(prog_path, {
                "state": "working",
                "count": len(part),
                "doneCalls": done_n,
                "questions": part,
            })
        except Exception as ex:  # البثّ لا يصحب فشل الكتابة أبداً
            print(f"PROGRESS_FAIL {str(ex)[:120]}", file=sys.stderr)

    def absorb(got):
        """يضيف الأسئلة الجديدة فقط ويعيد عدد المضاف."""
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
        return added

    done_calls = 0
    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        it_jobs = iter(jobs)
        pending = {}

        def submit_next():
            for k, ex, pg, n, fc in it_jobs:
                pending[pool.submit(
                    gen_one, providers, ex, n, k % PARALLEL, pg,
                    sub=args.sub, focus=fc,
                    avoid=recent_stems(items),
                    source=source_doc)] = (k, n)
                return True
            return False

        for _ in range(PARALLEL):
            if not submit_next():
                break
        while pending:
            fut = next(as_completed(list(pending)))
            _k, _n = pending.pop(fut)
            done_calls += 1
            try:
                got = fut.result()
            except Exception as ex:  # شبكة/أخرى
                print(f"CALL_FAIL {_k}: {str(ex)[:120]}", file=sys.stderr)
                got = []
            added = absorb(got)
            print(
                f"call#{done_calls}/{plan} added={added} total={len(items)}",
                file=sys.stderr,
            )
            # بثّ ما وصلنا إليه فوراً (بلا انتظار نهاية التوليد).
            if len(items) > first_count_done:
                flush_progress(items, done_calls)
            if len(items) >= args.count:
                for f in list(pending):
                    f.cancel()
                break
            submit_next()

    # ===== جولات إضافية: يجب أن يسبق المولّد المستخدم حتى يبلغ العدد =====
    round_no = 0
    while len(items) < args.count and round_no < 4:
        round_no += 1
        need = args.count - len(items)
        extra_calls = min(MAX_CALLS, -(-need // PER_CALL) + PLAN_MARGIN)
        print(
            f"ROUND_EXTRA r={round_no} need={need} calls={extra_calls} "
            f"have={len(items)}",
            file=sys.stderr,
        )
        rjobs = []
        for k in range(extra_calls):
            ci = (k * 3 + round_no * 5) % n_chunks
            text, pgs = chunks[ci]
            focus = FOCUS_ANGLES[(round_no * 3 + k) % len(FOCUS_ANGLES)]
            rjobs.append((k, text, pgs, PER_CALL, focus))
        round_added = 0
        with ThreadPoolExecutor(max_workers=PARALLEL) as pool2:
            riter = iter(rjobs)
            rpending = {}

            def submit_round():
                for k, ex, pg, n, fc in riter:
                    rpending[pool2.submit(
                        gen_one, providers, ex, n, k % PARALLEL, pg,
                        sub=args.sub, focus=fc,
                        avoid=recent_stems(items),
                        source=source_doc)] = (k, n)
                    return True
                return False

            for _ in range(PARALLEL):
                if not submit_round():
                    break
            while rpending:
                fut = next(as_completed(list(rpending)))
                rpending.pop(fut)
                try:
                    got = fut.result()
                except Exception as ex:
                    print(f"ROUND_CALL_FAIL {str(ex)[:100]}", file=sys.stderr)
                    got = []
                added = absorb(got)
                round_added += added
                if added:
                    print(
                        f"round#{round_no} added={added} total={len(items)}",
                        file=sys.stderr,
                    )
                    flush_progress(items, done_calls + round_no)
                if len(items) >= args.count:
                    for f in list(rpending):
                        f.cancel()
                    break
                submit_round()
        if len(items) >= args.count:
            break
        if round_added == 0 and round_no >= 2:
            break  # لا فائدة من محاولة أخرى

    if len(items) < args.count:
        # نقبل ما توافر ما دام بلغ حدّاً معقولاً: العرض التقدمي أهم من العدد.
        if progressive and len(items) >= first_count_done + 8:
            print(
                f"PARTIAL_OK got={len(items)} need={args.count}",
                file=sys.stderr,
            )
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
    if prog_path is not None:
        try:
            prog_path.unlink()
        except OSError:
            pass
    print(f"GEN_OK count={len(questions)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
