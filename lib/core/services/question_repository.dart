import 'dart:math';

import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/question_validator.dart';

/// طبقة الوصول إلى بنك الأسئلة.
///  - تجمع الأسئلة من البنوك المحملة من JSON.
///  - لا تُضيف وضعيات — الأسئلة تبقى كما هي من البنك.
class QuestionRepository {
  QuestionRepository._();

  static final Random _random = Random();

  static final QuestionRepository instance = QuestionRepository._();

  /// عدد أسئلة أي اختبار/كويز: 70 سؤالاً.
  static const int targetCount = 50;

  /// أسئلة مادة [subject] (أو كل المواد عند null):
  Future<List<Question>> loadQuestions({String? subject, String? level}) async {
    final pool = <Question>[];
    final seen = <String>{};
    void addAll(Iterable<Question> qs) {
      for (final q in qs) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    if (subject != null) {
      addAll(QuestionBankLoader.questionsFor(subject) ?? const []);

      // إذا لم يُعثر على أسئلة بالمفتاح الدقيق، نبحث بمفتاح جزئي.
      if (pool.isEmpty) {
        for (final key in QuestionBankLoader.bank.keys) {
          if (key.contains(subject) || subject.contains(key)) {
            addAll(QuestionBankLoader.questionsFor(key) ?? const []);
          }
        }
      }
    } else {
      for (final qs in QuestionBankLoader.bank.values) {
        addAll(qs);
      }
    }

    var list = QuestionValidator.filterValid(pool);
    if (level != null) {
      final filtered = list.where((q) => q.level == level).toList();
      if (filtered.isNotEmpty) list = filtered;
    }

    list.shuffle(_random);
    if (list.length > targetCount) list = list.take(targetCount).toList();
    // توزيع مواضع الإجابة الصحيحة على جميع الاختيارات لا الأولى فقط.
    return list.map(QuestionGenerator.withShuffledOptions).toList();
  }
}
