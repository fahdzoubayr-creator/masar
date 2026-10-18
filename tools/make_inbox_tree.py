# -*- coding: utf-8 -*-
"""ينشئ شجرة التسليم: مجلد لكل محور رئيسي، وداخله ملف لكل محور فرعي.

    assets/banks/manual_inbox/<المحور الرئيسي>/<المحور الفرعي>.txt

المسار نفسه هو المصدر: اسم المجلد = المحور الرئيسي، واسم الملف = المحور
الفرعي. فلا حاجة لكتابة # المجلد: داخل الملف، ولا خطر في اختلاط الانتماء.
"""
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = Path(__file__).resolve().parent.parent
INBOX = PROJECT / "assets" / "banks" / "manual_inbox"
MANIFEST = PROJECT / "assets" / "review_files" / "manifest.json"
SKIP_FOLDERS = {"بنك الاسئلة"}  # مجلد وثائقي لملفات أسئلة جاهزة، لا محور منهج

HEADER = """# المحور الفرعي: {topic}
# ضع أسئلتك أسفل هذا السطر، وافصل بين كل سؤال وآخر بسطر من الشرطات.
# صيغة السؤال: الوضعية / السؤال / أ ب ج د / الإجابة / الشرح.
"""


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    made = 0
    folders = 0
    for folder, entries in data.items():
        if folder.strip() in SKIP_FOLDERS:
            continue
        topics = []
        for e in entries:
            topic = ((e.get("topic") or folder) if isinstance(e, dict)
                     else folder).strip()
            if topic not in topics:
                topics.append(topic)
        if not topics:
            continue
        fd = INBOX / folder.strip()
        fd.mkdir(parents=True, exist_ok=True)
        folders += 1
        for topic in topics:
            f = fd / f"{topic}.txt"
            if not f.exists():
                f.write_text(HEADER.format(topic=topic), encoding="utf-8")
                made += 1
        print(f"{folder}: {len(topics)} محور فرعي")
    print(f"\n{folders} مجلد رئيسي، {made} ملف جديد -> {INBOX}")


if __name__ == "__main__":
    main()