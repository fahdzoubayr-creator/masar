import 'dart:math';

import 'package:masar_app/core/data/french_bank_data.dart';
import 'package:masar_app/core/data/popular_bank_data.dart';
import 'package:masar_app/core/data/questions_data.dart';
import 'package:masar_app/core/data/science_bank_data.dart';
import 'package:masar_app/core/data/statutory_bank_data.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_generator.dart';

/// طبقة الوصول إلى بنك الأسئلة.
///  - تجمع الأسئلة من البنوك الثابتة والشائعة واليدوية.
///  - تُثري كل سؤال بوضعية تلقائية إن لم تكن له.
///  - تكمل العدد من البنك المخفي (PopularBankData) عند النقص.
class QuestionRepository {
  QuestionRepository._();

  static final Random _random = Random();

  static final QuestionRepository instance = QuestionRepository._();

  /// عدد أسئلة أي اختبار/كويز: 70 سؤالاً.
  static const int targetCount = 70;

  /// أسئلة مادة [subject] (أو كل المواد عند null):
  ///  - يجمع من البنوك الثابتة والشائعة واليدوية.
  ///  - يُثري كل سؤال بوضعية تلقائية.
  ///  - يُكمّل العدد من PopularBankData عند النقص.
  Future<List<Question>> loadQuestions({String? subject, String? level}) async {
    final pool = <Question>[];
    final seen = <String>{};
    void addAll(Iterable<Question> qs) {
      for (final q in qs) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    addAll(questionsFor(subject));
    if (subject != null) {
      addAll(PopularBankData.questionsFor(subject) ?? const []);
      addAll(_bankForSubject(subject));
    } else {
      for (final qs in PopularBankData.bank.values) {
        addAll(qs);
      }
      addAll(StatutoryBankData.questions);
      addAll(FrenchBankData.questions);
      addAll(ScienceBankData.questions);
    }

    var list = pool;
    if (level != null) {
      final filtered = pool.where((q) => q.level == level).toList();
      if (filtered.isNotEmpty) list = filtered;
    }

    // إثراء جميع الأسئلة بوضعيات تلقائية.
    list = QuestionGenerator.enrichWithSituations(list);

    list.shuffle(_random);
    if (list.length > targetCount) list = list.take(targetCount).toList();
    return list;
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
}
