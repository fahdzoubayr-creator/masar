#!/usr/bin/env python3
import json, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
with open(r"D:\masar_app\masar_app\tools\ai_review\validated_questions.json", encoding="utf-8") as f:
    data = json.load(f)
for bk, bd in data["banks"].items():
    print(f"=== {bk} ===")
    for q in bd["questions"][:3]:
        v = q.get("_verdict", "?")
        ch = q.get("_changes", [])
        txt = q.get("text", "")[:80]
        opts = q.get("options", [])
        ci = q.get("correctIndex", "?")
        exp = q.get("explanation", "")[:100]
        print(f"  verdict: {v}")
        if ch:
            for c in ch:
                print(f"    -> {c}")
        print(f"  text: {txt}")
        print(f"  opts({len(opts)}): {opts[:2]}")
        print(f"  correctIndex: {ci}")
        print(f"  explanation: {exp}")
        print()
