# -*- coding: utf-8 -*-
"""جرد مصادر الأسئلة المتاحة: بنك مدمج، مخرجات مولّدة، وبنوك موضوعية."""
import json
import sys
from collections import Counter
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
ROOT = Path(__file__).resolve().parent.parent
BANKS = ROOT / "assets" / "banks"


def count(path):
    try:
        d = json.loads(path.read_text(encoding="utf-8"))
    except Exception as ex:
        return f"unreadable: {ex}"
    if isinstance(d, dict):
        if isinstance(d.get("questions"), list):
            return f"{len(d['questions'])} questions | subject={d.get('subject')}"
        if all(isinstance(v, list) for v in d.values()):
            n = sum(len(v) for v in d.values())
            return f"map of {len(d)} keys / {n} questions"
        return f"dict keys={list(d)[:5]}"
    if isinstance(d, list):
        return f"list of {len(d)}"
    return type(d).__name__


print("=== banks/generated ===")
for f in sorted((BANKS / "generated").glob("*.json")):
    d = json.loads(f.read_text(encoding="utf-8"))
    qs = d.get("questions") if isinstance(d, dict) else d
    subs = Counter(str(q.get("subject"))[:44] for q in (qs or []))
    print(f"{f.name}: {count(f)}")
    print("   subjects:", dict(subs.most_common(8)))
    if qs:
        print("   keys:", list(qs[0].keys()))

print("\n=== generated_jobs sample ===")
files = sorted((BANKS / "generated_jobs").glob("*.json"))
print("files:", len(files))
tot = 0
for f in files[:3]:
    d = json.loads(f.read_text(encoding="utf-8"))
    qs = d.get("questions") or []
    tot += len(qs)
    print(f"  {f.name}: keys={list(d)} n={len(qs)}")
    if qs:
        print("     first keys:", list(qs[0].keys()))
        print("     source sample:", qs[0].get("source"))

print("\n=== per-topic quiz files on disk ===")
pat = list((ROOT / "assets" / "review_files").rglob("*quiz*.json"))
print("quiz json files:", len(pat))
for p in pat[:10]:
    print("  ", p.relative_to(ROOT))

print("\n=== banks by size (top) ===")
for f in sorted(BANKS.glob("*.json"), key=lambda x: -x.stat().st_size)[:8]:
    print(f"{f.stat().st_size:9d}  {f.name}: {count(f)}")