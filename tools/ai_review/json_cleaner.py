#!/usr/bin/env python3
"""
JSON Bank Cleaner v3 — Fix corrupted options & enforce 5-option format.

Rules:
1. Every question must have exactly 5 options.
2. Option[4] = "كل الاقتراحات خاطئة" (AR) / "Toutes les réponses ci-dessus sont fausses." (FR)
3. Options[0]-[3] = unique valid options (no corruption, no placeholders).
4. If <4 valid options remain after cleanup, correctIndex MUST be 4 (allWrong).
5. NO placeholder text ever generated. Corrupted options are REMOVED, not replaced.
6. Reclassify "مشروع المؤسسة" / "مجالس المؤسسة" questions to التشريع المدرسي.

Usage:
    python json_cleaner.py                     # clean all files
    python json_cleaner.py --file some.json    # clean one file
    python json_cleaner.py --dry-run           # preview without writing
"""

import json
import re
import sys
import io
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

BANKS_DIR = Path(__file__).parent.parent.parent / "assets" / "banks"

ALL_WRONG_OPTION_AR = "كل الاقتراحات خاطئة"
ALL_WRONG_OPTION_FR = "Toutes les réponses ci-dessus sont fausses."

ALL_WRONG_PATTERNS = [
    "جميع الاختيارات أعلاه خاطئة",
    "جميع ما سبق خاطئ",
    "جميع الخيارات خاطئة",
    "جميع الإجابات أعلاه خاطئة",
    "جميع الاختيارات أعلاه غير صحيحة",
    "all of the above are wrong",
    "toutes les réponses précédentes sont fausses",
    "toutes les réponses ci-dessus sont fausses",
    "tous les choix ci-dessus sont incorrects",
    "لا شيء مما سبق",
    "none of the above",
    "كل الاقتراحات خاطئة",
]

CORRUPTED_OPTION_PATTERNS = [
    "[غير متوفر]",
    "[غير موجود]",
    "[غير معرف]",
    "[غير محدد]",
]

CORRUPTED_OPTION_REGEX = [
    r'^الخيار\s+البديل\s+رقم\s+\d+',     # "الخيار البديل رقم X"
    r'^Option\s+alternative\s+\d+',         # "Option alternative X"
    r"^L'option\s+alternative\s+\d+",       # "L'option alternative X"
    r'^الخيار\s+[أ-ي]\s*:',               # "الخيار أ:" etc.
]

RECLASSIFY_KEYWORDS = [
    "مشروع المؤسسة", "مجالس المؤسسة", "مجالس المؤسسة التعليمية",
    "المجلس التربوي", "مجلس التأطير", "مجلس الإدارة",
    "المجلس الإداري", "أنواع المجالس", "نوعيات المجالس",
    "رئاسة المجلس", "أعضاء المجلس", "انتخابات المجلس",
    "ميثاق المؤسسة", "المشروع التربوي للمؤسسة",
]

RECLASSIFY_FROM = {"علوم التربية والبيداغوجيا", "علوم التربية"}
RECLASSIFY_TO = "التشريع المدرسي والإداري"


def is_all_wrong(text):
    t = text.strip().lower()
    return any(p.lower() == t for p in ALL_WRONG_PATTERNS)


def is_corrupted_option(text):
    t = text.strip()
    for pat in CORRUPTED_OPTION_PATTERNS:
        if pat in t:
            return True
    for regex in CORRUPTED_OPTION_REGEX:
        if re.match(regex, t):
            return True
    return False


def clean_text(text):
    s = text.strip()
    s = re.sub(r'\s*\(غير\s+موجود\)', '', s)
    s = re.sub(r'\s*\(غير\s+متوفر\)', '', s)
    s = re.sub(r'\s*\(غير\s+معرف\)', '', s)
    s = re.sub(r'\s*\(غير\s+محدد\)', '', s)
    s = re.sub(r'^الخيار\s+[أ-ي]\s*:\s*', '', s)
    s = re.sub(r'\s{2,}', ' ', s)
    s = re.sub(r'^[\s،,·:：\-–—]+|[\s،,·:：\-–—]+$', '', s)
    return s.strip()


def should_reclassify(text):
    for kw in RECLASSIFY_KEYWORDS:
        if kw in text:
            return True
    return False


def deduplicate_options(options):
    seen = set()
    unique = []
    for opt in options:
        k = opt.strip().lower()
        if k and k not in seen:
            seen.add(k)
            unique.append(opt)
    return unique


def is_french_question(q):
    opts = q.get("options", [])
    text = q.get("text", "")
    fr_markers = ["Toutes les", "réponses", "suivantes", "D'après", "Selon", "le texte"]
    ar_markers = ["وفق النص", "ما المقصود", "أي عبارة"]
    fr_count = sum(1 for m in fr_markers if m.lower() in text.lower())
    ar_count = sum(1 for m in ar_markers if m.lower() in text.lower())
    return fr_count > ar_count


def ensure_5_options(q):
    """
    Enforce exactly 5 options:
    - [0]-[3] = 4 unique valid objective options
    - [4] = allWrong
    - If <4 valid options remain after removing corrupted ones, correctIndex = 4
    - NEVER generate placeholder text
    """
    issues = []
    opts = list(q.get("options", []))
    idx = q.get("correctIndex", 0)
    french = is_french_question(q)
    all_wrong = ALL_WRONG_OPTION_FR if french else ALL_WRONG_OPTION_AR

    # 1. Remove all allWrong options from current list
    cleaned_opts = [o for o in opts if not is_all_wrong(o)]
    removed_aw = len(opts) - len(cleaned_opts)
    if removed_aw:
        issues.append(f"removed_{removed_aw}_all_wrong")

    # 2. Remove all corrupted options
    real_opts = [o for o in cleaned_opts if not is_corrupted_option(o)]
    removed_corr = len(cleaned_opts) - len(real_opts)
    if removed_corr:
        issues.append(f"removed_{removed_corr}_corrupted")

    # 3. Clean text of each remaining option
    real_opts = [clean_text(o) for o in real_opts]

    # 4. Remove empty options after cleaning
    real_opts = [o for o in real_opts if o.strip()]

    # 5. Deduplicate
    deduped = deduplicate_options(real_opts)
    if len(deduped) < len(real_opts):
        issues.append(f"removed_{len(real_opts) - len(deduped)}_duplicates")

    # 6. If more than 4 real options, keep 4
    if len(deduped) > 4:
        if idx < len(opts) and not is_all_wrong(opts[idx]) and not is_corrupted_option(opts[idx]):
            correct_text = clean_text(opts[idx])
            others = [o for o in deduped if o != correct_text]
            deduped = [correct_text] + others[:3]
        else:
            deduped = deduped[:4]
        issues.append("trimmed_to_4")

    # 7. Fix correctIndex
    # If the original correctIndex pointed to an allWrong or corrupted option, set to 4
    if idx < len(opts):
        if is_all_wrong(opts[idx]) or is_corrupted_option(opts[idx]):
            idx = 4
            issues.append("corrected_index_from_corrupted")
    if idx >= len(deduped) and idx != 4:
        idx = 4
        issues.append("corrected_index_out_of_range")

    # 8. If fewer than 4 real options, pad with dashes to reach exactly 4
    #    But DO NOT force correctIndex=4 if the original answer is still valid
    if len(deduped) < 4:
        # Pad with dashes to reach exactly 4 before allWrong
        while len(deduped) < 4:
            deduped.append("—")
        issues.append("padded_with_dash")

    if idx < 0:
        idx = 0

    # 9. Build final: 4 options + allWrong
    final_opts = deduped[:4] + [all_wrong]

    # Final index safety
    if idx > 4 or idx < 0:
        idx = 4

    q["options"] = final_opts
    q["correctIndex"] = idx

    return q, issues


def process_file(json_path, dry_run=False):
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    stats = {
        "total": 0,
        "cleaned": 0,
        "reclassified": 0,
        "issues": [],
    }

    cleaned_data = {}
    for subject, questions in data.items():
        cleaned_qs = []
        for q in questions:
            stats["total"] += 1
            text = q.get("text", "")

            if subject in RECLASSIFY_FROM and should_reclassify(text):
                q["subject"] = RECLASSIFY_TO
                stats["reclassified"] += 1
                issues = [f"reclassified_to_{RECLASSIFY_TO}"]
            else:
                issues = []

            q["text"] = clean_text(text)
            q, opt_issues = ensure_5_options(q)
            issues.extend(opt_issues)

            if issues:
                stats["cleaned"] += 1
                stats["issues"].append({
                    "subject": subject,
                    "text": q["text"][:60],
                    "issues": issues,
                })

            cleaned_qs.append(q)

        reclassified = [q for q in cleaned_qs if q.get("subject") == RECLASSIFY_TO]
        remaining = [q for q in cleaned_qs if q.get("subject") != RECLASSIFY_TO]

        if reclassified:
            if RECLASSIFY_TO not in cleaned_data:
                cleaned_data[RECLASSIFY_TO] = []
            cleaned_data[RECLASSIFY_TO].extend(reclassified)
        if remaining:
            if subject not in cleaned_data:
                cleaned_data[subject] = []
            cleaned_data[subject].extend(remaining)

    return cleaned_data, stats


def write_json(data, out_path):
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="JSON Bank Cleaner v3")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--files", nargs="*", help="Specific files")
    args = parser.parse_args()

    if args.files:
        files = [Path(f) for f in args.files]
    else:
        files = sorted(BANKS_DIR.glob("*.json"))

    total_q = 0
    total_cleaned = 0
    total_reclassified = 0

    for fp in files:
        if not fp.exists():
            continue

        data, stats = process_file(str(fp), dry_run=args.dry_run)
        total_q += stats["total"]
        total_cleaned += stats["cleaned"]
        total_reclassified += stats["reclassified"]

        if not args.dry_run:
            write_json(data, fp)

        if stats["issues"]:
            print(f"\n{'='*60}")
            print(f"  {fp.name} — {stats['total']} questions, {len(stats['issues'])} fixed")
            print(f"{'='*60}")
            for iss in stats["issues"][:10]:
                print(f"  [{iss['subject']}] {iss['text']}")
                print(f"    -> {', '.join(iss['issues'])}")
            if len(stats["issues"]) > 10:
                print(f"  ... and {len(stats['issues']) - 10} more")

        if stats["reclassified"]:
            print(f"  RECLASSIFY: {stats['reclassified']} -> {RECLASSIFY_TO}")

    mode = "preview" if args.dry_run else "applied"
    print(f"\n{'─'*60}")
    print(f"  {mode}: {total_q} questions, {total_cleaned} fixed, {total_reclassified} reclassified")
    print(f"  Files: {len(list(files))}")
    print(f"{'─'*60}")


if __name__ == "__main__":
    main()
