import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';

class SubjectCardTile extends StatelessWidget {
  final String icon;
  final String title;

  /// سطر ثانٍ اختياري beneath العنوان (يُخفى إن كان فارغاً).
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const SubjectCardTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 17)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.cream)),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (showChevron)
              // سهم تقدّم: chevron_right تنعكس في RTL فتشير يسارًا (اتجاه التقدّم).
              const Icon(Icons.chevron_right, color: AppColors.goldSoft, size: 20),
          ],
        ),
      ),
    );
  }
}
