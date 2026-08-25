import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/level_progress_service.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/exams/presentation/screens/final_exams_screen.dart';
import 'package:masar_app/features/exams/presentation/screens/quiz_level_play_screen.dart';

/// مسار تحدي الكفاءة — خريطة مراحل منحنية على طريقة الألعاب.
///
/// كل مرحلة: 8 أسئلة عشوائية من بنك الأسئلة، نقاط + نجوم + بونص سرعة،
/// وفتح تدريجي للمراحل مع توليد لا نهائي للمراحل الجديدة.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  static const double _itemH = 110;
  static const double _padV = 40;
  static const int _questionsPerLevel = 8;

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
    WidgetsBinding.addPostFrameCallback((_) => _scrollToCurrent());
  }

  /// عدد المراحل المعروضة — يتوسع تلقائياً كلما اقترب اللاعب من النهاية.
  int get _levelCount =>
      max(20, ((_progress.unlockedUpTo + 3) / 10).ceil() * 10);

  double get _contentHeight => (_levelCount * _itemH) + (2 * _padV);

  void _scrollToCurrent() {
    if (!_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = _padV +
        (_progress.currentLevel - 1) * _itemH +
        _itemH / 2 -
        viewport * 0.62;
    final clamped = target.clamp(0.0, max(0.0, _scroll.position.maxScrollExtent));
    _scroll.animateTo(clamped,
        duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
  }

  /// يجمع بنك الأسئلة كاملاً (دون تكرار النص) ويخلطه.
  List<Question> _buildPool() {
    final seen = <String>{};
    final pool = <Question>[];
    for (final questions in QuestionBankLoader.bank.values) {
      for (final q in questions) {
        if (seen.add(q.text)) pool.add(q);
      }
    }
    pool.shuffle(Random());
    return pool;
  }

  Future<void> _openLevel(int levelNumber) async {
    playSfx(Sfx.select);
    final pool = _buildPool();
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('لا توجد أسئلة متاحة حالياً',
              style: GoogleFonts.tajawal(color: AppColors.cream)),
          backgroundColor: AppColors.bgDeep,
          behavior: SnackBarBehavior.floating,
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
              child: SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
                  height: _contentHeight,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          size: Size(double.infinity, _contentHeight),
                          painter: _PathPainter(levelCount: _levelCount),
                        ),
                      ),
                      for (var i = 0; i < _levelCount; i++)
                        _buildNodeAt(i),
                    ],
                  ),
                ),
              ),
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
          // فتح النماذج الكلاسيكية القديمة يبقى متاحاً دائماً.
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
          _statChip(
            icon: Icons.star_rounded,
            value: '${_progress.totalStars}',
            color: Colors.amber,
          ),
          const SizedBox(width: 6),
          _statChip(
            icon: Icons.bolt_rounded,
            value: '${_progress.totalScore}',
            color: Colors.orangeAccent,
          ),
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
        border:
            Border.all(color: AppColors.cream.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(value,
              style: GoogleFonts.tajawal(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream)),
        ],
      ),
    );
  }

  Positioned _buildNodeAt(int index) {
    final levelNumber = index + 1;
    final width = MediaQuery.sizeOf(context).width;
    final xCenter =
        width / 2 + sin(index * 0.8) * (width * 0.28);
    final yCenter = _padV + index * _itemH + _itemH / 2;
    final record = _progress.records[levelNumber];
    final unlocked = _progress.isUnlocked(levelNumber);
    final isCurrent = unlocked && (record == null || record.stars == 0);

    return Positioned(
      top: yCenter - 46,
      left: xCenter - 46,
      width: 92,
      child: Center(child: _LevelNode(
        levelNumber: levelNumber,
        stars: record?.stars ?? 0,
        unlocked: unlocked,
        isCurrent: isCurrent,
        onTap: unlocked ? () => _openLevel(levelNumber) : null,
      )),
    );
  }
}

/// عقدة مرحلة واحدة — زر دائري مضيء فوقه صف نجوم.
class _LevelNode extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Icon(
              Icons.star_rounded,
              size: 15,
              color: i < stars ? Colors.amber : Colors.white24,
            )),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isCurrent ? 66 : 58,
            height: isCurrent ? 66 : 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: !unlocked
                  ? LinearGradient(colors: [
                      AppColors.cream.withValues(alpha: 0.06),
                      AppColors.cream.withValues(alpha: 0.03),
                    ])
                  : isCurrent
                      ? const LinearGradient(
                          colors: [Color(0xFFD2664F), Color(0xFFFF9A3C)])
                      : const LinearGradient(
                          colors: [Color(0xFF2E8B74), Color(0xFF1E5F54)]),
              border: Border.all(
                color: unlocked
                    ? AppColors.goldSoft.withValues(alpha: 0.85)
                    : AppColors.muted.withValues(alpha: 0.35),
                width: 2.2,
              ),
              boxShadow: unlocked
                  ? [
                      BoxShadow(
                        color: (isCurrent
                                ? const Color(0xFFFF9A3C)
                                : const Color(0xFF2E8B74))
                            .withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ]
                  : const [],
            ),
            child: Center(
              child: unlocked
                  ? Text('$levelNumber',
                      style: GoogleFonts.tajawal(
                          color: Colors.white,
                          fontSize: isCurrent ? 22 : 19,
                          fontWeight: FontWeight.w800))
                  : Icon(Icons.lock_rounded,
                      color: AppColors.muted.withValues(alpha: 0.7), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// الخط المنحني الذي يربط عقد المراحل — إحداثياته مطابقة تماماً لمواضعها.
class _PathPainter extends CustomPainter {
  final int levelCount;
  _PathPainter({required this.levelCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    Offset centerAt(int i) {
      final y = _LevelMapScreenState._padV + i * _LevelMapScreenState._itemH +
          _LevelMapScreenState._itemH / 2;
      final x = size.width / 2 + sin(i * 0.8) * (size.width * 0.28);
      return Offset(x, y);
    }

    final first = centerAt(0);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = 1; i < levelCount; i++) {
      final prev = centerAt(i - 1);
      final cur = centerAt(i);
      final controlY = (prev.dy + cur.dy) / 2;
      path.cubicTo(prev.dx, controlY, cur.dx, controlY, cur.dx, cur.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) =>
      oldDelegate.levelCount != levelCount;
}
