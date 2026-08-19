import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';

/// أزرار تكبير/تصغير عامة تُركَّب فوق أي عارض مستندات.
///
/// لا تحوي أي منطق خاص بنوع ملف معيّن؛ تستقبل نسبة التكبير الحالية
/// والاستدعاءات من العارض، فيعمل بنفس الطريقة لجميع أنواع الوثائق
/// (PDF، صور، نصوص...). توضع داخل [Stack] فتظهر عائمة أسفل اليمين.
class ZoomControlsOverlay extends StatelessWidget {
  /// نسبة التكبير الحالية (1.0 = الحجم الطبيعي) لعرض النسبة المئوية.
  final double zoomRatio;

  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onReset;

  const ZoomControlsOverlay({
    super.key,
    required this.zoomRatio,
    this.onZoomIn,
    this.onZoomOut,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: Material(
        color: AppColors.bgCard.withValues(alpha: 0.94),
        elevation: 6,
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(
                Icons.add_rounded,
                'تكبير',
                onZoomIn,
              ),
              _button(
                Icons.remove_rounded,
                'تصغير',
                onZoomOut,
              ),
              _button(
                Icons.restart_alt_rounded,
                'استعادة الحجم',
                onReset,
              ),
              const SizedBox(height: 2),
              Text(
                '${(zoomRatio * 100).round()}%',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.goldSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 22, color: AppColors.cream),
      visualDensity: VisualDensity.compact,
    );
  }
}
