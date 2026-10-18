import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:masar_app/core/models/question.dart';

/// بنك أسئلة ثابت لكل محور فرعي — محتوى مؤلَّف ومراجَع، محفوظ داخل التطبيق.
///
/// بنية المحتوى (يُبنى بـ tools/build_topic_banks.py):
///   assets/banks/topics_index.json      فهرس: key ← {folder, topic, file, count}
///   assets/banks/topics/<مفتاح>.json    أسئلة ذلك المحور فقط
///
/// لماذا ملف لكل محور؟ لأن عنوان المحور ليس فريداً: «ديداكتيك» محور في
/// «ديداكتيك اللغة العربية» و«ديداكتيك النشاط العلمي»، فبنك واحد بالعنوان
/// يخلط مادتين. لذلك المفتاح = المجلد + المحور.
///
/// لا يوجد أي توليد حيّ: إمّا يوجد بنك أو لا يوجد، والواجهة تُعلم المستخدم
/// بذلك بدل الانتظار.
class TopicBankService {
  TopicBankService._();

  static const String indexAsset = 'assets/banks/topics_index.json';

  static Map<String, Map<String, dynamic>>? _index;
  static final Map<String, List<Question>> _cache = {};

  /// مفتاح المحور داخل الفهرس.
  static String key(String folder, String topic) =>
      '${_norm(folder)}::${_norm(_topicOr(folder, topic))}';

  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String _topicOr(String folder, String topic) =>
      topic.trim().isEmpty ? folder : topic;

  static Future<Map<String, Map<String, dynamic>>> _entries() async {
    if (_index != null) return _index!;
    try {
      final raw = await rootBundle.loadString(indexAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, Map<String, dynamic>>{};
      final byTopic = <String, List<String>>{};
      for (final e in (decoded['topics'] as List?) ?? const []) {
        if (e is! Map) continue;
        final m = e.cast<String, dynamic>();
        final k = (m['key'] as String?)?.trim() ?? '';
        if (k.isEmpty) continue;
        out[k] = m;
        final t = _norm((m['topic'] ?? '').toString());
        byTopic.putIfAbsent(t, () => <String>[]).add(k);
      }
      // اسم محور غير فريد لا يُرجع، لأن اختيار فرع عشوائي يخلط بين مادتين.
      for (final entry in byTopic.entries) {
        out['topic-only::${entry.key}'] =
            entry.value.length == 1 ? out[entry.value.first]! : <String, dynamic>{};
      }
      _index = out;
    } catch (_) {
      _index = <String, Map<String, dynamic>>{};
    }
    return _index!;
  }

  /// عدد الأسئلة كما هو مسجّل في الفهرس، دون تحميل الملف (لعرض فوري).
  static Future<int> indexedCount(String folder, String topic) async {
    final e = await _resolve(folder, topic);
    final n = (e?['count'] as num?)?.toInt() ?? 0;
    return n > 0 ? n : 0;
  }

  static Future<Map<String, dynamic>?> _resolve(
      String folder, String topic) async {
    final entries = await _entries();
    final direct = entries[key(folder, topic)];
    if (direct != null && direct.isNotEmpty) return direct;
    final byTopic = entries['topic-only::${_norm(_topicOr(folder, topic))}'];
    if (byTopic != null && byTopic.isNotEmpty) return byTopic;
    return null;
  }

  /// أسئلة المحور الجاهزة، أو قائمة فارغة إن لم يكن له بنك.
  static Future<List<Question>> forTopic(String folder, String topic) async {
    final k = key(folder, topic);
    final hit = _cache[k];
    if (hit != null) return hit;
    final e = await _resolve(folder, topic);
    final file = e?['file'] as String?;
    if (file == null || file.isEmpty) {
      _cache[k] = const <Question>[];
      return _cache[k]!;
    }
    List<Question> out;
    try {
      final raw = await rootBundle.loadString('assets/banks/$file');
      final list = jsonDecode(raw) as List;
      final qs = <Question>[];
      for (final item in list) {
        if (item is! Map) continue;
        final q = Question.fromJson(item.cast<String, dynamic>());
        if (q.text.trim().isEmpty || q.options.length < 3) continue;
        qs.add(q);
      }
      out = qs;
    } catch (_) {
      out = const <Question>[];
    }
    _cache[k] = out;
    return out;
  }

  /// عدد أسئلة المحور الجاهزة (لعرضه فورًا دون أي طلب شبكة).
  static Future<int> countFor(String folder, String topic) async =>
      (await forTopic(folder, topic)).length;

  static Future<bool> hasBank(String folder, String topic) async =>
      (await forTopic(folder, topic)).isNotEmpty;

  /// هل المطلوب في هذا المحور لا بنك له — عندها نعرض رسالة صريحة
  /// بدل الانتظار على توليد.
  static Future<bool> isMissing(String folder, String topic) async {
    final e = await _resolve(folder, topic);
    if (e == null) return true;
    return ((e['count'] as num?)?.toInt() ?? 0) == 0;
  }

  @visibleForTesting
  static void resetCache() {
    _cache.clear();
    _index = null;
  }
}