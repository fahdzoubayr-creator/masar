import 'dart:math';

import 'package:flutter/foundation.dart';

/// قاعة «مفتوحة للجميع» — تظهر في شاشة القاعات ويدخلها أي أحد بضغطة واحدة
/// دون الحاجة إلى رمز (الرمز نفسه اسم الغرفة في LiveKit).
class PublicRoom {
  final String code;
  final String name;

  /// رمز تعبيري يميّز القاعة في القائمة.
  final String icon;

  const PublicRoom({
    required this.code,
    required this.name,
    this.icon = '🎙️',
  });
}

/// إعدادات القاعة (صوت وصورة) عبر LiveKit.
///
/// تعمل الجلسات على خادم LiveKit (ذاتي الاستضافة عبر Docker) للصوت والفيديو.
/// **لا يحمل التطبيق أي سرّ إطلاقاً**: يطلب توكنه من خدمة التوكنات في
/// الخادم الخفي ([tokenEndpoint])، والخادم هو من يوقّعه بمفاتيح الإنتاج
/// المخزنة في ملف البيئة `.env` لديه.
///
/// طالما كان [tokenEndpoint] فارغاً يعمل التطبيق في **وضع تجريبي** يحاكي
/// الحاضرين والشات والفيديو محلياً.
class AudioRoomConfig {
  AudioRoomConfig._();

  // ===== رابط خدمة التوكنات في الخادم الخفي =====

  /// يمكن تجاوز العنوان عند البناء:
  /// `flutter run --dart-define=API_BASE=http://192.168.100.97:8123`
  static const String _apiBaseOverride = String.fromEnvironment('API_BASE');

  /// عنوان خادم الدليل والتوكنات.
  ///
  /// أولوية الاختيار:
  /// 1) قيمة `--dart-define=API_BASE=...` إن وُجدت.
  /// 2) على الويب: نفس أصل الصفحة إذا كانت تخدم من خادمنا المحلي
  ///    (منفذ 8123/http أو 8443/https) — فيعمل الدليل والحضور دون
  ///    مشاكل CORS ولا حجب المحتوى المختلط.
  /// 3) خادم التجربة المحلي على شبكة المنزل.
  static String get apiBase {
    if (_apiBaseOverride.isNotEmpty) return _apiBaseOverride;
    if (kIsWeb) {
      final base = Uri.base;
      if (base.port == 8123 || base.port == 8443) {
        return '${base.scheme}://${base.host}:${base.port}';
      }
    }
    return 'http://192.168.100.97:8123';
  }

  static String get tokenEndpoint => '$apiBase/api/livekit/token';

  /// هل خدمة التوكنات مضبوطة؟ عندها نتصل بخادم البث فعلياً، وإلا نعمل
  /// في الوضع التجريبي (محاكاة داخلية دون إنترنت).
  static bool get isConfigured => tokenEndpoint.isNotEmpty;

  /// اسم قاعة LiveKit — يُسبق ببادئة ثابتة ويُطهَّر ليكون صالحاً.
  static String liveKitRoomName(String room) => '$roomPrefix${sanitizeRoom(room)}';

  /// بادئة أسماء الغرف — تميّز جلسات التطبيق وتجعل الاسم أقل قابلية للتخمين.
  static const String roomPrefix = 'Ehtiraf_';

  /// ينظف اسم الغرفة المدخل ليصلح مع LiveKit (حروف/أرقام/شرطة فقط).
  static String sanitizeRoom(String input) {
    final cleaned = input
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return cleaned.isEmpty ? roomPrefix : cleaned;
  }

  /// يولّد اسماً عشوائياً يصعب تخمينه — وهو بذاته بمثابة «رمز الدعوة».
  static String generateRoomId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    final buf = StringBuffer(roomPrefix);
    for (var i = 0; i < 8; i++) {
      buf.write(chars[rnd.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  /// يولّد رمز قاعة مفتوحة من اسم القاعة — رمز مستقر وسهل التذكر
  /// (لأن القاعة المفتوحة لا تحتاج رمزاً سرياً).
  static String generateOpenRoomCode(String name) {
    final base = sanitizeRoom(name).replaceFirst(roomPrefix, '');
    final cleaned = base.isEmpty ? 'Open' : base;
    return '$roomPrefix${cleaned}_Open';
  }

  /// قاعات «مفتوحة للجميع» بمواضيع ثابتة — تظهر دائماً في شاشة القاعات.
  static const List<PublicRoom> publicRooms = [
    PublicRoom(code: 'Ehtiraf_Arabic_Open', name: 'قاعة اللغة العربية', icon: '📗'),
    PublicRoom(code: 'Ehtiraf_Math_Open', name: 'قاعة الرياضيات', icon: '🧮'),
    PublicRoom(code: 'Ehtiraf_Science_Open', name: 'قاعة النشاط العلمي', icon: '🔬'),
    PublicRoom(code: 'Ehtiraf_French_Open', name: 'قاعة الفرنسية', icon: '🇫🇷'),
    PublicRoom(code: 'Ehtiraf_Pedagogy_Open', name: 'قاعة علوم التربية', icon: '📘'),
    PublicRoom(code: 'Ehtiraf_EduLaw_Open', name: 'قاعة التشريع المدرسي', icon: '⚖️'),
  ];

  /// يحدّد تسمية نافذة القاعة داخل واجهتنا.
  static String friendlyRoomLabel(String room) =>
      sanitizeRoom(room).replaceFirst(roomPrefix, '');
}
