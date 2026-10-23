import 'package:flutter/material.dart';

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
      ReviewFolder('علوم التربية', Icons.school_outlined, topics: [
        ReviewTopic('الإصلاح التربوي', pdfTopic: 'الإصلاح التربوي والسياسة التعليمية'),
        ReviewTopic('الإصلاح التربوي والسياسة التعليمية'),
        ReviewTopic('التخطيط وتدبير التعلمات', pdfTopic: 'تخطيط وتدبير التعلمات'),
        ReviewTopic('التقويم والدعم', pdfTopic: 'التقويم والدعم التربويان'),
        ReviewTopic('التقويم والدعم التربويان'),
        ReviewTopic('التمايز البيداغوجي', pdfTopic: 'التقويم والدعم التربويان'),
        ReviewTopic('المقاربات البيداغوجية', pdfTopic: 'نظريات التعلم والمقاربات البيداغوجية'),
        ReviewTopic('النمو', pdfTopic: 'النمو واستراتيجيات اكتساب الفهم'),
        ReviewTopic('النمو واستراتيجيات اكتساب الفهم'),
        ReviewTopic('سوسيولوجيا التربية وسيكوسوسيولوجيا التربية'),
        ReviewTopic('سيكوسوسيولوجيا التربية', pdfTopic: 'سوسيولوجيا التربية وسيكوسوسيولوجيا التربية'),
        ReviewTopic('سيكولوجيا التربية وتقاطعاتها'),
        ReviewTopic('صعوبات التعلم', pdfTopic: 'صعوبات التعلم وعوائقه'),
        ReviewTopic('علم النفس النمو', pdfTopic: 'سيكولوجيا التربية وتقاطعاتها'),
        ReviewTopic('نظريات التعلم', pdfTopic: 'نظريات التعلم والمقاربات البيداغوجية'),
        ReviewTopic('نظريات التعلم والمقاربات البيداغوجية'),
      ]),
      ReviewFolder('ديداكتيك اللغة العربية', Icons.auto_stories_outlined, topics: [
        ReviewTopic('الإنتاج الكتابي'),
        ReviewTopic('الحصص'),
        ReviewTopic('الحصص اللغوية', pdfTopic: 'الحصص'),
        ReviewTopic('القراءة والتعبير'),
        ReviewTopic('المستويان الاول والثاني', pdfTopic: 'عدة كاملة خاصة بالمستويات الابتدائية'),
        ReviewTopic('المستويان الثالث والرابع', pdfTopic: 'عدة كاملة خاصة بالمستويات الابتدائية'),
        ReviewTopic('المستويان الخامس والسادس', pdfTopic: 'عدة كاملة خاصة بالمستويات الابتدائية'),
        ReviewTopic('بيداغوجيا الجملة'),
        ReviewTopic('ديداكتيك'),
        ReviewTopic('ديداكتيك اللغة العربية'),
        ReviewTopic('عدة كاملة خاصة بالمستويات الابتدائية'),
        ReviewTopic('مهارات اللغة العربية'),
      ]),
      ReviewFolder('ديداكتيك اللغة الفرنسية', Icons.translate_outlined, topics: [
        ReviewTopic('Didactique'),
        ReviewTopic('approche communicative', pdfTopic: 'Didactique'),
        ReviewTopic('didactique de l\'oral', pdfTopic: 'Didactique'),
        ReviewTopic('didactique de l\'écrit', pdfTopic: 'Didactique'),
        ReviewTopic('l\'évaluation en français', pdfTopic: 'Didactique'),
        ReviewTopic('la grammaire en contexte', pdfTopic: 'Didactique'),
      ]),
      ReviewFolder('ديداكتيك الرياضيات', Icons.calculate_outlined, topics: [
        ReviewTopic('أخطاء شائعة', pdfTopic: 'ديداكتيك الرياضيات'),
        ReviewTopic('الأنشطة المنهجية', pdfTopic: 'ديداكتيك الرياضيات'),
        ReviewTopic('التفكير الرياضي', pdfTopic: 'ديداكتيك الرياضيات'),
        ReviewTopic('التقويم في الرياضيات', pdfTopic: 'ديداكتيك الرياضيات'),
        ReviewTopic('التمثيل الرياضي', pdfTopic: 'ديداكتيك الرياضيات'),
        ReviewTopic('ديداكتيك الرياضيات'),
        ReviewTopic('مفاهيم رياضية', pdfTopic: 'ديداكتيك الرياضيات'),
      ]),
      ReviewFolder('ديداكتيك النشاط العلمي', Icons.science_outlined, topics: [
        ReviewTopic('التقويم في النشاط العلمي', pdfTopic: 'ديداكتيك'),
        ReviewTopic('الفرضيات', pdfTopic: 'ديداكتيك'),
        ReviewTopic('المفاهيم العلمية', pdfTopic: 'ديداكتيك'),
        ReviewTopic('الملاحظة والقياس', pdfTopic: 'ديداكتيك'),
        ReviewTopic('الممارسة العلمية', pdfTopic: 'ديداكتيك'),
        ReviewTopic('ديداكتيك'),
      ]),
      ReviewFolder('التشريع المدرسي', Icons.balance_outlined, topics: [
        ReviewTopic('التوقيف المؤقت والإلحاق', pdfTopic: 'التشريع المدرسي'),
        ReviewTopic('المسؤولية القانونية', pdfTopic: 'التشريع المدرسي'),
        ReviewTopic('جمعيات أمهات وآباء التلاميذ', pdfTopic: 'التشريع المدرسي'),
      ]),
      ReviewFolder('التنشيط التربوي', Icons.emoji_people_outlined, topics: [
        ReviewTopic('الاندية التربوية'),
        ReviewTopic('التربية الدامجة'),
        ReviewTopic('التربية على القيم'),
        ReviewTopic('التنشيط التربوي'),
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
        ReviewTopic('البرنامج الاستعجالي', pdfTopic: 'مراسلات ومذكرات'),
        ReviewTopic('التوجيهات التربوية', pdfTopic: 'مراسلات ومذكرات'),
        ReviewTopic('الرسائل الوزارية', pdfTopic: 'مراسلات ومذكرات'),
        ReviewTopic('القانون الإطار 51.17', pdfTopic: 'مراسلات ومذكرات'),
        ReviewTopic('مذكرة 73', pdfTopic: 'مراسلات ومذكرات'),
      ]),
      ReviewFolder('مشروع المؤسسة المندمج', Icons.hub_outlined, topics: [
        ReviewTopic('التشخيص والتقييم الذاتي', pdfTopic: 'مشروع المؤسسة المندمج'),
        ReviewTopic('ثقافة المشروع', pdfTopic: 'مشروع المؤسسة المندمج'),
      ]),
      ReviewFolder('مؤسسات الريادة', Icons.star_rounded, topics: [
        ReviewTopic('التحفيز على التعلم', pdfTopic: 'مؤسسات الريادة — مقاربة TaRL'),
        ReviewTopic('مؤسسات الريادة — مقاربة TaRL'),
      ]),
    ],
  ),
];
