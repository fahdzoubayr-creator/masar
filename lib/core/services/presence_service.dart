import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:masar_app/features/audio_room/config/audio_room_config.dart';

/// حضور البطاقات: كل جهاز يُرسل نبضة كل بضع ثوانٍ وهو **داخل** فضاء،
/// فيعرض خادم الدليل عدد المتصلين في كل فضاء الآن. النبضة القديمة تسقط
/// تلقائياً بعد [ttl] على الخادم، فلا تبقى أعداد وهمية بعد إغلاق التبويب.
class PresenceService {
  PresenceService._();

  /// عدّاد المتصلين لكل فضاء حسب آخر استجابة من الخادم —
  /// مفتاحه معرّف الفضاء نفسه المستعمل في [enter].
  static final ValueNotifier<Map<String, int>> counts =
      ValueNotifier<Map<String, int>>(const {});

  /// نبضة كل 3 ثوانٍ — سريعة بما يكفي لظهور «متصل واحد الآن» خلال ثوانٍ.
  static const Duration interval = Duration(seconds: 3);
  static const Duration _timeout = Duration(seconds: 5);

  /// معرّف عشوائي لهذه الجلسة — تبويبان في نفس المتصفح = جهازان.
  static final String deviceId = () {
    final rnd = Random();
    const hex = '0123456789abcdef';
    return List.generate(12, (_) => hex[rnd.nextInt(hex.length)]).join();
  }();

  static Timer? _timer;
  static String? _card;
  static bool _sending = false;

  /// يبدأ النبض الدوري (مرة واحدة) — يُستدعى عند فتح لوحة البطاقات.
  static void start() {
    _timer ??= Timer.periodic(interval, (_) => _beat());
    _beat();
  }

  /// يُسجّل أن المستخدم دخل الفضاء [card] — فيبدأ احتسابه متصلاً فيه.
  static void enter(String card) {
    _card = card;
    start();
    _beat();
  }

  /// يُسجّل خروج المستخدم من الفضاء (رجوعه إلى لوحة البطاقات).
  static void leave() {
    _card = null;
    _beat();
  }

  /// يوقف النبض نهائياً (عند مغادرة اللوحة).
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _card = null;
  }

  static Future<void> _beat() async {
    if (_sending) return;
    _sending = true;
    try {
      final card = _card;
      final res = await http
          .post(
            Uri.parse('${AudioRoomConfig.apiBase}/api/presence'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId, 'card': card ?? ''}),
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final raw = (body is Map ? body['counts'] : null);
      if (raw is Map) {
        counts.value = {
          for (final e in raw.entries)
            '${e.key}': (e.value is num ? (e.value as num).toInt() : 0),
        };
      }
    } catch (_) {
      // الخادم غير متاح — تُبقى آخر الأعداد المعروفة كما هي.
    } finally {
      _sending = false;
    }
  }
}
