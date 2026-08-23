import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:masar_app/core/models/question.dart';

/// خدمة تحميل بنوك الأسئلة من ملفات JSON في assets/banks/.
///
/// 1) استدعاء `await QuestionBankLoader.init()` مرة واحدة عند بدء التطبيق.
/// 2) بعد التحميل، استدعاء `QuestionBankLoader.questionsFor(subject)`
///    بشكل متزامن (sync) — يعمل كبنوك الداتا القديمة بالضبط.
class QuestionBankLoader {
  QuestionBankLoader._();

  static Map<String, List<Question>>? _bank;

  static const _bankPaths = <String>[
    'assets/banks/amazigh_didactics.json',
    'assets/banks/animation.json',
    'assets/banks/arabic_didactics.json',
    'assets/banks/development_psychology.json',
    'assets/banks/french_bank.json',
    'assets/banks/french_didactics_all.json',
    'assets/banks/french_didactics_small.json',
    'assets/banks/life_skills.json',
    'assets/banks/math_didactics.json',
    'assets/banks/math_didactics_small.json',
    'assets/banks/popular_bank.json',
    'assets/banks/professional_bank.json',
    'assets/banks/professional_exam_bank.json',
    'assets/banks/professional_situations.json',
    'assets/banks/reform.json',
    'assets/banks/riyada.json',
    'assets/banks/school_councils.json',
    'assets/banks/school_project.json',
    'assets/banks/science.json',
    'assets/banks/science_activity.json',
    'assets/banks/science_didactics.json',
    'assets/banks/science_edu.json',
    'assets/banks/socio_psychology.json',
    'assets/banks/statutory_bank.json',
    'assets/banks/wadiaa_bank.json',
  ];

  /// تحميل كل ملفات JSON — يجب استدعاءها مرة واحدة في main() قبل runApp().
  static Future<void> init() async {
    final bank = <String, List<Question>>{};

    for (final path in _bankPaths) {
      final jsonStr = await rootBundle.loadString(path);
      final Map<String, dynamic> data =
          jsonDecode(jsonStr) as Map<String, dynamic>;

      for (final entry in data.entries) {
        final subject = entry.key;
        final questions = (entry.value as List<dynamic>)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();
        bank.update(
          subject,
          (existing) => [...existing, ...questions],
          ifAbsent: () => questions,
        );
      }
    }

    _bank = bank;
  }

  /// هل تم التحميل؟
  static bool get isLoaded => _bank != null;

  /// إرجاع أسئلة لموضوع معيّن، أو `null` إذا لم يوجد بنك له.
  /// يعمل بشكل متزامن بعد استدعاء init().
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
