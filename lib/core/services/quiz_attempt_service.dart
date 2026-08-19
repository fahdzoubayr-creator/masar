import 'dart:convert';
import 'package:masar_app/core/models/quiz_result.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يسجل محاولات المستخدم في كويزات المحاور الفرعية:
/// أفضل نسبة لكل محور + كل المحاولات + الحظر لمدة 3 ساعات عند الفشل.
class QuizAttemptService {
  static const _key = 'topic_attempts_v1';

  /// عتبة النجاح: من يقل عن 50% يُعتبر فاشلاً ويُمنع من الكويز 3 ساعات.
  static const int passThreshold = 50;

  /// مدة الحظر بعد الفشل: 3 ساعات.
  static const Duration lockDuration = Duration(hours: 3);

  static Future<Map<String, TopicAttempt>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(
          k, TopicAttempt.fromJson(Map<String, dynamic>.from(v as Map))));
    } catch (_) {
      return {};
    }
  }

  static Future<TopicAttempt?> load(String quizId) async {
    final all = await loadAll();
    return all[quizId];
  }

  static Future<void> _save(Map<String, TopicAttempt> all) async {
    final prefs = await SharedPreferences.getInstance();
    final map = all.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_key, jsonEncode(map));
  }

  /// يسجل محاولة جديدة: يحدّث أفضل نسبة، يضيف المحاولة للتاريخ،
  /// ويضبط الحظر إذا كانت النسبة أقل من 50%.
  static Future<TopicAttempt> record(String quizId, QuizResult result) async {
    final all = await loadAll();
    final cur = all[quizId];
    final history = [
      ...?cur?.history,
      {
        'percentage': result.percentage,
        'score': result.score,
        'total': result.total,
        'date': result.date.toIso8601String(),
      },
    ];
    if (history.length > 50) history.removeRange(0, history.length - 50);

    DateTime? lockedUntil = cur?.lockedUntil;
    if (result.percentage < passThreshold) {
      final t = DateTime.now().add(lockDuration);
      if (lockedUntil == null || lockedUntil.isBefore(t)) lockedUntil = t;
    }

    final updated = TopicAttempt(
      bestPercentage: cur == null
          ? result.percentage
          : result.percentage > cur.bestPercentage
              ? result.percentage
              : cur.bestPercentage,
      attempts: history.length,
      lockedUntil: lockedUntil,
      history: history,
    );
    all[quizId] = updated;
    await _save(all);
    return updated;
  }

  static bool isLocked(TopicAttempt? attempt) {
    final until = attempt?.lockedUntil;
    return until != null && until.isAfter(DateTime.now());
  }

  static Duration? remainingLock(TopicAttempt? attempt) {
    final until = attempt?.lockedUntil;
    if (until == null) return null;
    final d = until.difference(DateTime.now());
    return d.isNegative ? null : d;
  }
}
