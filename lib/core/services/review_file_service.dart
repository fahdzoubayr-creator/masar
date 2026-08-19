import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:masar_app/core/services/review_file_cache.dart';

/// ملف مراجعة واحد داخل المحور: مسار الـPDF للعرض + الاسم العربي للعرض.
class ReviewPdf {
  final String assetPath;
  final String displayName;
  const ReviewPdf({required this.assetPath, required this.displayName});
}

/// يقرأ ملفات المراجعة من السحابة (GitHub Pages) بدل تضمينها داخل التطبيق.
/// تُعرض ملفات PDF داخل التطبيق نفسه بواسطة شاشة PdfViewerScreen،
/// بينما تُقرأ النصوص المستخرجة (txt) لتوليد كويزات المحاور الفرعية.
///
/// عند تعذّر التحميل من السحابة (انقطاع الشبكة أو ملف غير مرفوع) يُعوَّض
/// تلقائياً بالأصول المضمّنة داخل التطبيق (assets/review_files) إن وُجدت.
class ReviewFileService {
  /// عنوان ملفات المراجعة على GitHub Pages — تُقدَّم عند الطلب فقط
  /// فيبقى التطبيق (ويب وهاتف) صغيراً وسريعاً.
  static const String baseUrl =
      'https://fahdzoubayr-creator.github.io/masar/files';

  /// ملف دليل الملفات النصية لكل محور — يُولَّد تلقائياً عند البناء
  /// بواسطة أداة build_manifest.js ويُرفع مع الملفات إلى السحابة.
  static String get manifestUrl => '$baseUrl/manifest.json';

  /// يحوّل مسار الأصول (assets/review_files/...) إلى رابط السحابة المقابل.
  static String urlFor(String assetPath) =>
      '$baseUrl/${assetPath.replaceFirst('assets/review_files/', '')}';

  /// يقرأ ملفاً (PDF أو TXT): من السحابة أولاً، ثم من الكاش،
  /// ثم من الأصول المضمّنة داخل التطبيق عند تعذّر التحميل.
  static Future<Uint8List> readAsset(String assetPath) async {
    final url = urlFor(assetPath);
    final cached = await ReviewFileDiskCache.read(url);
    if (cached != null) return cached;
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 90));
      if (resp.statusCode == 200) {
        ReviewFileDiskCache.save(url, resp.bodyBytes);
        return resp.bodyBytes;
      }
    } catch (_) {
      // انقطاع الشبكة — ننتقل إلى الأصول المحلية.
    }
    return _fromBundle(assetPath);
  }

  /// يقرأ الملف من الأصول المضمّنة داخل التطبيق.
  static Future<Uint8List> _fromBundle(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      throw Exception('تعذّر تحميل الملف (غير متوفر في السحابة ولا في الأصول)');
    }
  }

  static Future<String> _fetchString(String url) async {
    final resp = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('خطأ ${resp.statusCode}');
    }
    return utf8.decode(resp.bodyBytes);
  }

  /// يقرأ نص ملف المراجعة: من السحابة أو من الأصول المحلية عند التعذّر.
  static Future<String> readText(String assetPath) async {
    try {
      return await _fetchString(urlFor(assetPath));
    } catch (_) {
      try {
        return await rootBundle.loadString(assetPath);
      } catch (_) {
        return '';
      }
    }
  }

  /// يعيد خريطة: اسم المحور (المجلد) → قائمة مداخل ملفاته
  /// (كل مدخل فيه pdf + txt + name).
  static Future<Map<String, List<Map<String, String>>>> loadManifest() async {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(await _fetchString(manifestUrl)) as Map<String, dynamic>;
    } catch (_) {
      try {
        json = jsonDecode(
                await rootBundle.loadString('assets/review_files/manifest.json'))
            as Map<String, dynamic>;
      } catch (_) {
        return {};
      }
    }
    return json.map((k, v) {
      final list = (v as List)
          .map((e) => (e as Map).map(
                (kk, vv) => MapEntry(
                  kk as String,
                  vv is bool ? vv.toString() : vv as String,
                ),
              ))
          .toList();
      return MapEntry(k, list);
    });
  }

  /// يقرأ كل الملفات النصية لمحور معيّن ويجمعها في نص واحد.
  /// [topic] يفلتر على محور فرعي واحد إن حُدّد.
  /// يعيد نصاً فارغاً إذا لم توجد ملفات في المحور بعد.
  static Future<String> loadFolderText(String folder, {String? topic}) async {
    final manifest = await _manifestOnce();
    final files = manifest[folder] ?? const <Map<String, String>>[];
    var text = '';
    for (final entry in files) {
      if (entry['quiz'] == 'false') continue;
      if (topic != null && entry['topic'] != topic) continue;
      final txt = entry['txt'];
      if (txt == null) continue;
      try {
        text += await readText(txt);
        text += '\n';
      } catch (_) {
        // نتجاوز الملف غير القابل للقراءة
      }
    }
    return text;
  }

  /// ذاكرة مؤقتة للمانيفست — يُقرأ مرة واحدة فقط بدل إعادة تحميله
  /// في كل استدعاء (يوفّر عشرات الطلبات على الويب).
  static Future<Map<String, List<Map<String, String>>>>? _cachedManifest;
  static Future<Map<String, List<Map<String, String>>>> _manifestOnce() {
    return _cachedManifest ??= loadManifest();
  }

  /// يعيد عدد ملفات PDF المتاحة لمحور معيّن مباشرة من الفهرس
  /// (دون تحميل أي ملف)، لعرض العداد فوراً في قوائم المحاور.
  /// [topic] يفلتر على محور فرعي واحد إن حُدّد.
  static Future<int> countFolderPdfs(String folder, {String? topic}) async {
    final manifest = await _manifestOnce();
    return (manifest[folder] ?? const <Map<String, String>>[])
        .where((e) =>
            e['pdf'] != null && (topic == null || e['topic'] == topic))
        .length;
  }

  /// يعيد عدد الملفات النصية الصالحة لتوليد الأسئلة لمحور معيّن.
  /// [topic] يفلتر على محور فرعي واحد إن حُدّد.
  static Future<int> countFolderQuizFiles(String folder, {String? topic}) async {
    final manifest = await _manifestOnce();
    return (manifest[folder] ?? const <Map<String, String>>[])
        .where((e) =>
            e['txt'] != null &&
            e['quiz'] != 'false' &&
            (topic == null || e['topic'] == topic))
        .length;
  }

  /// يعيد قائمة ملفات PDF لمحور معيّن مع أسمائها العربية للعرض.
  /// [topic] يفلتر على محور فرعي واحد إن حُدّد.
  static Future<List<ReviewPdf>> loadFolderPdfs(String folder,
      {String? topic}) async {
    final manifest = await _manifestOnce();
    final files = manifest[folder] ?? const <Map<String, String>>[];
    final pdfs = <ReviewPdf>[];
    for (final entry in files) {
      final pdf = entry['pdf'];
      if (pdf == null) continue;
      if (topic != null && entry['topic'] != topic) continue;
      pdfs.add(ReviewPdf(
        assetPath: pdf,
        displayName: entry['name'] ?? pdf,
      ));
    }
    pdfs.sort((a, b) {
      final na = int.tryParse(
              RegExp(r'/(\d+)\.pdf$').firstMatch(a.assetPath)?.group(1) ?? '') ??
          9999;
      final nb = int.tryParse(
              RegExp(r'/(\d+)\.pdf$').firstMatch(b.assetPath)?.group(1) ?? '') ??
          9999;
      return na.compareTo(nb);
    });
    return pdfs;
  }
}
