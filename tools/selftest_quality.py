# -*- coding: utf-8 -*-
"""فحص ذاتي سريع (بلا شبكة ولا حصة LLM) لبوابة الجودة ولتوليد الخيارات.

    python tools/selftest_quality.py     # يطبع PASS/FAIL ويخرج 1 عند الفشل
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import quiz_from_pdf as q  # noqa: E402
import question_quality as qq  # noqa: E402

FAILS = []


def check(name, got, want):
    ok = got == want
    print(("PASS " if ok else "FAIL ") + name)
    if not ok:
        print(f"      got : {got!r}")
        print(f"      want: {want!r}")
        FAILS.append(name)


def one(text, options, ci, situation="", topic="محور"):
    return {"text": text, "options": options, "correctIndex": ci,
            "situation": situation, "topic": topic}


def main():
    rng = random.Random(7)

    # 1) التوليد: 4 خيارات حقيقية من النموذج، بلا «كل الأجوبة السابقة خاطئة».
    item = {"t": "السبب المادي", "f1": "السبب الغائي", "f2": "السبب الشكل",
            "f3": "السبب الفعال", "q": "سؤال", "situation": "وضعية",
            "explanation": "تعليل"}
    out = q.compose([item], "موضوع", rng, "مرجع")[0]
    check("compose: أربعة خيارات", len(out["options"]), 4)
    check("compose: بلا خيار وصفي",
          any(qq.CATCH_ALL.search(o) for o in out["options"]), False)
    check("compose: الخيارات هي trio النموذج",
          set(out["options"]),
          {"السبب المادي", "السبب الغائي", "السبب الشكل", "السبب الفعال"})

    # 2) إزالة الإحالة الإشارية من الذيل + الحرف المعلّق.
    check("strip: ذيل «كما ورد في النص»",
          q.strip_deictic("ما مبدأ أرسطو كما ورد في النص المرجعي", "مرجع"),
          "ما مبدأ أرسطو — حسب «مرجع»")
    check("strip: «المذكور في الفقرة» بلا مرجع",
          q.strip_deictic("ما اسم أفلاطون المذكور في الفقرة", "مرجع"),
          "ما اسم أفلاطون")
    check("strip: لا يمسّ سؤالاً سليماً",
          q.strip_deictic("ما هو دور اللوغوس في الرسالة", "مرجع"),
          "ما هو دور اللوغوس في الرسالة")

# 3) بوابة الجودة ترصد الرذائل.
    check("QA: خيار «كل الأجوبة السابقة خاطئة»",
          qq.drop_reason(one("سؤال عن المنهج",
                             ["المقاربة المعرفية", "المقاربة البنائية",
                              "المقاربة السلوكية",
                              "كل الأجوبة السابقة خاطئة"], 0)),
          "catch_all_option")
    check("QA: تسريب الإجابة من نص السؤال",
          qq.drop_reason(one("ما المبدأ الذي يعبر عن عدم التناقض الفلسفي",
                             ["مبدأ عدم التناقض", "مبدأ الهوية",
                              "مبدأ الوجود", "مبدأ الكيان"], 0)),
          "leak_in_stem")
    check("QA: تسريب من الوضعية",
          qq.drop_reason(one("اختر الإجابة الصحيحة",
                             ["تخصيص فترة قصيرة لخلق بيئة آمنة",
                              "إلغاء الأنشطة الافتتاحية",
                              "إطالة مدة الحصة إلى ساعتين",
                              "تعميم الدعم على كل التلاميذ"], 0,
                             situation="يحرص المعلم على خلق بيئة آمنة للتلميذ")),
          "leak_in_stem")
    check("QA: الإجابة الأطول وحدها",
          qq.drop_reason(one("ما دور المبدأ في تشكيل الاتجاه",
                             ["دور مختصر", "دور قصار", "دور قصير",
                              "دور طويل جداً ومفصّل جدا إلى حدود شرح السياق"],
                             3)),
          "longest_giveaway")
    check("QA: نمط الخيارات يكشف الإجابة",
          qq.drop_reason(one("ما الصفات الخاصة بالعرض",
                             ["الكم، النوع، المكان", "الكم، العرض، النوع",
                              "الكم، النوع، الزمن", "النوع، المكان", "الزمن"], 3)),
          "pattern_giveaway")
    check("QA: نفي الإجابة",
          qq.drop_reason(one("ما أثر العواطف في تلقّي الرسالة",
                             ["العواطف تؤثر على ثقة الجمهور",
                              "لا تؤثر العواطف على ثقة الجمهور",
                              "العواطف ترفع المحتوى", "العواطف تشتت الانتباه"], 0)),
          "negation_duplicate")
    check("QA: إحالة إشارية باقية",
          qq.drop_reason(one("كيف يوضح المقتطف دور النمو في بناء المعرفة",
                             ["نمو الجسد", "نمو اللغة",
                              "نمو المنطق", "نمو الفكرة"], 0)),
          "deictic_in_text")
    check("QA: سياق مادة أخرى",
          qq.drop_reason(one("كيف يوظّف المعلم المبدأ",
                             ["تطبيق المبدأ", "إهمال المبدأ",
                              "تجاهل المبدأ", "المبدأ بلا أثر"], 0,
                             situation="سؤال تاريخي في مادة التاريخ العام للصف السادس"),
                             topic="نظريات التعلم والمقارنات البيداغوجية"),
          "foreign_context")
    check("QA: سؤال سليم يُقبل",
          qq.drop_reason(one("ما المرحلة العمرية السابقة لبدء المدرسة الابتدائية",
                             ["الطفولة المتأخرة", "الطفولة المبكرة",
                              "المراهقة", "الرشد"], 1)),
          "")

    print(f"\n{'كل الفحوص ناجحة' if not FAILS else 'فشل: ' + str(FAILS)}")
    return 1 if FAILS else 0


if __name__ == "__main__":
    sys.exit(main())