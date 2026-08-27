import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:masar_app/core/models/question.dart';

/// خدمة تحميل بنك الأسئلة الرئيسي (game_challenges.json).
///
/// 1) استدعاء `await QuestionBankLoader.init()` مرة واحدة عند بدء التطبيق.
/// 2) بعد التحميل، استدعاء `QuestionBankLoader.questionsFor(subject)`
///    بشكل متزامن (sync).
class QuestionBankLoader {
  QuestionBankLoader._();

  static Map<String, List<Question>>? _bank;

  /// تحميل بنك game_challenges.json فقط — يجب استدعاءها مرة واحدة في main().
  static Future<void> init() async {
    final bank = <String, List<Question>>{};

    final jsonStr =
        await rootBundle.loadString('assets/banks/game_challenges.json');
    final Map<String, dynamic> data =
        jsonDecode(jsonStr) as Map<String, dynamic>;

    // البنك مُنسّق كـ { "تحدي الكفاءة المهنية": [ {...}, ... ] }
    for (final entry in data.entries) {
      final questions = (entry.value as List<dynamic>)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList();
      if (questions.isEmpty) continue;

      // تجميع الأسئلة حسب حقل subject
      for (final q in questions) {
        final subject = q.subject.isNotEmpty ? q.subject : entry.key;
        bank.update(
          subject,
          (existing) => [...existing, q],
          ifAbsent: () => [q],
        );
      }
    }

    _bank = bank;
  }

  /// هل تم التحميل؟
  static bool get isLoaded => _bank != null;

  /// إرجاع أسئلة لموضوع معيّن، أو `null` إذا لم يوجد بنك له.
  static List<Question>? questionsFor(String subject) => _bank?[subject];

  /// إرجاع البنك الكامل (جميع المحاور).
  static Map<String, List<Question>> get bank => _bank ?? const {};

  /// إرجاع كل المفاتيح المتاحة.
  static List<String> get availableSubjects {
    final keys = _bank?.keys.toList() ?? const <String>[];
    final sorted = List<String>.from(keys)..sort();
    return sorted;
  }

  /// عدد الأسئلة الإجمالي.
  static int get totalCount =>
      _bank?.values.fold<int>(0, (sum, qs) => sum + qs.length) ?? 0;
}
