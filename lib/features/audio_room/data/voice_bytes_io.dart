import 'dart:io';
import 'dart:typed_data';

/// على الجوال: نتيجة التسجيل مسار ملف — نقرأه مباشرة.
Future<Uint8List?> readRecordedBytes(String source) async {
  try {
    final f = File(source);
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}
