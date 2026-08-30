import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// محمل بنك أسئلة مسار التحدي مع تتبع الأسئلة المستخدمة.
///
/// يمنع تكرار الأسئلة حتى تُلعب كل الأسئلة على الأقل مرة واحدة.
/// إذا انتهت الأسئلة، يُعاد الضبط تلقائياً.
class GameBankLoader {
  GameBankLoader._();

  static const String _usedIdsKey = 'game_used_question_ids';
  static List<Question> _allQuestions = [];

  /// تحميل بنك الأسئلة — يجب استدعاؤه مرة واحدة عند بدء التطبيق.
  static Future<void> init() async {
    try {
      final jsonStr = await rootBundle.loadString(_bankPath);
      final Map<String, dynamic> data =
          jsonDecode(jsonStr) as Map<String, dynamic>;

      final all = <Question>[];
      for (final entry in data.entries) {
        final questions = (entry.value as List<dynamic>)
            .map((q) =>
                QuestionBankLoader.tagBankSource(Question.fromJson(q as Map<String, dynamic>)))
            .toList();
        all.addAll(questions);
      }
      _allQuestions = all;
    } catch (_) {
      _allQuestions = [];
    }
  }

  static const _bankPath = 'assets/banks/game_challenges.json';

  /// هل تم التحميل؟
  static bool get isLoaded => _allQuestions.isNotEmpty;

  /// كل أسئلة اللعبة.
  static List<Question> get all => _allQuestions;

  /// عدد الأسئلة الإجمالي.
  static int get count => all.length;

  /// جلب معرفات الأسئلة المستخدمة مسبقاً.
  static Future<Set<String>> _getUsedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_usedIdsKey) ?? [];
    return list.toSet();
  }

  /// حفظ معرفات الأسئلة المستخدمة.
  static Future<void> _saveUsedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_usedIdsKey, ids.toList());
  }

  /// اختيار أسئلة غير مكررة للمستوى.
  ///
  /// تُرجع最多 `count` أسئلة لم تُلعَب من قبل.
  /// إذا انتهت الأسئلة، يُعاد ضبط السجل ويُعاد الخلط.
  static Future<List<Question>> getUniqueQuestionsForLevel(
      {int count = 10}) async {
    if (_allQuestions.isEmpty) return [];

    final usedIds = await _getUsedIds();

    // تصفية الأسئلة المستخدمة
    List<Question> available =
        _allQuestions.where((q) => !usedIds.contains(q.id)).toList();

    // إعادة ضبط إذا انتهت الأسئلة
    if (available.length < count) {
      await clearUsedHistory();
      available = List.from(_allQuestions);
    }

    // الخلط واختيار
    available.shuffle(Random());
    return available.take(count).toList();
  }

  /// تسجيل الأسئلة كمستخدمة بعد الإجابة عليها.
  static Future<void> markQuestionsAsUsed(List<String> questionIds) async {
    final usedIds = await _getUsedIds();
    usedIds.addAll(questionIds);
    await _saveUsedIds(usedIds);
  }

  /// إعادة ضبط سجل الأسئلة المستخدمة.
  static Future<void> clearUsedHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usedIdsKey);
  }
}
