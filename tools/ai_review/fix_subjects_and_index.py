#!/usr/bin/env python3
"""
إصلاح مباشر: إعادة تصنيف + correctIndex في ملفات Dart.
يعمل سطر بسطر ويعدّل فقط ما هو ضروري.
"""
import re
import sys
import io
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

DATA_DIR = Path(__file__).parent.parent.parent / "lib" / "core" / "data"

# ─── قواعد إعادة التصنيف ───
RECLASSIFY_RULES = [
    # (كلمة مفتاحية في نص السؤال, subject الصحيح, السبب)
    # مجالس المؤسسة
    ("مجالس المؤسسة", "التشريع المدرسي", "مجالس المؤسسة"),
    ("مجلس الإدارة", "التشريع المدرسي", "مجلس الإدارة"),
    ("المجلس التربوي", "التشريع المدرسي", "المجلس التربوي"),
    ("مجلس التأطير", "التشريع المدرسي", "مجلس التأطير"),
    ("رئاسة المجلس", "التشريع المدرسي", "رئاسة المجلس"),
    ("أعضاء المجلس", "التشريع المدرسي", "أعضاء المجلس"),
    ("مجالس التعليمية", "التشريع المدرسي", "مجالس التعليمية"),
    ("المجلس الإداري", "التشريع المدرسي", "المجلس الإداري"),
    ("نوعيات المجالس", "التشريع المدرسي", "نوعيات المجالس"),
    ("انتخابات المجلس", "التشريع المدرسي", "انتخابات المجلس"),
    ("مجلس الأعضاء", "التشريع المدرسي", "مجلس الأعضاء"),
    ("يندرج ضمن مجالس", "التشريع المدرسي", "يندرج ضمن مجالس"),
    ("يترأس مجالس", "التشريع المدرسي", "يترأس مجالس"),
    ("المجلس الذي يحضره ممثل", "التشريع المدرسي", "مجلس بحضور جماعي"),
    ("يصادق على النظام الداخلي", "التشريع المدرسي", "النظام الداخلي"),
    ("يترأس أعمال المجلس الإداري", "التشريع المدرسي", "رئاسة المجلس الإداري"),
    ("الصالحيات التي يتمتع بها المجلس الإداري", "التشريع المدرسي", "صالحيات المجلس"),
    ("المجلس الذي يقترح النظام الداخلي", "التشريع المدرسي", "اقتراح النظام الداخلي"),
    ("يتم تعيين أعضاء المجلس التربوي", "التشريع المدرسي", "تعيين أعضاء المجلس"),
    ("يصادق على耏ttilت", "التشريع المدرسي", "مصادقة"),

    # النظام الداخلي / العقوبات / التشريع
    ("النظام الداخلي", "التشريع المدرسي", "النظام الداخلي"),
    ("العقوبات التأديبية", "التشريع المدرسي", "العقوبات التأديبية"),
    ("النظام الأساسي العام", "التشريع المدرسي", "النظام الأساسي"),
    ("النظام التأديبي", "التشريع المدرسي", "النظام التأديبي"),
    ("القانون الإطار", "التشريع المدرسي", "القانون الإطار"),
    ("القانون 01-00", "التشريع المدرسي", "القانون"),

    # الحياة المدرسية / التنشيط
    ("الحياة المدرسية", "التنشيط التربوي", "الحياة المدرسية"),
    ("الأنشطة الموازية", "التنشيط التربوي", "الأنشطة الموازية"),
    ("الرحلات المدرسية", "التنشيط التربوي", "الرحلات المدرسية"),
    ("المكتبة المدرسية", "التنشيط التربوي", "المكتبة المدرسية"),
    ("الأندية التربوية", "التنشيط التربوي", "الأندية التربوية"),
    ("أنشطة الحياة المدرسية", "التنشيط التربوي", "أنشطة الحياة المدرسية"),
    ("تنشيط الحياة المدرسية", "التنشيط التربوي", "تنشيط الحياة المدرسية"),
    ("الحياة المدرسية بالمؤسسة", "التنشيط التربوي", "الحياة المدرسية"),
    ("الحياة المدرسية حسب", "التنشيط التربوي", "الحياة المدرسية"),
    ("دليل الحياة المدرسية", "التنشيط التربوي", "دليل الحياة المدرسية"),
    ("الرخص الأدبية", "التنشيط التربوي", "الحياة المدرسية"),
]

# كلمات يجب ألا تُنقّل (مجالس في سياق نظري)
FALSE_POSITIVE_PATTERNS = [
    "مجلس torino",
    "المجلس التربوي في النظرية",
]


def classify(text):
    """يصنف النص ويُرجع (subject, reason) أو (None, None)."""
    for kw, subject, reason in RECLASSIFY_RULES:
        if kw in text:
            # تحقق من الإيجابيات الكاذبة
            for fp in FALSE_POSITIVE_PATTERNS:
                if fp in text:
                    return None, None
            return subject, reason
    return None, None


def process_file(file_path, dry_run=False):
    """يعالج ملف Dart سطراً بسطر."""
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    changes = []
    in_question = False
    current_subject_line = None
    current_subject = None
    question_text = ""
    in_options = False
    option_count = 0
    correct_index_line = None
    correct_index_val = None
    block_start = 0

    for i, line in enumerate(lines):
        stripped = line.strip()

        # بداية سؤال جديد
        if "Question(" in stripped and not stripped.startswith("//"):
            in_question = True
            current_subject_line = None
            current_subject = None
            question_text = ""
            in_options = False
            option_count = 0
            correct_index_line = None
            correct_index_val = None
            block_start = i

        if not in_question:
            continue

        # استخراج subject
        m = re.search(r"subject:\s*'([^']+)'", stripped)
        if m:
            current_subject_line = i
            current_subject = m.group(1)

        # استخراج text
        m = re.search(r"text:\s*'((?:[^'\\]|\\.)*)'", stripped)
        if not m:
            m = re.search(r'text:\s*"((?:[^"\\]|\\.)*)"', stripped)
        if m:
            question_text = m.group(1)

        # عدّ الخيارات
        if "options:" in stripped:
            in_options = True
            option_count = len(re.findall(r"'[^']*'|\"[^\"]*\"", stripped)) - 1
            # خيار subject يُحسب — نطرحه
            if option_count > 0:
                option_count = max(0, option_count - 1)
        elif in_options:
            if stripped.startswith("]"):
                in_options = False
            else:
                option_count += len(re.findall(r"'[^']*'|\"[^\"]*\"", stripped))

        # correctIndex
        m = re.search(r"correctIndex:\s*(\d+)", stripped)
        if m:
            correct_index_line = i
            correct_index_val = int(m.group(1))

        # نهاية السؤال
        if stripped in ("),", ")") and in_question:
            in_question = False

            # 1. إعادة تصنيف
            if question_text and current_subject:
                new_subj, reason = classify(question_text)
                if new_subj and new_subj != current_subject:
                    changes.append({
                        "line": current_subject_line + 1,
                        "type": "reclassify",
                        "old": current_subject,
                        "new": new_subj,
                        "reason": reason,
                        "text": question_text[:60],
                    })
                    if not dry_run:
                        lines[current_subject_line] = lines[current_subject_line].replace(
                            f"subject: '{current_subject}'",
                            f"subject: '{new_subj}'"
                        )

            # 2. إصلاح correctIndex خاطئ (4 في بنك4 خيارات)
            if correct_index_line is not None and correct_index_val is not None:
                if option_count > 0 and correct_index_val >= option_count:
                    changes.append({
                        "line": correct_index_line + 1,
                        "type": "fix_index",
                        "old": correct_index_val,
                        "new": 0,
                        "text": question_text[:60],
                    })
                    if not dry_run:
                        lines[correct_index_line] = lines[correct_index_line].replace(
                            f"correctIndex: {correct_index_val}",
                            "correctIndex: 0"
                        )

    if not dry_run:
        with open(file_path, "w", encoding="utf-8") as f:
            f.writelines(lines)

    return changes


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--files", nargs="*")
    args = parser.parse_args()

    if args.files:
        files = [Path(f) for f in args.files]
    else:
        files = sorted(DATA_DIR.glob("*bank*.dart"))

    total = 0
    for fp in files:
        if not fp.exists():
            continue
        changes = process_file(str(fp), dry_run=args.dry_run)
        if changes:
            print()
            print('=' * 60)
            print(f"  {fp.name} -- {len(changes)} changes")
            print('=' * 60)
            for c in changes:
                tag = "RECLASSIFY" if c["type"] == "reclassify" else "FIX_INDEX"
                if c["type"] == "reclassify":
                    print(f"  Line {c['line']}: [{tag}] {c['old']} >> {c['new']} ({c['reason']})")
                    print(f"    {c['text']}")
                else:
                    print(f"  Line {c['line']}: [{tag}] correctIndex: {c['old']} >> {c['new']}")
                    print(f"    {c['text']}")
            total += len(changes)

    mode = "DRY RUN" if args.dry_run else "APPLIED"
    print()
    print('-' * 60)
    print(f"  {mode}: {total} changes in {len(files)} files")
    print('-' * 60)


if __name__ == "__main__":
    main()
