# -*- coding: utf-8 -*-
"""جرد كل بنك أسئلة داخل التطبيق: كم سؤالاً في كل ملف، وكم يمرّ فحص الجودة.

    python tools/inventory_app_banks.py
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
BANKS = PROJECT / "assets" / "banks"
PAGE_TAIL = re.compile(r"\s*[(\[][^)\]]*(?:صفحة|صفحات|ص|صـ)[^)\]]*[)\]]\s*$")


def norm(s):
    return re.sub(r"\s+", " ", str(s or "").strip())


def looks_ok(qo):
    if not isinstance(qo, dict):
        return False
    text = (qo.get("text") or "").strip()
    opts = qo.get("options")
    ci = qo.get("correctIndex")
    if len(text) < 20 or len(text) > 400:
        return False
    if not isinstance(opts, list) or len(opts) < 3:
        return False
    if not isinstance(ci, int) or not (0 <= ci < len(opts)):
        return False
    if any((o or "").strip() in ("", "...") for o in opts):
        return False
    if not (qo.get("explanation") or "").strip():
        return False
    if re.search(r"[A-Za-z]", " ".join([text, *[o or "" for o in opts]])):
        return False
    if any(qq.CATCH_ALL.search(o or "") for o in opts):
        return False
    if qq.DEICTIC_ANY.search(text):
        return False
    return True


def count_reasons(qo):
    why = []
    if not (qo.get("explanation") or "").strip():
        why.append("شرح")
    if re.search(r"[A-Za-z]", " ".join([(qo.get("text") or ""),
                                         *[o or "" for o in qo.get("options") or []]])):
        why.append("لاتيني")
    if any(qq.CATCH_ALL.search(o or "") for o in qo.get("options") or []):
        why.append("خيار وصفي")
    if qq.DEICTIC_ANY.search(qo.get("text") or ""):
        why.append("إحالة")
    if not why:
        why.append("تسريب/نمط/أطول")
    return why


def main():
    files = [f for f in sorted(BANKS.glob("*.json"))
             if f.name not in ("topics_index.json",)]
    total_all = total_ok = 0
    print(f"{'ملف':38s} {'أسئلة':>7s} {'جيدة':>7s}  {'مصدر':<22s}")
    for f in files:
        try:
            d = json.loads(f.read_text(encoding="utf-8"))
        except Exception as ex:
            print(f"{f.name:38s}  (!) {ex}")
            continue
        qs = []
        if isinstance(d, dict) and isinstance(d.get("questions"), list):
            qs = d["questions"]
        elif isinstance(d, dict) and d and all(
                isinstance(v, list) for v in d.values()):
            # شكل «{اسم المحور: [أسئلة]}» وهوformas的文件多数。
            for cat, items in d.items():
                for q in items:
                    if isinstance(q, dict):
                        q = dict(q)
                        q.setdefault("subject", cat)
                        qs.append(q)
        elif isinstance(d, dict):
            for v in d.values():
                if isinstance(v, list):
                    qs.extend(v)
        elif isinstance(d, list):
            qs = d
        ok = [q for q in qs if looks_ok(q)]
        total_all += len(qs)
        total_ok += len(ok)
        subs = Counter(norm(q.get("subject") or "") for q in ok)
        top = "، ".join(f"{k[:18]}({v})" for k, v in subs.most_common(2))
        print(f"{f.name:38s} {len(qs):7d} {len(ok):7d}  {top[:40]}")
    print(f"\nالمجموع: {total_all} سؤالاً، منها {total_ok} يمرّ الفحص البنيوي.")


if __name__ == "__main__":
    main()