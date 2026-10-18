# -*- coding: utf-8 -*-
"""يضع شجرة التسليم على سطح المكتب: مجلد لكل محور رئيسي، ملف لكل محور فرعي.

    ~/Desktop/أسئلة المحاور/<المحور الرئيسي>/<المحور الفرعي>.txt

نفس قواعد tools/make_inbox_tree.py، لكن على سطح المكتب ليكون في المتناول.
المحوّل tools/import_manual.py يقرأ من هنا ومن داخل المشروع معاً.

    python tools/make_desktop_inbox.py
"""
import json
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
PROJECT = Path(__file__).resolve().parent.parent
MANIFEST = PROJECT / "assets" / "review_files" / "manifest.json"
DESKTOP = Path.home() / "Desktop"
ROOT_NAME = "أسئلة المحاور"
SKIP_FOLDERS = {"بنك الاسئلة"}  # مجلد وثائقي لملفات جاهزة، لا محور منهج

HEADER = """# المحور الفرعي: {topic}
# ضع أسئلتك أسفل هذا السطر، وافصل بين كل سؤال وآخر بسطر من الشرطات.
# صيغة السؤال: الوضعية / السؤال / أ ب ج د / الإجابة / الشرح.
"""


def main():
    root = DESKTOP / ROOT_NAME
    root.mkdir(parents=True, exist_ok=True)
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    folders = made = 0
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
        d = root / folder.strip()
        d.mkdir(parents=True, exist_ok=True)
        folders += 1
        for topic in topics:
            f = d / f"{topic}.txt"
            if not f.exists():
                f.write_text(HEADER.format(topic=topic), encoding="utf-8")
                made += 1
        readme = d / "_اقرأني.txt"
        if not readme.exists():
            readme.write_text(
                f"المحور الرئيسي: {folder.strip()}\n"
                "افتح أي ملف هنا واكتب أسئلتك تحته، ثم شغّل:\n"
                "    python tools/import_manual.py\n\n"
                "الصيغة:\n"
                "الوضعية: ...\nالسؤال: ...\n"
                "أ) ... ب) ... ج) ... د) ...\n"
                "الإجابة: ب\nالشرح: ...\n",
                encoding="utf-8")
        print(f"{folder.strip()}: {len(topics)} محور فرعي")
    print(f"\n{folders} مجلد رئيسي، {made} ملف جديد -> {root}")


if __name__ == "__main__":
    main()