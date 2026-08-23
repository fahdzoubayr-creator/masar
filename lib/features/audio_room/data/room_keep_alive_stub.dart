/// نسخة لا-عملية للمنصات غير الأندرويد (الويب/سطح المكتب) —
/// نفس الواجهة بلا أي تأثير، ليبقى استدعاء المتحكم موحّداً.
class RoomKeepAlive {
  const RoomKeepAlive._();

  static bool get supported => false;

  static Future<void> start(String title) async {}

  static Future<void> stop() async {}
}
