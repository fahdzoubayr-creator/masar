#!/usr/bin/env python3
"""
Dart Bank → JSON converter [DEPRECATED — conversion complete].

This script has already been used to convert all Dart bank files to JSON
in assets/banks/. For cleaning/maintaining JSON files, use json_cleaner.py.

Kept as historical reference only.
"""

import re
import json
import sys
import io
import os
import hashlib
from pathlib import Path
from collections import OrderedDict

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

DATA_DIR = Path(__file__).parent.parent.parent / "lib" / "core" / "data"
OUT_DIR = Path(__file__).parent.parent.parent / "assets" / "banks"

# Files to SKIP (unused / dead data)
SKIP_FILES = {
    'education_sciences_all_bank_data.dart',
    'subjects_data.dart',
    'questions_data.dart',
}

# Mapping: dart filename → JSON output name
FILE_MAP = {
    'popular_bank_data.dart': 'popular_bank.json',
    'wadiaa_bank_data.dart': 'wadiaa_bank.json',
    'professional_bank_data.dart': 'professional_bank.json',
    'professional_exam_bank_data.dart': 'professional_exam_bank.json',
    'professional_situations_bank.dart': 'professional_situations.json',
    'statutory_bank_data.dart': 'statutory_bank.json',
    'science_edu_bank_data.dart': 'science_edu.json',
    'arabic_didactics_all_bank_data.dart': 'arabic_didactics.json',
    'math_didactics_all_bank_data.dart': 'math_didactics.json',
    'math_didactics_bank.dart': 'math_didactics_small.json',
    'french_didactics_bank_all.dart': 'french_didactics_all.json',
    'french_didactics_bank.dart': 'french_didactics_small.json',
    'french_bank_data.dart': 'french_bank.json',
    'animation_bank_data.dart': 'animation.json',
    'life_skills_bank_data.dart': 'life_skills.json',
    'school_councils_bank_data.dart': 'school_councils.json',
    'science_activity_bank_all.dart': 'science_activity.json',
    'science_bank_data.dart': 'science.json',
    'science_didactics_bank.dart': 'science_didactics.json',
    'reform_bank_data.dart': 'reform.json',
    'school_project_bank_data.dart': 'school_project.json',
    'development_psychology_bank_data.dart': 'development_psychology.json',
    'socio_psychology_bank_data.dart': 'socio_psychology.json',
    'riyada_bank_data.dart': 'riyada.json',
    'amazigh_didactics_bank.dart': 'amazigh_didactics.json',
    'learning_theories_bank_data.dart': 'learning_theories.json',
}


def extract_string_value(s):
    """Extract a Dart string literal, handling escaped quotes."""
    s = s.strip()
    if s.startswith("'") and s.endswith("'"):
        inner = s[1:-1]
    elif s.startswith('"') and s.endswith('"'):
        inner = s[1:-1]
    else:
        return s
    # Unescape Dart string escapes
    inner = inner.replace("\\'", "'").replace('\\"', '"')
    inner = inner.replace("\\n", "\n").replace("\\t", "\t")
    inner = inner.replace("\\\\", "\\")
    return inner


# allWrong variants (variable references + string literals)
ALL_WRONG_REFS = {
    'allWrong',
    'WadiaaBankData.allWrong',
    'PopularBankData.allWrong',
    'ProfessionalBankData.allWrong',
    'ProfessionalExamBankData.allWrong',
    'ProfessionalSituationsBank.allWrong',
    'AnimationBankData.allWrong',
    'LifeSkillsBankData.allWrong',
    'SchoolCouncilsBankData.allWrong',
    'ScienceActivityBankAll.allWrong',
}
ALL_WRONG_STRINGS = [
    'جميع الاختيارات أعلاه خاطئة',
    'جميع ما سبق خاطئ',
    'جميع الخيارات خاطئة',
    'all of the above are wrong',
    'Toutes les réponses précédentes sont fausses',
    'toutes les réponses précédentes sont fausses',
]


def is_all_wrong(opt_text):
    """Check if an option text is an allWrong reference."""
    if opt_text.strip() in ALL_WRONG_REFS:
        return True
    for pat in ALL_WRONG_STRINGS:
        if pat.lower() in opt_text.lower():
            return True
    return False


def parse_questions_from_dart(content):
    """
    Parse all Question(...) blocks from Dart source content.
    Returns dict of {subject_key: [question_dicts]}.
    """
    banks = OrderedDict()

    # Find all Question( blocks
    # We split on Question( and parse each block
    parts = re.split(r'Question\(', content)

    for part in parts[1:]:  # skip everything before first Question(
        q = parse_single_question(part)
        if q is not None:
            subj = q['subject']
            if subj not in banks:
                banks[subj] = []
            banks[subj].append(q)

    return banks


def parse_single_question(block):
    """Parse a single Question(...) block. Returns dict or None."""
    # Find matching closing paren — we need to handle nested parens
    depth = 1
    end = 0
    for i, ch in enumerate(block):
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth -= 1
            if depth == 0:
                end = i
                break
    if end == 0:
        return None
    body = block[:end]

    # Extract subject
    m = re.search(r"subject:\s*'((?:[^'\\]|\\.)*)'", body)
    if not m:
        m = re.search(r'subject:\s*"((?:[^"\\]|\\.)*)"', body)
    if not m:
        return None
    subject = extract_string_value(m.group(0).split(':', 1)[1].strip())

    # Extract level (optional)
    level = None
    m = re.search(r"level:\s*'((?:[^'\\]|\\.)*)'", body)
    if not m:
        m = re.search(r'level:\s*"((?:[^"\\]|\\.)*)"', body)
    if m:
        level = extract_string_value(m.group(0).split(':', 1)[1].strip())

    # Extract text
    m = re.search(r"text:\s*'((?:[^'\\]|\\.)*)'", body)
    if not m:
        m = re.search(r'text:\s*"((?:[^"\\]|\\.)*)"', body)
    if not m:
        return None
    text = extract_string_value(m.group(0).split(':', 1)[1].strip())

    # Extract options list
    m = re.search(r'options:\s*\[(.*?)\]', body, re.DOTALL)
    if not m:
        return None
    options_raw = m.group(1)
    # Parse individual option strings AND bare variable references
    options = []
    for token_match in re.finditer(
        r"'((?:[^'\\]|\\.)*)'|"               # single-quoted string
        r'"((?:[^"\\]|\\.)*)"|'               # double-quoted string
        r'\b(allWrong|[\w]+\.allWrong)\b',     # bare variable ref
        options_raw
    ):
        raw = token_match.group(0)
        options.append(extract_string_value(raw))

    # Extract correctIndex
    m = re.search(r'correctIndex:\s*(\d+)', body)
    if not m:
        return None
    correct_index = int(m.group(1))

    # Extract explanation
    m = re.search(r"explanation:\s*'((?:[^'\\]|\\.)*)'", body)
    if not m:
        m = re.search(r'explanation:\s*"((?:[^"\\]|\\.)*)"', body)
    explanation = ''
    if m:
        explanation = extract_string_value(m.group(0).split(':', 1)[1].strip())

    # Extract source (optional)
    source = None
    m = re.search(r"source:\s*'((?:[^'\\]|\\.)*)'", body)
    if not m:
        m = re.search(r'source:\s*"((?:[^"\\]|\\.)*)"', body)
    if m:
        source = extract_string_value(m.group(0).split(':', 1)[1].strip())

    # Extract situation (optional)
    situation = None
    m = re.search(r"situation:\s*'((?:[^'\\]|\\.)*)'", body)
    if not m:
        m = re.search(r'situation:\s*"((?:[^"\\]|\\.)*)"', body)
    if m:
        situation = extract_string_value(m.group(0).split(':', 1)[1].strip())

    return {
        'subject': subject,
        'level': level,
        'text': text.strip(),
        'options': options,
        'correctIndex': correct_index,
        'explanation': explanation.strip(),
        'source': source,
        'situation': situation,
    }


def clean_question(q):
    """
    Clean a single question:
    1. Remove 'allWrong' option
    2. Remove duplicate options (keep first occurrence)
    3. Ensure exactly 4 options
    4. Fix correctIndex if out of range
    Returns (cleaned_q, list_of_issues).
    """
    issues = []
    opts = list(q['options'])
    idx = q['correctIndex']

    # 1. Detect and remove allWrong option
    all_wrong_idx = None
    for i, opt in enumerate(opts):
        if is_all_wrong(opt):
            all_wrong_idx = i
            break

    if all_wrong_idx is not None:
        opts.pop(all_wrong_idx)
        issues.append(f'removed_all_wrong_at_{all_wrong_idx}')
        # Adjust correctIndex
        if idx > all_wrong_idx:
            idx -= 1
        elif idx == all_wrong_idx:
            # The correct answer was "allWrong" — set to 0, will be handled below
            idx = 0

    # 2. Remove duplicate options (exact match after normalization)
    seen = set()
    unique_opts = []
    for opt in opts:
        norm = opt.strip().lower()
        if norm not in seen:
            seen.add(norm)
            unique_opts.append(opt)
    if len(unique_opts) < len(opts):
        issues.append(f'removed_{len(opts) - len(unique_opts)}_duplicate_options')
    opts = unique_opts

    # 3. Ensure exactly 4 options
    if len(opts) > 4:
        # Keep first 4 (or keep correctIndex option + 3 others)
        if idx < len(opts):
            correct_opt = opts[idx]
            others = [o for i, o in enumerate(opts) if i != idx]
            opts = [correct_opt] + others[:3]
            idx = 0
            issues.append(f'trimmed_to_4_with_correct')
        else:
            opts = opts[:4]
            issues.append(f'trimmed_to_4_head')
    elif len(opts) < 4:
        # Pad with empty strings — will be caught by validator
        while len(opts) < 4:
            opts.append('[غير متوفر]')
            issues.append('padded_option')

    # 4. Fix correctIndex
    if idx >= len(opts):
        issues.append(f'fixed_correctIndex_from_{idx}_to_0')
        idx = 0
    if idx < 0:
        idx = 0

    q['options'] = opts
    q['correctIndex'] = idx
    return q, issues


def process_file(dart_path, dry_run=False):
    """Process a single Dart bank file → cleaned dict of banks."""
    with open(dart_path, 'r', encoding='utf-8') as f:
        content = f.read()

    banks = parse_questions_from_dart(content)
    stats = {
        'total': 0,
        'cleaned': 0,
        'issues': [],
    }

    cleaned_banks = OrderedDict()
    for subj, questions in banks.items():
        cleaned_qs = []
        for q in questions:
            stats['total'] += 1
            cq, issues = clean_question(q)
            if issues:
                stats['cleaned'] += 1
                stats['issues'].append({
                    'text': q['text'][:60],
                    'issues': issues,
                })
            cleaned_qs.append(cq)
        cleaned_banks[subj] = cleaned_qs

    return cleaned_banks, stats


def write_json(banks, out_path):
    """Write banks dict to JSON file."""
    with open(out_path, 'w', encoding='utf-8') as f:
        json.dump(banks, f, ensure_ascii=False, indent=2)


def main():
    import argparse
    parser = argparse.ArgumentParser(description='Convert Dart bank files to JSON')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--file', help='Process a single Dart file')
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if args.file:
        dart_files = [Path(args.file)]
    else:
        dart_files = sorted(DATA_DIR.glob("*bank*.dart"))

    total_questions = 0
    total_cleaned = 0
    total_issues = 0

    for dart_path in dart_files:
        if not dart_path.exists():
            continue
        if dart_path.name in SKIP_FILES:
            print(f"SKIP: {dart_path.name}")
            continue

        banks, stats = process_file(str(dart_path), dry_run=args.dry_run)
        total_questions += stats['total']
        total_cleaned += stats['cleaned']
        total_issues += len(stats['issues'])

        # Determine output filename
        json_name = FILE_MAP.get(dart_path.name)
        if not json_name:
            json_name = dart_path.stem + '.json'

        out_path = OUT_DIR / json_name

        # Count questions per subject
        q_counts = {k: len(v) for k, v in banks.items()}

        if not args.dry_run:
            write_json(banks, out_path)

        print(f"{'WRITE' if not args.dry_run else 'DRY'}: {dart_path.name} -> {json_name}")
        for subj, count in q_counts.items():
            print(f"  {subj}: {count} questions")
        if stats['issues']:
            for issue in stats['issues'][:5]:
                print(f"  FIX: {issue['text']}... -> {issue['issues']}")
            if len(stats['issues']) > 5:
                print(f"  ... and {len(stats['issues']) - 5} more fixes")
        print()

    print(f"{'='*60}")
    print(f"  Total: {total_questions} questions from {len(list(dart_files))} files")
    print(f"  Cleaned: {total_cleaned} questions had issues")
    print(f"  Issues fixed: {total_issues}")
    mode = "DRY RUN" if args.dry_run else "WRITTEN"
    print(f"  Output: {OUT_DIR} ({mode})")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()
