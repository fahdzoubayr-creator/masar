# -*- coding: utf-8 -*-
"""أسئلة مؤلَّفة يدوياً لكل محور — تُكتب في assets/banks/manual/<مفتاح>.json

المصدر الوحيد المعتمد للتطبيق: تأليف بشري، لكل محور على حدة، بلا توليد آلي.

    python tools/manual_seed.py         # كتابة ملفات manual/
    python tools/check_manual.py --strict # فحص الجودة (يجب أن ينجح)
    python tools/build_topic_banks.py  # دمجها في بنوك التشغيل

قواعد الكتابة:
  - أربعة خيارات حقيقية، بلا «كل الأجوبة السابقة خاطئة».
  - الخيارات متقاربة الطول، والإجابة الصحيحة ليست الأطول وضوحاً.
  - لا تكرار لعبارة السؤال داخل الإجابة الصحيحة.
  - لا إحالة إلى النص؛ المرجع يُذكر باسمه أو يُحذف.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(__file__).resolve().parent.parent
MANUAL = PROJECT / "assets" / "banks" / "manual"
BANK = {}


def add(folder, topic, situation, text, options, correct, explanation,
        source=None):
    assert len(options) == 4, f"أربعة خيارات: {text}"
    assert 0 <= correct < 4, f"مؤشر خاطئ: {text}"
    BANK.setdefault((folder, topic), []).append({
        "situation": situation,
        "text": text,
        "options": options,
        "correctIndex": correct,
        "explanation": explanation,
        "source": source or topic,
    })


def write_all():
    import unicodedata
    import re

    def slug(folder, topic):
        raw = f"{folder}__{topic}"
        s = unicodedata.normalize("NFKC", raw)
        s = re.sub(r"[\s\-–—_/\\]+", "-", s.strip())
        s = re.sub(r"[^\w؀-ۿ\-]", "", s)
        return re.sub(r"-{2,}", "-", s).strip("-") or "bank"

    MANUAL.mkdir(parents=True, exist_ok=True)
    n = 0
    for (folder, topic), qs in sorted(BANK.items()):
        path = MANUAL / f"{slug(folder, topic)}.json"
        path.write_text(json.dumps(
            {"folder": folder, "topic": topic, "questions": qs},
            ensure_ascii=False, indent=1), encoding="utf-8")
        n += len(qs)
        print(f"{len(qs):4d}  {topic}  [{folder}]")
    print(f"wrote {len(BANK)} files, {n} questions -> {MANUAL}")