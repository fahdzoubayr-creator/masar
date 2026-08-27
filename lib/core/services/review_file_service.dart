import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // جذر موقع النشر على GitHub Pages — الملفات تحت assets/assets/review_files.
  static const String baseUrl = 'https://fahdzoubayr-creator.github.io/masar';

  /// ملفات الـPDF الفعلية مستضافة كأصول Release على GitHub
  /// (حدود Pages هي 1GB فقط بينما Releases يدعم حتى 2GB للملف الواحد).
  static const String releaseBase =
      'https://github.com/fahdzoubayr-creator/masar/releases/download/review-files-v1/';

  /// ترجمة اسم مجلد المحور إلى المزالج اللاتينية المستخدمة في أسماء
  /// أصول الـRelease — GitHub يقصّ المحارف غير اللاتينية من الأسماء.
  static const Map<String, String> folderSlugs = {
    'التشريع المدرسي': 'tachrii_madrasii',
    'التنشيط التربوي': 'tanshit_tarbawi',
    'خطاطات ذهنية': 'khatatat_dhihniya',
    'دورات تكوينية': 'dawrat_takwiniya',
    'ديداكتيك الرياضيات': 'didactique_maths',
    'ديداكتيك اللغة الأمازيغية': 'didactique_amazigh',
    'ديداكتيك اللغة العربية': 'didactique_arabe',
    'ديداكتيك اللغة الفرنسية': 'didactique_francais',
    'ديداكتيك النشاط العلمي': 'didactique_science',
    'علوم التربية': 'ouloum_tarbiya',
    'مؤسسات الريادة': 'mouassasat_riyada',
    'مراسلات ومذكرات': 'murasilat_mudhakkirat',
    'مشروع المؤسسة المندمج': 'mashroua_muassasa',
    'التعليم الثانوي بسلكيه': 'taalim_thaanawi',
    'بنك الاسئلة': 'bank_asila',
  };

  /// دليل الملفات لكل محور — يُجلب من الفرع الرئيسي مباشرة (raw)
  /// ليظهر أي تحديث فوراً دون انتظار إعادة نشر الموقع.
  static String get manifestUrl =>
      'https://raw.githubusercontent.com/fahdzoubayr-creator/masar/main/'
      'assets/assets/review_files/manifest.json';

  /// يحوّل مسار الأصول (assets/review_files/<مجلد>/<NN>.pdf)
  /// إلى رابط الـRelease المقابل، أو رابط Pages كبديل للمسارات غير المعروفة.
  static String urlFor(String assetPath) {
    final m =
        RegExp(r'^assets/(?:assets/)?review_files/([^/]+)/(.+)$').firstMatch(assetPath);
    final slug = m == null ? null : folderSlugs[m.group(1)];
    if (m != null && slug != null) return '$releaseBase${slug}__${m.group(2)}';
    return '$baseUrl/${assetPath.replaceFirst('assets/', 'assets/assets/')}';
  }

  /// رابط التحميل الفعلي للبايتات: على الويب نمرّ عبر السيرفر المحلي
  /// كوسيط لأن روابط Releases لا ترسل ترويسات CORS فيرفضها المتصفح،
  /// أما الهاتف (لا يخضع لـCORS) فيجلبها مباشرة من الـRelease.
  static String downloadUrlFor(String assetPath) {
    if (kIsWeb) {
      return Uri.base.resolve(
        '/api/review-files/file?path=${Uri.encodeComponent(assetPath)}',
      ).toString();
    }
    return urlFor(assetPath);
  }

  /// يقرأ ملفاً (PDF أو TXT): من السحابة أولاً، ثم من الكاش،
  /// ثم من الأصول المضمّنة داخل التطبيق عند تعذّر التحميل.
  static Future<Uint8List> readAsset(String assetPath) async {
    final url = downloadUrlFor(assetPath);
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
    if (pdfs.isEmpty) {
      // المانيفست قد يكون قديماً أو غير متاح — اسأل السيرفر المحلي عن
      // الملفات الموجودة فعلياً على القرص داخل مجلد المحور.
      try {
        final uri = Uri.base.resolve(
            '/api/review-files/list?folder=${Uri.encodeComponent(folder)}');
        final resp = await http.get(uri).timeout(const Duration(seconds: 8));
        if (resp.statusCode == 200) {
          final data =
              jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
          final list = (data['files'] as List?) ?? const [];
          for (final e in list.cast<Map<String, dynamic>>()) {
            pdfs.add(ReviewPdf(
              assetPath: e['path'] as String,
              displayName:
                  (e['name'] as String?) ?? (e['path'] as String),
            ));
          }
        }
      } catch (_) {
        // بلا سيرفر: تبقى القائمة فارغة وتظهر حالة عدم توفر ملفات.
      }
    }
    // الترتيب يتبع ترتيب manifest.json مباشرة (بعد إعادة ترتيب الأسماء).
    return pdfs;
  }
}
