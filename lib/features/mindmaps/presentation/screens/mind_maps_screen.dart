import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';

/// الخطاطات الذهنية — ملخصات بصرية وتخطيطات ذهنية.
class MindMapsScreen extends StatelessWidget {
  const MindMapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الخطاطات الذهنية')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_outlined,
                    size: 56, color: AppColors.goldSoft),
                const SizedBox(height: 16),
                const Text('ملخصات بصرية',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cream)),
                const SizedBox(height: 8),
                const Text('الخطاطات الذهنية قيد الإعداد',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                    foregroundColor: AppColors.goldSoft,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  // زر رجوع: chevron_left تنعكس في RTL فتشير يمينًا.
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: const Text('العودة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
