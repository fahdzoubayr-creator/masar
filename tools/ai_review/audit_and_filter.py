#!/usr/bin/env python3
"""
audit_and_filter.py — Static audit of all question banks + filtered JSON export.

Replicates the Dart QuestionValidator logic offline:
  - empty text
  - garbled/mojibake text (UTF-8 corruption, CJK, control chars)
  - invalid option count (not 4 or 5)
  - duplicate options within a question
  - empty options
  - invalid correctIndex (out of range)
  - empty explanation

Usage:
    python audit_and_filter.py [--bank-dir DIR] [--output DIR]

Outputs:
    1. audit_report.json    — full stats, per-bank breakdown, reason counts
    2. filtered_questions.json — clean questions only (ready for AI validation)
    3. rejected_questions.json — broken questions with rejection reasons
    4. console summary
"""

import os
import re
import json
import sys
import io
import argparse
from pathlib import Path
from collections import defaultdict

# Force UTF-8
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

BANK_DIR = Path(r"D:\masar_app\masar_app\lib\core\data")
OUTPUT_DIR = Path(r"D:\masar_app\masar_app\tools\ai_review")

SKIP_FILES = {
    "popular_bank_data.dart",
    "wadiaa_bank_data.dart",
    "professional_bank_data.dart",
}

# ─── Garbled text detection (mirrors Dart QuestionValidator) ───
GARBLED_RE = re.compile(
    r'[\u0000-\u0008\u000B\u000C\u000E-\u001F'
    r'\u200B-\u200F\u2028-\u202F\u2060-\u2069'
    r'\u4E00-\u9FFF\u3400-\u4DBF'
    r'\uFFFD\uFFFE\uFFFF]'
)

MOJIBAKE_RE = re.compile(
    r'(?:Ø§Ù|ÙØ§|Ø§Ù„|Ù…Ø§|ÙŠÙ†|Ø¹Ù„|Ã)'
)


def extract_string_value(text, key):
    """Extract a string value from Dart code, handling escaped quotes."""
    for quote in ["'", '"']:
        pattern = rf"{key}\s*:\s*{quote}"
        m = re.search(pattern, text)
        if not m:
            continue
        start = m.end()
        buf = []
        i = start
        while i < len(text):
            ch = text[i]
            if ch == "\\" and i + 1 < len(text):
                nxt = text[i + 1]
                if nxt == quote:
                    buf.append(quote)
                elif nxt == "'":
                    buf.append("'")
                elif nxt == '"':
                    buf.append('"')
                elif nxt == "n":
                    buf.append("\n")
                elif nxt == "\\":
                    buf.append("\\")
                else:
                    buf.append(ch)
                    buf.append(nxt)
                i += 2
            elif ch == quote:
                break
            else:
                buf.append(ch)
                i += 1
        return "".join(buf).strip()
    return None


def extract_int_value(text, key):
    m = re.search(rf"{key}\s*:\s*(\d+)", text)
    return int(m.group(1)) if m else None


def parse_options_array(text):
    m = re.search(r"options\s*:\s*\[", text)
    if not m:
        return []
    start = m.end()
    depth = 1
    pos = start
    while pos < len(text) and depth > 0:
        if text[pos] == "[":
            depth += 1
        elif text[pos] == "]":
            depth -= 1
        pos += 1
    options_text = text[start:pos - 1]
    options = []
    i = 0
    n = len(options_text)
    while i < n:
        c = options_text[i]
        if c in ("'", '"'):
            quote = c
            i += 1
            buf = []
            while i < n:
                ch = options_text[i]
                if ch == "\\" and i + 1 < n:
                    nxt = options_text[i + 1]
                    if nxt == quote:
                        buf.append(quote)
                    elif nxt == "'":
                        buf.append("'")
                    elif nxt == '"':
                        buf.append('"')
                    elif nxt == "n":
                        buf.append("\n")
                    elif nxt == "\\":
                        buf.append("\\")
                    else:
                        buf.append(ch)
                        buf.append(nxt)
                    i += 2
                elif ch == quote:
                    i += 1
                    break
                else:
                    buf.append(ch)
                    i += 1
            options.append("".join(buf))
        elif c.isalpha() or c == "_":
            j = i
            while j < n and (options_text[j].isalnum() or options_text[j] in "_."):
                j += 1
            var_name = options_text[i:j]
            options.append(f"__ref__{var_name}")
            i = j
        else:
            i += 1
    return options


def parse_question_blocks(content):
    """Parse all Question(...) blocks from Dart source content.
    
    Uses a state machine that respects string boundaries so that
    parens/brackets inside string literals don't confuse the block parser.
    """
    questions = []
    pattern = re.compile(r'(?:const\s+)?Question\s*\(', re.MULTILINE)
    for m in pattern.finditer(content):
        start = m.start()
        depth = 1
        pos = m.end()
        in_string = None  # None = not in string, or the quote char
        while pos < len(content) and depth > 0:
            ch = content[pos]
            if in_string:
                if ch == "\\" and pos + 1 < len(content):
                    pos += 2  # skip escaped char
                    continue
                if ch == in_string:
                    in_string = None
            else:
                if ch in ("'", '"'):
                    in_string = ch
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
            pos += 1
        block = content[start:pos]
        # Strip outer parens
        inner = block[block.index("(") + 1:-1]
        q = {}
        q["subject"] = extract_string_value(inner, "subject") or ""
        q["level"] = extract_string_value(inner, "level")
        q["text"] = extract_string_value(inner, "text") or ""
        q["options"] = parse_options_array(inner)
        q["correctIndex"] = extract_int_value(inner, "correctIndex")
        q["explanation"] = extract_string_value(inner, "explanation") or ""
        q["source"] = extract_string_value(inner, "source")
        q["situation"] = extract_string_value(inner, "situation")
        if q["correctIndex"] is None:
            q["correctIndex"] = -1
        questions.append(q)
    return questions


def validate_question(q):
    """Validate a single question dict. Returns (is_valid, reasons_list).
    
    Rejects ONLY structurally broken questions:
      - empty/garbled text
      - invalid option count
      - duplicate/empty options
      - out-of-range correctIndex
    
    Does NOT reject empty explanation — that's a quality warning, not a blocker.
    """
    reasons = []

    if not q.get("text", "").strip():
        reasons.append("empty_text")

    text = q.get("text", "")
    if GARBLED_RE.search(text):
        reasons.append("garbled_text")
    if MOJIBAKE_RE.search(text):
        reasons.append("mojibake_text")

    opts = q.get("options", [])
    if len(opts) < 4 or len(opts) > 5:
        reasons.append(f"invalid_option_count_{len(opts)}")

    for i, opt in enumerate(opts):
        if opt.strip() == "":
            reasons.append(f"empty_option_{i}")

    normalized = [o.strip().lower() for o in opts]
    if len(normalized) != len(set(normalized)):
        reasons.append("duplicate_options")

    ci = q.get("correctIndex", -1)
    if ci < 0 or ci >= len(opts):
        reasons.append(f"invalid_correctIndex_{ci}_of_{len(opts)}")

    return (len(reasons) == 0, reasons)


def scan_bank_files(bank_dir):
    """Scan all Dart bank files and return dict of bank_key -> questions."""
    banks = {}
    for f in sorted(bank_dir.glob("*.dart")):
        if f.name in SKIP_FILES:
            continue
        if not f.name.endswith("_data.dart") and not f.name.endswith("_all.dart"):
            continue
        content = f.read_text(encoding="utf-8", errors="replace")
        qs = parse_question_blocks(content)
        if qs:
            bank_key = f.stem
            banks[bank_key] = {
                "source_file": f.name,
                "questions": qs,
            }
    return banks


def main():
    parser = argparse.ArgumentParser(description="Audit and filter question banks")
    parser.add_argument("--bank-dir", default=str(BANK_DIR))
    parser.add_argument("--output", default=str(OUTPUT_DIR))
    args = parser.parse_args()

    bank_dir = Path(args.bank_dir)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Scanning bank files in: {bank_dir}")
    banks = scan_bank_files(bank_dir)

    total_all = 0
    valid_all = 0
    rejected_all = 0
    warning_all = 0
    reason_counts = defaultdict(int)
    warning_counts = defaultdict(int)
    filtered_banks = {}
    rejected_banks = {}
    per_bank_stats = {}

    for bank_key, bank_data in banks.items():
        qs = bank_data["questions"]
        total = len(qs)
        total_all += total

        valid_qs = []
        rejected_qs = []
        warning_count = 0

        for q in qs:
            # Check warnings (non-blocking)
            if not q.get("explanation", "").strip():
                warning_counts["empty_explanation"] += 1
                warning_count += 1

            is_valid, reasons = validate_question(q)
            if is_valid:
                valid_qs.append(q)
            else:
                for r in reasons:
                    # Normalize reason key (strip index for counting)
                    base = re.sub(r'_\d+_of_\d+', '', re.sub(r'_\d+$', '', r))
                    reason_counts[base] += 1
                rejected_qs.append({"question": q, "reasons": reasons})

        valid_all += len(valid_qs)
        rejected_all += len(rejected_qs)
        warning_all += warning_count

        if valid_qs:
            filtered_banks[bank_key] = {
                "source_file": bank_data["source_file"],
                "questions": valid_qs,
            }
        if rejected_qs:
            rejected_banks[bank_key] = {
                "source_file": bank_data["source_file"],
                "rejected": rejected_qs,
            }

        pct = (len(valid_qs) / total * 100) if total else 0
        per_bank_stats[bank_key] = {
            "source_file": bank_data["source_file"],
            "total": total,
            "valid": len(valid_qs),
            "rejected": len(rejected_qs),
            "warnings": warning_count,
            "pass_rate": f"{pct:.1f}%",
        }

        status = "✓" if len(rejected_qs) == 0 else "✗"
        print(f"  {status} {bank_key}: {len(valid_qs)}/{total} valid "
              f"({len(rejected_qs)} rejected) [{bank_data['source_file']}]")

    # ─── Write outputs ───
    report = {
        "summary": {
            "total_scanned": total_all,
            "valid": valid_all,
            "rejected": rejected_all,
            "warnings": warning_all,
            "pass_rate": f"{(valid_all/total_all*100):.1f}%" if total_all else "0%",
        },
        "structural_rejection_reasons": dict(sorted(reason_counts.items(), key=lambda x: -x[1])),
        "quality_warnings": dict(sorted(warning_counts.items(), key=lambda x: -x[1])),
        "per_bank": per_bank_stats,
    }

    with open(output_dir / "audit_report.json", "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)

    with open(output_dir / "filtered_questions.json", "w", encoding="utf-8") as f:
        json.dump(filtered_banks, f, ensure_ascii=False, indent=2)

    with open(output_dir / "rejected_questions.json", "w", encoding="utf-8") as f:
        json.dump(rejected_banks, f, ensure_ascii=False, indent=2)

    # ─── Console summary ───
    print(f"\n{'='*60}")
    print(f"  AUDIT SUMMARY (structural filter only)")
    print(f"{'='*60}")
    print(f"  Total scanned:  {total_all}")
    print(f"  Valid:           {valid_all} ({(valid_all/total_all*100):.1f}%)" if total_all else "  Valid: 0")
    print(f"  Rejected:        {rejected_all} (structural breakage)" if total_all else "  Rejected: 0")
    print(f"  Warnings:        {warning_all} (quality issues, not filtered)" if total_all else "  Warnings: 0")
    print(f"\n  Structural rejection reasons:")
    for reason, count in sorted(reason_counts.items(), key=lambda x: -x[1]):
        print(f"    {reason}: {count}")
    if warning_counts:
        print(f"\n  Quality warnings:")
        for reason, count in sorted(warning_counts.items(), key=lambda x: -x[1]):
            print(f"    {reason}: {count}")
    print(f"\n  Files written:")
    print(f"    {output_dir / 'audit_report.json'}")
    print(f"    {output_dir / 'filtered_questions.json'}")
    print(f"    {output_dir / 'rejected_questions.json'}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
