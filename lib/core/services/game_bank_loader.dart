import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:masar_app/core/models/question.dart';

/// محمل بنك أسئلة مسار التحدي — منفصل عن البنك العام.
///
/// يحمّل فقط من `assets/banks/game_challenges.json`.
/// لُمّاح شروط: لا يخلط مع بنوك الاختبارات أو الكويزات.
class GameBankLoader {
  GameBankLoader._();

  static List<Question>? _questions;

  static const _bankPath = 'assets/banks/game_challenges.json';

  /// تحميل بنك الأسئلة — يجب استدعاؤه مرة واحدة عند بدء التطبيق.
  static Future<void> init() async {
    try {
      final jsonStr = await rootBundle.loadString(_bankPath);
      final Map<String, dynamic> data =
          jsonDecode(jsonStr) as Map<String, dynamic>;

      final all = <Question>[];
      for (final entry in data.entries) {
        final questions = (entry.value as List<dynamic>)
            .map((q) => Question.fromJson(q as Map<String, dynamic>))
            .toList();
        all.addAll(questions);
      }
      _questions = all;
    } catch (_) {
      _questions = [];
    }
  }

  /// هل تم التحميل؟
  static bool get isLoaded => _questions != null;

  /// كل أسئلة اللعبة.
  static List<Question> get all => _questions ?? const [];

  /// عدد الأسئلة الإجمالي.
  static int get count => all.length;
}
