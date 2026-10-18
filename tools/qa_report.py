# -*- coding: utf-8 -*-
"""تقرير جودة بنك المحاور: يعرض عيّنة من كل محور + توزيع أسباب الإسقاط.

الاستخدام:
    python tools/qa_report.py                 # عيّنة 3 لكل محور
    python tools/qa_report.py 8               # عيّنة 8
    python tools/qa_report.py 0 arask         # كل أسئلة أرسطو
"""
import json
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import question_quality as qq  # noqa: E402

BANK = Path(__file__).resolve().parent.parent / "assets" / "banks" / "topics.json"


def show(qo, mark="-"):
    print(f"{mark} [{qo.get('situation') or ''}]"[:150])
    print(f"  Q: {qo['text']}")
    for i, o in enumerate(qo["options"]):
        print(("   *" if i == qo["correctIndex"] else "    ") + f" {o}")
    print(f"  E: {(qo.get('explanation') or '')[:140]}")


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    needle = sys.argv[2] if len(sys.argv) > 2 else ""
    data = json.loads(BANK.read_text(encoding="utf-8"))
    print(f"topics={len(data)} questions={sum(len(v) for v in data.values())}")
    for topic, qs in data.items():
        reasons = [qq.drop_reason(q, topic) for q in qs]
        bad = [r for r in reasons if r]
        print(f"\n=== {topic} ({len(qs)}) === survivors_with_flaws={len(bad)}"
              f" {dict((r, bad.count(r)) for r in set(bad)) if bad else ''}")
        if needle:
            picked = [q for q in qs if needle in json.dumps(q, ensure_ascii=False)]
        else:
            picked = random.sample(qs, min(n, len(qs)))
        for qo in picked:
            show(qo)


if __name__ == "__main__":
    main()