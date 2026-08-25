#!/usr/bin/env python3
"""Merge locally-uploaded review PDFs with the legacy cloud manifest.

The legacy manifest (git history) carries rich metadata per file:
    {pdf, txt, name, quiz, topic}
while the fresh upload only knows folder + original filename. This tool
re-attaches topic/txt/quiz/name to every uploaded file by fuzzy-matching
titles inside the same folder, so the app's subtopic filtering keeps working.

Output overwrites tools/release_manifest.json (UTF-8, ensure_ascii=False).
"""

from __future__ import annotations

import difflib
import json
import os
import re
import subprocess
import sys

PROJECT = r"D:\masar_app\masar_app"
OLD_REF = "0756247~1:assets/review_files/manifest.json"


def norm(s: str) -> str:
    s = s.lower()
    s = re.sub(r"^[\s\-_–—]+", "", s)          # leading "-4 -" style junk
    s = re.sub(r"[\(\[\{].*?[\)\]\}]", " ", s)  # bracketed bits
    s = re.sub(r"[_\-–—.,؛;:!؟?'\"«»()]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    table = str.maketrans({"أ": "ا", "إ": "ا", "آ": "ا", "ى": "ي", "ة": "ه"})
    return s.translate(table)


def clean_title(fn: str) -> str:
    t = os.path.splitext(os.path.basename(fn))[0]
    t = re.sub(r"^[\s\-_–—]+\d*[\s\-_–—]*", "", t).strip()
    return t or os.path.splitext(os.path.basename(fn))[0]


def main() -> int:
    src = os.environ.get("SRC_DIR")
    if not src or not os.path.isdir(src):
        print("ERROR: set SRC_DIR", file=sys.stderr)
        return 2

    raw = subprocess.run(
        ["git", "-C", PROJECT, "show", OLD_REF], capture_output=True
    ).stdout
    if not raw:
        print("ERROR: cannot read old manifest from git", file=sys.stderr)
        return 2
    old = json.loads(raw.decode("utf-8"))

    current = json.load(
        open(os.path.join(PROJECT, "tools", "release_manifest.json"), encoding="utf-8")
    )

    merged = {}
    stats = {"matched": 0, "fuzzy": 0, "unmatched": 0}
    for folder, entries in current.items():
        old_entries = old.get(folder, [])
        # index old titles for this folder
        old_idx = []
        for e in old_entries:
            title = e["name"].split("\\")[-1].split("/")[-1]
            old_idx.append((norm(title), e))
        out = []
        used = set()
        for e in entries:
            fname = e["name"]
            key = norm(fname)
            best_i, best_r = -1, 0.0
            for i, (nk, _) in enumerate(old_idx):
                if i in used or not nk:
                    continue
                r = difflib.SequenceMatcher(None, key, nk).ratio()
                if r > best_r:
                    best_i, best_r = i, r
            new_e = {
                "pdf": e["pdf"],
                "txt": None,
                "name": clean_title(fname),
                "quiz": True,
            }
            if best_r >= 0.80:
                src_e = old_idx[best_i][1]
                used.add(best_i)
                new_e.update({
                    "name": src_e["name"],
                    "topic": src_e.get("topic"),
                    "quiz": src_e.get("quiz", True),
                    "txt": src_e.get("txt"),
                })
                stats["matched"] += 1
            elif best_r >= 0.60:
                src_e = old_idx[best_i][1]
                used.add(best_i)
                new_e.update({
                    "name": src_e["name"],
                    "topic": src_e.get("topic"),
                    "quiz": src_e.get("quiz", True),
                    "txt": src_e.get("txt"),
                })
                stats["fuzzy"] += 1
            else:
                stats["unmatched"] += 1
            if not new_e.get("topic"):
                new_e.pop("topic", None)
            if not new_e.get("txt"):
                new_e.pop("txt", None)
            out.append(new_e)
        # keep legacy numbering order by number in pdf path
        out.sort(key=lambda x: x["pdf"])
        merged[folder] = out

    dst = os.path.join(PROJECT, "tools", "release_manifest.json")
    with open(dst, "w", encoding="utf-8") as fh:
        json.dump(merged, fh, ensure_ascii=False, indent=1)
    total = sum(len(v) for v in merged.values())
    print(f"folders={len(merged)} entries={total} stats={stats}")
    print("written:", dst)
    return 0


if __name__ == "__main__":
    sys.exit(main())
