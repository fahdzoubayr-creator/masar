import 'dart:math';
import 'dart:ui' as ui;

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

class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});
  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen>
    with TickerProviderStateMixin {
  static const double _itemH = 120;
  static const double _padV = 50;
  static const int _questionsPerLevel = 10;

  LevelProgress _progress = LevelProgress.initial;
  final ScrollController _scroll = ScrollController();

  late final AnimationController _unlockCtrl;
  Animation<Offset>? _unlockFrom;
  Animation<Offset>? _unlockTo;
  bool _isUnlockAnimating = false;
  (int, int)? _pendingUnlock;

  // ── Animated environment ──
  late final AnimationController _envCtrl; // butterflies / birds / fog

  // ── Dam gate state ──
  late final AnimationController _damCtrl;
  bool _isDamAnimating = false;
  int _animatingGateLevel = 0;

  /// كل مرحلة مضاعفة لـ 10 هي مرحلة سد حاسمة.
  static bool _isGateLevel(int n) => n > 0 && n % 10 == 0;

  /// شرط فتح السد: تجاوز عدد النجوم المطلوب للعالم السابق.
  /// gate 10 → 0 نجوم (يكفي اجتياز المرحلات)
  /// gate 20 → 24 نجمة
  /// gate 30 → 48 نجمة ... إلخ.
  bool _isGateUnlocked(int gateLevel) {
    // Gate is "truly unlocked" if the cascade happened — all 9 levels
    // in the next world are accessible.
    return _progress.unlockedUpTo >= gateLevel + 10;
  }

  /// قائمة المراحل غير المكتملة في العالم الحالي فقط (بين السدين).
  List<int> _gateIncompleteLevels(int gateLevel) {
    final prevGate = gateLevel - 10;
    final start = prevGate < 1 ? 1 : prevGate + 1;
    final end = gateLevel;
    final incomplete = <int>[];
    for (var l = start; l < end; l++) {
      if (_isGateLevel(l)) continue;
      final rec = _progress.records[l];
      if (rec == null || rec.stars < 2) {
        incomplete.add(l);
      }
    }
    return incomplete;
  }

  bool _canUnlockGate(int gateLevel) {
    return _gateIncompleteLevels(gateLevel).isEmpty;
  }

  /// هل المرحلة مفتوحة فعلياً (بما في ذلك قيود السد)?
  bool _isLevelReallyUnlocked(int level) {
    if (!_progress.isUnlocked(level)) return false;
    // السدود (10, 20, 30...) دائماً قابلة للنقر — لكن قد تظهر رسالة.
    if (_isGateLevel(level)) return true;
    // تحقق من أن جميع الأبواب السابقة مفتوحة.
    for (var g = 10; g < level; g += 10) {
      if (!_isGateUnlocked(g)) return false;
    }
    return true;
  }

  /// هل المنطقة بعد السد مغطاة بالضباب?
  bool _isFogged(int level) {
    for (var g = 10; g < level; g += 10) {
      if (!_isGateUnlocked(g)) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _unlockCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _unlockCtrl.addStatusListener(_onUnlockStatus);
    _envCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 40))
      ..repeat();
    _damCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _load();
  }

  @override
  void dispose() {
    _unlockCtrl.removeListener(_onUnlockAnim);
    _unlockCtrl.removeStatusListener(_onUnlockStatus);
    _unlockCtrl.dispose();
    _envCtrl.dispose();
    _damCtrl.dispose();
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

  /// بداية الفضاء: آخر 20 مرحلة في الأسفل = أرض، ما فوقها = فضاء.
  double get _spaceStartY => _contentHeight * 0.12;

  /// نجوم الفضاء المولدة مسبقاً.
  late final List<_Star> _spaceStars = _generateStars(250);

  List<_Star> _generateStars(int count) {
    final rnd = Random(42);
    return List.generate(count, (_) {
      return _Star(
        rnd.nextDouble(), // x ratio
        rnd.nextDouble(), // y ratio
        0.5 + rnd.nextDouble() * 1.5, // radius
        0.3 + rnd.nextDouble() * 0.7, // brightness
      );
    });
  }

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

  void _startUnlockAnimation(int fromLevel, int toLevel, double w, double amp) {
    final fromIdx = fromLevel - 1;
    final toIdx = toLevel - 1;
    final fromPos = _nodeCenter(fromIdx, w, amp);
    final toPos = _nodeCenter(toIdx, w, amp);
    _unlockFrom = AlwaysStoppedAnimation(fromPos);
    _unlockTo = AlwaysStoppedAnimation(toPos);
    _isUnlockAnimating = true;
    playRisingSfx();
    _scrollToNode(toIdx);
    _unlockCtrl.forward(from: 0);
  }

  void _scrollToNode(int index) {
    if (!_scroll.hasClients) return;
    final nodeY = _contentHeight - _padV - _itemH / 2 - index * _itemH;
    final viewport = _scroll.position.viewportDimension;
    final target = nodeY - viewport * 0.55;
    final clamped =
        target.clamp(0.0, max(0.0, _scroll.position.maxScrollExtent))
            .toDouble();
    _scroll.animateTo(clamped,
        duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic);
  }

  void _onUnlockAnim() {
    if (mounted) setState(() {});
  }

  void _onUnlockStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        setState(() => _isUnlockAnimating = false);
      });
    }
  }

  Offset _nodeCenter(int index, double width, double amp) {
    final y = _contentHeight - _padV - _itemH / 2 - index * _itemH;
    final x = width / 2 + sin(index * 0.8) * amp;
    return Offset(x, y);
  }

  List<Question> _buildPool() {
    final pool = List<Question>.from(GameBankLoader.all);
    pool.shuffle(Random());
    return pool;
  }

  Future<void> _openLevel(int levelNumber) async {
    playSfx(Sfx.select);

    // ── فحص السد: إذا مرحلة سد والنجوم غير كافية → رسالة ──
    if (_isGateLevel(levelNumber) && !_canUnlockGate(levelNumber)) {
      if (!mounted) return;
      _showGateBlockedDialog(levelNumber);
      return;
    }

    // جلب أسئلة غير مكررة
    final questions = await GameBankLoader.getUniqueQuestionsForLevel(
        count: _questionsPerLevel);
    if (questions.isEmpty) {
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
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizLevelPlayScreen(
        levelNumber: levelNumber,
        questions: questions,
        onCompleted: (score, timeSeconds, stars) {
          // تسجيل الأسئلة كمستخدمة
          GameBankLoader.markQuestionsAsUsed(
              questions.map((q) => q.id).toList());
          _onLevelCompleted(levelNumber, score, timeSeconds, stars);
        },
      ),
    ));
    if (_pendingUnlock != null && mounted) {
      final (from, to) = _pendingUnlock!;
      _pendingUnlock = null;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject();
        if (box is! RenderBox) return;
        final w = box.size.width;
        final amp = min(w * 0.27, max(0.0, w / 2 - 58));
        _startUnlockAnimation(from, to, w, amp);
      });
    }
  }

  void _showGateBlockedDialog(int gateLevel) {
    final incomplete = _gateIncompleteLevels(gateLevel);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A2535),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF3A5070), width: 1.5)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                        colors: [Color(0xFFFFD54F), Color(0xFFC8960A)]),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFFFAA30).withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock_rounded,
                      color: Color(0xFF5A3A00), size: 36),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'سد المرحلة $gateLevel',
                  style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(height: 8),

                // Message
                Text(
                  'يجب الحصول على نجمتين على الأقل في كل مرحلة من هذه السلسلة لفتح السد',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),

                // Incomplete levels list
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المراحل التي تحتاج نجمتين (${incomplete.length}):',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF8A65),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Flexible(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: incomplete.map((l) {
                            final rec = _progress.records[l];
                            final stars = rec?.stars ?? 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: stars == 0
                                        ? const Color(0xFFFF5252)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFFFFAA30)
                                            .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'مرحلة $l',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ...List.generate(
                                    2,
                                    (i) => Icon(
                                      i < stars
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 12,
                                      color: i < stars
                                          ? const Color(0xFFFFD700)
                                          : Colors.white30,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Back button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _scrollToIncompleteLevel(gateLevel);
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(
                      'ارجع لاستكمال المراحل',
                      style: GoogleFonts.tajawal(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8B74),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToIncompleteLevel(int beforeGate) {
    final prevGate = beforeGate - 10;
    final start = prevGate < 1 ? 1 : prevGate + 1;
    int target = start;
    for (var l = start; l < beforeGate; l++) {
      if (_isGateLevel(l)) continue;
      final rec = _progress.records[l];
      if (rec == null || rec.stars < 2) {
        target = l;
      }
    }
    // Levels go bottom-to-top: level 1 at bottom (high y), level N at top (low y).
    final nodeY = _contentHeight - _padV - _itemH / 2 - (target - 1) * _itemH;
    _scroll.animateTo(
      max(0.0, nodeY - 200),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
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
    final didUnlockNew = starsEarned > 0 && levelNumber + 1 > unlocked;
    if (didUnlockNew) {
      unlocked = levelNumber + 1;
      _pendingUnlock = (levelNumber, levelNumber + 1);
    }
    final updated = _progress.copyWith(unlockedUpTo: unlocked, records: records);
    await LevelProgressService.save(updated);
    if (!mounted) return;
    setState(() => _progress = updated);

    // Check if a gate cascade should trigger.
    final isGate = _isGateLevel(levelNumber);
    if (isGate && starsEarned > 0) {
      final worldEnd = min(levelNumber + 10, _levelCount);
      if (unlocked < worldEnd && _canUnlockGate(levelNumber)) {
        // Cascade-unlock all 9 levels in the new world.
        unlocked = worldEnd;
        final updated2 =
            _progress.copyWith(unlockedUpTo: unlocked, records: records);
        await LevelProgressService.save(updated2);
        if (mounted) setState(() => _progress = updated2);
        _animatingGateLevel = levelNumber;
        _isDamAnimating = true;
        playSfx(Sfx.dam_unlock);
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _damCtrl.forward(from: 0).then((_) {
            if (!mounted) return;
            setState(() {
              _isDamAnimating = false;
              _pendingUnlock = (levelNumber, worldEnd - 1);
            });
          });
        });
      }
    }
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
                        // ── Background: Earth (bottom) + Space (top) ──
                        Positioned(
                          top: _spaceStartY,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Image.asset(
                            'assets/images/game_map_bg.jpg',
                            fit: BoxFit.cover,
                            alignment: Alignment.bottomCenter,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: _spaceStartY,
                          child: CustomPaint(
                            painter: _SpacePainter(
                              spaceStartY: _spaceStartY,
                              contentHeight: _contentHeight,
                              stars: _spaceStars,
                            ),
                          ),
                        ),
                        // ── Animated environment overlay ──
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _envCtrl,
                              builder: (_, __) => CustomPaint(
                                size: Size(w, _contentHeight),
                                painter: _EnvironmentPainter(
                                  progress: _envCtrl.value,
                                  contentHeight: _contentHeight,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ── Scrim gradient ──
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: const [0, 0.35, 0.7, 1],
                                  colors: [
                                    AppColors.bgDeep.withValues(alpha: 0.20),
                                    AppColors.bgDeep.withValues(alpha: 0.05),
                                    AppColors.bgDeep.withValues(alpha: 0.05),
                                    AppColors.bgDeep.withValues(alpha: 0.28),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // ── Road with perspective ──
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
                        // ── Glow on unlocked segments ──
                        Positioned.fill(
                          child: CustomPaint(
                            size: Size(w, _contentHeight),
                            painter: _GlowPainter(
                              levelCount: _levelCount,
                              unlockedUpTo: _progress.unlockedUpTo,
                              width: w,
                              amplitude: amp,
                            ),
                          ),
                        ),
                        // ── Character sprite during unlock ──
                        if (_isUnlockAnimating &&
                            _unlockFrom != null &&
                            _unlockTo != null)
                          AnimatedBuilder(
                            animation: _unlockCtrl,
                            builder: (_, __) {
                              final t = Curves.easeInOutCubic
                                  .transform(_unlockCtrl.value);
                              final pos = Offset.lerp(
                                  _unlockFrom!.value, _unlockTo!.value, t)!;
                              return Positioned(
                                top: pos.dy - 36,
                                left: pos.dx - 16,
                                child: _CharacterSprite(progress: t),
                              );
                            },
                          ),
                        // ── 3D Level nodes + Gate nodes ──
                        for (var i = 0; i < _levelCount; i++)
                          _buildNodeAt(i, w, amp),
                        // ── Fog overlays for locked worlds ──
                        for (var g = 10; g < _levelCount; g += 10)
                          if (!_isGateUnlocked(g))
                            _buildFogOverlay(g, w, amp),
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
          _statChip(
              icon: Icons.star_rounded,
              value: '${_progress.totalStars}',
              color: Colors.amber),
          const SizedBox(width: 6),
          _statChip(
              icon: Icons.bolt_rounded,
              value: '${_progress.totalScore}',
              color: Colors.orangeAccent),
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
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.cream)),
        ],
      ),
    );
  }

  Positioned _buildNodeAt(int index, double width, double amplitude) {
    final levelNumber = index + 1;
    final xCenter = width / 2 + sin(index * 0.8) * amplitude;
    final yCenter = _contentHeight - _padV - _itemH / 2 - index * _itemH;
    final record = _progress.records[levelNumber];
    final reallyUnlocked = _isLevelReallyUnlocked(levelNumber);
    final isCurrent = reallyUnlocked && (record == null || record.stars == 0);
    final depthScale = 0.85 + (index / max(_levelCount, 1)) * 0.30;

    // Gate level — render dam gate instead of normal node.
    if (_isGateLevel(levelNumber)) {
      final gateUnlocked = _isGateUnlocked(levelNumber);
      final canUnlock = _canUnlockGate(levelNumber);
      final incompleteCount = _gateIncompleteLevels(levelNumber).length;
      final totalLevels = levelNumber - 1; // non-gate levels before gate
      final completedCount = totalLevels - incompleteCount;
      return Positioned(
        top: yCenter - 56 * depthScale,
        left: xCenter - 52 * depthScale,
        width: 104 * depthScale,
        child: _DamGateNode(
          levelNumber: levelNumber,
          unlocked: gateUnlocked,
          canUnlock: canUnlock,
          completedLevels: completedCount,
          totalLevels: totalLevels,
          depthScale: depthScale,
          isAnimating:
              _isDamAnimating && _animatingGateLevel == levelNumber,
          damCtrl: _damCtrl,
          onTap: () => _openLevel(levelNumber),
        ),
      );
    }

    return Positioned(
      top: yCenter - 48 * depthScale,
      left: xCenter - 44 * depthScale,
      width: 88 * depthScale,
      child: _Node3D(
        levelNumber: levelNumber,
        stars: record?.stars ?? 0,
        unlocked: reallyUnlocked,
        isCurrent: isCurrent,
        depthScale: depthScale,
        onTap: reallyUnlocked ? () => _openLevel(levelNumber) : null,
      ),
    );
  }

  // ── Fog overlay for levels after a locked gate ──
  Positioned _buildFogOverlay(int gateLevel, double width, double amp) {
    final startIdx = gateLevel; // first fogged level index (0-based)
    final fogCount = min(10, _levelCount - gateLevel);
    if (fogCount <= 0) {
      return const Positioned(left: 0, top: 0, width: 0, height: 0, child: SizedBox.shrink());
    }

    final topIdx = gateLevel + fogCount - 1;
    final topY = _contentHeight - _padV - _itemH / 2 - topIdx * _itemH - 60;
    final bottomY = _contentHeight - _padV - _itemH / 2 - startIdx * _itemH + 60;

    return Positioned(
      top: topY,
      left: 0,
      right: 0,
      height: bottomY - topY,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A2535).withValues(alpha: 0.0),
                const Color(0xFF1A2535).withValues(alpha: 0.82),
                const Color(0xFF1A2535).withValues(alpha: 0.92),
                const Color(0xFF1A2535).withValues(alpha: 0.82),
                const Color(0xFF1A2535).withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.15, 0.5, 0.85, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// عقدة مرحلة ثلاثية الأبعاد — قرص حجري مصقول مع حافة مذهبة وظل عميق
// ═══════════════════════════════════════════════════════════════════════════════
class _Node3D extends StatefulWidget {
  final int levelNumber;
  final int stars;
  final bool unlocked;
  final bool isCurrent;
  final double depthScale;
  final VoidCallback? onTap;
  const _Node3D({
    required this.levelNumber,
    required this.stars,
    required this.unlocked,
    required this.isCurrent,
    required this.depthScale,
    this.onTap,
  });
  @override
  State<_Node3D> createState() => _Node3DState();
}

class _Node3DState extends State<_Node3D> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.isCurrent) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Node3D old) {
    super.didUpdateWidget(old);
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
    final s = widget.depthScale;
    final discW = 72.0 * s;
    final discH = 44.0 * s;
    final sideH = 14.0 * s;
    final goldBorder = 3.0 * s;

    // ── Neon Colors ──
    final Color topFace;
    final Color sideFace;
    final Color borderColor;
    final Color glowColor;
    final Color numberColor;

    if (!widget.unlocked) {
      topFace = const Color(0xFF1A1F36);
      sideFace = const Color(0xFF0F1520);
      borderColor = const Color(0xFF4A5060);
      glowColor = Colors.transparent;
      numberColor = Colors.grey;
    } else if (widget.isCurrent) {
      // نيون ذهبي متوهج — المرحلة الحالية
      topFace = const Color(0xFF1A1F36);
      sideFace = const Color(0xFF0F1520);
      borderColor = const Color(0xFFFFD54F);
      glowColor = const Color(0xFFFFAA30);
      numberColor = const Color(0xFFFFD54F);
    } else {
      // نيون أخضر متوهج — مراحل مكتملة
      topFace = const Color(0xFF0F2027);
      sideFace = const Color(0xFF0A1418);
      borderColor = const Color(0xFF00E676);
      glowColor = const Color(0xFF00E676);
      numberColor = const Color(0xFF00E676);
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          final lift = widget.isCurrent ? _pulse.value * 3.0 : 0.0;
          return Transform.translate(
            offset: Offset(0, -lift),
            child: child,
          );
        },
        child: SizedBox(
          width: discW + 8,
          height: discH + sideH + 30,
          child: Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              // ── Stars (above disc) ──
              Positioned(
                top: 0,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 4 * s, vertical: 2 * s),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 6 * s,
                        offset: Offset(0, 2 * s),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (i) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.0 * s),
                        child: Icon(Icons.star_rounded,
                            size: 12 * s,
                            color: i < widget.stars
                                ? const Color(0xFFFFD700)
                                : Colors.white24),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Ground shadow ──
              Positioned(
                bottom: 0,
                child: Container(
                  width: discW * 0.85,
                  height: sideH * 0.7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: RadialGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Disc body (3D) ──
              Positioned(
                bottom: sideH * 0.3,
                child: SizedBox(
                  width: discW,
                  height: discH + sideH,
                  child: CustomPaint(
                    painter: _Disc3DPainter(
                      width: discW,
                      height: discH,
                      sideHeight: sideH,
                      topColor: topFace,
                      sideColor: sideFace,
                      borderColor: borderColor,
                      borderWidth: goldBorder,
                      glowColor: glowColor,
                      isCurrent: widget.isCurrent,
                      unlocked: widget.unlocked,
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: sideH * 0.5),
                        child: widget.unlocked
                            ? Text('${widget.levelNumber}',
                                style: GoogleFonts.tajawal(
                                    color: numberColor,
                                    fontSize: 20 * s,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                          color: Colors.black45,
                                          blurRadius: 3,
                                          offset: const Offset(0, 1)),
                                    ]))
                            : Icon(Icons.lock_rounded,
                                color: Colors.white24, size: 16 * s),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام القرص ثلاثي الأبعاد — وجه علوي مصقول + جانب داكن + حافة مذهبة
// ═══════════════════════════════════════════════════════════════════════════════
class _Disc3DPainter extends CustomPainter {
  final double width, height, sideHeight, borderWidth;
  final Color topColor, sideColor, borderColor, glowColor;
  final bool isCurrent, unlocked;

  _Disc3DPainter({
    required this.width,
    required this.height,
    required this.sideHeight,
    required this.topColor,
    required this.sideColor,
    required this.borderColor,
    required this.borderWidth,
    required this.glowColor,
    required this.isCurrent,
    required this.unlocked,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = width;
    final h = height;
    final sh = sideHeight;
    final rx = w / 2;
    final ry = h / 2;

    // ── Side face (dark lower half) ──
    final sidePath = Path()
      ..moveTo(0, h * 0.5)
      ..arcToPoint(Offset(w, h * 0.5),
          radius: Radius.circular(rx), clockwise: false)
      ..lineTo(w, h * 0.5 + sh)
      ..arcToPoint(Offset(0, h * 0.5 + sh),
          radius: Radius.circular(rx), clockwise: true)
      ..close();
    canvas.drawPath(
      sidePath,
      Paint()..color = sideColor,
    );

    // ── Side highlight stripe ──
    final stripePath = Path()
      ..moveTo(w * 0.15, h * 0.5 + sh * 0.3)
      ..lineTo(w * 0.85, h * 0.5 + sh * 0.3)
      ..lineTo(w * 0.85, h * 0.5 + sh * 0.6)
      ..lineTo(w * 0.15, h * 0.5 + sh * 0.6)
      ..close();
    canvas.drawPath(
      stripePath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // ── Top face (elliptical disc) ──
    final topRect = Rect.fromCenter(
        center: Offset(rx, h * 0.5), width: w, height: h);
    final topOval = Path()..addOval(topRect);

    // Glossy gradient on top face.
    canvas.drawOval(
      topRect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h * 0.15),
          Offset(0, h * 0.85),
          [
            topColor.withValues(alpha: 1.0),
            topColor.withValues(alpha: 0.75),
          ],
        ),
    );

    // Glossy highlight (specular).
    final highlightRect = Rect.fromCenter(
        center: Offset(rx, h * 0.38), width: w * 0.65, height: h * 0.35);
    canvas.drawOval(
      highlightRect,
      Paint()
        ..color = Colors.white.withValues(alpha: isCurrent ? 0.30 : 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Border (golden ring) ──
    final borderOval = Path()
      ..addOval(topRect.deflate(borderWidth / 2));
    canvas.drawPath(
      borderOval,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth,
    );

    // ── Neon glow (double layer) ──
    if (unlocked) {
      // Outer soft glow
      canvas.drawOval(
        topRect.deflate(-6),
        Paint()
          ..color = glowColor.withValues(alpha: isCurrent ? 0.45 : 0.20)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, isCurrent ? 22 : 14),
      );
      // Inner strong glow
      canvas.drawOval(
        topRect.deflate(-1),
        Paint()
          ..color = glowColor.withValues(alpha: isCurrent ? 0.70 : 0.35)
          ..maskFilter =
              MaskFilter.blur(BlurStyle.normal, isCurrent ? 8 : 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Disc3DPainter old) =>
      old.topColor != topColor ||
      old.isCurrent != isCurrent ||
      old.unlocked != unlocked ||
      old.glowColor != glowColor;
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام الطريق — حافة داكنة + جسم رملي + خطوط جانبية + متقطع
// ═══════════════════════════════════════════════════════════════════════════════
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

  void _drawDashed(Canvas canvas, Path path, Paint paint,
      {double dash = 12, double gap = 14}) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final end = min(d + dash, m.length);
        canvas.drawPath(m.extractPath(d, end), paint);
        d += dash + gap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Outer dark edge.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF3A2510).withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 34
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Road body.
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD4B87A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Inner shadow for depth.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    // Side edge lines (left and right of road center).
    for (final side in [-1.0, 1.0]) {
      final edgePath = Path();
      bool first = true;
      for (var i = 0; i < levelCount; i++) {
        final c = _centerAt(size, i);
        final off = Offset(side * 11, 0);
        if (first) {
          edgePath.moveTo(c.dx + off.dx, c.dy + off.dy);
          first = false;
        } else {
          final prev = _centerAt(size, i - 1) + off;
          final cy = (prev.dy + c.dy + off.dy) / 2;
          edgePath.cubicTo(prev.dx, cy, c.dx + off.dx, cy,
              c.dx + off.dx, c.dy + off.dy);
        }
      }
      canvas.drawPath(
        edgePath,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // Center dashed line.
    _drawDashed(
      canvas,
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.levelCount != levelCount || old.width != width;
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام إضاءة المسار المفتوح
// ═══════════════════════════════════════════════════════════════════════════════
class _GlowPainter extends CustomPainter {
  final int levelCount;
  final int unlockedUpTo;
  final double width;
  final double amplitude;
  _GlowPainter({
    required this.levelCount,
    required this.unlockedUpTo,
    required this.width,
    required this.amplitude,
  });

  Offset _centerAt(Size size, int i) {
    final y = size.height - _LevelMapScreenState._padV -
        _LevelMapScreenState._itemH / 2 - i * _LevelMapScreenState._itemH;
    final x = width / 2 + sin(i * 0.8) * amplitude;
    return Offset(x, y);
  }

  Path _buildSegment(Size size, int from, int to) {
    final first = _centerAt(size, from);
    final path = Path()..moveTo(first.dx, first.dy);
    for (var i = from + 1; i <= to; i++) {
      final prev = _centerAt(size, i - 1);
      final cur = _centerAt(size, i);
      final cy = (prev.dy + cur.dy) / 2;
      path.cubicTo(prev.dx, cy, cur.dx, cy, cur.dx, cur.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (unlockedUpTo < 2) return;
    for (var i = 0; i < min(unlockedUpTo, levelCount - 1); i++) {
      final seg = _buildSegment(size, i, i + 1);
      // Outer glow.
      canvas.drawPath(
        seg,
        Paint()
          ..color = const Color(0xFFFFD54F).withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 42
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      // Inner glow.
      canvas.drawPath(
        seg,
        Paint()
          ..color = const Color(0xFFFFE082).withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter old) =>
      old.unlockedUpTo != unlockedUpTo || old.width != width;
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام العناصر البيئية الحية — فراشات + عصافير + ضباب
// ═══════════════════════════════════════════════════════════════════════════════
class _EnvironmentPainter extends CustomPainter {
  final double progress;
  final double contentHeight;
  _EnvironmentPainter({required this.progress, required this.contentHeight});

  static final _rnd = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;

    // ── Fog wisps between mountain peaks (upper third) ──
    final fogPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    for (var i = 0; i < 5; i++) {
      final baseX = _rnd.nextDouble() * size.width;
      final baseY = contentHeight * 0.08 + _rnd.nextDouble() * contentHeight * 0.18;
      final drift = sin(t * 2 * pi + i * 1.3) * 40;
      final fw = 60.0 + _rnd.nextDouble() * 80;
      final fh = 18.0 + _rnd.nextDouble() * 14;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(baseX + drift, baseY), width: fw, height: fh),
          fogPaint);
    }

    // ── Butterflies (flutter across mid-section) ──
    for (var i = 0; i < 4; i++) {
      final startX = _rnd.nextDouble() * size.width;
      final baseY = contentHeight * 0.25 + _rnd.nextDouble() * contentHeight * 0.50;
      final x = startX + sin(t * 2 * pi * 0.8 + i * 2.1) * 50;
      final y = baseY + cos(t * 2 * pi * 0.6 + i * 1.7) * 20;
      final wingAngle = sin(t * 2 * pi * 1.2 + i) * 0.5;
      final colors = [
        [Colors.orange.shade300, Colors.deepOrange.shade200],
        [Colors.pink.shade200, Colors.purple.shade200],
        [Colors.lightBlue.shade200, Colors.cyan.shade200],
        [Colors.yellow.shade300, Colors.amber.shade200],
      ];
      final c = colors[i % colors.length];

      canvas.save();
      canvas.translate(x, y);

      // Left wing.
      canvas.save();
      canvas.rotate(-0.3 + wingAngle);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(-4, 0), width: 9, height: 6),
          Paint()..color = c[0].withValues(alpha: 0.55));
      canvas.restore();

      // Right wing.
      canvas.save();
      canvas.rotate(0.3 - wingAngle);
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(4, 0), width: 9, height: 6),
          Paint()..color = c[1].withValues(alpha: 0.55));
      canvas.restore();

      // Body.
      canvas.drawLine(
          Offset.zero, Offset(0, 4),
          Paint()
            ..color = Colors.brown.withValues(alpha: 0.4)
            ..strokeWidth = 1);

      canvas.restore();
    }

    // ── Birds (V-shape in the sky area) ──
    for (var i = 0; i < 3; i++) {
      final bx = (size.width * 0.2 + i * size.width * 0.25) +
          sin(t * 2 * pi * 0.3 + i * 3) * 30;
      final by = contentHeight * 0.05 + i * 18.0 +
          cos(t * 2 * pi * 0.2 + i * 2) * 8;
      final wingUp = sin(t * 2 * pi * 0.9 + i * 1.5) * 4;

      final birdPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;

      // Left wing.
      canvas.drawLine(
          Offset(bx, by),
          Offset(bx - 7, by - 3 - wingUp),
          birdPaint);
      // Right wing.
      canvas.drawLine(
          Offset(bx, by),
          Offset(bx + 7, by - 3 - wingUp),
          birdPaint);
    }

    // ── Water stream (thin wavy line in lower half) ──
    final waterPath = Path();
    final waterY = contentHeight * 0.72;
    waterPath.moveTo(size.width * 0.05, waterY);
    for (var x = 0.0; x < size.width * 0.9; x += 2) {
      final wave = sin((x / 30) + t * 4 * pi) * 3;
      waterPath.lineTo(size.width * 0.05 + x, waterY + wave);
    }
    canvas.drawPath(
      waterPath,
      Paint()
        ..color = const Color(0xFF60B0D0).withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // Water shimmer.
    canvas.drawPath(
      waterPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _EnvironmentPainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// عقدة سد مائي — مجسم كرتوني مع قفل + بوابات + عداد نجوم
// ═══════════════════════════════════════════════════════════════════════════════
class _DamGateNode extends StatelessWidget {
  final int levelNumber;
  final bool unlocked;
  final bool canUnlock;
  final int completedLevels;
  final int totalLevels;
  final double depthScale;
  final bool isAnimating;
  final AnimationController damCtrl;
  final VoidCallback? onTap;

  const _DamGateNode({
    required this.levelNumber,
    required this.unlocked,
    required this.canUnlock,
    required this.completedLevels,
    required this.totalLevels,
    required this.depthScale,
    required this.isAnimating,
    required this.damCtrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = depthScale;
    final gateW = 92.0 * s;
    final gateH = 70.0 * s;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: damCtrl,
        builder: (_, __) {
          final t = isAnimating ? damCtrl.value : (unlocked ? 1.0 : 0.0);
          // Gate doors slide up during unlock.
          final doorOffset = Curves.easeOutBack.transform(min(t * 1.5, 1.0)) * gateH * 0.7;
          // Lock fades + scales down.
          final lockOpacity = (1.0 - min(t * 2.0, 1.0)).clamp(0.0, 1.0);
          final lockScale = 1.0 - Curves.easeInBack.transform(min(t * 2.0, 1.0)) * 0.5;
          // Sparkle burst at t ~ 0.3.
          final sparkleOpacity = t > 0.1 && t < 0.7
              ? sin((t - 0.1) / 0.6 * pi) * 0.9
              : 0.0;

          return SizedBox(
            width: gateW + 12,
            height: gateH + 36,
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                // ── Stars counter pill ──
                Positioned(
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 6 * s, vertical: 3 * s),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: unlocked
                              ? const Color(0xFFFFD54F).withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded,
                            size: 12 * s,
                            color: unlocked
                                ? const Color(0xFFFFD700)
                                : Colors.white54),
                        SizedBox(width: 3 * s),
                        Text(
                          unlocked
                              ? '✓ مفتوح'
                              : '$completedLevels/$totalLevels',
                          style: GoogleFonts.tajawal(
                            fontSize: 10 * s,
                            fontWeight: FontWeight.w700,
                            color: unlocked
                                ? const Color(0xFFFFD700)
                                : canUnlock
                                    ? Colors.greenAccent
                                    : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Dam body ──
                Positioned(
                  top: 22 * s,
                  child: SizedBox(
                    width: gateW,
                    height: gateH,
                    child: CustomPaint(
                      painter: _DamBodyPainter(
                        width: gateW,
                        height: gateH,
                        unlocked: unlocked,
                        doorOffset: doorOffset,
                      ),
                    ),
                  ),
                ),

                // ── Lock icon ──
                if (!unlocked)
                  Positioned(
                    top: 22 * s + gateH * 0.25,
                    child: Transform.scale(
                      scale: lockScale,
                      child: Opacity(
                        opacity: lockOpacity,
                        child: Container(
                          width: 30 * s,
                          height: 30 * s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                Color(0xFFFFD54F),
                                Color(0xFFC8960A),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFAA30)
                                    .withValues(alpha: 0.5),
                                blurRadius: 12 * s,
                                spreadRadius: 2 * s,
                              ),
                            ],
                          ),
                          child: Icon(Icons.lock_rounded,
                              color: const Color(0xFF5A3A00),
                              size: 16 * s),
                        ),
                      ),
                    ),
                  ),

                // ── Sparkle burst ──
                if (sparkleOpacity > 0.01)
                  Positioned(
                    top: 22 * s + gateH * 0.2,
                    child: Opacity(
                      opacity: sparkleOpacity,
                      child: SizedBox(
                        width: gateW * 1.4,
                        height: gateH * 1.2,
                        child: CustomPaint(
                          painter: _SparkleBurstPainter(
                            progress: t,
                            color: const Color(0xFFFFD54F),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Gate label ──
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8 * s, vertical: 2 * s),
                    decoration: BoxDecoration(
                      color: unlocked
                          ? const Color(0xFF2E8B74).withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'سد المرحلة $levelNumber',
                      style: GoogleFonts.tajawal(
                        fontSize: 9 * s,
                        fontWeight: FontWeight.w700,
                        color: unlocked
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام جسم السد — هيكل خرساني + بوابات متحركة + مياه
// ═══════════════════════════════════════════════════════════════════════════════
class _DamBodyPainter extends CustomPainter {
  final double width, height;
  final bool unlocked;
  final double doorOffset;

  _DamBodyPainter({
    required this.width,
    required this.height,
    required this.unlocked,
    required this.doorOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Dam walls (left + right pillars) ──
    final wallPaint = Paint()..color = const Color(0xFF7A8590);
    final wallHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Left pillar.
    final leftPillar = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, h * 0.1, w * 0.22, h * 0.9),
        const Radius.circular(4));
    canvas.drawRRect(leftPillar, wallPaint);
    canvas.drawRRect(leftPillar.deflate(2), wallHighlight);

    // Right pillar.
    final rightPillar = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.78, h * 0.1, w * 0.22, h * 0.9),
        const Radius.circular(4));
    canvas.drawRRect(rightPillar, wallPaint);
    canvas.drawRRect(rightPillar.deflate(2), wallHighlight);

    // ── Dam top beam ──
    final beamPaint = Paint()..color = const Color(0xFF8A9098);
    final beam = RRect.fromRectAndRadius(
        Rect.fromLTWH(-2, 0, w + 4, h * 0.18),
        const Radius.circular(3));
    canvas.drawRRect(beam, beamPaint);
    canvas.drawRRect(beam.deflate(1), wallHighlight);

    // ── Gate doors (slide up when unlocking) ──
    final doorPaint = Paint()..color = const Color(0xFF5A6872);
    final doorHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final doorLeft = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.22, h * 0.18 - doorOffset, w * 0.26, h * 0.82),
        const Radius.circular(2));
    canvas.drawRRect(doorLeft, doorPaint);
    canvas.drawRRect(doorLeft.deflate(1), doorHighlight);

    final doorRight = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.52, h * 0.18 - doorOffset, w * 0.26, h * 0.82),
        const Radius.circular(2));
    canvas.drawRRect(doorRight, doorPaint);
    canvas.drawRRect(doorRight.deflate(1), doorHighlight);

    // ── Water behind dam (visible when unlocked / during animation) ──
    if (unlocked || doorOffset > 2) {
      final waterLevel = h * 0.35;
      final waterPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, waterLevel),
          Offset(0, h),
          [
            const Color(0xFF4090C0).withValues(alpha: 0.5),
            const Color(0xFF2060A0).withValues(alpha: 0.7),
          ],
        );
      final waterPath = Path()
        ..moveTo(w * 0.22, waterLevel)
        ..lineTo(w * 0.78, waterLevel)
        ..lineTo(w * 0.78, h)
        ..lineTo(w * 0.22, h)
        ..close();
      canvas.drawPath(waterPath, waterPaint);

      // Water shimmer.
      final shimmerPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var y = waterLevel + 6; y < h; y += 8) {
        canvas.drawLine(
            Offset(w * 0.25, y), Offset(w * 0.75, y), shimmerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DamBodyPainter old) =>
      old.unlocked != unlocked || old.doorOffset != doorOffset;
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام تأثير انفجار النجوم عند فتح السد
// ═══════════════════════════════════════════════════════════════════════════════
class _SparkleBurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  static final _rnd = Random(77);

  _SparkleBurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final spread = Curves.easeOut.transform(progress) * size.width * 0.45;

    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + progress * 0.5;
      final dist = spread * (0.5 + _rnd.nextDouble() * 0.5);
      final dx = cx + cos(angle) * dist;
      final dy = cy + sin(angle) * dist;
      final sz = 2.0 + _rnd.nextDouble() * 3;

      canvas.drawCircle(
          Offset(dx, dy),
          sz,
          Paint()
            ..color = color.withValues(alpha: 0.7)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 0.8));
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleBurstPainter old) =>
      old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════════
// بيانات النجوم
// ═══════════════════════════════════════════════════════════════════════════════
class _Star {
  final double x, y, radius, brightness;
  const _Star(this.x, this.y, this.radius, this.brightness);
}

// ═══════════════════════════════════════════════════════════════════════════════
// رسام الفضاء — نجوم + كواكب + توهج + مجرات
// ═══════════════════════════════════════════════════════════════════════════════
class _SpacePainter extends CustomPainter {
  final double spaceStartY;
  final double contentHeight;
  final List<_Star> stars;

  _SpacePainter({
    required this.spaceStartY,
    required this.contentHeight,
    required this.stars,
  });

  // ── قائمة الكواكب والأجرام السماوية ──
  // side: -1 = يسار الطريق، 1 = يمين الطريق
  static const _celestialBodies = <Map<String, dynamic>>[
    // المجموعة الشمسية
    {'name': 'earth', 'emoji': '🌍', 'y': 0.00, 'radius': 30.0, 'side': -1,
     'color': Color(0xFF2196F3), 'glow': Color(0xFF64B5F6), 'glowRadius': 18.0},
    {'name': 'moon', 'emoji': '🌙', 'y': 0.04, 'radius': 14.0, 'side': 1,
     'color': Color(0xFFE0E0E0), 'glow': Color(0xFFFFFFFF), 'glowRadius': 10.0},
    {'name': 'mars', 'emoji': '🔴', 'y': 0.08, 'radius': 20.0, 'side': -1,
     'color': Color(0xFFD32F2F), 'glow': Color(0xFFFF5252), 'glowRadius': 16.0},
    {'name': 'jupiter', 'emoji': '🟠', 'y': 0.14, 'radius': 38.0, 'side': 1,
     'color': Color(0xFFFF9800), 'glow': Color(0xFFFFCC02), 'glowRadius': 22.0},
    {'name': 'saturn', 'emoji': '🪐', 'y': 0.20, 'radius': 32.0, 'side': -1,
     'color': Color(0xFFFFD54F), 'glow': Color(0xFFFFECB3), 'glowRadius': 20.0},
    {'name': 'uranus', 'emoji': '🔵', 'y': 0.26, 'radius': 24.0, 'side': 1,
     'color': Color(0xFF00BCD4), 'glow': Color(0xFF80DEEA), 'glowRadius': 14.0},
    {'name': 'neptune', 'emoji': '🔵', 'y': 0.32, 'radius': 22.0, 'side': -1,
     'color': Color(0xFF1565C0), 'glow': Color(0xFF42A5F5), 'glowRadius': 14.0},
    // الشمس ☀️
    {'name': 'sun', 'emoji': '☀️', 'y': 0.38, 'radius': 50.0, 'side': 0,
     'color': Color(0xFFFFC107), 'glow': Color(0xFFFFEB3B), 'glowRadius': 35.0},
    // ما بعد الشمس — نجوم عملاقة
    {'name': 'arcturus', 'emoji': '⭐', 'y': 0.50, 'radius': 28.0, 'side': 1,
     'color': Color(0xFFFF7043), 'glow': Color(0xFFFFAB91), 'glowRadius': 18.0},
    {'name': 'betelgeuse', 'emoji': '⭐', 'y': 0.58, 'radius': 35.0, 'side': -1,
     'color': Color(0xFFE53935), 'glow': Color(0xFFFF8A80), 'glowRadius': 22.0},
    {'name': 'rigel', 'emoji': '⭐', 'y': 0.66, 'radius': 30.0, 'side': 1,
     'color': Color(0xFF42A5F5), 'glow': Color(0xFF90CAF9), 'glowRadius': 20.0},
    // المجرات البعيدة
    {'name': 'andromeda', 'emoji': '🌌', 'y': 0.78, 'radius': 55.0, 'side': 0,
     'color': Color(0xFF7B1FA2), 'glow': Color(0xFFCE93D8), 'glowRadius': 40.0},
    {'name': 'deep_space', 'emoji': '✨', 'y': 0.92, 'radius': 45.0, 'side': 0,
     'color': Color(0xFF1A237E), 'glow': Color(0xFF7986CB), 'glowRadius': 30.0},
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final spaceH = size.height;

    // ── خلفية الفضاء المتدرجة ──
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, spaceH),
        [
          const Color(0xFF050A15),
          const Color(0xFF0A1628),
          const Color(0xFF0D1F3C),
          const Color(0xFF0A1628),
          const Color(0xFF050A15),
        ],
        const [0.0, 0.2, 0.5, 0.8, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w, spaceH), bgPaint);

    // ── النجوم ──
    for (final star in stars) {
      final sx = star.x * w;
      final sy = star.y * spaceH;
      final paint = Paint()..color = Colors.white.withValues(alpha: star.brightness);
      canvas.drawCircle(Offset(sx, sy), star.radius, paint);
    }

    // ── الكواكب والأجرام السماوية ──
    final roadCenterX = w / 2;
    final roadAmplitude = w * 0.18;
    final t = DateTime.now().millisecondsSinceEpoch / 3000.0;

    for (final body in _celestialBodies) {
      final bodyY = spaceH * (body['y'] as double);
      final radius = body['radius'] as double;
      final glowRadius = body['glowRadius'] as double;
      final bodyColor = body['color'] as Color;
      final glowColor = body['glow'] as Color;
      final side = body['side'] as int;

      // موضع أفقي: على اليمين أو اليسار من الطريق
      final offsetX = (roadAmplitude + radius + 20) * side;
      final cx = roadCenterX + offsetX;

      // ── توهج خارجي ──
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius);
      canvas.drawCircle(Offset(cx, bodyY), radius + glowRadius * 0.6, glowPaint);

      // ── طبقة توهج ثانية (أقوى) ──
      final innerGlow = Paint()
        ..color = glowColor.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.4);
      canvas.drawCircle(Offset(cx, bodyY), radius + 4, innerGlow);

      // ── جسم الكوكب ──
      final bodyPaint = Paint()..color = bodyColor;
      canvas.drawCircle(Offset(cx, bodyY), radius, bodyPaint);

      // ── خلفية متوهجة (حتى تظهر الأقراص بوضوح) ──
      final discBg = Paint()
        ..color = bodyColor.withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, bodyY), radius + 8, discBg);

      // ── زحل: حلقات ──
      if (body['name'] == 'saturn') {
        final ringPaint = Paint()
          ..color = bodyColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(cx, bodyY),
            width: radius * 2.8,
            height: radius * 0.8,
          ),
          ringPaint,
        );
      }

      // ── المشتري: خطوط أفقية ──
      if (body['name'] == 'jupiter') {
        final stripePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..strokeWidth = 1.5;
        for (var i = -2; i <= 2; i++) {
          final stripeY = bodyY + i * radius * 0.25;
          final stripeW = sqrt(max(0, radius * radius - (i * radius * 0.25) * (i * radius * 0.25)));
          canvas.drawLine(
            Offset(cx - stripeW, stripeY),
            Offset(cx + stripeW, stripeY),
            stripePaint,
          );
        }
      }

      // ── الشمس: أشعة ──
      if (body['name'] == 'sun') {
        final rayPaint = Paint()
          ..color = glowColor.withValues(alpha: 0.3)
          ..strokeWidth = 2;
        for (var i = 0; i < 12; i++) {
          final angle = i * pi / 6 + t * 0.3;
          final inner = radius + 5;
          final outer = radius + 20 + sin(t + i) * 8;
          canvas.drawLine(
            Offset(cx + cos(angle) * inner, bodyY + sin(angle) * inner),
            Offset(cx + cos(angle) * outer, bodyY + sin(angle) * outer),
            rayPaint,
          );
        }
      }

      // ── مجرة أندروميدا: حلزونية ──
      if (body['name'] == 'andromeda') {
        final spiralPaint = Paint()
          ..color = glowColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final path = Path();
        for (var a = 0.0; a < pi * 4; a += 0.1) {
          final r = a * radius / (pi * 4);
          final px = cx + cos(a + t * 0.2) * r;
          final py = bodyY + sin(a + t * 0.2) * r * 0.5;
          if (a == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        canvas.drawPath(path, spiralPaint);
      }

      // ── اسم الكوكب ──
      final namePainter = TextPainter(
        text: TextSpan(
          text: body['name'] as String,
          style: TextStyle(
            color: glowColor.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      namePainter.paint(
        canvas,
        Offset(cx - namePainter.width / 2, bodyY + radius + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpacePainter old) =>
      old.spaceStartY != spaceStartY || old.contentHeight != contentHeight;
}

// ═══════════════════════════════════════════════════════════════════════════════
// شخصية اللاعب المتحركة على المسار
// ═══════════════════════════════════════════════════════════════════════════════
class _CharacterSprite extends StatelessWidget {
  final double progress;
  const _CharacterSprite({required this.progress});

  @override
  Widget build(BuildContext context) {
    final bounce = sin(progress * pi) * 8;
    return Transform.translate(
      offset: Offset(0, -bounce),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFE082), Color(0xFFE7942C)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFAA30).withValues(alpha: 0.7),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
