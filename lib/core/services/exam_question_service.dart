import 'dart:math';

import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_validator.dart';

/// يبني نماذج الاختبارات النهائية العامة (70 سؤالاً لكل اختبار).
///
/// القاعدة المعتمدة: كل اختبار نهائي يتكوّن من 70 سؤالاً بالضبط.
///  - يأخذ من بنوك JSON المحملة عبر QuestionBankLoader.
///  - الاختبار الشامل يخلط أسئلة كل المواد.
///  - لا تُضاف وضعيات — الأسئلة تبقى كما هي من البنك.
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

    // 1) بنك الأسئلة الشائعة للمادة.
    addAll(QuestionBankLoader.questionsFor(subject) ?? const []);

    // 2) إذا لم يُعثر على أسئلة بالمفتاح الدقيق، نبحث بمفتاح جزئي.
    if (pool.isEmpty) {
      for (final key in QuestionBankLoader.bank.keys) {
        if (key.contains(subject) || subject.contains(key)) {
          addAll(QuestionBankLoader.questionsFor(key) ?? const []);
        }
      }
    }

    final validPool = QuestionValidator.filterValid(pool);
    validPool.shuffle(_random);
    if (validPool.length > examQuestionCount) {
      return validPool.take(examQuestionCount).toList();
    }
    return validPool;
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

    for (final questions in QuestionBankLoader.bank.values) {
      addAll(questions);
    }

    final validPool = QuestionValidator.filterValid(pool);
    validPool.shuffle(_random);
    if (validPool.length > examQuestionCount) {
      return validPool.take(examQuestionCount).toList();
    }
    return validPool;
  }
}
