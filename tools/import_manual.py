# -*- coding: utf-8 -*-
"""يحوّل ملفات assets/banks/manual_inbox/ إلى بنوك manual/<مفتاح>.json.

المدخل المقبول:
  1) نص عربي بالتعريفات التالية (الافتراضي):
       # المجلد: ...      # المحور: ...
       الوضعية: ...       السؤال: ...
       أ) ... ب) ... ج) ... د) ...
       الإجابة: ب         الشرح: ...
  2) JSON: {folder, topic, questions:[{situation,text,options,correctIndex,explanation}]}

ثم يشغّل build_topic_banks.py تلقائياً ليحدّث بنوك التشغيل والفهرس.

    python tools/import_manual.py            # استيراد + بناء
    python tools/import_manual.py --no-build # استيراد فقط
"""
import json
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

PROJECT = Path(__file__).resolve().parent.parent
INBOX = PROJECT / "assets" / "banks" / "manual_inbox"
DESKTOP_INBOX = Path.home() / "Desktop" / "أسئلة المحاور"
MANUAL = PROJECT / "assets" / "banks" / "manual"

SEP = re.compile(r"^\s*[-=_*]{3,}\s*$")
OPTION_LETTER = re.compile(r"^([أبجدهوزحطيكلمنسف])(?:\s*[).\-:]\s*|\s+)(.+)$")
HEAD_RE = re.compile(r"^#\s*(المجلد|المحور)\s*:\s*(.+)$")
ANSWER_RE = re.compile(r"^(?:الإجابة|الجواب)\s*:\s*(.+)$")
EXPLAIN_RE = re.compile(r"^(?:الشرح|التعليل)\s*:\s*(.+)$")
ANSWER_MAP = {
    "ا": 0, "أ": 0, "إ": 0, "آ": 0, "1": 0,
    "ب": 1, "2": 1,
    "ج": 2, "3": 2,
    "د": 3, "4": 3,
}


def slug(folder, topic):
    raw = unicodedata.normalize("NFKC", f"{folder}__{topic}")
    s = re.sub(r"[\s\-_/\\]+", "-", raw.strip())
    s = re.sub(r"[^\w\u0600-\u06FF\-]", "", s)
    return re.sub(r"-{2,}", "-", s).strip("-") or "bank"


def parse_text(raw):
    """يحوّل نص القالب إلى (folder, topic, [questions])."""
    folder = topic = None
    blocks, cur = [], []
    for line in raw.splitlines():
        if SEP.match(line):
            if cur:
                blocks.append(cur)
                cur = []
            continue
        cur.append(line)
    if cur:
        blocks.append(cur)

    questions, errors = [], []
    for n, lines in enumerate(blocks, 1):
        rec, letter = {"situation": "", "text": "", "options": [],
                       "correctIndex": -1, "explanation": ""}, None
        for line in lines:
            t = line.strip()
            if not t:
                continue
            if t.startswith("#"):
                m = HEAD_RE.match(t)
                if m:
                    if m.group(1) == "المجلد":
                        folder = m.group(2).strip()
                    else:
                        topic = m.group(2).strip()
                continue
            for key, field in (("الوضعية:", "situation"),
                               ("السؤال:", "text")):
                if t.startswith(key):
                    rec[field] = t[len(key):].strip()
                    break
            else:
                m = OPTION_LETTER.match(t)
                if m:
                    rec["options"].append(m.group(2).strip())
                    letter = ANSWER_MAP.get(m.group(1), -1)
                    continue
                m = ANSWER_RE.match(t)
                if m:
                    v = m.group(1).strip()
                    rec["correctIndex"] = (ANSWER_MAP.get(v, -1)
                                           if len(v) <= 2 else -1)
                    continue
                m = EXPLAIN_RE.match(t)
                if m:
                    rec["explanation"] = m.group(1).strip()
                    continue
                errors.append(f"سطر غير معروف: {t[:50]}")
        if (rec["correctIndex"] is None or rec["correctIndex"] < 0) \
                and letter is not None and letter >= 0 and rec["options"]:
            rec["correctIndex"] = letter
        if not rec["text"]:
            continue
        if len(rec["options"]) != 4 or rec["correctIndex"] < 0:
            errors.append(
                f"سؤال «{rec['text'][:40]}»: خيارات={len(rec['options'])} "
                f"إجابة={rec['correctIndex']}")
            continue
        questions.append(rec)
    return folder, topic, questions, errors


def main():
    MANUAL.mkdir(parents=True, exist_ok=True)
    no_build = "--no-build" in sys.argv
    # مصادر الاستقبال: سطح المكتب أولاً، ثم داخل المشروع.
    roots = [r for r in (DESKTOP_INBOX, INBOX) if r.is_dir()]
    files = []
    for root in roots:
        for f in sorted(root.rglob("*")):
            if not f.is_file() or f.name.startswith("_"):
                continue
            if f.suffix.lower() not in (".txt", ".md", ".json"):
                continue
            files.append(f)
    if not files:
        print("لا ملفات أسئلة. ضعها في:")
        print(f"  {DESKTOP_INBOX}")
        return 0
    total = 0
    for f in files:
        raw = f.read_text(encoding="utf-8")
        # المسار هو المصدر: مجلد = المحور الرئيسي، ملف = المحور الفرعي.
        root = DESKTOP_INBOX if DESKTOP_INBOX in f.parents else INBOX
        rel = f.relative_to(root)
        from_path_folder = rel.parts[0].strip() if len(rel.parts) > 1 else ""
        from_path_topic = (f.stem if len(rel.parts) > 1
                           else (rel.parts[0].rsplit(".", 1)[0]))
        if f.suffix.lower() == ".json":
            d = json.loads(raw)
            folder = (d.get("folder") or from_path_folder).strip()
            topic = (d.get("topic") or from_path_topic).strip()
            qs = d.get("questions") or []
            errs = []
        else:
            folder, topic, qs, errs = parse_text(raw)
            # المسار يغلب ما ورد في الترويسة، فهو الأدقّ.
            if from_path_folder:
                folder = from_path_folder
            if from_path_topic and (not topic or from_path_topic != "manual"):
                topic = from_path_topic
        if not folder or not topic:
            print(f"skip {rel}: مجلد أو محور غير محدد")
            continue
        path = MANUAL / f"{slug(folder, topic)}.json"
        old = {}
        if path.exists():
            old = json.loads(path.read_text(encoding="utf-8"))
        have = {q.get("text", "").strip() for q in old.get("questions") or []}
        added = [q for q in qs if q.get("text", "").strip() not in have]
        merged = (old.get("questions") or []) + added
        # لا ننشئ بنكاً فارغاً: يُبنى عند أول سؤال يُضاف إليه.
        if merged:
            path.write_text(json.dumps(
                {"folder": folder, "topic": topic, "questions": merged},
                ensure_ascii=False, indent=1), encoding="utf-8")
        elif path.exists():
            path.unlink()
        total += len(added)
        if added:
            print(f"{rel}: +{len(added)} "
                  f"(البنك الآن {len(merged)})  {topic} [{folder}]")
        for e in errs[:10]:
            print("   !", e)
    print(f"imported {total} new questions")

    # بوابة الجودة قبل البناء: لا يدخل البنك إلا ما اجتاز الفحص.
    gate = subprocess.run([sys.executable,
                           str(PROJECT / "tools" / "check_manual.py"),
                           "--strict"], capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    if gate.stdout:
        print(gate.stdout)
    if gate.returncode != 0:
        print("توقّف: البنوك اليدوية فيها أخطاء. صحّح ثم أعد التشغيل.")
        return 2
    print("البوابة مرّت: لا تلف ولا تسريب. يُكمل البناء…")
    if not no_build:
        r = subprocess.run([sys.executable,
                            str(PROJECT / "tools" / "build_topic_banks.py")])
        return r.returncode
    return 0


if __name__ == "__main__":
    sys.exit(main())