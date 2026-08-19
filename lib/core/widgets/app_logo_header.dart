import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';

class AppLogoHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final double logoSize;

  const AppLogoHeader({
    super.key,
    this.title,
    this.subtitle,
    this.logoSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/شعار التطبيق1.png',
          width: logoSize,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (title != null) ...[
          const SizedBox(height: 10),
          Text(
            title!,
            textAlign: TextAlign.center,
            style: AppTheme.displayFont(size: 16, weight: FontWeight.w700),
          ),
        ],
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
        ],
      ],
    );
  }
}
