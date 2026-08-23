import 'dart:io';

import 'package:flutter/services.dart';

/// يُشغّل/يوقف خدمة الواجهة الأمامية الأصلية (RoomForegroundService)
/// على أندرويد فقط — تُبقي صوت الجلسة حياً عند إغلاق الشاشة.
class RoomKeepAlive {
  const RoomKeepAlive._();

  static const MethodChannel _channel = MethodChannel('masar/room_service');

  static bool get supported => Platform.isAndroid;

  static Future<void> start(String title) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('start', {'title': title});
    } catch (_) {
      // فشل الخدمة لا يعطل دخول القاعة (مثلاً قيود المصنّع).
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }
}
