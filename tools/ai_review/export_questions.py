#!/usr/bin/env python3
"""
export_questions.py — Extract all questions from Dart bank files to JSON.

Usage:
    python export_questions.py [--bank-dir DIR] [--output FILE]

Output: JSON file with structure:
{
  "banks": {
    "bank_key": {
      "source_file": "filename.dart",
      "questions": [
        {
          "id": "bank_key_001",
          "subject": "...",
          "level": "...",
          "text": "...",
          "options": [...],
          "correctIndex": 0,
          "explanation": "...",
          "source": "...",
          "situation": "..."
        }
      ]
    }
  },
  "stats": { ... }
}
"""

import os
import re
import json
import sys
import io
import argparse
from pathlib import Path
from typing import Optional

# Force UTF-8 output on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

BANK_DIR = Path(r"D:\masar_app\masar_app\lib\core\data")
OUTPUT = Path(r"D:\masar_app\masar_app\tools\ai_review\raw_questions.json")

# Dart files to skip (not question banks)
SKIP_FILES = {
    "popular_bank_data.dart",
    "wadiaa_bank_data.dart",
    "professional_bank_data.dart",  # has its own internal structure
}


def extract_string_value(text: str, key: str) -> Optional[str]:
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


def extract_int_value(text: str, key: str) -> Optional[int]:
    """Extract an integer value from Dart code."""
    m = re.search(rf"{key}\s*:\s*(\d+)", text)
    if m:
        return int(m.group(1))
    return None


def parse_options_array(text: str) -> list:
    """Parse the options: [...] array from a Question block using a state machine."""
    # Find options: [
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

    options_text = text[start : pos - 1]

    # State machine parser
    options = []
    i = 0
    n = len(options_text)
    while i < n:
        c = options_text[i]

        if c in ("'", '"'):
            # Quoted string
            quote = c
            i += 1
            buf = []
            while i < n:
                ch = options_text[i]
                if ch == "\\" and i + 1 < n:
                    next_ch = options_text[i + 1]
                    if next_ch == quote:
                        buf.append(quote)
                    elif next_ch == "'":
                        buf.append("'")
                    elif next_ch == '"':
                        buf.append('"')
                    elif next_ch == "n":
                        buf.append("\n")
                    elif next_ch == "\\":
                        buf.append("\\")
                    else:
                        buf.append(ch)
                        buf.append(next_ch)
                    i += 2
                elif ch == quote:
                    i += 1
                    break
                else:
                    buf.append(ch)
                    i += 1
            options.append("".join(buf))
        elif c.isalpha() or c == "_":
            # Variable reference like allWrong
            j = i
            while j < n and (options_text[j].isalnum() or options_text[j] in "_."):
                j += 1
            var_name = options_text[i:j]
            options.append(f"__ref__{var_name}")
            i = j
        else:
            i += 1  # skip commas, whitespace, etc.

    return options

    return options


def extract_question_blocks(content: str) -> list:
    """Extract individual Question(...) blocks from Dart file content."""
    blocks = []
    pos = 0

    while True:
        # Find next Question(
        idx = content.find("Question(", pos)
        if idx == -1:
            break

        # Check if this looks like a constructor call (not a comment or string)
        line_start = content.rfind("\n", 0, idx) + 1
        line_before = content[line_start:idx].strip()
        if line_before.startswith("//"):
            pos = idx + 1
            continue

        # Find matching closing paren, respecting quoted strings
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
                    i += 2  # skip escaped char
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
        blocks.append(block)
        pos = end

    return blocks


def parse_question(block: str, bank_key: str, index: int) -> dict:
    """Parse a single Question(...) block into a dict."""
    q = {}

    q["subject"] = extract_string_value(block, "subject") or bank_key
    q["level"] = extract_string_value(block, "level")
    q["text"] = extract_string_value(block, "text") or ""
    q["options"] = parse_options_array(block)
    q["correctIndex"] = extract_int_value(block, "correctIndex") or 0
    q["explanation"] = extract_string_value(block, "explanation") or ""
    q["source"] = extract_string_value(block, "source")
    q["situation"] = extract_string_value(block, "situation")

    # Generate ID
    q["id"] = f"{bank_key}_{index:04d}"

    return q


def extract_bank_keys_and_questions(filepath: Path) -> dict:
    """Extract all bank keys and their questions from a Dart file."""
    content = filepath.read_text(encoding="utf-8")

    # Find bank map keys: 'key': [
    # Pattern: 'some_key': [
    key_pattern = re.compile(r"""'([^']+)'\s*:\s*\[""")
    results = {}

    for km in key_pattern.finditer(content):
        bank_key = km.group(1)
        # Find the matching closing ] for this list
        start = km.end()
        depth = 1
        pos = start
        while pos < len(content) and depth > 0:
            if content[pos] == "[":
                depth += 1
            elif content[pos] == "]":
                depth -= 1
            pos += 1

        list_content = content[start : pos - 1]
        blocks = extract_question_blocks(list_content)

        questions = []
        for i, block in enumerate(blocks, 1):
            q = parse_question(block, bank_key, i)
            if q["text"]:  # Skip empty/broken
                questions.append(q)

        results[bank_key] = {
            "source_file": filepath.name,
            "questions": questions,
        }

    # Also handle ProfessionalBankData's _bank format
    # static const Map<String, List<Question>> _bank = { ... }
    if not results:
        # Try alternate pattern
        alt_pattern = re.compile(r"""'([^']+)'\s*:\s*\[""")
        for km in alt_pattern.finditer(content):
            bank_key = km.group(1)
            start = km.end()
            depth = 1
            pos = start
            while pos < len(content) and depth > 0:
                if content[pos] == "[":
                    depth += 1
                elif content[pos] == "]":
                    depth -= 1
                pos += 1

            list_content = content[start : pos - 1]
            blocks = extract_question_blocks(list_content)

            questions = []
            for i, block in enumerate(blocks, 1):
                q = parse_question(block, bank_key, i)
                if q["text"]:
                    questions.append(q)

            results[bank_key] = {
                "source_file": filepath.name,
                "questions": questions,
            }

    return results


def process_professional_bank(filepath: Path) -> dict:
    """Special handler for professional_bank_data.dart which has _bank and _situations."""
    content = filepath.read_text(encoding="utf-8")
    results = {}

    # Find all static const Map<String, List<Question>> patterns
    map_pattern = re.compile(
        r"static\s+const\s+Map<String,\s*List<Question>>\s+(\w+)\s*=\s*\{"
    )

    for mm in map_pattern.finditer(content):
        var_name = mm.group(1)
        start = mm.end()
        # Find matching closing }
        depth = 1
        pos = start
        while pos < len(content) and depth > 0:
            if content[pos] == "{":
                depth += 1
            elif content[pos] == "}":
                depth -= 1
            pos += 1

        map_content = content[start : pos - 1]

        # Find keys in this map
        key_pattern = re.compile(r"""'([^']+)'\s*:\s*\[""")
        for km in key_pattern.finditer(map_content):
            bank_key = km.group(1)
            kstart = km.end()
            kdepth = 1
            kpos = kstart
            while kpos < len(map_content) and kdepth > 0:
                if map_content[kpos] == "[":
                    kdepth += 1
                elif map_content[kpos] == "]":
                    kdepth -= 1
                kpos += 1

            list_content = map_content[kstart : kpos - 1]
            blocks = extract_question_blocks(list_content)

            questions = []
            for i, block in enumerate(blocks, 1):
                q = parse_question(block, bank_key, i)
                if q["text"]:
                    questions.append(q)

            results[bank_key] = {
                "source_file": filepath.name,
                "questions": questions,
            }

    return results


def main():
    parser = argparse.ArgumentParser(description="Export Dart bank questions to JSON")
    parser.add_argument("--bank-dir", type=Path, default=BANK_DIR)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()

    bank_dir = args.bank_dir
    output = args.output

    all_banks = {}
    total_questions = 0
    files_processed = 0

    # Process each Dart file
    for dart_file in sorted(bank_dir.glob("*_bank*.dart")):
        if dart_file.name in SKIP_FILES:
            continue

        print(f"  Parsing: {dart_file.name}")

        if dart_file.name == "professional_bank_data.dart":
            banks = process_professional_bank(dart_file)
        else:
            banks = extract_bank_keys_and_questions(dart_file)

        for key, data in banks.items():
            if key in all_banks:
                # Merge (append)
                all_banks[key]["questions"].extend(data["questions"])
                print(f"    WARNING: Duplicate key '{key}' - merging")
            else:
                all_banks[key] = data

            count = len(data["questions"])
            total_questions += count

        files_processed += 1

    # Build output
    output_data = {
        "banks": all_banks,
        "stats": {
            "total_files": files_processed,
            "total_banks": len(all_banks),
            "total_questions": total_questions,
            "bank_counts": {
                k: len(v["questions"]) for k, v in all_banks.items()
            },
        },
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    with open(output, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"\n=== Export Complete ===")
    print(f"Files processed: {files_processed}")
    print(f"Bank keys found: {len(all_banks)}")
    print(f"Total questions: {total_questions}")
    print(f"Output: {output}")
    print(f"\nBank breakdown:")
    for k, v in sorted(all_banks.items(), key=lambda x: -len(x[1]["questions"])):
        print(f"  {k}: {len(v['questions'])} questions ({v['source_file']})")


if __name__ == "__main__":
    main()
