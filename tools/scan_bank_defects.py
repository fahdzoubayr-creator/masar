# -*- coding: utf-8 -*-
"""مسح سريع لأنماط الرذالة المتبقية في بنك المحاور (للتشخيص فقط)."""
import json
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
BANK = Path(__file__).resolve().parent.parent / "assets" / "banks" / "topics.json"

d = json.loads(BANK.read_text(encoding="utf-8"))
pats = {
    "latin": re.compile(r"[A-Za-z]{2,}"),
    "latin_digits": re.compile(r"[A-Za-z]{2,}\d{2,}"),
    "deictic_any": re.compile(r"(?:المقتطف|المقتطفات|النص|الفقرة|المعطى|المعطيات)"),
    "dash_ref": re.compile(r"\b(?:ب|و)\s+—\s+حسب"),
    "noise_ref": re.compile(r"مهم\s+جدا"),
    "no_situation": None,
    "open_end": re.compile(r"(?:ب|و|،|,)\s*$"),
    "empty_exp": re.compile(r"^$"),
}
counts = {k: 0 for k in pats}
samples = {k: [] for k in pats}
for t, qs in d.items():
    for q in qs:
        blob = " ".join([q["text"], q.get("situation") or ""] + list(q["options"]))
        for k, p in pats.items():
            if p is None:
                continue
            if p.search(blob) or (k in ("dash_ref", "open_end") and p.search(q["text"])):
                counts[k] += 1
                if len(samples[k]) < 4:
                    samples[k].append((t, q["text"][:90]))
        if not (q.get("situation") or "").strip():
            counts["no_situation"] += 1
for k, v in counts.items():
    print(f"{k:14s} {v:5d}")
    for s in samples[k]:
        print("      ", s[0][:28], "|", s[1])