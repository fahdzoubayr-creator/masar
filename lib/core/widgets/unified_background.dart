import 'package:flutter/material.dart';

/// الخلفية الموحدة لجميع شاشات التطبيق — صورة خلفية مع تدرج داكن
/// يضمن بقاء المحتوى واضحاً وقابلاً للقراءة فوق الصورة.
class UnifiedBackground extends StatelessWidget {
  final Widget child;

  const UnifiedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: Image(
            image: AssetImage('assets/images/خلفية_الموحدة.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x800F3D3D),
                  Color(0x730B2B2B),
                  Color(0xB3061919),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
