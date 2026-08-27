import 'dart:math';

import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/question_validator.dart';

/// يبني نماذج الاختبارات النهائية العامة (70 سؤالاً لكل اختبار).
///
/// القاعدة المعتمدة:
///  - الاختبار الشامل: 70 سؤالاً موزعة بالتساوي على جميع المواد.
///  - الاختبار حسب المادة: 70 سؤالاً من المادة نفسها فقط.
///  - توليد عشوائي في كل محاولة (لا تكرار).
class ExamQuestionService {
  /// عدد أسئلة أي اختبار نهائي.
  static const int examQuestionCount = 70;

  /// مدة أي اختبار نهائي.
  static const Duration examDuration = Duration(minutes: 60);

  static final Random _random = Random();

  /// يبني اختباراً نهائياً من مادة واحدة (70 سؤالاً من المادة نفسها).
  static Future<List<Question>> buildExam(String subject) async {
    final pool = <Question>[];
    final seen = <String>{};

    void addAll(Iterable<Question> questions) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }

    // أولاً: البحث بالمفتاح الدقيق
    addAll(QuestionBankLoader.questionsFor(subject) ?? const []);

    // ثانياً: إذا لم يُعثر على أسئلة، نبحث بمفتاح جزئي
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

  /// يبني اختباراً شاملاً: 70 سؤالاً موزعة بالتساوي على كل المواد.
  ///
  /// يأخذ من كل مادة بعدد متساوٍ تقريباً (4 أو 5 من كل مادة).
  static Future<List<Question>> buildComprehensiveExam() async {
    final subjects = QuestionBankLoader.availableSubjects;
    if (subjects.isEmpty) return const [];

    final perSubject = examQuestionCount ~/ subjects.length;
    final remainder = examQuestionCount % subjects.length;

    final pool = <Question>[];
    final seen = <String>{};

    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      final questions = QuestionBankLoader.questionsFor(subject) ?? const [];
      final valid = QuestionValidator.filterValid(questions);
      valid.shuffle(_random);

      // أول [remainder] مواد تحصل على سؤال إضافي
      final count = perSubject + (i < remainder ? 1 : 0);
      for (final q in valid) {
        if (pool.length >= examQuestionCount) break;
        if (seen.add(q.text)) pool.add(q);
      }
    }

    pool.shuffle(_random);
    return pool.take(examQuestionCount).toList();
  }
}
