/// عنوان خادم التطبيق — مصدر واحد للحقيقة.
///
/// يُستعمل في الهاتف (الويب يستخدم نفس أصل الصفحة تلقائياً)، ويمكن
/// تغييره وقت البناء عبر:
///   flutter build apk --release --dart-define=SERVER_API_BASE=http://<ip>:8123
///
/// ⚙️ القيمة الافتراضية عنوان الشبكة المحلية للجهاز الخادم.
class ServerAddress {
  ServerAddress._();

  /// العنوان الافتراضي (يُستبدل عند البناء أو بالعنوان المخصّص).
  static const String defaultBase = 'http://192.168.0.129:8123';

  /// عنوان الخادم الفعلي.
  static const String apiBase = String.fromEnvironment(
    'SERVER_API_BASE',
    defaultValue: defaultBase,
  );
}
