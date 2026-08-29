import 'package:flutter/material.dart';

/// بيانات المحاور الفرعية لفضاء المراجعة والتحضير —
/// مشتركة بين شاشة فضاء المراجعة وشاشة أفضل النسب.
class ReviewTopic {
  final String title;
  const ReviewTopic(this.title);
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
      ReviewFolder('علوم التربية', Icons.school_outlined, topics: [
        ReviewTopic('نظريات التعلم والمقاربات البيداغوجية'),
        ReviewTopic('النمو واستراتيجيات اكتساب الفهم'),
        ReviewTopic('سيكولوجيا التربية وتقاطعاتها'),
        ReviewTopic('صعوبات التعلم وعوائقه'),
        ReviewTopic('سوسيولوجيا التربية وسيكوسوسيولوجيا التربية'),
        ReviewTopic('التقويم والدعم التربويان'),
        ReviewTopic('الإصلاح التربوي والسياسة التعليمية'),
        ReviewTopic('تخطيط وتدبير التعلمات'),
      ]),
      ReviewFolder('ديداكتيك اللغة العربية', Icons.auto_stories_outlined,
          topics: [
        ReviewTopic('الحصص'),
        ReviewTopic('ديداكتيك'),
        ReviewTopic('عدة كاملة خاصة بالمستويات الابتدائية'),
      ]),
      ReviewFolder('ديداكتيك اللغة الفرنسية', Icons.translate_outlined, topics: [
        ReviewTopic('Didactique'),
      ]),
      ReviewFolder('ديداكتيك الرياضيات', Icons.calculate_outlined, topics: [
        ReviewTopic('ديداكتيك الرياضيات'),
      ]),
      ReviewFolder('ديداكتيك النشاط العلمي', Icons.science_outlined, topics: [
        ReviewTopic('ديداكتيك'),
      ]),
      ReviewFolder('التشريع المدرسي', Icons.balance_outlined, topics: [
        ReviewTopic('التشريع المدرسي'),
      ]),
      ReviewFolder('التنشيط التربوي', Icons.emoji_people_outlined, topics: [
        ReviewTopic('الاندية التربوية'),
        ReviewTopic('التربية الدامجة'),
        ReviewTopic('التنشيط'),
        ReviewTopic('الحياة المدرسية'),
        ReviewTopic('مجالس المؤسسة'),
      ]),
      ReviewFolder('خطاطات ذهنية', Icons.account_tree_outlined, topics: [
        ReviewTopic('خطاطات ذهنية'),
      ]),
      ReviewFolder('دورات تكوينية', Icons.card_membership_outlined, topics: [
        ReviewTopic('دورات تكوينية'),
      ]),
      ReviewFolder('مراسلات ومذكرات', Icons.mail_outline_rounded, topics: [
        ReviewTopic('مراسلات ومذكرات'),
      ]),
      ReviewFolder('مشروع المؤسسة المندمج', Icons.hub_outlined, topics: [
        ReviewTopic('مشروع المؤسسة المندمج'),
      ]),
      ReviewFolder('مؤسسات الريادة', Icons.star_rounded, topics: [
        ReviewTopic('مؤسسات الريادة — مقاربة TaRL'),
      ]),
    ],
  ),
];
