import 'dart:async';

import 'package:flutter/foundation.dart';

/// نظام تسجيل بسيط غير حظري: الكتابة لا توقف مسار التنفيذ أبداً.
///
/// المستويات الأساسية: INFO / WARN / ERROR. مفعّل افتراضياً في وضع التطوير،
/// ويُفعّل عند الحاجة في الإنتاج عبر [setEnabled].
class AppLog {
  AppLog._();

  static bool _enabled = kDebugMode;

  /// يضبط التفعيل العام (افتراضياً: التطوير فقط).
  static void setEnabled(bool value) => _enabled = value;

  static void info(String message) => _write('INFO', message);
  static void warn(String message) => _write('WARN', message);
  static void error(String message) => _write('ERROR', message);

  static void _write(String level, String message) {
    if (!_enabled) return;
    final line = '[$level] $message';
    // إرسال غير متزامن حتى لا يُحجب تدفق الوسائط أو الاتصال.
    unawaited(() async {
      debugPrint(line);
    }());
  }
}
