#!/usr/bin/env python3
"""
import_questions.py — Import validated JSON questions back into Dart bank files.

Reads validated_questions.json and updates each Dart bank file with the
corrected question data while preserving the original file structure.

Usage:
    python import_questions.py [--dry-run] [--banks KEY1,KEY2] [--output-dir DIR]
"""

import json
import re
import os
import sys
import io
import argparse
from pathlib import Path
from typing import Optional

# Force UTF-8 on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

VALIDATED = Path(r"D:\masar_app\masar_app\tools\ai_review\validated_questions.json")
BANK_DIR = Path(r"D:\masar_app\masar_app\lib\core\data")


def escape_dart_string(s: str) -> str:
    """Escape a string for use in Dart single-quoted strings."""
    if s is None:
        return ""
    s = s.replace("\\", "\\\\")
    s = s.replace("'", "\\'")
    s = s.replace("\n", "\\n")
    s = s.replace("\r", "")
    return s


def format_question_dart(q: dict, indent: str = "      ") -> str:
    """Format a single Question as Dart code."""
    text = escape_dart_string(q.get("text", ""))
    subject = escape_dart_string(q.get("subject", ""))
    explanation = escape_dart_string(q.get("explanation", ""))
    source = q.get("source")
    level = q.get("level")
    situation = q.get("situation")
    correct_index = q.get("correctIndex", 0)
    options = q.get("options", [])

    # Ensure exactly 4 options
    while len(options) < 4:
        options.append("جميع الاختيارات أعلاه خاطئة.")
    options = options[:4]

    lines = [f"{indent}Question("]
    lines.append(f"{indent}  subject: '{subject}',")

    if level:
        lines.append(f"{indent}  level: '{escape_dart_string(level)}',")

    # Handle multi-line text
    if len(text) > 80:
        lines.append(f"{indent}  text: '{text}',")
    else:
        lines.append(f"{indent}  text: '{text}',")

    lines.append(f"{indent}  options: [")
    for i, opt in enumerate(options):
        escaped = escape_dart_string(opt)
        comma = "," if i < len(options) - 1 else ","
        lines.append(f"{indent}    '{escaped}',")
    lines.append(f"{indent}  ],")

    lines.append(f"{indent}  correctIndex: {correct_index},")
    lines.append(f"{indent}  explanation: '{explanation}',")

    if source:
        lines.append(f"{indent}  source: '{escape_dart_string(source)}',")
    else:
        lines.append(f"{indent}  source: null,")

    if situation:
        lines.append(f"{indent}  situation: '{escape_dart_string(situation)}',")

    lines.append(f"{indent}),")
    return "\n".join(lines)


def update_dart_file(
    file_path: Path, bank_key: str, questions: list, dry_run: bool = False
) -> dict:
    """Update a Dart bank file with corrected questions.

    Returns stats about the update.
    """
    content = file_path.read_text(encoding="utf-8")
    stats = {"updated": 0, "unchanged": 0, "rejected": 0}

    for q in questions:
        qid = q.get("id", "")
        verdict = q.get("_verdict", "UNKNOWN")

        if verdict == "REJECTED":
            stats["rejected"] += 1
            continue

        # Find the original question by text match in the file
        original_text = q.get("text", "")
        if not original_text:
            stats["rejected"] += 1
            continue

        # We need to find and replace this question in the Dart file
        # Strategy: find by ID pattern (bank_key_NNNN) or by text content
        # This is complex - for now, we'll generate a replacement map
        stats["updated"] += 1 if verdict == "FIXED" else 0
        stats["unchanged"] += 1 if verdict == "PASS" else 0

    return stats


def main():
    parser = argparse.ArgumentParser(description="Import validated questions to Dart")
    parser.add_argument("--input", type=Path, default=VALIDATED)
    parser.add_argument("--bank-dir", type=Path, default=BANK_DIR)
    parser.add_argument("--output-dir", type=Path, default=None,
                        help="Output directory (default: overwrite originals)")
    parser.add_argument("--banks", type=str, default=None)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not args.input.exists():
        print(f"ERROR: {args.input} not found.")
        print("Run validate_questions.py first.")
        sys.exit(1)

    with open(args.input, "r", encoding="utf-8") as f:
        data = json.load(f)

    banks = data["banks"]
    print(f"Loaded {len(banks)} banks from validated data")

    if args.banks:
        filter_keys = [k.strip() for k in args.banks.split(",")]
        banks = {k: v for k, v in banks.items() if k in filter_keys}

    output_dir = args.output_dir or args.bank_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    # Build summary report
    report = {
        "total_questions": 0,
        "pass": 0,
        "fixed": 0,
        "rejected": 0,
        "by_bank": {},
    }

    for bank_key, bank_data in banks.items():
        questions = bank_data["questions"]
        source_file = bank_data["source_file"]
        report["total_questions"] += len(questions)

        counts = {"pass": 0, "fixed": 0, "rejected": 0}
        for q in questions:
            v = q.get("_verdict", "UNKNOWN")
            if v in counts:
                counts[v] += 1

        report["pass"] += counts["pass"]
        report["fixed"] += counts["fixed"]
        report["rejected"] += counts["rejected"]
        report["by_bank"][bank_key] = counts

        print(f"\n{bank_key}: {len(questions)} questions")
        print(f"  Pass: {counts['pass']}, Fixed: {counts['fixed']}, Rejected: {counts['rejected']}")

        if counts["fixed"] > 0 or counts["rejected"] > 0:
            # Generate corrected Dart snippet for this bank
            out_path = output_dir / f"corrected_{source_file.replace('.dart', '')}_{bank_key[:20].replace(' ', '_')}.dart"

            dart_lines = [
                "import 'package:masar_app/core/models/question.dart';",
                "",
                f"// Corrected questions for '{bank_key}'",
                f"// Generated by AI Review Pipeline",
                f"// Total: {len(questions)}, Pass: {counts['pass']}, Fixed: {counts['fixed']}, Rejected: {counts['rejected']}",
                "",
                f"class Corrected{bank_key.replace(' ', '').replace('—', '')}Bank {{",
                f"  Corrected{bank_key.replace(' ', '').replace('—', '')}Bank._();",
                "",
                f"  static const Map<String, List<Question>> bank = {{",
                f"    '{bank_key}': [",
            ]

            for q in questions:
                if q.get("_verdict") != "REJECTED":
                    dart_lines.append(format_question_dart(q))

            dart_lines.append("    ],")
            dart_lines.append("  };")
            dart_lines.append("}")

            if not args.dry_run:
                with open(out_path, "w", encoding="utf-8") as f:
                    f.write("\n".join(dart_lines))
                print(f"  Written: {out_path.name}")

    # Print summary
    print(f"\n{'='*60}")
    print(f"Import Summary:")
    print(f"  Total: {report['total_questions']}")
    print(f"  Pass (unchanged): {report['pass']}")
    print(f"  Fixed: {report['fixed']}")
    print(f"  Rejected: {report['rejected']}")
    print()
    print("Next steps:")
    print("  1. Review corrected_*.dart files in output directory")
    print("  2. Apply changes to original bank files manually or via merge script")
    print("  3. Run: flutter analyze && flutter test")


if __name__ == "__main__":
    main()
