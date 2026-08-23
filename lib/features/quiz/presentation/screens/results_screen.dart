import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';

class ResultsScreen extends StatelessWidget {
  final int score;
  final int total;
  final VoidCallback onRestart;

  /// رسالة تحذيرية تُعرض عند الفشل (مثلاً: الحظر 3 ساعات والرجوع للمراجعة).
  final String? warning;

  const ResultsScreen({
    super.key,
    required this.score,
    required this.total,
    required this.onRestart,
    this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((score / total) * 100).round();
    final String title;
    final String text;
    if (pct >= 80) {
      title = 'ممتاز! أنت جاهز';
      text = 'مستواك قوي في هذا المحور. حافظ على هذا الإيقاع وانتقل إلى محور جديد.';
    } else if (pct >= 30) {
      title = 'جيد، تحتاج مراجعة بسيطة';
      text = 'راجع الأسئلة التي أخطأت فيها قبل الانتقال إلى محور آخر.';
    } else {
      title = 'استمر في المحاولة';
      text = 'هذا المحور يحتاج مراجعة أعمق. لا بأس، التكرار هو سر الإتقان.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: pct / 100,
                      strokeWidth: 10,
                      backgroundColor: AppColors.cream.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$pct%', style: AppTheme.displayFont(size: 26)),
                      const Text('نسبة النجاح', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppTheme.displayFont(size: 19)),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.7)),
            if (warning != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.err.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.err.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_clock_rounded,
                        color: AppColors.err, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(warning!,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.err, height: 1.7)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.gold, width: 1.5),
                foregroundColor: AppColors.goldSoft,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              onPressed: onRestart,
              child: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
