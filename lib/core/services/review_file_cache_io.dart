import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// ذاكرة مؤقتة على القرص (الهاتف/الكمبيوتر): تُحفظ ملفات الـPDF المحمّلة
/// فيُفتح الملف فوراً في الزيارات التالية حتى بدون انترنت.
class ReviewFileDiskCache {
  static Directory? _cacheDir;

  static Future<Directory?> _directory() async {
    if (_cacheDir != null) return _cacheDir;
    try {
      final base = await getApplicationSupportDirectory();
      final dir =
          Directory('${base.path}${Platform.pathSeparator}pdf_cache');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _cacheDir = dir;
      return dir;
    } catch (_) {
      return null;
    }
  }

  static Future<File?> _file(String url) async {
    final dir = await _directory();
    if (dir == null) return null;
    final hash = url.hashCode.toUnsigned(32).toRadixString(16);
    return File('${dir.path}${Platform.pathSeparator}$hash.pdf');
  }

  /// يعيد محتوى الملف المخزّن أو null إن لم يكن مخزّناً بعد.
  static Future<Uint8List?> read(String url) async {
    final file = await _file(url);
    if (file == null || !await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      return bytes.isNotEmpty ? bytes : null;
    } catch (_) {
      return null;
    }
  }

  /// يحفظ الملف في القرص. الكتابة عبر ملف مؤقت ثم إعادة تسمية
  /// فلا يُفسد الكاش لو انقطع الحفظ في منتصفه.
  static Future<void> save(String url, Uint8List bytes) async {
    final file = await _file(url);
    if (file == null) return;
    try {
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // فشل الحفظ لا يمنع فتح الملف في هذه الجلسة.
    }
  }
}
