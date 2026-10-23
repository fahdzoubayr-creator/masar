# -*- coding: utf-8 -*-
"""اختبار ذاتي لأداة الفحص: تحقّق أنها ترصد التلف الحقيقي قبل دخول البنك.

    python tools/selftest_check_manual.py
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = Path(__file__).resolve().parent.parent
CHECK = PROJECT / "tools" / "check_manual.py"


def q(text, options, ci=1, situation="", explanation="شرح صحيح موجز."):
    return {"situation": situation, "text": text, "options": options,
            "correctIndex": ci, "explanation": explanation}


GOOD = [
    q("ما وظيفة التخطيط المسبق في العمل الجماعي؟",
      ["ترتيب المحتويات من الأسهل إلى الأصعب.",
       "توزيع الأدوار وضبط وقت العمل.",
       "قياس مستوى التلاميذ قبل الدرس.",
       "توحيد إجابات المجموعات في الجواب."], 1,
      "وزع أستاذ مجموعات على تلاميذه ثلاث بطاقات وطلب عرض عملها.",
      "التخطيط المسبق يحدد الأدوار والزمن والمخرجات لكل مجموعة."),
    q("ما المبدأ الذي طوره فيجوتسكي في التعلم؟",
      ["منطقة النمو القريب والتعلم بتوجيه من الآخر.",
       "التعلم بالمحاكاة والتعزيز المستمر.",
       "الانتقال من الجزيئي إلى الكل مفهوم جديد.",
       "التعلم بالملاحظة ونمذجة السلوك."], 0,
      "يركز فيجوتسكي على ما ينجزه المتعلم بمساعدة معلمه.",
      "يحدد فيجوتسكي منطقة النمو القريب، ويكون التعلم فيها بتوجيه من الآخر."),
]

CASES = {
    "Latin garbage": [
        q("أي مبدأ يعتمد عليه ترتيبBACtertNo التعلم؟",
          ["منطقة النمو القريب والتعلم服从 المحاولة.",
           "التعلم境外 بالمحاكاة والتعزيز المستمر.",
           "الانتقال من الجزيئي إلى الكل مفهوم.",
           "التعلم بالملاحظة ونمذجة skills."], 0, "", "شرح قصير."),
    ],
    "Word repeat": [
        q("ما الشرح الشرح الذي يمنع التسرع في إنجاز العمل؟",
          ["التخطيط المسبق يحدد الأدوار والزمن.",
           "المراجعة持续的持续的 تسبق الإنجاز.",
           "الحوار المفتوح مع الزملاء.",
           "عرض النتائج على المجموعة."], 1, "", "شرح قصير."),
    ],
    "Meta option": [
        q("ما الصفة التي تميز_groups مستعدة؟",
          ["كل الأجوبة السابقة خاطئة.",
           "التعاون في إنجاز المهمة.",
           "احترام الوقت المحدد.",
           "تقاسم الأدوار بين الأعضاء."], 1, "", "شرح قصير."),
    ],
    "Missing explanation": [
        q("ما الصفة التي تميز Groûp المتعاونة؟",
          ["التعاون في إنجاز المهمة.",
           "سرعة إنجاز المهمة.",
           "تقاسم الأدوات.",
           "الصمت أثناء العمل."], 0, "", ""),
    ],
    "Answer in stem": [
        q("ما التخطيط المسبق للأدوار والزمن والمخرجات؟",
          ["التخطيط المسبق للأدوار والزمن والمخرجات",
           "بطء الإنجاز في المجموعة.",
           "ضعف الانتباه داخل الصف.",
           "تكرار الشرح من طرف الأستاذ."], 0, "", "شرح قصير."),
    ],
    "Wrong options count": [
        q("ما أثر غياب التخطيط؟",
          ["فقدان التفاعل.", "بطء الإنجاز."], 0, "", "شرح قصير."),
    ],
    "Longest giveaway": [
        q("ما أثر غياب التخطيط المسبق؟",
          ["فقدان التفاعل بين التلاميذ وإضاعة الوقت.",
           "بطء الإنجاز.",
           "ضعف الانتباه.",
           "تكرار الشرح."], 0, "", "شرح قصير موجز."),
    ],
    "Duplicate question": [
        GOOD[0], GOOD[0],
    ],
    "Replacement char": [
        q("ما أثر \ufffd غياب التخطيط؟",
          ["بطء الإنجاز.", "فقدان التفاعل.", "ضعف الانتباه.", "تكرار الشرح."],
          0, "", "شرح قصير."),
    ],
    "Good control": GOOD,
}


def main():
    fails = []
    for name, questions in CASES.items():
        # كل حالة في مجلد مستقل، وإلا عدّت الأداة مشاكل الحالات الأخرى.
        with tempfile.TemporaryDirectory() as td:
            (Path(td) / "bank.json").write_text(json.dumps(
                {"folder": "علوم التربية", "topic": name,
                 "questions": questions}, ensure_ascii=False), encoding="utf-8")
            r = subprocess.run([sys.executable, str(CHECK), "--dir", td],
                               capture_output=True, text=True,
                               encoding="utf-8", errors="replace")
            n = 0
            for line in r.stdout.splitlines():
                if line.strip().startswith("problems="):
                    n = int(line.split("=")[1])
            should_fail = name != "Good control"
            ok = (n > 0) if should_fail else (n == 0)
            print(f"{'PASS' if ok else 'FAIL'}  {name}: problems={n}")
            if not ok:
                fails.append(name)
                print(r.stdout[:1200])
    print(f"\n{len(CASES) - len(fails)}/{len(CASES)} passed")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())