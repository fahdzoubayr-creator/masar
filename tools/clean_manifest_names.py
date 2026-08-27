# -*- coding: utf-8 -*-
"""
تنظيف أسماء ملفات المراجعة في manifest.json وإعادة ترتيب كل محور فرعي
حسب أرقام الترتيب المحمولة في الأسماء (بادئة أو لاحقة بعد شرطة).

- يحافظ على مسارات pdf/txt كما هي.
- يرتب داخل كل (مجلد، محور فرعي) بحسب الرقم، مع بقاء المداخل غير المرقمة
  بعد المرقمة (بنفس ترتيبها الأصلي النسبي).
- يحذف رقم الترتيب من الاسم وينظف الشوائب (._-'":/، ملفات مكررة، امتدادات).
- يصحح أخطاء إملائية مدروسة.

الاستخدام:
    python tools/clean_manifest_names.py           # يكتب التقرير فقط
    python tools/clean_manifest_names.py --apply    # يكتب manifest.json جديد
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import OrderedDict

sys.stdout.reconfigure(encoding="utf-8")

PROJECT = r"D:\masar_app\masar_app"
MANIFEST = PROJECT + r"\assets\review_files\manifest.json"
REPORT = r"C:\Users\JAMAL\AppData\Local\Temp\opencode\manifest_clean_report.txt"

# محاور تُطبق عليها إعادة الترتيب بالأرقام (لاحقة شرطة/بادئة).
ORDERED_FOLDERS = {
    "خطاطات ذهنية",
    "دورات تكوينية",
    "ديداكتيك الرياضيات",
    "التنشيط التربوي",
    "ديداكتيك اللغة العربية",
    "التشريع المدرسي",
}

# نسبة الحد الأدنى من المداخل المرقمة داخل المحور الفرعي لاعتماد الفرز.
NUMBERED_TOPIC_RATIO = 0.55


# ---------------- استخراج رقم الترتيب ----------------

def leading_number(name: str):
    """رقم بادئة يتبعه فراغ/شرطة، أو ملاصق لجملة داخل محاور مرقمة فقط."""
    m = re.match(r"^\s*(\d{1,3})\s*(?:[-_–—]\s*)?", name)
    if not m:
        return None
    num = int(m.group(1))
    rest = name[m.end():]
    # لا تُعتبر "100سؤال"/"1030 سؤال"/"المستوى 2..." أرقام ترتيب عامة
    # الاشتراط: لا يتلوه حرف لاتيني (1re/1AP) ولا كلمة "سؤال/المستوى/الجزء"
    head = rest.lstrip()[:6]
    if re.match(r"^[A-Za-z]", head):
        return None
    if num > 0 and num <= 999:
        return num
    return None


def suffix_number(name: str):
    """رقم لاحقة بعد شرطة/شرطة سفلية: 'اسم-N'"""
    m = re.search(r"[-_–—]\s*(\d{1,3})\s*$", name)
    if not m:
        return None
    num = int(m.group(1))
    if num > 0 and num <= 999:
        return num
    return None


def extract_number(name: str):
    lead = leading_number(name)
    if lead is not None:
        return lead, "prefix"
    suf = suffix_number(name)
    if suf is not None:
        return suf, "suffix"
    return None, None


# ---------------- حذف رقم الترتيب من الاسم ----------------

def strip_order_marker(name: str) -> str:
    lead = leading_number(name)
    if lead is not None:
        # يبتلع أيضًا الترقيم (فاصلة/نقطة...) بعد رقم البادئة: "5, الكفايات" -> "الكفايات"
        return re.sub(r"^\s*(\d{1,3})\s*(?:[-_–—]\s*|[,.;،:·]\s*)?", "", name, count=1)
    suf = suffix_number(name)
    if suf is not None:
        return re.sub(r"[-_–—]\s*(\d{1,3})\s*$", "", name, count=1)
    return name


def strip_junk_attached_digit(name: str) -> str:
    """في المحاور غير المرقمة: يزيل رقمًا واحدًا ملاصقًا لعربية فقط ('1نهج' -> 'نهج')
    دون المساس بأعداد حقيقية مثل '100سؤال' أو '1030 سؤال'."""
    m = re.match(r"^\s*\d\s*([\u0600-\u06FF])", name)
    if m:
        return m.group(1) + name[m.end():]
    return name


# ---------------- تنظيف الاسم ----------------

def clean_name(raw: str, allow_order_strip: bool = False) -> str:
    s = raw.strip()
    if allow_order_strip:
        s = strip_order_marker(s)
    else:
        s = strip_junk_attached_digit(s)
    # امتدادات وملحقات ملفات (في أي موضع، وليس فقط النهاية)
    s = re.sub(r"\.(?:pdf|pptx?|docx?|xlsx?)\b", "", s, flags=re.I)
    # "(100) سؤال" -> "100 سؤال" (عدد حقيقي، لا يُحذف)
    s = re.sub(r"\(\s*(\d+)\s*\)\s*(سؤال)", r"\1 \2", s)
    s = re.sub(r"\s*\(\s*\d+\s*\)\s*\(\s*\d+\s*\)", "", s)  # (1) (1)
    s = re.sub(r"\s*\(\s*\d+\s*\)", "", s)                  # (1)/(2)
    s = re.sub(r"~1", "", s, flags=re.I)
    # محارف شائعة في أسماء الملفات → فراغ
    s = s.replace("_", " ")
    s = s.replace(",", " ")
    s = s.replace("+", " ")
    s = s.replace("،", "، ")
    s = s.replace("  ", " ")
    # فراغ بين العربية والأرقام: المستوى4 -> المستوى 4
    s = re.sub(r"([\u0600-\u06FF])(\d)", r"\1 \2", s)
    s = re.sub(r"(\d)([\u0600-\u06FF])", r"\1 \2", s)
    # الهامزة المكسورة الإملائية
    corrections = [
        ("أخالقيات", "أخلاقيات"),
        ("نمودج", "نموذج"),
        ("تاسيس", "تأسيس"),
        ("الاندية", "الأندية"),
        ("الانشطة", "الأنشطة"),
        ("التةاصل", "التواصل"),
        ("ديدكتيك", "ديداكتيك"),
        ("استراتيجات", "استراتيجيات"),
        ("إبتدائي", "ابتدائي"),
        ("الابتذائي", "الابتدائي"),
        ("الابتذائية", "الابتدائية"),
        ("الاستراتجية", "الاستراتيجية"),
        ("فاسفة", "فلسفة"),
        ("بيداخوجيات", "بيداغوجيات"),
        ("ماقل ودل", "مقال ودل"),
        ("العالجة", "المعالجة"),
        ("الياضيات", "الرياضيات"),
        ("التغدية", "التغذية"),
        ("النمودج", "النموذج"),
        ("ضعيات", "وضعيات"),
        ("الاجابة", "الإجابة"),
        ("المستوىالاول", "المستوى الأول"),
        ("المستوىالثاني", "المستوى الثاني"),
        ("ية", "ية"),
        ("Annee 5", "Année 5"),
        ("Annee 6", "Année 6"),
        ("franA§ais", "français"),
        ("FranA§ais", "français"),
        ("canA§a", "ç"),
    ]
    for a, b in corrections:
        if a == "ية":
            continue
        s = s.replace(a, b)
    # فراغات وعزل متكرر
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"^\s*[#*٪@،:;-]\s*", "", s)
    s = re.sub(r"\s*[-_–—]\s*$", "", s)
    s = s.strip(" .-–—_:;'/")
    return s.strip()


def topic_key(e):
    return e.get("topic", "")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = json.load(fh, object_pairs_hook=OrderedDict)

    report_lines = []
    total_changed = 0
    reordered = 0

    for folder, entries in manifest.items():
        # ترتيب ظهور المواضيع: أول ظهور في المصفوفة الأصلية
        topic_order: list[str] = []
        for e in entries:
            tk = topic_key(e)
            if tk and tk not in topic_order:
                topic_order.append(tk)

        groups: "OrderedDict[str, list]" = OrderedDict()
        for tk in topic_order:
            groups[tk] = []
        groups[""] = []  # بلا موضوع

        for e in entries:
            groups[topic_key(e)].append(e)

        new_entries = []
        for tk, group in groups.items():
            if not group:
                continue
            # تحديد هل هذا المحور الفرعي مؤهل للفرز بالأرقام
            numbered = [e for e in group if extract_number(e.get("name", ""))[0] is not None]
            do_sort = (
                folder in ORDERED_FOLDERS
                and len(group) >= 3
                and len(numbered) / len(group) >= NUMBERED_TOPIC_RATIO
            )
            if do_sort:
                # مستقرة: المرقمة تصاعدياً، غير المرقمة بعدها بترتيبها الأصلي
                tagged = [
                    (extract_number(e.get("name", ""))[0], e) for e in group
                ]
                tagged.sort(key=lambda t: (t[0] is None, t[0] if t[0] is not None else 0))
                group = [e for _n, e in tagged]
                if tk:
                    reordered += len(group)

            # تنظيف الأسماء (يتم هنا حتى لا تتأثر أكواد الفرز أعلاه)
            for e in group:
                old_name = e.get("name", "")
                new_name = clean_name(old_name, do_sort)
                changed = new_name != old_name
                total_changed += 1 if changed else 0
                e["name"] = new_name
                report_lines.append(f"{folder} | #{len(new_entries) + 1:>3} | old: {old_name}")
                if changed:
                    report_lines.append(f"{' ' * len(folder)} |      | new: {new_name}")
                else:
                    report_lines.append(f"{' ' * len(folder)} |      | new: (دون تغيير)")
                new_entries.append(e)

        manifest[folder] = [dict(e) for e in new_entries]

    report_lines.insert(0, f"CFG apply={args.apply}  folders={len(manifest)}")
    report_lines.insert(1, f"changed_names={total_changed}  reordered_in_topics={reordered}")

    with open(REPORT, "w", encoding="utf-8") as fh:
        fh.write("\n".join(report_lines) + "\n")

    if args.apply:
        with open(MANIFEST, "w", encoding="utf-8") as fh:
            json.dump(manifest, fh, ensure_ascii=False, indent=2)
            fh.write("\n")
        print(f"APPLIED -> {MANIFEST}")
    else:
        print(f"REPORT -> {REPORT} (dry-run; لا تغيير)")

    print(f"folders={len(manifest)} changed_names={total_changed} reordered_in_topics={reordered}")
    return 0


if __name__ == "__main__":
    sys.exit(main())