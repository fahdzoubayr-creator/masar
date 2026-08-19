import 'dart:math';

import 'package:masar_app/core/data/french_bank_data.dart';
import 'package:masar_app/core/data/popular_bank_data.dart';
import 'package:masar_app/core/data/questions_data.dart';
import 'package:masar_app/core/data/science_bank_data.dart';
import 'package:masar_app/core/data/statutory_bank_data.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_generator.dart';

/// يبني نماذج الاختبارات النهائية العامة (70 سؤالاً لكل اختبار).
///
/// القاعدة المعتمدة: كل اختبار نهائي يتكوّن من 70 سؤالاً بالضبط.
///  - تُثري كل سؤال بوضعية تلقائية.
///  - المادة التي لها بنك أسئلة شائعة (PopularBankData) تُفضَّل منه أولاً،
///    ثم يُسدّد النقص من البنك الثابت (questions_data.dart) ومن البنوك
///    اليدوية المخصصة (التشريع، الفرنسية، النشاط العلمي) حتى بلوغ 70.
///  - الاختبار الشامل يخلط أسئلة كل المواد.
class ExamQuestionService {
  /// عدد أسئلة أي اختبار نهائي.
  static const int examQuestionCount = 70;

  /// مدة أي اختبار نهائي.
  static const Duration examDuration = Duration(minutes: 60);

  static final Random _random = Random();

  /// يبني اختباراً نهائياً لمادة [subject] (70 سؤالاً).
  static Future<List<Question>> buildExam(String subject) async {
    final pool = <Question>[];
    final seen = <String>{};

    void addAll(Iterable<Question> questions) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    addAll(PopularBankData.questionsFor(subject) ?? const []);
    addAll(questionsFor(subject));
    addAll(_bankForSubject(subject));

    // إثراء جميع الأسئلة بوضعيات تلقائية.
    final enriched = QuestionGenerator.enrichWithSituations(pool);

    enriched.shuffle(_random);
    if (enriched.length > examQuestionCount) {
      return enriched.take(examQuestionCount).toList();
    }
    return enriched;
  }

  /// البنوك اليدوية المخصصة لمادة [subject].
  static List<Question> _bankForSubject(String subject) {
    switch (subject) {
      case StatutoryBankData.subject:
        return StatutoryBankData.questions;
      case FrenchBankData.subject:
        return FrenchBankData.questions;
      case ScienceBankData.subject:
        return ScienceBankData.questions;
    }
    return const [];
  }

  /// يبني اختباراً نهائياً شاملاً يخلط أسئلة كل المواد (70 سؤالاً).
  static Future<List<Question>> buildComprehensiveExam() async {
    final pool = <Question>[];
    final seen = <String>{};

    void addAll(Iterable<Question> questions) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    for (final questions in PopularBankData.bank.values) {
      addAll(questions);
    }
    addAll(questionsBank);
    addAll(StatutoryBankData.questions);
    addAll(FrenchBankData.questions);
    addAll(ScienceBankData.questions);

    // إثراء جميع الأسئلة بوضعيات تلقائية.
    final enriched = QuestionGenerator.enrichWithSituations(pool);

    enriched.shuffle(_random);
    if (enriched.length > examQuestionCount) {
      return enriched.take(examQuestionCount).toList();
    }
    return enriched;
  }
}
