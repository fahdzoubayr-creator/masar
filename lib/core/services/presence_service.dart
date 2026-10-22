import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:masar_app/core/config/server_address.dart';

/// فضاءات لوحة التحضير — المعرّفات المستخدمة في سجلّ الحضور.
class PresenceSpace {
  PresenceSpace._();

  /// المستخدم في لوحة التحضير (خارج أي بطاقة) — لا يُحتسب ضمن أي بطاقة.
  static const String lobby = 'lobby';

  static const String review = 'review';
  static const String quiz = 'quiz';
  static const String jawaaher = 'jawaaher';
  static const String history = 'history';
  static const String mindMaps = 'mindMaps';
  static const String liveRoom = 'liveRoom';

  /// المساحات التي تُعرض أرقامها على البطاقات.
  static const List<String> cards = [
    review,
    quiz,
    jawaaher,
    history,
    mindMaps,
    liveRoom,
  ];
}

/// خدمة حضور المستخدمين: تسجّل كل مستخدم في الفضاء الذي دخله،
/// وتُرجع عدد الحاضرين الآن في كل فضاء لتُعرض أسفل بطاقات اللوحة.
///
/// الآلية: نبضة دورية (heartbeat) كل [heartbeatInterval] ثانية تحمل معرّف
/// الجهاز والفضاء الحالي؛ والسيرفر يحذف السجلات المنتهية بعد
/// [ttlSeconds] ثانية، فيختفي المستخدم المتوقف/المغلق فورياً.
class PresenceService {
  PresenceService._();

  static const Duration heartbeatInterval = Duration(seconds: 20);
  static const Duration _timeout = Duration(seconds: 8);

  /// مهلة انتهاء السجلات في السيرفر (ثوانٍ) — أكبر من فترة النبض.
  static const int ttlSeconds = 70;

  /// عنوان الخادم: نفس الأصل على الويب، وعنوان الشبكة المحلية على الهاتف.
  static String get _base {
    if (kIsWeb) return Uri.base.origin;
    return ServerAddress.apiBase;
  }

  static final Random _rnd = Random();
  static String? _clientId;
  static String _space = PresenceSpace.lobby;
  static Timer? _timer;

  /// معرّف العميل — ثابت طوال تشغيل التطبيق.
  static String get clientId => _clientId ??= _newId();

  static String _newId() {
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final salt = _rnd.nextInt(1 << 30).toRadixString(36);
    return '$stamp-$salt';
  }

  static Uri _uri(String path) => Uri.parse('$_base$path');

  /// عدد الحاضرين الآن في كل فضاء (المفتاح = معرّف الفضاء).
  static Map<String, int> _counts = const {};

  /// آخر الأعداد المقروءة (للعرض).
  static Map<String, int> get counts => _counts;

  /// هل صار لدينا أرقام من السيرفر؟ (false = غير متصل بالخادم)
  static bool get hasData => _counts.isNotEmpty;

  /// يضبط الفضاء الحالي ويُرسل نبضة فورية.
  static Future<void> setSpace(String space) async {
    _space = space;
    await _beat();
  }

  /// يشغّل النبض الدوري (يُستدعى عند فتح اللوحة) ويُرجع بعد أول نبضة
  /// حتى تتوفّر الأعداد فوراً دون انتظار الدورة التالية.
  static Future<void> start() async {
    _timer?.cancel();
    _timer = Timer.periodic(heartbeatInterval, (_) => _beat());
    await _beat();
  }

  /// يوقف النبض (عند مغادرة اللوحة) ويُخبر السيرفر بالخروج.
  static void stop() {
    _timer?.cancel();
    _timer = null;
    unawaited(_leave());
  }

  /// يُرجع الأعداد الحالية من السيرفر (استدعاء واحد).
  static Future<Map<String, int>> fetch() async {
    try {
      final res = await http.get(_uri('/api/presence/counts')).timeout(_timeout);
      if (res.statusCode != 200) return _counts;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final raw = (body is Map ? body['counts'] : null);
      if (raw is! Map) return _counts;
      final next = <String, int>{};
      raw.forEach((k, v) {
        if (v is num) next['$k'] = v.toInt();
      });
      _counts = next;
      return next;
    } catch (_) {
      return _counts;
    }
  }

  static Future<void> _beat() async {
    try {
      final res = await http
          .post(
            _uri('/api/presence/heartbeat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id': clientId, 'space': _space}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final raw = (body is Map ? body['counts'] : null);
      if (raw is! Map) return;
      final next = <String, int>{};
      raw.forEach((k, v) {
        if (v is num) next['$k'] = v.toInt();
      });
      _counts = next;
    } catch (_) {
      // الخادم غير متاح — نُبقي آخر أرقام معروفة.
    }
  }

  static Future<void> _leave() async {
    try {
      await http
          .post(
            _uri('/api/presence/leave'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'id': clientId, 'space': _space}),
          )
          .timeout(_timeout);
    } catch (_) {
      // تجاهل — السيرفر يحذف السجل تلقائياً بعد انتهاء المهلة.
    }
  }
}
