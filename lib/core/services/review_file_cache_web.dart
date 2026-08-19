import 'dart:typed_data';

/// نسخة الويب: بلا ذاكرة قرص محلية — يستخدم المتصفح ذاكرته الخاصة.
class ReviewFileDiskCache {
  static Future<Uint8List?> read(String url) async => null;

  static Future<void> save(String url, Uint8List bytes) async {}
}
