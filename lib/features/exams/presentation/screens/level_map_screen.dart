import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/level_progress_service.dart';
import 'package:masar_app/core/services/game_bank_loader.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/exams/presentation/screens/final_exams_screen.dart';
import 'package:masar_app/features/exams/presentation/screens/quiz_level_play_screen.dart';

/// مسار تحدي الكفاءة — خريطة مراحل على طريقة الألعاب التنافسية.
///
/// كل مرحلة: 10 أسئلة عشوائية، نقاط + نجوم + بونص سرعة، وفتح تدريجي لا نهائي.
/// الصعود من الأسفل (المرحلة 1) إلى الأعلى.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  static const double _itemH = 110;
  static const double _padV = 40;
  static const int _questionsPerLevel = 10;

  LevelProgress _progress = LevelProgress.initial;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final progress = await LevelProgressService.load();
    if (!mounted) return;
    setState(() => _progress = progress);
    SchedulerBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  int get _levelCount =>
      max(20, ((_progress.unlockedUpTo + 3) / 10).ceil() * 10);

  double get _contentHeight => (_levelCount * _itemH) + (2 * _padV);

  void _scrollToCurrent() {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final nodeY = _contentHeight - _padV - _itemH / 2 -
        (_progress.currentLevel - 1) * _itemH;
    final target = nodeY - viewport * 0.62;
    final clamped =
        target.clamp(0.0, max(0.0, _scroll.position.maxScrollExtent))
            .toDouble();
    _scroll.animateTo(clamped,
        duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
  }

  List<Question> _buildPool() {
    final pool = List<Question>.from(GameBankLoader.all);
    pool.shuffle(Random());
    return pool;
  }

  Future<void> _openLevel(int levelNumber) async {
    playSfx(Sfx.select);
    final pool = _buildPool();
    if (pool.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              'بنك أسئلة اللعبة فارغ — أضف أسئلة عبر السكربت:\nnode tools/add_game_question.js',
              style: GoogleFonts.tajawal(color: AppColors.cream)),
          backgroundColor: AppColors.bgDeep,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      return;
    }
    final questions = pool.take(_questionsPerLevel).toList();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizLevelPlayScreen(
        levelNumber: levelNumber,
        questions: questions,
        onCompleted: (score, timeSeconds, stars) =>
            _onLevelCompleted(levelNumber, score, timeSeconds, stars),
      ),
    ));
  }

  Future<void> _onLevelCompleted(
      int levelNumber, int score, int timeSeconds, int starsEarned) async {
    final records = Map<int, LevelRecord>.from(_progress.records);
    final existing = records[levelNumber];
    records[levelNumber] = existing == null
        ? LevelRecord(
            stars: starsEarned,
            bestScore: score,
            bestTimeSeconds: timeSeconds)
        : existing.merge(stars: starsEarned, score: score, time: timeSeconds);
    var unlocked = _progress.unlockedUpTo;
    if (starsEarned > 0 && levelNumber + 1 > unlocked) {
      unlocked = levelNumber + 1;
    }
    final updated = _progress.copyWith(unlockedUpTo: unlocked, records: records);
    await LevelProgressService.save(updated);
    if (!mounted) return;
    setState(() => _progress = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: LayoutBuilder(builder: (context, cons) {
                final w = cons.maxWidth;
                final amp = min(w * 0.27, max(0.0, w / 2 - 58));
                return SingleChildScrollView(
                  controller: _scroll,
                  child: SizedBox(
                    height: _contentHeight,
                    width: w,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // خلفية اللعبة تمتد على كامل الارتفاع.
                        Positioned.fill(
                          child: Image.asset(
                            'assets/images/game_map_bg.jpg',
                            fit: BoxFit.fill,
                            alignment: Alignment.topCenter,
                          ),
                        ),
                        // طبقة تعتيم خفيفة.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0, 0.45, 1],
                                  colors: [
                                    AppColors.bgDeep.withValues(alpha: 0.34),
                                    AppColors.bgDeep.withValues(alpha: 0.10),
                                    AppColors.bgDeep.withValues(alpha: 0.36),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // الطريق الترابي three-layered painted directly
                        // through each node's center position.
                        Positioned.fill(
                          child: CustomPaint(
                            size: Size(w, _contentHeight),
                            painter: _RoadPainter(
                              levelCount: _levelCount,
                              width: w,
                              amplitude: amp,
                            ),
                          ),
                        ),
                        for (var i = 0; i < _levelCount; i++)
                          _buildNodeAt(i, w, amp),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.goldSoft, size: 18),
            tooltip: 'رجوع',
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسار تحدي الكفاءة',
                    style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldSoft)),
                Text('اجتز المراحل واجمع النجوم',
                    style: GoogleFonts.tajawal(
                        fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              playSfx(Sfx.tap);
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const FinalExamsScreen()));
            },
            icon: const Icon(Icons.fact_check_outlined,
                color: AppColors.goldSoft, size: 20),
            tooltip: 'النماذج الكلاسيكية',
          ),
          const SizedBox(width: 4),
          _statChip(icon: Icons.star_rounded, value: '${_progress.totalStars}', color: Colors.amber),
          const SizedBox(width: 6),
          _statChip(icon: Icons.bolt_rounded, value: '${_progress.totalScore}', color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _statChip(
      {required IconData icon, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.cream.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(value,
              style: GoogleFonts.tajawal(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.cream)),
        ],
      ),
    );
  }

  Positioned _buildNodeAt(int index, double width, double amplitude) {
    final levelNumber = index + 1;
    final xCenter = width / 2 + sin(index * 0.8) * amplitude;
    final yCenter =
        _contentHeight - _padV - _itemH / 2 - index * _itemH;
    final record = _progress.records[levelNumber];
    final unlocked = _progress.isUnlocked(levelNumber);
    final isCurrent = unlocked && (record == null || record.stars == 0);

    return Positioned(
      top: yCenter - 42,
      left: xCenter - 40,
      width: 80,
      child: _LevelNode(
        levelNumber: levelNumber,
        stars: record?.stars ?? 0,
        unlocked: unlocked,
        isCurrent: isCurrent,
        onTap: unlocked ? () => _openLevel(levelNumber) : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// عقدة مرحلة — قرص مفلطح مرئي على الأرض مع ظل + نجوم + مؤشر نبض للمرحلة
// ---------------------------------------------------------------------------
class _LevelNode extends StatefulWidget {
  final int levelNumber;
  final int stars;
  final bool unlocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.levelNumber,
    required this.stars,
    required this.unlocked,
    required this.isCurrent,
    this.onTap,
  });

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    if (widget.isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LevelNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color discFill;
    final Color discBorder;
    final Color glowColor;
    if (!widget.unlocked) {
      discFill = const Color(0xFF3A4555);
      discBorder = const Color(0xFF5A6575);
      glowColor = Colors.transparent;
    } else if (widget.isCurrent) {
      discFill = const Color(0xFFE7942C);
      discBorder = AppColors.goldSoft;
      glowColor = const Color(0xFFFFAA30);
    } else {
      discFill = const Color(0xFF2E8B74);
      discBorder = AppColors.goldSoft;
      glowColor = const Color(0xFF2E8B74);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // صف النجوم فوق القرص.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Icon(Icons.star_rounded,
                    size: 13,
                    color: i < widget.stars ? Colors.amber : Colors.white30)),
          ),
          const SizedBox(height: 4),
          // ظل القرص المفلطح على الأرض (الجزء السفلي).
          Container(
            width: 54,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          // القرص المفلطح المرسوم على الأرض.
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final scale = widget.isCurrent ? 1.0 + _pulse.value * 0.06 : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 64,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [discFill, discFill.withValues(alpha: 0.82)],
                ),
                border: Border.all(color: discBorder, width: 2.4),
                boxShadow: widget.unlocked
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.55),
                          blurRadius: widget.isCurrent ? 20 : 10,
                          spreadRadius: widget.isCurrent ? 4 : 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: widget.unlocked
                    ? Text('${widget.levelNumber}',
                        style: GoogleFonts.tajawal(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900))
                    : Icon(Icons.lock_rounded,
                        color: AppColors.muted.withValues(alpha: 0.65),
                        size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// رسام الطريق الترابي — حافة داكنة + جسم رملي + خط متقطع
// ---------------------------------------------------------------------------
class _RoadPainter extends CustomPainter {
  final int levelCount;
  final double width;
  final double amplitude;
  _RoadPainter({
    required this.levelCount,
    required this.width,
    required this.amplitude,
  });

  Offset _centerAt(Size size, int i) {
    final y = size.height - _LevelMapScreenState._padV -
        _LevelMapScreenState._itemH / 2 - i * _LevelMapScreenState._itemH;
    final x = width / 2 + sin(i * 0.8) * amplitude;
    return Offset(x, y);
  }

  Path _buildPath(Size size) {
    final first = _centerAt(size, 0);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < levelCount; i++) {
      final prev = _centerAt(size, i - 1);
      final cur = _centerAt(size, i);
      final cy = (prev.dy + cur.dy) / 2;
      path.cubicTo(prev.dx, cy, cur.dx, cy, cur.dx, cur.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // حافة الطريق الخارجية الداكنة.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4A3319).withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // جسم الطريق الرملي.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFE7C98F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ظل داخلROAD لإضافة العمق.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    // الخط المتقطع الأبيض في وسط الطريق.
    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      const dashLen = 12.0;
      const gapLen = 14.0;
      var dist = 0.0;
      while (dist < metric.length) {
        final end = min(dist + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), dashedPaint);
        dist += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter oldDelegate) =>
      oldDelegate.levelCount != levelCount || oldDelegate.width != width;
}
