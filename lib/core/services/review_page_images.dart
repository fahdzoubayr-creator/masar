import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:masar_app/core/services/review_file_service.dart';

/// أبعاد صفحة واحدة كما صُوّرت (بكسل طبيعي).
class ReviewPageSize {
  final double width;
  final double height;
  const ReviewPageSize(this.width, this.height);
}

/// بيان ملف واحد: عدد الصفحات + أبعادها الطبيعية.
class ReviewPagesMeta {
  final int pages;
  final List<ReviewPageSize> natural;
  const ReviewPagesMeta({required this.pages, required this.natural});
}

/// مولد الصفحات المصوّرة المضغوطة (MuPDF) لملفات المراجعة.
///
/// تُرفع صفحات كل ملف على أي استضافة تدعم CORS (Firebase Storage / S3 /
/// أي سيرفر ثابت) أو تُضمّن داخل التطبيق، ببنية مجلدات موازية لـ
/// assets/review_pages_cache:
///
///   <base>/<slug>__NN.pdf/meta.json
///   <base>/<slug>__NN.pdf/p01.png  … pNN.png
///
/// تُفعَّل عبر حقن القاعدة عند البناء (بلا مفاتيح في الكود):
///   flutter build --dart-define=REVIEW_PAGE_BASE=https://…/review_pages
///
/// لمّا لا تتوفر (قاعدة فارغة أو الخدمة التعطّلت) تعود شاشة العرض
/// تلقائياً إلى المحرك الأصلي (pdfx) دون أي اعتماد على سيرفر محلي.
class ReviewPageImages {
  static const String _base = String.fromEnvironment(
    'REVIEW_PAGE_BASE',
    defaultValue: '',
  );

  /// هل وضعية الصور مفعّلة في هذا البناء؟
  static bool get enabled => _base.isNotEmpty;

  static String get baseUrl => _base;

  /// اسم مجلد الصور في السحابة/الأصول: <slug>__NN (يطابق review_pages_cache).
  static String? folderFor(String assetPath) {
    final m = RegExp(
      r'^assets/(?:assets/)?review_files/([^/]+)/(.+)$',
    ).firstMatch(assetPath);
    if (m == null) return null;
    final slug = ReviewFileService.folderSlugs[m.group(1)];
    if (slug == null) return null;
    var name = m.group(2)!;
    if (name.toLowerCase().endsWith('.pdf')) {
      name = name.substring(0, name.length - 4);
    }
    return '${slug}__$name';
  }

  /// رابط كائن داخل استضافة CORS اعتماداً على قاعدة صريحة —
  /// (Firebase REST/مسار ثابت). صيغة الفراغ: حرّة الاختبار عبر
  /// [objectUrl] التي تستخدم القاعدة الممررة عند البناء.
  static Uri objectUrlForBase(String base, String assetPath, String name) {
    final folder = folderFor(assetPath);
    if (folder == null) throw Exception('مسار ملف غير معروف للصور');
    final b = base.endsWith('/') ? base : '$base/';
    if (b.contains('firebasestorage.googleapis.com')) {
      return Uri.parse(
        '$b${Uri.encodeComponent(folder)}%2F${Uri.encodeComponent(name)}'
        '?alt=media',
      );
    }
    return Uri.parse('$b$folder/$name');
  }

  /// رابط كائن داخل استضافة CORS (قاعدة البناء).
  static Uri objectUrl(String assetPath, String name) =>
      objectUrlForBase(_base, assetPath, name);

  /// رابط بيان الصفحات (المقاييس الطبيعية + العدد).
  static Uri metaUrl(String assetPath) => objectUrl(assetPath, 'meta.json');

  /// رابط صفحة واحدة: p01.png … pNN.png (فهارس تبدأ من 1).
  static Uri pageUrl(String assetPath, int page) =>
      objectUrl(assetPath, 'p${page.toString().padLeft(2, '0')}.png');

  /// يقرأ بيان الصفحات من السحابة ويعيد null عند غياب الخدمة/الفشل.
  static Future<ReviewPagesMeta?> fetchMeta(String assetPath) async {
    if (!enabled) return null;
    return fetchMetaForBase(_base, assetPath);
  }

  /// كـ[fetchMeta] مع قاعدة صريحة (لسهولة الاختبار).
  static Future<ReviewPagesMeta?> fetchMetaForBase(
      String base, String assetPath) async {
    try {
      final resp = await http
          .get(objectUrlForBase(base, assetPath, 'meta.json'))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final mode = j['mode'];
      if (mode != null && mode != 'png') return null;
      final pages = j['pages'] as int?;
      final natural = (j['natural'] as List?)?.cast<List>();
      if (pages == null || natural == null || natural.length < pages) {
        return null;
      }
      return ReviewPagesMeta(
        pages: pages,
        natural: natural
            .take(pages)
            .map((n) => ReviewPageSize(
                  (n[0] as num).toDouble(),
                  (n[1] as num).toDouble(),
                ))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}