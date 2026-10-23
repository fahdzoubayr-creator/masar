# -*- coding: utf-8 -*-
"""فحص: لماذا لا تُلتقط الإحالات الإشارية الباقية داخل البنك؟"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.stdout.reconfigure(encoding="utf-8")

import question_quality as qq  # noqa: E402

BANK = Path(__file__).resolve().parent.parent / "assets" / "banks" / "topics.json"
data = json.loads(BANK.read_text(encoding="utf-8"))
hits = 0
for topic, qs in data.items():
    for q in qs:
        blob = q["text"] + " " + (q.get("situation") or "") + " " + " ".join(q["options"])
        m = re.search(r"\S*(?:المقتطف|النص|الفقرة|المعطى|المعطيات)\S*", blob)
        if m:
            hits += 1
            if hits <= 6:
                print("FOUND:", repr(m.group(0)), "| in text:", m.group(0) in q["text"])
                print("  pattern_match:", bool(qq.DEICTIC_ANY.search(m.group(0))))
                print("  text:", q["text"][:100])
print("total_hits =", hits)