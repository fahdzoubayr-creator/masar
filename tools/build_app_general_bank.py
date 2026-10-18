# -*- coding: utf-8 -*-
"""بناء ملف واحد يجمع كل الأسئلة الجيدة الموجودة في التطبيق: bank_general.json"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import question_quality as qq  # noqa

PROJECT = Path(__file__).resolve().parent.parent
BANKS = PROJECT / "assets" / "banks"


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


def main():
    out = []
    seen = set()
    for fp in sorted(BANKS.glob("*.json")):
        if fp.name in ("topics_index.json", "bank_general.json"):
            continue
        try:
            d = json.loads(fp.read_text(encoding="utf-8"))
        except Exception:
            continue
        qs = []
        if isinstance(d, dict) and isinstance(d.get("questions"), list):
            qs = d["questions"]
        elif isinstance(d, dict) and d and all(isinstance(v, list) for v in d.values()):
            for cat, items in d.items():
                for q in items:
                    if isinstance(q, dict):
                        q = dict(q)
                        q.setdefault("source_bank", fp.name)
                        q.setdefault("subject", cat)
                        qs.append(q)
        elif isinstance(d, dict):
            for v in d.values():
                if isinstance(v, list):
                    qs.extend(v)
        elif isinstance(d, list):
            qs = d
        for q in qs:
            if not isinstance(q, dict):
                continue
            if not looks_ok(q):
                continue
            key = (q.get("text") or "").strip()
            if not key or key in seen:
                continue
            seen.add(key)
            qqn = dict(q)
            qqn.setdefault("source_bank", fp.name)
            out.append(qqn)
    dst = BANKS / "bank_general.json"
    dst.write_text(json.dumps({"folder": "عام", "topic": "بنك عام",
                              "questions": out}, ensure_ascii=False, indent=1),
                   encoding="utf-8")
    print(f"كتبت {len(out)} سؤال في: {dst}")
    print(dst)


if __name__ == "__main__":
    main()