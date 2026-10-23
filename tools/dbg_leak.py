# -*- coding: utf-8 -*-
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")
import question_quality as qq

q = {
    "text": "اختر الإجابة الصحيحة",
    "situation": "يحرص المعلم على خلق بيئة آمنة للتلميذ",
    "options": ["تخصيص فترة قصيرة لخلق بيئة آمنة",
                "إلغاء الأنشطة الافتتاحية",
                "إطالة مدة الحصة إلى ساعتين",
                "تعميم الدعم على كل التلاميذ"],
    "correctIndex": 0,
}
dt = qq.tokens(q["options"][0])
ct = qq.tokens(q["text"] + " " + q["situation"])
print("dt   =", sorted(dt))
print("ct   =", sorted(ct))
print("shared=", sorted(dt & ct), len(dt & ct), "ratio=", len(dt & ct) / len(dt))
print("reason=", repr(qq.drop_reason(q)))