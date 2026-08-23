import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// الهوية البصرية لتطبيق "مسار" — أخضر داكن مستوحى من الطابع المؤسساتي
/// مع لمسة ذهبية، بروح زخرفية مغربية بسيطة وغير مباشرة.
class AppColors {
  static const bgDeep = Color(0xFF0F3D3D);
  static const bgSurface = Color(0xFF134847);
  static const bgCard = Color(0xFF175452);
  static const gold = Color(0xFFC9A24A);
  static const goldSoft = Color(0xFFE7CE8C);
  static const cream = Color(0xFFF4EEDF);
  static const ok = Color(0xFF5FAE82);
  static const err = Color(0xFFD2664F);
  static const muted = Color(0xFF8FB5AE);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData.dark();
    final textTheme = GoogleFonts.alexandriaTextTheme(base.textTheme)
        .apply(
          bodyColor: AppColors.cream,
          displayColor: AppColors.cream,
        )
        .copyWith(
          bodyMedium: const TextStyle(
            fontFamily: 'Alexandria',
            fontSize: 13,
            color: AppColors.cream,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Alexandria',
            fontSize: 12,
            color: AppColors.cream,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Alexandria',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.cream,
          ),
        );
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.gold,
        secondary: AppColors.goldSoft,
        surface: AppColors.bgSurface,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(size: 18, color: AppColors.cream),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(size: 18, color: AppColors.cream),
        titleTextStyle: TextStyle(
          fontFamily: 'Alexandria',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.cream,
        ),
      ),
    );
  }

  static TextStyle displayFont({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.cream,
  }) {
    return GoogleFonts.alexandria(fontSize: size, fontWeight: weight, color: color);
  }
}
