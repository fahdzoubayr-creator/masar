import 'package:flutter/material.dart';

/// الخلفية الموحدة لجميع شاشات التطبيق بعد واجهة الترحيب.
///
/// تستخدم `background_screens.png` — خلفية كحلية مولَّدة بإضاءة مقيَّدة
/// (ذروة السطوع 0.032) فلا تُطبع أي منطقة ساطعة تطمس العناوين أو
/// الإطارات، ولا حاجة إلى طبقة تعتيم فوقها.
class UnifiedBackground extends StatelessWidget {
  final Widget child;

  const UnifiedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: Image(
            image: AssetImage('assets/images/background_screens.png'),
            fit: BoxFit.cover,
          ),
        ),
        child,
      ],
    );
  }
}
