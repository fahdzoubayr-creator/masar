# -*- coding: utf-8 -*-
"""يكشف أي حرف لاتيني داخل نص عربي في ملفات الأدوات (تلف كتابي شائع)."""
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
AR = re.compile(r"[\u0600-\u06FF]")
LAT = re.compile(r"[A-Za-z]")

targets = sys.argv[1:] or [
    "tools/selftest_check_manual.py",
    "tools/check_manual.py",
    "assets/banks/manual_inbox/_TEMPLATE.txt",
]
bad = 0
for t in targets:
    p = Path(t)
    if not p.exists():
        print("missing", t)
        continue
    for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
        
        code = re.sub(r'"[^"]*"|\'[^\']*\'', "", line)
        if AR.search(line) and LAT.search(line):
            # نراجع فقط الكلمات المدمجة: حرف لاتيني ملتصق بحرف عربي
            if re.search(r"[\u0600-\u06FF][A-Za-z]|[A-Za-z][\u0600-\u06FF]", line):
                print(f"{t}:{i}  {line.strip()[:110]}")
                bad += 1
print("mixed_script_hits =", bad)
sys.exit(1 if bad else 0)