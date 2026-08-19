import 'package:web/web.dart' as web;

/// يزيل معاملات الرابط العميق من عنوان المتصفح (إصدار الويب)
/// عبر `history.replaceState` دون إعادة تحميل الصفحة.
void clearDeepLinkQuery(String cleanUrl) {
  web.window.history.replaceState(null, '', cleanUrl);
}
