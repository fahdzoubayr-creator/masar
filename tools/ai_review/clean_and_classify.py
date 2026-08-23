#!/usr/bin/env python3
"""
سكريبت تنظيف وتصنيف بنوك الأسئلة — نسخة JSON.
يعمل على ملفات assets/banks/*.json مباشرة.

الضوابط:
1. إعادة تصنيف "مشروع المؤسسة" و"مجالس المؤسسة" → التشريع المدرسي
2. تنظيف النصوص التالفة
3. ضمان 5 خيارات (يتطلب json_cleaner.py)
"""

import json
import re
import sys
import os
from pathlib import Path

BANKS_DIR = Path(__file__).parent.parent.parent / "assets" / "banks"

# ─── تصنيف المحاور (نقاطertiary) ───

RECLASSIFY_KEYWORDS = [
    "مشروع المؤسسة", "مجالس المؤسسة", "مجالس المؤسسة التعليمية",
    "المجلس التربوي", "مجلس التأطير", "مجلس الإدارة",
    "المجلس الإداري", "أنواع المجالس", "نوعيات المجالس",
    "رئاسة المجلس", "أعضاء المجلس", "انتخابات المجلس",
    "ميثاق المؤسسة", "المشروع التربوي للمؤسسة",
    "Partenariat", "numéral", "n mural",
]

RECLASSIFY_FROM = {"علوم التربية والبيداغوجيا", "علوم التربية"}
RECLASSIFY_TO = "التشريع المدرسي والإداري"

SUBJECT_RULES = [
    {
        "keywords": [
            "النظام الداخلي", "العقوبات التأديبية", "الرخص",
            "المسؤولية التقصيرية", "القانون 01-00", "النظام التأديبي",
            "الجزاء", "المخالفة التأديبية", "الإنذار", "الция",
        ],
        "subject": "التشريع المدرسي والإداري",
        "reason": "سؤال تشريعي/تنظيمي",
    },
    {
        "keywords": [
            "الحياة المدرسية", "الرحلات المدرسية", "المكتبة المدرسية",
            "الأنشطة التربوية", "الأندية التربوية", "فتح المؤسسة",
        ],
        "subject": "التنشيط التربوي",
        "reason": "سؤال عن الحياة المدرسية",
    },
]


def classify_question(text, current_subject):
    """يصنف السؤال حسب المحتوى."""
    # إعادة تصنيف مشاركة المؤسسة
    if current_subject in RECLASSIFY_FROM:
        for kw in RECLASSIFY_KEYWORDS:
            if kw in text:
                return RECLASSIFY_TO, f"سؤال عن {kw}"

    # تصنيف عام
    for rule in SUBJECT_RULES:
        for kw in rule["keywords"]:
            if kw in text:
                return rule["subject"], rule["reason"]

    return None, None


def clean_text(text):
    """تنظيف النص."""
    s = text.strip()
    s = re.sub(r'\s*\(غير\s+موجود\)', '', s)
    s = re.sub(r'\s*\(غير\s+متوفر\)', '', s)
    s = re.sub(r'\s{2,}', ' ', s)
    return s.strip()


def process_file(json_path, dry_run=False):
    """يعالج ملف JSON واحد."""
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    total = 0
    issues = []

    for subject, questions in data.items():
        for qi, q in enumerate(questions):
            total += 1
            text = q.get("text", "")
            subject_key = q.get("subject", subject)

            # تنظيف النص
            cleaned = clean_text(text)
            if cleaned != text:
                issues.append({
                    "subject": subject,
                    "index": qi,
                    "text": text[:70],
                    "problems": [f"تنظيف النص"],
                })
                if not dry_run:
                    q["text"] = cleaned

            # تصنيف
            new_subj, reason = classify_question(cleaned, subject_key)
            if new_subj and new_subj != subject_key:
                issues.append({
                    "subject": subject,
                    "index": qi,
                    "text": cleaned[:70],
                    "problems": [f"تصنيف: {subject_key} → {new_subj} ({reason})"],
                })
                if not dry_run:
                    q["subject"] = new_subj

    return data, total, issues


def write_json(data, out_path):
    """يكتب البيانات إلى ملف JSON."""
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="تنقيب وتصنيف بنوك الأسئلة (JSON)")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--files", nargs="*", help="ملفات محددة")
    args = parser.parse_args()

    if args.files:
        files = [Path(f) for f in args.files]
    else:
        files = sorted(BANKS_DIR.glob("*.json"))

    total_q = 0
    total_issues = 0

    for fp in files:
        if not fp.exists():
            continue

        data, count, issues = process_file(str(fp), dry_run=args.dry_run)
        total_q += count
        total_issues += len(issues)

        if issues:
            print(f"\n{'='*60}")
            print(f"  {fp.name} — {count} سؤال، {len(issues)} مشكلة")
            print(f"{'='*60}")
            for iss in issues[:10]:
                print(f"  [{iss['subject']}] #{iss['index']}: {iss['text']}")
                print(f"    → {', '.join(iss['problems'])}")
            if len(issues) > 10:
                print(f"  ... و {len(issues) - 10} مشاكل أخرى")

        if not args.dry_run and issues:
            write_json(data, fp)

    mode = "مراجعة" if args.dry_run else "تطبيق"
    print(f"\n{'─'*60}")
    print(f"  {mode}: {total_q} سؤال، {total_issues} مشكلة في {len(list(files))} ملف")
    print(f"{'─'*60}")


if __name__ == "__main__":
    main()
