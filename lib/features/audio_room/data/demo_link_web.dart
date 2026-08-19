import 'dart:convert';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

/// ربط تجريبي بين نوافذ المتصفح عبر `localStorage`: تنشر كل نافذة حالتها في
/// مفتاح خاص بها، وتصل التغييرات إلى النوافذ الأخرى عبر حدث `storage`.
/// يسمح للوضع التجريبي (دون LiveKit) بمزامنة الطلبات وأجهزة القاعة بين
/// النوافذ على نفس الجهاز.
class DemoLink {
  DemoLink._();

  static final Random _rnd = Random.secure();
  static const String _winKey = 'masar_demo_window_id';
  static JSFunction? _listener;
  static void Function(String payload)? _onData;
  static String? _prefix;

  /// معرف ثابت لكل نافذة (يُحفظ في sessionStorage — خاص بالنافذة).
  static String get windowId {
    final cached = web.window.sessionStorage.getItem(_winKey);
    if (cached != null && cached.isNotEmpty) return cached;
    final id =
        'w_${DateTime.now().microsecondsSinceEpoch}_${_rnd.nextInt(1 << 32)}';
    web.window.sessionStorage.setItem(_winKey, id);
    return id;
  }

  /// ينشر حمولة من نافذتنا تحت مفتاح فريد يبدأ بالبادئة.
  static void publish(String prefix, String payload) {
    web.window.localStorage.setItem(
      '${prefix}_$windowId',
      jsonEncode({'w': windowId, 'd': payload}),
    );
  }

  /// يعيد كل الحمولات المنشورة تحت البادئة (باستثناء نافذتنا) — يُستخدم
  /// لقراءة الحالة الأولية عند انضمام نافذة بعد الآخرين.
  static List<String> readAll(String prefix) {
    final result = <String>[];
    for (var i = 0; i < web.window.localStorage.length; i++) {
      final key = web.window.localStorage.key(i);
      if (key == null || !key.startsWith(prefix)) continue;
      final raw = web.window.localStorage.getItem(key);
      if (raw == null) continue;
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        if (map['w'] == windowId) continue;
        final payload = map['d'] as String?;
        if (payload != null) result.add(payload);
      } catch (_) {}
    }
    return result;
  }

  /// يستمع لتحديثات النوافذ الأخرى تحت البادئة (مستمع واحد فقط).
  static void subscribe(String prefix, void Function(String payload) onData) {
    unsubscribe();
    _prefix = prefix;
    _onData = onData;
    _listener = _handleStorage.toJS;
    web.window.addEventListener('storage', _listener);
  }

  static void _handleStorage(web.StorageEvent event) {
    final key = event.key;
    final prefix = _prefix;
    if (prefix == null || key == null || !key.startsWith(prefix)) return;
    final raw = event.newValue;
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['w'] == windowId) return;
      final payload = map['d'] as String?;
      if (payload != null) _onData?.call(payload);
    } catch (_) {}
  }

  /// يزيل المستمع (يُستدعى عند مغادرة القاعة).
  static void unsubscribe() {
    final listener = _listener;
    if (listener != null) {
      web.window.removeEventListener('storage', listener);
      _listener = null;
    }
    _onData = null;
    _prefix = null;
  }
}
