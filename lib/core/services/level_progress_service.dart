import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// سجل نتيجة مرحلة واحدة في مسار التحدي.
class LevelRecord {
  final int stars;
  final int bestScore;
  final int bestTimeSeconds;

  const LevelRecord({
    required this.stars,
    required this.bestScore,
    required this.bestTimeSeconds,
  });

  LevelRecord merge({required int stars, required int score, required int time}) {
    return LevelRecord(
      stars: this.stars > stars ? this.stars : stars,
      bestScore: bestScore > score ? bestScore : score,
      bestTimeSeconds: bestTimeSeconds == 0 || time < bestTimeSeconds ? time : bestTimeSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'stars': stars,
        'bestScore': bestScore,
        'bestTime': bestTimeSeconds,
      };

  static LevelRecord fromJson(Map<String, dynamic> j) => LevelRecord(
        stars: j['stars'] as int? ?? 0,
        bestScore: j['bestScore'] as int? ?? 0,
        bestTimeSeconds: j['bestTime'] as int? ?? 0,
      );
}

/// حالة تقدم المستخدم في مسار التحدي (المراحل المفتوحة + سجلاتها).
class LevelProgress {
  final int unlockedUpTo;
  final Map<int, LevelRecord> records;

  const LevelProgress({required this.unlockedUpTo, required this.records});

  static const initial = LevelProgress(unlockedUpTo: 1, records: {});

  bool isUnlocked(int levelNumber) => levelNumber <= unlockedUpTo;

  /// المرحلة الحالية: أول مرحلة مفتوحة بلا نجوم، وإلا آخر مرحلة مفتوحة.
  int get currentLevel {
    for (var n = 1; n <= unlockedUpTo; n++) {
      if (!(records[n]?.stars != null && records[n]!.stars > 0)) return n;
    }
    return unlockedUpTo;
  }

  int get totalStars =>
      records.values.fold(0, (sum, r) => sum + r.stars);
  int get totalScore =>
      records.values.fold(0, (sum, r) => sum + r.bestScore);

  LevelProgress copyWith({
    int? unlockedUpTo,
    Map<int, LevelRecord>? records,
  }) =>
      LevelProgress(
        unlockedUpTo: unlockedUpTo ?? this.unlockedUpTo,
        records: records ?? this.records,
      );

  Map<String, dynamic> toJson() => {
        'unlockedUpTo': unlockedUpTo,
        'records': records.map((k, v) => MapEntry(k.toString(), v.toJson())),
      };

  static LevelProgress fromJson(Map<String, dynamic> j) => LevelProgress(
        unlockedUpTo: j['unlockedUpTo'] as int? ?? 1,
        records: (j['records'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(int.parse(k), LevelRecord.fromJson(v)),
        ),
      );
}

/// حفظ واسترجاع تقدم مسار التحدي في shared_preferences.
class LevelProgressService {
  LevelProgressService._();

  static const _key = 'level_progress_v1';

  static Future<LevelProgress> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return LevelProgress.initial;
      return LevelProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return LevelProgress.initial;
    }
  }

  static Future<void> save(LevelProgress progress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(progress.toJson()));
    } catch (_) {}
  }
}
