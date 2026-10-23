# -*- coding: utf-8 -*-
"""يولّد lib/features/review/data/review_content.dart من topics_index.json.

كل محور فرعي في الفهرس = ملف مصدر واحد. يُضاف pdfTopic لربط المحاور
الجديدة بوسم PDF القديم في المانيفست (حتى لا تختفي ملفات المراجعة).
"""
import io
import json
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
INDEX = PROJECT / "assets" / "banks" / "topics_index.json"
OUT = PROJECT / "lib" / "features" / "review" / "data" / "review_content.dart"

FOLDERS = [
    ("علوم التربية", "school_outlined"),
    ("ديداكتيك اللغة العربية", "auto_stories_outlined"),
    ("ديداكتيك اللغة الفرنسية", "translate_outlined"),
    ("ديداكتيك الرياضيات", "calculate_outlined"),
    ("ديداكتيك النشاط العلمي", "science_outlined"),
    ("التشريع المدرسي", "balance_outlined"),
    ("التنشيط التربوي", "emoji_people_outlined"),
    ("خطاطات ذهنية", "account_tree_outlined"),
    ("دورات تكوينية", "card_membership_outlined"),
    ("مراسلات ومذكرات", "mail_outline_rounded"),
    ("مشروع المؤسسة المندمج", "hub_outlined"),
    ("مؤسسات الريادة", "star_rounded"),
]
EMPTY_TOPICS = {"خطاطات ذهنية": "خطاطات ذهنية",
                "دورات تكوينية": "دورات تكوينية"}

LEGACY = {
    "علوم التربية": {
        "صعوبات": "صعوبات التعلم وعوائقه",
        "سوسيولوجيا": "سوسيولوجيا التربية وسيكوسوسيولوجيا التربية",
        "سيكوسوسيولوجيا": "سوسيولوجيا التربية وسيكوسوسيولوجيا التربية",
        "سيكولوجيا": "سيكولوجيا التربية وتقاطعاتها",
        "علم النفس النمو": "سيكولوجيا التربية وتقاطعاتها",
        "النمو": "النمو واستراتيجيات اكتساب الفهم",
        "الإصلاح": "الإصلاح التربوي والسياسة التعليمية",
        "التخطيط": "تخطيط وتدبير التعلمات",
        "التقويم": "التقويم والدعم التربويان",
        "التمايز": "التقويم والدعم التربويان",
        "المقاربات": "نظريات التعلم والمقاربات البيداغوجية",
        "نظريات": "نظريات التعلم والمقاربات البيداغوجية",
    },
    "ديداكتيك اللغة العربية": {
        "الحصص": "الحصص",
        "المستويان": "عدة كاملة خاصة بالمستويات الابتدائية",
        "عدة كاملة": "عدة كاملة خاصة بالمستويات الابتدائية",
    },
    "التنشيط التربوي": {
        "الاندية": "الاندية التربوية",
        "التربية الدامجة": "التربية الدامجة",
        "الحياة المدرسية": "الحياة المدرسية",
        "مجالس المؤسسة": "مجالس المؤسسة",
    },
}
SINGLE = {
    "ديداكتيك اللغة الفرنسية": "Didactique",
    "ديداكتيك الرياضيات": "ديداكتيك الرياضيات",
    "ديداكتيك النشاط العلمي": "ديداكتيك",
    "التشريع المدرسي": "التشريع المدرسي",
    "مراسلات ومذكرات": "مراسلات ومذكرات",
    "مشروع المؤسسة المندمج": "مشروع المؤسسة المندمج",
    "مؤسسات الريادة": "مؤسسات الريادة — مقاربة TaRL",
}


def pdf_topic(folder, topic):
    if folder in SINGLE:
        return SINGLE[folder]
    for key, legacy in LEGACY.get(folder, {}).items():
        if key in topic:
            return legacy
    return topic


def dq(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")


def main():
    idx = json.loads(INDEX.read_text(encoding="utf-8"))
    topics = {}
    for e in idx.get("topics", []):
        topics.setdefault(e["folder"], []).append(e["topic"])
    for folder, _icon in FOLDERS:
        if folder in EMPTY_TOPICS and folder not in topics:
            topics[folder] = [EMPTY_TOPICS[folder]]

    head = """import 'package:flutter/material.dart';

/// بيانات المحاور الفرعية لفضاء المراجعة والتحضير —
/// مشتركة بين شاشة فضاء المراجعة وشاشة أفضل النسب.
/// مولَّد آلياً بـtools/gen_review_content.py من topics_index.json.
class ReviewTopic {
  final String title;
  /// وسم PDF القديم في المانيفست (يبقى رابط ملفات المراجعة سليماً).
  final String? pdfTopic;
  const ReviewTopic(this.title, {this.pdfTopic});
}

class ReviewFolder {
  final String title;
  final IconData icon;
  final List<ReviewTopic> topics;
  const ReviewFolder(this.title, this.icon, {this.topics = const []});
}

class ReviewSpace {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final List<ReviewFolder> folders;
  final List<ReviewTopic> topics;
  const ReviewSpace({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    this.folders = const [],
    this.topics = const [],
  });
}

/// معرّف كويز المحور الفرعي — فريد عبر كل المحاور.
String topicQuizId(ReviewFolder folder, ReviewTopic topic) =>
    '${folder.title} › ${topic.title}';

const List<ReviewSpace> reviewSpaces = [
  ReviewSpace(
    title: 'فضاء المراجعة والتحضير',
    subtitle: 'وثائق وملخصات PDF + اختبار تدريب تحت كل محور',
    icon: Icons.menu_book_rounded,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2E6B6B), Color(0xFF134847)],
    ),
    folders: [
"""
    lines = [head]
    for folder, icon in FOLDERS:
        lines.append(f"      ReviewFolder('{dq(folder)}', Icons.{icon}, topics: [\n")
        for t in topics.get(folder, []):
            pt = pdf_topic(folder, t)
            if pt != t:
                lines.append(f"        ReviewTopic('{dq(t)}', pdfTopic: '{dq(pt)}'),\n")
            else:
                lines.append(f"        ReviewTopic('{dq(t)}'),\n")
        lines.append("      ]),\n")
    lines.append("    ],\n  ),\n];\n")
    OUT.write_text("".join(lines), encoding="utf-8")
    n = sum(len(v) for v in topics.values())
    print(f"wrote {OUT}  folders={len(FOLDERS)} topics={n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
