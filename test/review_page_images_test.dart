import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:masar_app/core/services/review_page_images.dart';

/// التحقق من وضعية الصفحات المصوّرة (REVIEW_PAGE_BASE) بلا أي سيرفر تطبيق:
/// بنية الروابط، قراءة meta.json، وجلب صفحة PNG فعلية.
void main() {
  const asset =
      'assets/review_files/ديداكتيك اللغة العربية/01.pdf';

  test('بنية الرابط لاستضافة بمسار ثابت (S3/سيرفر ثابت)', () {
    final url = ReviewPageImages.objectUrlForBase(
      'https://cdn.example.com/review_pages/',
      asset,
      'p03.png',
    ).toString();
    expect(url, 'https://cdn.example.com/review_pages/'
        'didactique_arabe__01/p03.png');
  });

  test('بنية الرابط لـ Firebase Storage REST', () {
    final url = ReviewPageImages.objectUrlForBase(
      'https://firebasestorage.googleapis.com/v0/b/masar-review/o/',
      asset,
      'meta.json',
    ).toString();
    expect(url, 'https://firebasestorage.googleapis.com/v0/b/masar-review/o/'
        'didactique_arabe__01%2Fmeta.json?alt=media');
  });

  test('قراءة meta.json وجلب صفحة من خادم ثابت CORS حقيقي', () async {
    const base = String.fromEnvironment(
      'REVIEW_TEST_BASE',
      defaultValue: 'http://127.0.0.1:8641/',
    );
    final metaUrl = ReviewPageImages.objectUrlForBase(base, asset, 'meta.json');
    final direct = await http.get(metaUrl);
    expect(direct.statusCode, 200);
    final meta = await ReviewPageImages.fetchMetaForBase(base, asset);
    expect(meta, isNotNull, reason: 'يجب أن يضبط REVIEW_TEST_BASE على خادم الكاش');
    expect(meta!.pages, greaterThan(0));
    expect(meta.natural.length, meta.pages);
    for (final s in meta.natural) {
      expect(s.width, greaterThan(0));
      expect(s.height, greaterThan(0));
    }
    if (meta.pages >= 3) {
      final imgUrl = ReviewPageImages.objectUrlForBase(
        base,
        asset,
        'p03.png',
      );
      final resp = await http.get(imgUrl).timeout(const Duration(seconds: 20));
      expect(resp.statusCode, 200);
      expect(resp.bodyBytes.length, greaterThan(100 * 1024),
          reason: 'يجب أن تكون صفحة النص العربي غير فارغة');
    }
  });
}