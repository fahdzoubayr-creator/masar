import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';

/// مقدمة «الانفجار الكوني» — تُعرض مرة واحدة عند أول فتح للتطبيق بعد تثبيته.
///
/// تبدأ الشاشة فراغاً داكناً تنبثق منه نقطة ضوء صغيرة في المنتصف، تنبض
/// وتتوهج ثم تنفجر: وميض أبيض + حلقات صدمة متمددة + غبار نجمي متطاير.
/// وبالتوازي تنبثق واجهة الترحيب من نقطة في المركز وتتمدد حتى تملأ الشاشة.
class CosmicIntro extends StatefulWidget {
  const CosmicIntro({super.key, required this.child, this.onFinished});

  /// واجهة الترحيب الكاملة التي تنبثق من مركز الشاشة وتتمدد.
  final Widget child;

  /// يُستدعى عند اكتمال المشهد بالكامل ليفكّ الغلاف الأبوي.
  final VoidCallback? onFinished;

  @override
  State<CosmicIntro> createState() => _CosmicIntroState();
}

class _CosmicIntroState extends State<CosmicIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_StarParticle> _particles;
  Timer? _boomTimer;
  bool _boomPlayed = false;

  @override
  void initState() {
    super.initState();
    // بذرة ثابتة: توزيع النجوم نفسه في كل مرة (مشهد مصمم لا عشوائي).
    final rng = math.Random(20260824);
    _particles = List.generate(130, (_) => _StarParticle.random(rng));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3300),
    )
      ..addStatusListener(_onStatus)
      ..forward();

    // هدير الانفجار يتزامن مع ذروة الوميض (t≈0.37 من مدة المشهد).
    _boomTimer = Timer(const Duration(milliseconds: 1220), _fireBoom);
  }

  void _fireBoom() {
    if (_boomPlayed) return;
    _boomPlayed = true;
    playSfx(Sfx.explosion);
  }

  /// أول لمسة أثناء المشهد: تفكّ صوت المتصفح مبكراً، وإن كانت قريبة
  /// من لحظة الانفجار (أو بعده) يُطلق الهدير فوراً بدل انتظار متأخر.
  void _onPointerDown(_) {
    primeAudio();
    if (!_boomPlayed && _controller.value >= 0.28) {
      _boomTimer?.cancel();
      _fireBoom();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onFinished?.call();
  }

  @override
  void dispose() {
    _boomTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _c01(double v) => v.clamp(0.0, 1.0);

  /// منحنى الوميض الأبيض: صعود حاد نحو الذروة لحظة الانفجار ثم خبود.
  double _flashValue(double t) {
    if (t < 0.37 || t > 0.66) return 0;
    if (t < 0.43) return Curves.easeIn.transform((t - 0.37) / 0.06);
    return 1 - Curves.easeOut.transform((t - 0.43) / 0.23);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          // انتهى المشهد: الواجهة بحجمها الطبيعي وتستقبل اللمس مباشرة.
          if (t >= 1.0) return widget.child;

          // انبثاق واجهة الترحيب من نقطة في المركز ثم تمددها لتملأ الشاشة.
          final revealP =
              Curves.easeOutCubic.transform(_c01((t - 0.42) / 0.46));
          final uiScale = 0.015 + (1 - 0.015) * revealP;
          final uiOpacity = _c01((t - 0.46) / 0.18);
          final flash = _flashValue(t);

          return Stack(
            fit: StackFit.expand,
            children: [
              // الفراغ الكوني خلف كل شيء قبل أن تتمدد الواجهة.
              const ColoredBox(color: Color(0xFF04070E)),
              // الواجهة الحقيقية تنبثق من المركز — يُمنع لمسها أثناء المشهد.
              IgnorePointer(
                child: Opacity(
                  opacity: uiOpacity,
                  child: Transform.scale(scale: uiScale, child: widget.child),
                ),
              ),
              // حلقات الصدمة والنجوم المتطايرة فوق الفراغ والواجهة الناشئة.
              CustomPaint(
                  painter: _CosmicPainter(t: t, particles: _particles)),
              // وميض الانفجار يغمر الشاشة لحظة الذروة.
              IgnorePointer(
                child: ColoredBox(
                  color: Color.fromRGBO(255, 255, 255,
                      (flash * 0.95).clamp(0.0, 1.0)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Color _withAlpha(Color c, double a) =>
    c.withAlpha((a.clamp(0.0, 1.0) * 255).round());

/// جسيم نجمي بخصائص ثابتة: زاوية انطلاق، سرعة، حجم، لون، وطور وميض.
class _StarParticle {
  _StarParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.phase,
    required this.nx,
    required this.ny,
  });

  factory _StarParticle.random(math.Random rng) {
    const palette = [
      Color(0xFFFFE9A8), // ذهبي فاتح
      Color(0xFFF5C542), // ذهبي
      Color(0xFFBFE0FF), // سماوي فاتح
      Color(0xFF4DA3FF), // أزرق
      Color(0xFFFFFFFF), // أبيض
    ];
    return _StarParticle(
      angle: rng.nextDouble() * math.pi * 2,
      speed: 0.45 + rng.nextDouble() * 0.95,
      size: 0.8 + rng.nextDouble() * 2.1,
      color: palette[rng.nextInt(palette.length)],
      phase: rng.nextDouble() * math.pi * 2,
      nx: rng.nextDouble() * 2 - 1,
      ny: rng.nextDouble() * 2 - 1,
    );
  }

  final double angle; // زاوية الانطلاق من مركز الانفجار
  final double speed; // سرعة نسبية للتطاير
  final double size;
  final Color color;
  final double phase; // طور الوميض
  final double nx, ny; // موضع تطبيعي للنجوم الخلفية قبل الانفجار
}

class _CosmicPainter extends CustomPainter {
  _CosmicPainter({required this.t, required this.particles});

  final double t;
  final List<_StarParticle> particles;

  static double _c01(double v) => v.clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.longestSide * 0.78;

    _paintPreStars(canvas, size, center);
    _paintSingularity(canvas, center);
    _paintRings(canvas, center, maxR);
    _paintParticles(canvas, center, maxR);
  }

  /// نجوم خافتة تهتز في الفراغ قبيل الانفجار ثم تذوب مع اشتداد الضوء.
  void _paintPreStars(Canvas canvas, Size size, Offset center) {
    final alpha = 0.30 * (1 - _c01(t / 0.45));
    if (alpha <= 0.004) return;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      if (p.speed > 1.05) continue; // نصف الجسيمات فقط كنجوم خلفية
      final tw = 0.55 + 0.45 * math.sin(t * math.pi * 5 + p.phase);
      paint.color = _withAlpha(p.color, alpha * tw);
      canvas.drawCircle(
        Offset(
          center.dx + p.nx * size.width * 0.75,
          center.dy + p.ny * size.height * 0.75,
        ),
        p.size * 0.9,
        paint,
      );
    }
  }

  /// النقطة الأولى: تولد، تنبض، تشتد توهجتها، ثم تلتهمها قوة الانفجار.
  void _paintSingularity(Canvas canvas, Offset center) {
    if (t >= 0.43) return;
    final birth = Curves.easeOutBack.transform(_c01(t / 0.30));
    final swallow = 1 - _c01((t - 0.36) / 0.07);
    if (swallow <= 0) return;
    final pulse = 0.82 + 0.18 * math.sin(t * math.pi * 7);
    final charge = _c01((t - 0.24) / 0.13); // اشتداد قبيل الانفجار
    final r = (2.2 + 8.5 * birth) * pulse * (1 + charge * 0.9);

    // هالة توهج ذهبية ناعمة حول النواة.
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [
        _withAlpha(const Color(0xFFFFF3CE), 0.95 * swallow),
        _withAlpha(const Color(0xFFF5C542), 0.50 * swallow),
        _withAlpha(const Color(0xFFF5C542), 0),
      ]).createShader(Rect.fromCircle(center: center, radius: r * 7));
    canvas.drawCircle(center, r * 7, glowPaint);

    // النواة البيضاء الساطعة.
    canvas.drawCircle(
      center,
      r * (0.9 + charge * 0.6),
      Paint()
        ..style = PaintingStyle.fill
        ..color = Color.fromRGBO(
            255, 255, 255, ((0.85 + charge * 0.15) * swallow).clamp(0.0, 1.0)),
    );
  }

  /// حلقات صدمة متمددة بألوان الهوية: ذهبي/أزرق تتسع وتخبو تباعاً.
  void _paintRings(Canvas canvas, Offset center, double maxR) {
    const specs = [
      (start: 0.395, color: Color(0xFFFFE9A8)),
      (start: 0.425, color: Color(0xFF4DA3FF)),
      (start: 0.455, color: Color(0xFFF5C542)),
      (start: 0.495, color: Color(0xFFBFE0FF)),
    ];
    final paint = Paint()..style = PaintingStyle.stroke;
    for (final s in specs) {
      final p = _c01((t - s.start) / 0.52);
      if (p <= 0 || p >= 1) continue;
      final e = Curves.easeOutCubic.transform(p);
      paint.color = _withAlpha(s.color, (1 - p) * (1 - p) * 0.65);
      paint.strokeWidth = math.max(0.6, 13 * (1 - e));
      canvas.drawCircle(center, maxR * e, paint);
    }
  }

  /// الغبار النجمي المتطاير: يندفع خارج المركز ويومض ويخفت مع البعد.
  void _paintParticles(Canvas canvas, Offset center, double maxR) {
    final p = _c01((t - 0.40) / 0.54);
    if (p <= 0) return;
    final e = Curves.easeOutCubic.transform(p);
    final fade = 1 - p;
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in particles) {
      final dist = maxR * e * s.speed + 6 * e;
      final tw = 0.6 + 0.4 * math.sin(p * math.pi * 4 + s.phase);
      final alpha = fade * tw;
      if (alpha <= 0.01) continue;
      paint.color = _withAlpha(s.color, alpha);
      canvas.drawCircle(
        Offset(
          center.dx + math.cos(s.angle) * dist,
          center.dy + math.sin(s.angle) * dist,
        ),
        s.size * (1 - 0.45 * p),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CosmicPainter oldDelegate) => oldDelegate.t != t;
}
