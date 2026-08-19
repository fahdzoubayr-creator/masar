import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:masar_app/core/models/quiz_result.dart';

class ProgressService {
  static const _key = 'quiz_results_v1';

  static Future<List<QuizResult>> loadResults() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => QuizResult.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static Future<void> saveResult(QuizResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final list = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
    list.insert(0, result.toJson());
    if (list.length > 100) list.removeRange(100, list.length);
    await prefs.setString(_key, jsonEncode(list));
  }

  static Future<({int quizzes, int bestPct})> loadStats() async {
    final results = await loadResults();
    int best = 0;
    for (final r in results) {
      if (r.percentage > best) best = r.percentage;
    }
    return (quizzes: results.length, bestPct: best);
  }
}
