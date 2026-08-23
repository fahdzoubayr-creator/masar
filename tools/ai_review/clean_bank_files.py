#!/usr/bin/env python3
"""
clean_bank_files.py — Direct Dart bank file cleaner.

Cleans question bank Dart files in-place:
1. Remove duplicate options within each question
2. Ensure exactly 4 options (add fallback if needed)
3. Fix correctIndex after cleaning
4. Remove questions with all identical options or < 2 unique options
5. Remove questions with very short text (< 8 chars)
6. Remove questions with garbled text (mojibake/CJK)

Usage:
    python clean_bank_files.py [--dry-run] [--bank-dir DIR]
"""

import re
import os
import sys
import io
import argparse
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

BANK_DIR = Path(r"D:\masar_app\masar_app\lib\core\data")

SKIP_FILES = {
    "popular_bank_data.dart",
    "wadiaa_bank_data.dart",
    "professional_bank_data.dart",
}

# Garbled text patterns
GARBLED = re.compile(
    r'[\u200B-\u200F\u2028-\u202F\u2060-\u2069'
    r'\u4E00-\u9FFF\u3400-\u4DBF'
    r'\uFFFD\uFFFE\uFFFF'
    r'\u0000-\u0008\u000B\u000C\u000E-\u001F]'
)
MOJIBAKE = re.compile(r'(?:Ø§Ù|ÙØ§|Ø§Ù„|Ù…Ø§|ÙŠÙ†|Ø¹Ù„|Ã)')

# All-wrong patterns
ALL_WRONG = re.compile(
    r'جميع\s+(?:الاختيارات\s+)?(?:أعلاه|المذكورة|السابقة)\s+خاطئ'
)
NO_CORRECT = re.compile(
    r'لا\s+توجد\s+إجابة\s+صحيحة|لا\s+أي\s+من\s+الخيارات\s+صحيحة'
)

FALLBACK_OPTIONS = [
    "جميع الاختيارات أعلاه خاطئة",
    "لا شيء مما سبق",
    "غير ذلك",
]


def escape_dart_string(s: str) -> str:
    s = s.replace("\\", "\\\\")
    s = s.replace("'", "\\'")
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "")
    return s


def extract_string_value(text: str, key: str):
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


def extract_int_value(text: str, key: str):
    m = re.search(rf"{key}\s*:\s*(\d+)", text)
    if m:
        return int(m.group(1))
    return None


def parse_options_array(text: str) -> list:
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


def find_question_blocks(content: str) -> list:
    """Find all Question(...) blocks with their start/end positions."""
    blocks = []
    pos = 0
    while True:
        idx = content.find("Question(", pos)
        if idx == -1:
            break
        line_start = content.rfind("\n", 0, idx) + 1
        line_before = content[line_start:idx].strip()
        if line_before.startswith("//"):
            pos = idx + 1
            continue

        start = idx
        depth = 0
        end = idx
        in_string = False
        string_char = None
        i = idx
        while i < len(content):
            ch = content[i]
            if in_string:
                if ch == "\\" and i + 1 < len(content):
                    i += 2
                    continue
                elif ch == string_char:
                    in_string = False
            else:
                if ch in ("'", '"'):
                    in_string = True
                    string_char = ch
                elif ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        end = i + 1
                        break
            i += 1

        block = content[start:end]
        blocks.append((start, end, block))
        pos = end
    return blocks


def clean_question(block: str) -> tuple:
    """Clean a question block. Returns (cleaned_block, action, details)."""
    text = extract_string_value(block, "text") or ""
    options = parse_options_array(block)
    old_correct = extract_int_value(block, "correctIndex") or 0

    # Reject: very short text
    if len(text.strip()) < 8:
        return None, "REMOVED", "short_text"

    # Reject: garbled text
    if GARBLED.search(text) or MOJIBAKE.search(text):
        return None, "REMOVED", "garbled_text"

    # Reject: no options
    if len(options) < 2:
        return None, "REMOVED", "too_few_options"

    # --- Normalize options ---
    # Remove __ref__ markers (resolve them later)
    clean_opts = []
    for opt in options:
        if opt.startswith("__ref__"):
            # Keep as-is, will be handled during dedup
            clean_opts.append(opt)
        else:
            clean_opts.append(opt.strip())

    # Remove empty options
    clean_opts = [o for o in clean_opts if o]

    if len(clean_opts) < 2:
        return None, "REMOVED", "empty_options"

    # --- Deduplicate ---
    seen = set()
    unique = []
    for opt in clean_opts:
        key = opt.lower().strip()
        if key not in seen:
            seen.add(key)
            unique.append(opt)

    # Also check for all-wrong duplicates (semantic dedup)
    all_wrong_indices = []
    for i, opt in enumerate(unique):
        if ALL_WRONG.search(opt) or NO_CORRECT.search(opt):
            all_wrong_indices.append(i)

    if len(all_wrong_indices) > 1:
        # Keep only the first all-wrong option
        keep = all_wrong_indices[0]
        unique = [
            opt for i, opt in enumerate(unique) if i not in all_wrong_indices[1:]
        ]

    # --- Ensure exactly 4 options ---
    while len(unique) < 4:
        added = False
        for fb in FALLBACK_OPTIONS:
            if fb not in unique:
                unique.append(fb)
                added = True
                break
        if not added:
            unique.append("جميع الاختيارات أعلاه خاطئة")
        if len(unique) >= 4:
            break

    unique = unique[:4]

    # --- Fix correctIndex ---
    if old_correct < len(options):
        correct_text = options[old_correct].strip()
    else:
        correct_text = unique[0]

    try:
        new_correct = next(
            i for i, opt in enumerate(unique) if opt.strip() == correct_text
        )
    except StopIteration:
        # Try fuzzy match
        new_correct = 0
        for i, opt in enumerate(unique):
            if correct_text.lower() in opt.lower() or opt.lower() in correct_text.lower():
                new_correct = i
                break

    # Check if anything changed
    old_opts_clean = [o.strip() for o in options if o.strip()]
    changed = (
        len(unique) != len(old_opts_clean)
        or any(unique[i].strip() != old_opts_clean[i] for i in range(min(len(unique), len(old_opts_clean))))
        or new_correct != old_correct
    )

    if not changed:
        return block, "PASS", None

    # --- Rebuild the block ---
    # Replace options array
    old_options_match = re.search(r"options\s*:\s*\[.*?\]", block, re.DOTALL)
    if not old_options_match:
        return block, "PASS", None

    new_opts_str = ", ".join(f"'{escape_dart_string(o)}'" for o in unique)
    new_options = f"options: [{new_opts_str}],"
    new_block = block[:old_options_match.start()] + new_options + block[old_options_match.end():]

    # Replace correctIndex
    old_ci_match = re.search(r"correctIndex\s*:\s*\d+", new_block)
    if old_ci_match:
        new_block = (
            new_block[:old_ci_match.start()]
            + f"correctIndex: {new_correct}"
            + new_block[old_ci_match.end():]
        )

    return new_block, "FIXED", f"dups={len(options) - len(unique)}"


def process_file(filepath: Path, dry_run: bool = False) -> dict:
    """Process a single Dart bank file."""
    content = filepath.read_text(encoding="utf-8")
    blocks = find_question_blocks(content)

    stats = {"total": len(blocks), "passed": 0, "fixed": 0, "removed": 0, "reasons": {}}

    # Process blocks in reverse order (to preserve positions)
    replacements = []
    for start, end, block in blocks:
        cleaned, action, detail = clean_question(block)
        if action == "PASS":
            stats["passed"] += 1
        elif action == "FIXED":
            stats["fixed"] += 1
            replacements.append((start, end, cleaned))
        elif action == "REMOVED":
            stats["removed"] += 1
            stats["reasons"][detail] = stats["reasons"].get(detail, 0) + 1
            replacements.append((start, end, None))  # None = remove

    # Apply replacements in reverse order
    if replacements and not dry_run:
        for start, end, replacement in sorted(replacements, key=lambda x: -x[0]):
            if replacement is None:
                # Remove the block and trailing comma/newline
                end_trim = end
                while end_trim < len(content) and content[end_trim] in (" ", "\n", "\r", ","):
                    end_trim += 1
                content = content[:start] + content[end_trim:]
            else:
                content = content[:start] + replacement + content[end:]

        filepath.write_text(content, encoding="utf-8")

    return stats


def main():
    parser = argparse.ArgumentParser(description="Clean Dart bank files directly")
    parser.add_argument("--bank-dir", type=Path, default=BANK_DIR)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    total_stats = {"total": 0, "passed": 0, "fixed": 0, "removed": 0, "reasons": {}}

    for dart_file in sorted(args.bank_dir.glob("*_bank*.dart")):
        if dart_file.name in SKIP_FILES:
            continue

        stats = process_file(dart_file, dry_run=args.dry_run)
        total_stats["total"] += stats["total"]
        total_stats["passed"] += stats["passed"]
        total_stats["fixed"] += stats["fixed"]
        total_stats["removed"] += stats["removed"]
        for k, v in stats["reasons"].items():
            total_stats["reasons"][k] = total_stats["reasons"].get(k, 0) + v

        action = "DRY RUN" if args.dry_run else "CLEANED"
        if stats["fixed"] > 0 or stats["removed"] > 0:
            print(
                f"  {action} {dart_file.name}: "
                f"{stats['total']} total, "
                f"{stats['passed']} pass, "
                f"{stats['fixed']} fixed, "
                f"{stats['removed']} removed"
            )

    print(f"\n{'='*60}")
    print(f"  {'DRY RUN' if args.dry_run else 'CLEANING'} COMPLETE")
    print(f"{'='*60}")
    print(f"  Total questions: {total_stats['total']}")
    print(f"  Passed:          {total_stats['passed']}")
    print(f"  Fixed:           {total_stats['fixed']}")
    print(f"  Removed:         {total_stats['removed']}")
    if total_stats["reasons"]:
        print(f"  Removal reasons:")
        for k, v in sorted(total_stats["reasons"].items(), key=lambda x: -x[1]):
            print(f"    {k}: {v}")


if __name__ == "__main__":
    main()
