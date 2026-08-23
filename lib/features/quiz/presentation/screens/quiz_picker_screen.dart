import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/widgets/subject_card.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_screen.dart';

/// الكويزات والتدريبات — اختبار مادة من بنك الأسئلة الشائعة، أو اختبار شامل.
class QuizPickerScreen extends StatelessWidget {
  const QuizPickerScreen({super.key});

  /// أيقونة لكل مادة بناءً على المفتاح.
  static const _icons = <String, String>{
    'علوم التربية': '📘',
    'نظريات التعلم': '🧠',
    'النمو': '🌱',
    'سيكولوجيا التربية': '💭',
    'صعوبات التعلم': '📖',
    'سوسيولوجيا التربية': '👥',
    'التقويم والدعم': '📊',
    'الإصلاح التربوي': '🏛',
    'تخطيط وتدبير التعلمات': '📋',
    'ديداكتيك اللغة العربية': '📗',
    'ديداكتيك الفرنسية': '🇫🇷',
    'ديداكتيك الرياضيات': '🧮',
    'النشاط العلمي': '🔬',
    'ديداكتيك النشاط العلمي': '🧪',
    'التشريع': '⚖️',
    'التنشيط التربوي': '🎉',
    'المجالس التعليمية': '🏫',
    'المهارات الحياتية': '💡',
    'مؤسسة الريادة': '⭐',
    'كفايات المستويات': '📈',
    'مشروع المؤسسة': '🏗',
    'الكفاءة المهنية': '🎯',
    'أخلاقيات المهنة': '🤝',
    'الأكاديميات': '🎓',
    'التقويم والقياس': '📏',
  };

  String _iconFor(String subject) {
    for (final entry in _icons.entries) {
      if (subject.contains(entry.key)) return entry.value;
    }
    return '📝';
  }

  @override
  Widget build(BuildContext context) {
    // جمع كل مفاتيح البنك الفريدة
    final subjects = QuestionBankLoader.availableSubjects;

    return Scaffold(
      appBar: AppBar(title: const Text('الكويزات والتدريبات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          children: [
            SubjectCardTile(
              icon: '🎯',
              title: 'اختبار شامل — جميع المواد',
              subtitle: '${subjects.length} مادة · 70 سؤالاً عشوائياً',
              onTap: () {
                playSfx(Sfx.select);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const QuizScreen(
                          subjectFilter: null,
                          testType: 'اختبار تدريبي',
                          axisName: 'جميع المواد')),
                );
              },
            ),
            const SizedBox(height: 10),
            Text('اختر محوراً للتدريب (${subjects.length} متاح)',
                style: AppTheme.displayFont(size: 15)),
            const SizedBox(height: 12),
            ...subjects.map((s) {
              final count = QuestionBankLoader.questionsFor(s)?.length ?? 0;
              return SubjectCardTile(
                icon: _iconFor(s),
                title: s,
                subtitle: '$count سؤالاً متاحاً',
                onTap: () {
                  playSfx(Sfx.select);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => QuizScreen(
                            subjectFilter: s,
                            testType: 'اختبار تدريبي',
                            axisName: s)),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
