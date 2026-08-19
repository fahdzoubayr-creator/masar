import 'package:flutter/material.dart';

/// لوحة ألوان القاعة الصوتية — بنمط Inspeak الداكن.
abstract class RoomPalette {
  /// خلفية القاعة الرئيسية.
  static const Color bg = Color(0xFF1e1e2f);

  /// أسطح البطاقات والقوائم.
  static const Color surface = Color(0xFF27293d);

  /// خلفية أعمق للوحات المتراكبة.
  static const Color deep = Color(0xFF1f1d2b);

  /// اللون الأخضر — المايك مفعل / أنا أتحدث.
  static const Color green = Color(0xFF00d68f);

  /// اللون البرتقالي — رفع اليد.
  static const Color amber = Color(0xFFFFAB00);

  /// اللون الأحمر — المايك مكتوم / مكتم.
  static const Color red = Color(0xFFe5484d);

  static const Color muted = Color(0xFF9a9ab0);
  static const Color text = Color(0xFFf2f2f7);
  static const Color border = Color(0xFF34364a);
}
