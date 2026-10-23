# -*- coding: utf-8 -*-
"""يفحص البنوك اليدوية: أرقام التغطية + كشف أي نص مشوّه أو ناقص.

    python tools/check_manual.py            # تقرير كامل
    python tools/check_manual.py --strict   # خروج بـ1 إن وُجد خلل
    python tools/check_manual.py --dir <مجلد>  # فحص مجلد مؤقت (للاختبار)

يكشف: حروف لاتينية، تلف التكرار («الشرح الشرح»)، محارف بديلة، خيارات
ناقصة/مكررة، مؤشر إجابة خارج المدى، شرح فارغ أو مكرر، إحالة إلى
«النص/المقتطف»، خيار وصفي، وتسريب الإجابة داخل السؤال.
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import question_quality as qq  # noqa: E402

PROJECT = Path(__file__).resolve().parent.parent
MANUAL = PROJECT / "assets" / "banks" / "manual"
INDEX = PROJECT / "assets" / "banks" / "topics_index.json"

LATIN = re.compile(r"[A-Za-z]")
REPLACEMENT = re.compile(r"\ufffd|\u0640{2,}")
# تكرار كلمة مباشرة: «إعادة الشرح الشرح»، «ترتيبBACtertNo».
REPEAT_WORD = re.compile(r"([\u0600-\u06FF]{2,})\s+\1(?:\s|$)")
# ثلاث حروف متطابقة متتالية (تلف كتابي).
TRIPLE = re.compile(r"(.)\1\1")
# كلمة عربية لحرف واحد أو حرفين مكررة (إعادة خطأ مثل «التENSE»).
ORPHAN = re.compile(r"(?:^|\s)([\u0600-\u06FF]{1,2})(?:\s|$)")
# خيار «كل الأجوبة السابقة خاطئة» بكل صيغه.
ALL_WRONG = re.compile(
    r"^(?:كل|جميع)\s+(?:الأجوبة|الإجابات|الاختيارات|الخيارات|الاقتراحات)"
    r"\s+(?:السابقة|المقترحة|أعلاه)\s+خاطئة?\.?$")


def main():
    strict = "--strict" in sys.argv
    manual_dir = MANUAL
    if "--dir" in sys.argv:
        manual_dir = Path(sys.argv[sys.argv.index("--dir") + 1])
    problems = []
    files = sorted(manual_dir.glob("*.json"))
    total = 0
    answers_seen = Counter()
    for f in files:
        d = json.loads(f.read_text(encoding="utf-8"))
        qs = d.get("questions") or []
        folder = (d.get("folder") or "").strip()
        total += len(qs)
        seen_text = Counter()
        for i, qo in enumerate(qs):
            tag = f"{f.name}#{i}"
            text = (qo.get("text") or "").strip()
            opts = qo.get("options") or []
            ci = qo.get("correctIndex")
            if len(opts) not in (3, 4, 5):
                problems.append(f"{tag}: خيارات={len(opts)} :: {text[:40]}")
            if len(opts) == 5 and not (
                    isinstance(ci, int) and 0 <= ci < 5
                    and ALL_WRONG.match((opts[ci] or "").strip())):
                problems.append(f"{tag}: خيار خامس غير مطابق :: {text[:40]}")
            if not isinstance(ci, int) or not (0 <= ci < len(opts)):
                problems.append(f"{tag}: مؤشر={ci} :: {text[:40]}")
            if not (qo.get("explanation") or "").strip():
                problems.append(f"{tag}: شرح فارغ :: {text[:40]}")
            blob = " | ".join([text, qo.get("situation") or ""]
                              + [o or "" for o in opts])
            # أسئلة الفرنسية: اللاتينية مباحة فيها بقرار المستخدم.
            if LATIN.search(blob) and folder != "ديداكتيك اللغة الفرنسية":
                problems.append(f"{tag}: نص لاتيني :: {text[:60]}")
            if REPLACEMENT.search(blob):
                problems.append(f"{tag}: محرف بديل/تطويل :: {text[:60]}")
            if REPEAT_WORD.search(blob):
                m = REPEAT_WORD.search(blob)
                problems.append(f"{tag}: تكرار كلمة «{m.group(1)}» :: {text[:50]}")
            if TRIPLE.search(blob):
                problems.append(f"{tag}: ثلاث حروف متطالية :: {text[:50]}")
            if qq.DEICTIC_ANY.search(text):
                problems.append(f"{tag}: إحالة إشارية :: {text[:60]}")
            if any(qq.CATCH_ALL.search(o or "")
                   for i, o in enumerate(opts) if i != ci):
                problems.append(f"{tag}: خيار وصفي :: {text[:40]}")
            no = [qq.norm(o) for o in opts]
            if len(set(no)) < len(no):
                problems.append(f"{tag}: خيارات مكررة :: {text[:40]}")
            lens = [len(o or "") for o in opts]
            others = sorted(lens[:ci] + lens[ci + 1:]) if isinstance(ci, int) and ci < len(lens) else []
            if (others and not qo.get("answerMarked")
                    and lens[ci] == max(lens)
                    and max(lens) - others[-1] >= 14):
                problems.append(f"{tag}: الإجابة الأطول وحدها :: {text[:40]}")
            dt = (qq.tokens(opts[ci])
                  if isinstance(ci, int) and ci < len(opts) else set())
            ct = qq.tokens(f"{text} {qo.get('situation') or ''}")
            sh = len(dt & ct)
            is_aw = (isinstance(ci, int) and ci < len(opts)
                     and (ALL_WRONG.match((opts[ci] or "").strip())
                          or qq.CATCH_ALL.search(opts[ci] or "")))
            if not is_aw and (sh >= 4 or (len(dt) >= 3
                                          and sh / len(dt) >= 0.5)):
                problems.append(f"{tag}: تسريب الإجابة :: {text[:40]}")
            if (isinstance(ci, int) and 0 <= ci < len(opts)
                    and not ALL_WRONG.match((opts[ci] or "").strip())):
                answers_seen[ci] += 1
            seen_text[qq.norm(text)] += 1

    # تكرار السؤال داخل نفس البنك (يُحذف المكرر عند الدمج، لكن ننبّه).
    for f in files:
        d = json.loads(f.read_text(encoding="utf-8"))
        texts = Counter(qq.norm((q.get("text") or "")) for q in d.get("questions") or [])
        for t, n in texts.items():
            if n > 1:
                problems.append(f"{f.name}: سؤال مكرر {n} مرات :: {t[:50]}")

    covered = []
    if INDEX.exists():
        idx = json.loads(INDEX.read_text(encoding="utf-8"))
        covered = [e for e in idx.get("topics", [])]

    print(f"manual files={len(files)}  questions={total}")
    for f in files:
        d = json.loads(f.read_text(encoding="utf-8"))
        print(f"  {len(d.get('questions') or []):4d}  "
              f"{(d.get('topic') or '')[:46]:46s} [{d.get('folder')}]")
    print(f"problems={len(problems)}")
    for p in problems[:60]:
        print("  -", p)
    # توزّع الإجابة على الخيارات: التحيّز سالب إن ركّزت في موضع واحد.
    if total >= 20 and answers_seen:
        top, n = answers_seen.most_common(1)[0]
        if n / total > 0.45:
            problems.append(f"تحيّز موضع الإجابة: الخيار {top + 1} في "
                            f"{n}/{total} من الأسئلة")
            print(f"  ! تحيّز موضع الإجابة: الخيار {top + 1} في {n}/{total}")
    if covered:
        print(f"index topics={len(covered)} "
              f"questions={sum(e['count'] for e in covered)}")

    # ===== تقدّم التأليف مقابل هدف 100+ سؤال لكل محور =====
    manifest = PROJECT / "assets" / "review_files" / "manifest.json"
    target = 100
    have = {e["key"]: e["count"] for e in covered}
    rows = []
    if manifest.exists() and "--dir" not in sys.argv:
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for folder, entries in data.items():
            if not isinstance(entries, list):
                continue
            # «بنك الاسئلة» مجلد وثائقي (ملفات أسئلة جاهزة)، لا محور منهج.
            if folder.strip() == "بنك الاسئلة":
                continue
            for e in entries:
                topic = ((e.get("topic") or folder) if isinstance(e, dict)
                         else folder).strip()
                key = f"{folder}::{topic}"
                if key not in [r[0] for r in rows]:
                    rows.append((key, have.get(key, 0)))
    done = [r for r in rows if r[1] >= target]
    if not rows:
        return 1 if (strict and problems) else 0
    print(f"\n--- هدف {target}+ سؤال لكل محور ---")
    print(f"محاور جاهزة={len(done)}/{len(rows)}  "
          f"الأسئلة المكتوبة={sum(r[1] for r in rows)}  "
          f"المتبقي={sum(max(0, target - r[1]) for r in rows)}")
    for key, n in sorted(rows, key=lambda r: r[1]):
        flag = 'OK ' if n >= target else '   '
        print(f"  {flag}{n:5d}  {key}")
    return 1 if (strict and problems) else 0


if __name__ == "__main__":
    sys.exit(main())