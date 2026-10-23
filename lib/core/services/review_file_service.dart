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
  ///
  /// تُجرَّب الإصدارات بالترتيب: الأول هو النسخة النهائية المولَّدة من
  /// مجلد «ملفات التطبيق نهائي»، والثاني إصدار قديم يخدم الملفات التي
  /// ليست ضمن النسخة النهائية (مثل بنك الأسئلة).
  static const List<String> releaseBases = [
    'https://github.com/fahdzoubayr-creator/masar/releases/download/review-files-v3/',
    'https://github.com/fahdzoubayr-creator/masar/releases/download/review-files-v1/',
  ];

  /// الإصدار الأساسي (النسخة النهائية).
  static const String releaseBase =
      'https://github.com/fahdzoubayr-creator/masar/releases/download/review-files-v3/';

  /// فرع المستودع الذي تُقرأ منه الملفات الخام (raw).
  static const String repoBranch = 'master';

  /// قاعدة استضافة CORS لملفات المراجعة (Firebase Storage / R2 / S3 …).
  ///
  /// تُحقن عند البناء فتصل ملفات PDF من نطاق يُرسل ترويسات CORS،
  /// ويصبح فتحها ممكناً في المتصفح على الاستضافة الثابتة (GitHub Pages)
  /// حيث يُمنع جلب ملفات الـRelease بسبب غياب ترويسة CORS:
  ///
  ///   flutter build web --release \
  ///     --dart-define=REVIEW_FILE_BASE=https://firebasestorage.googleapis.com/v0/b/<BUCKET>/o/
  ///
  /// وتُنسخ الملفات إلى هناك بنفس أسماء الـRelease: <slug>__<NN>.pdf
  static const String fileBase = String.fromEnvironment(
    'REVIEW_FILE_BASE',
    defaultValue: '',
  );

  /// هل تُرفع الملفات من استضافة CORS مهيّأة؟
  static bool get hasFileBase => fileBase.isNotEmpty;

  /// يبني رابط ملف في استضافة CORS من مساره في التطبيق.
  ///
  /// Firebase Storage يحتاج ترميز مسار الكائن (%2F) ومعامل ?alt=media،
  /// بينما R2/S3 يستقبلان المسار كما هو.
  static String cloudUrl(String base, String assetPath) {
    final m = RegExp(r'^assets/(?:assets/)?review_files/([^/]+)/(.+)$')
        .firstMatch(assetPath);
    if (m == null) return '';
    final slug = folderSlugs[m.group(1)];
    if (slug == null) return '';
    final name = '${slug}__${m.group(2)}';
    final b = base.endsWith('/') ? base : '$base/';
    if (b.contains('firebasestorage.googleapis.com')) {
      return '$b${Uri.encodeComponent(name)}?alt=media';
    }
    return '$b$name';
  }

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
    'بنك الاسئلة': 'bank_asila',
  };

  /// دليل الملفات لكل محور — يُجلب من الفرع الرئيسي مباشرة (raw)
  /// ليظهر أي تحديث فوراً دون انتظار إعادة نشر الموقع.
  static String get manifestUrl =>
      'https://raw.githubusercontent.com/fahdzoubayr-creator/masar/$repoBranch/'
      'assets/review_files/manifest.json';

  /// يحوّل مسار الأصول (assets/review_files/<مجلد>/<NN>.pdf)
  /// إلى رابط الـRelease المقابل، أو رابط Pages كبديل للمسارات غير المعروفة.
  static String urlFor(String assetPath) {
    final m =
        RegExp(r'^assets/(?:assets/)?review_files/([^/]+)/(.+)$').firstMatch(assetPath);
    final slug = m == null ? null : folderSlugs[m.group(1)];
    if (m != null && slug != null) return '$releaseBase${slug}__${m.group(2)}';
    return '$baseUrl/${assetPath.replaceFirst('assets/', 'assets/assets/')}';
  }

  /// كل روابط الـRelease الممكنة لملف معيّن — تُجرَّب بالترتيب
  /// (النسخة النهائية أولاً ثم الإصدار القديم).
  static List<String> releaseUrlsFor(String assetPath) {
    final m =
        RegExp(r'^assets/(?:assets/)?review_files/([^/]+)/(.+)$').firstMatch(assetPath);
    final slug = m == null ? null : folderSlugs[m.group(1)];
    if (m == null || slug == null) return const [];
    return [
      for (final base in releaseBases) '$base${slug}__${m.group(2)}',
    ];
  }

  /// اسم الملف في الريبو/الـRelease: <slug>__NN.pdf — يطابق محتوى
  /// assets/review_files_cache وكذلك ربط استضافة الصفحات المصوّرة.
  static String? repoFileNameFor(String assetPath) {
    final m =
        RegExp(r'^assets/(?:assets/)?review_files/([^/]+)/(.+)$').firstMatch(assetPath);
    final slug = m == null ? null : folderSlugs[m.group(1)];
    if (m != null && slug != null) return '${slug}__${m.group(2)}';
    return null;
  }

  /// رابط الجلب المباشر من الريبو عبر raw.githubusercontent.com —
  /// يرسل ترويسة CORS مسموحة فيعمل من أي متصفح دون سيرفر وسيط.
  /// الملفات المخزّنة (review_files_cache) موجودة في فرع master، لا main
  /// (main هو ناتج البناء المنشور) — لذلك الفرع هنا master.
  static String repoRawUrlFor(String assetPath) {
    final name = repoFileNameFor(assetPath);
    if (name == null) return '';
<<<<<<< HEAD
    return 'https://raw.githubusercontent.com/fahdzoubayr-creator/masar/master/'
=======
    return 'https://raw.githubusercontent.com/fahdzoubayr-creator/masar/$repoBranch/'
>>>>>>> ac0706f6b636bb2d19e9d21ba5af84b5930495f9
        'assets/review_files_cache/$name';
  }

  /// رابط فتح الملف على المتصفح في صفحة عرض كبيرة (viewer.html) مع منع
  /// التحميل والطباعة. يُحلّ نسبيًا فيرث أصل الخدمة الحالي (سيرفر/Pages)،
  /// ويستعمل صفحات PNG المعالَجة بـMuPDF لعرض عربي سليم وحجم مريح.
  static String viewerUrlFor(String assetPath) => Uri.base
      .resolve('viewer.html?path=${Uri.encodeComponent(assetPath)}')
      .toString();

  /// رابط الجلب من سيرفر API بنفس الأصل إن وُجد (ويب فقط): وسيط اختياري —
  /// يعمل حين تُحمل النسخة من server.js المحلي، ويُتجاوز بصمت (404) عند
  /// الاستضافة الثابتة. يخدم كمصدر ثانٍ قبل الـRelease.
  static String serverRelayUrlFor(String assetPath) => Uri.base
      .resolve('/api/review-files/file?path=${Uri.encodeComponent(assetPath)}')
      .toString();

  /// كل مصادر ملف معيّن مرتّبة حسب الأولوية (تُجرَّب بالترتيب):
  /// 1) استضافة CORS (إن هُيّئت)، 2) الـRelease (النسخة النهائية ثم القديمة)،
  /// 3) الريبو raw (CORS مسموح)، 4) وسيط API بنفس الأصل (سيرفر محلي).
  static List<String> sourcesFor(String assetPath) => <String>[
        if (hasFileBase) cloudUrl(fileBase, assetPath),
        ...releaseUrlsFor(assetPath),
        if (repoRawUrlFor(assetPath).isNotEmpty) repoRawUrlFor(assetPath),
        if (kIsWeb) serverRelayUrlFor(assetPath),
      ].where((u) => u.isNotEmpty).toList();

  /// يقرأ ملفاً (PDF) بترتيب مصادر مستقل تماماً عن أي سيرفر حتمي:
  /// 1) الـRelease، 2) الريبو (raw.githubusercontent — CORS مسموح)،
  /// 3) وسيط API بنفس الأصل (إن وُجد سياق سيرفر)، 4) الكاش،
  /// 5) الأصول المضمّنة داخل التطبيق.
  static Future<Uint8List> readAsset(String assetPath) async {
    final candidates = sourcesFor(assetPath);
    for (final url in candidates) {
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
        // فشل المصدر الحالي (انقطاع/رفض CORS) — نجرّب التالي.
      }
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

  /// يقرأ نص ملف المراجعة: من السحابة (كل المصادر) أو من الأصول المحلية
  /// عند التعذّر.
  static Future<String> readText(String assetPath) async {
    for (final url in sourcesFor(assetPath)) {
      try {
        return await _fetchString(url);
      } catch (_) {
        // نجرّب المصدر التالي.
      }
    }
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return '';
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
    // الترتيب يتبع ترتيب manifest.json مباشرة (بعد إعادة ترتيب الأسماء).
    return pdfs;
  }
}
