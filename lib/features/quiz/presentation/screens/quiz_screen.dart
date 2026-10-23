import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/models/quiz_result.dart';
import 'package:masar_app/core/services/progress_service.dart';
import 'package:masar_app/core/services/question_repository.dart';
import 'package:masar_app/core/services/question_validator.dart';
import 'package:masar_app/features/quiz/presentation/screens/results_screen.dart';

class QuizScreen extends StatefulWidget {
  /// اسم المادة لفلترة الأسئلة، أو null لاختبار شامل يجمع كل المواد
  final String? subjectFilter;

  /// مُحمّل أسئلة مخصص (مثلاً أسئلة مولّدة من ملفات المحور الفرعي).
  /// عندما يكون غير null يُستعمل بدل فلترة بنك الأسئلة.
  final Future<List<Question>> Function()? questionLoader;

  /// التوليد المتدرج: يُستدعى بعد ظهور الدفعة الأولى لإلحاق بقية الأسئلة
  /// أثناء لعب المستخدم — القائمة تتمدد تلقائياً حتى جاهزيتها.
  final Future<List<Question>> Function()? restLoader;

  /// استدعاء يُنفَّذ عند إنهاء الاختبار (لتسجيل المحاولة وأفضل نسبة والحظر).
  final void Function(QuizResult result)? onFinished;

  /// رسالة تظهر في شاشة النتيجة عند الفشل (أقل من 50%).
  final String? failureNote;

  /// مدة الاختبار بالمؤقّت: عند ضبطها يُعرض عدّاد تنازلي ويُرسل الاختبار
  /// تلقائياً عند انتهاء الوقت (يُحسب ما أُجيب عليه حتى اللحظة).
  final Duration? examDuration;

  /// نوع الاختبار: «اختبار تدريبي»، «كويز المحور الفرعي»، «الاختبارات العامة»
  final String? testType;

  /// اسم المحور (المادة) لتسجيله في النتيجة مثل: «اللغة العربية»
  final String? axisName;

  /// اسم المحور الفرعي لتسجيله في النتيجة مثل: «التخطيط والتدبير لأنشطة التعلم»
  final String? subAxisName;

  const QuizScreen({
    super.key,
    this.subjectFilter,
    this.questionLoader,
    this.restLoader,
    this.onFinished,
    this.failureNote,
    this.examDuration,
    this.testType,
    this.axisName,
    this.subAxisName,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question>? pool;
  int current = 0;
  int score = 0;
  int? selectedIndex;
  bool answered = false;
  bool finished = false;
  bool _moreLoading = false;
  bool _waitingMore = false;
  bool _exhausted = false;
  bool _loading = false;
  int _loadTries = 0;
  Timer? _moreTimer;
  int? _lastPct;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  final Map<int, bool> _answers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _moreTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final list = widget.questionLoader != null
        ? await widget.questionLoader!()
        : await QuestionRepository.instance.loadQuestions(
            subject: widget.subjectFilter,
          );
    if (!mounted) return;
    final filtered = QuestionValidator.filterValid(list);
    setState(() {
      _loading = false;
      pool = filtered;
      _remaining = widget.examDuration ?? Duration.zero;
    });
    if (widget.examDuration != null && filtered.isNotEmpty) _startTimer();
    // نستدعي الاستكمال حتى إن كانت الدفعة الأولى فارغة (بنك الموضوع قد
    // يكون قليلاً/فارغاً)، وإلا بقي الكويز عالقاً على شاشة التوليد.
    if (widget.restLoader != null && widget.examDuration == null) {
      _loadMore();
    }
  }

  /// يجلب بقية أسئلة التوليد المتدرج ويُلحقها بالقائمة الحالية.
  ///
  /// تُستدعى دورياً حتى تنتهي المهمة أو يتوقف الخادم عن إعطاء جديد،
  /// حتى لا يعلق الكويز على أربع أسئلة.
  Future<void> _loadMore() async {
    if (_moreLoading || _exhausted || widget.restLoader == null) return;
    setState(() => _moreLoading = true);
    List<Question> rest = const [];
    try {
      rest = await widget.restLoader!();
    } catch (_) {}
    if (!mounted) return;

    final cur = pool ?? const <Question>[];
    final fresh = QuestionValidator.filterValid(rest)
        .where((q) => !cur.any((p) => p.text.trim() == q.text.trim()))
        .toList();

    // لا جديد بعد عدة محاولات => انتهى التوليد.
    _loadTries = fresh.isEmpty ? _loadTries + 1 : 0;

    if (fresh.isNotEmpty) {
      setState(() {
        pool = [...cur, ...fresh];
        _moreLoading = false;
        if (_waitingMore) {
          _waitingMore = false;
          current++;
          selectedIndex = null;
          answered = false;
        }
      });
      // سؤال واحد في كل نداء => يتحرّك العدّاد سؤالاً بعد سؤال.
      _scheduleMore(1);
      return;
    }

    setState(() => _moreLoading = false);

    if (_loadTries < 120) {
      // لم تنتهِ المهمة بعد: أعطها فرصة أخرى بدل الإنهاء المبكر
      // (120 × 3 ثوانٍ ≈ 6 دقائق، وهي المدة القصوى للتوليد).
      _scheduleMore(3);
      if (_waitingMore) return; // ننتظر دون إنهاء الكويز
    } else {
      _exhausted = true;
      if (_waitingMore && !finished) {
        _saveResult();
        setState(() => finished = true);
        _playFinish();
      }
    }
  }

  /// يعيد جدولة جلب الدفعة التالية دون تراكم المؤقتات.
  void _scheduleMore(int seconds) {
    _moreTimer?.cancel();
    _moreTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) _loadMore();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds <= 1) {
          _timer?.cancel();
          _remaining = Duration.zero;
          _submitByTime();
        } else {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  /// يُرسل الاختبار عند انتهاء الوقت: يحسب نتيجة ما أُجيب عليه حتى الآن.
  void _submitByTime() {
    _saveResult();
    setState(() => finished = true);
    _playFinish();
  }

  /// نهاية الكويز: هتاف جماهيري عند تجاوز عتبة 30%، وزئير استياء عند الاستبعاد.
  void _playFinish() {
    final pool = this.pool;
    if (pool == null || pool.isEmpty) {
      playSfx(Sfx.complete);
      return;
    }
    final pct = ((score / pool.length) * 100).round();
    playSfx(pct >= 30 ? Sfx.victory : Sfx.defeat);
  }

  void _select(int index) {
    if (answered) return;
    final pool = this.pool;
    if (pool == null) return;
    final ok = index == pool[current].correctIndex;
    setState(() {
      selectedIndex = index;
      answered = true;
      _answers[current] = ok;
      if (ok) score++;
    });
    // نغمة حكم فورية: رنين دافئ للصواب وهمهمة لطيفة للخطأ.
    playSfx(ok ? Sfx.success : Sfx.error);
  }

  void _next() {
    if (!answered) return;
    final pool = this.pool;
    if (pool == null) return;
    if (current == pool.length - 1) {
      // التوليد المتدرج: إن كان الاستكمال جارياً أو لم ينته بعد،
      // ننتظر الدفعة التالية بدل إنهاء الكويز على 10 أسئلة.
      if (widget.restLoader != null && !_exhausted) {
        setState(() => _waitingMore = true);
        if (!_moreLoading) _loadMore();
        return;
      }
      _saveResult();
      setState(() => finished = true);
      _playFinish();
    } else {
      // فحص الحظر الفوري: إذا كانت نسبة الإجابات الصحيحة الحالية أقل من 30%
      // ولا يمكن للمترشح بلوغ 30% حتى لو أجاب صحيحاً على ما تبقى.
      final answeredCount = current + 1;
      final maxPossible = score + (pool.length - answeredCount);
      final currentPct = ((score / answeredCount) * 100).round();
      final bestPossiblePct = ((maxPossible / pool.length) * 100).round();
      if (currentPct < 30 && bestPossiblePct < 30) {
        // استبعاد فوري — لا يمكن بلوغ 30% مهما أجاب على ما تبقى.
        _saveResult();
        setState(() {
          finished = true;
        });
        // استبعاد مؤكد — لا مجال للنجاح: بكاء الجماهير.
        playSfx(Sfx.defeat);
        return;
      }
      setState(() {
        current++;
        selectedIndex = null;
        answered = false;
      });
    }
  }

  String get _title =>
      widget.subAxisName ??
      widget.axisName ??
      widget.subjectFilter ??
      (widget.questionLoader != null ? 'كويز المحور الفرعي' : 'اختبار شامل');

  Future<void> _saveResult() async {
    final pool = this.pool;
    if (pool == null) return;
    final pct = ((score / pool.length) * 100).round();
    _lastPct = pct;
    final result = QuizResult(
      subject: widget.axisName ??
          widget.subjectFilter ??
          (widget.questionLoader != null ? 'كويز المحور الفرعي' : 'اختبار شامل'),
      score: score,
      total: pool.length,
      percentage: pct,
      date: DateTime.now(),
      testType: widget.testType,
      axis: widget.axisName,
      subAxis: widget.subAxisName,
    );
    widget.onFinished?.call(result);
    await ProgressService.saveResult(result);
  }

  void _restart() {
    if (widget.onFinished != null && (_lastPct ?? 0) < 30) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
                'لم تتجاوز الحد الأدنى (30%). يرجى العودة لمراجعة ملفات المحور قبل إعادة الاختبار بعد 3 ساعات.'),
            backgroundColor: AppColors.err,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      return;
    }
    setState(() {
      current = 0;
      score = 0;
      selectedIndex = null;
      answered = false;
      finished = false;
      _answers.clear();
      _remaining = widget.examDuration ?? Duration.zero;
    });
    if (widget.examDuration != null) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final pool = this.pool;
    if (pool == null || _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 18),
              Text(
                'جارٍ توليد الأسئلة من المحور…',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'قد تستغرق العملية لحظات',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    // ما زال التوليد جارياً ولم تصل أي دفعة بعد -> ننتظر ولا نُنهِ الكويز.
    if (pool.isEmpty && !_exhausted && widget.restLoader != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 18),
              Text(
                'جارٍ توليد الأسئلة من المحور…',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'سيبدأ العرض تلقائياً بمجرد جاهزية أول دفعة',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    // بنك الأسئلة فارغ لهذه المادة (المحتوى قيد الإعداد بعد)
    if (pool.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('الاختبار')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Text(
              widget.questionLoader != null
                  ? 'لا توجد ملفات مراجعة في هذا المحور بعد، وبالتالي لا يمكن توليد الأسئلة.\nأضف ملفات المحور أولاً ثم أعد المحاولة.'
                  : 'بنك الأسئلة لمادة "${widget.subjectFilter}" قيد الإعداد حالياً.\nجرّب الاختبار الشامل أو مادة أخرى.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.8),
            ),
          ),
        ),
      );
    }

    if (finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('النتيجة')),
        body: ResultsScreen(
          score: score,
          total: pool.length,
          onRestart: _restart,
          warning: (widget.failureNote != null && (_lastPct ?? 0) < 30)
              ? widget.failureNote
              : null,
        ),
      );
    }

    final item = pool[current];

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(
                current: current,
                total: pool.length,
                score: score,
                answers: List<bool?>.generate(
                    pool.length, (i) => _answers[i]),
                remaining: widget.examDuration != null ? _remaining : null),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _QuestionNumberBadge(number: current + 1),
                        const SizedBox(width: 10),
                        _SubjectTag(text: item.subject),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if ((item.situation ?? '').trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cream.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          item.situation!.trim(),
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.7,
                              color: AppColors.goldSoft),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(item.text,
                        style: AppTheme.displayFont(size: 18, weight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    ...List.generate(item.options.length, (i) {
                      return _OptionTile(
                        letter: const ['أ', 'ب', 'ج', 'د', 'هـ'][i],
                        text: item.options[i],
                        state: !answered
                            ? _OptionState.idle
                            : i == item.correctIndex
                                ? _OptionState.correct
                                : i == selectedIndex
                                    ? _OptionState.wrong
                                    : _OptionState.disabled,
                        onTap: () => _select(i),
                      );
                    }),
                    if (answered) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                              right: BorderSide(color: AppColors.gold, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.explanation,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.7,
                                    color: AppColors.goldSoft)),
                            if (item.source != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.menu_book_rounded,
                                      size: 15,
                                      color: AppColors.err),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'المصدر: ${item.source}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.err),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF06201F),
                    disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: answered && !_waitingMore ? _next : null,
                  child: _waitingMore
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF06201F)),
                            ),
                            SizedBox(width: 10),
                            Text('جاري تحضير بقية الأسئلة…',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                          ],
                        )
                      : Text(
                          current == pool.length - 1
                              ? 'إنهاء الاختبار'
                              : 'السؤال التالي',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatefulWidget {
  final int current;
  final int total;
  final int score;

  /// حالة كل سؤال: null لم يُجب، true صحيح، false خطأ.
  final List<bool?> answers;

  /// الوقت المتبقي في الاختبارات الموقّتة (null لغير الموقّتة).
  final Duration? remaining;
  const _ProgressHeader({
    required this.current,
    required this.total,
    required this.score,
    required this.answers,
    this.remaining,
  });

  @override
  State<_ProgressHeader> createState() => _ProgressHeaderState();
}

class _ProgressHeaderState extends State<_ProgressHeader> {
  final ScrollController _scroll = ScrollController();
  static const double _step = 28;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center());
  }

  @override
  void didUpdateWidget(covariant _ProgressHeader old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _center());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _center() {
    if (!_scroll.hasClients) return;
    final width = _scroll.position.viewportDimension;
    final target = (widget.current * _step - width / 2 + _step / 2)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  static String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inMinutes)}:${p(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.remaining;
    final low = rem != null && rem.inMinutes < 5;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.2))),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 26,
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemCount: widget.answers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, i) {
                final done = widget.answers[i];
                final isCurrent = i == widget.current;
                final color = done == true
                    ? AppColors.gold
                    : done == false
                        ? AppColors.err
                        : AppColors.cream.withValues(alpha: 0.12);
                final fg =
                    done == null ? AppColors.muted : const Color(0xFF06201F);
                return Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: AppColors.goldSoft, width: 2)
                        : null,
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: fg)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('السؤال ${widget.current + 1} من ${widget.total}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              if (rem != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (low ? AppColors.err : AppColors.gold)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 14,
                          color: low ? AppColors.err : AppColors.goldSoft),
                      const SizedBox(width: 5),
                      Text(
                        'متبقي: ${_fmt(rem)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: low ? AppColors.err : AppColors.goldSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Text('النقاط: ${widget.score}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionNumberBadge extends StatelessWidget {
  final int number;
  const _QuestionNumberBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.tag, size: 13, color: Color(0xFF06201F)),
          const SizedBox(width: 4),
          Text('$number',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF06201F))),
        ],
      ),
    );
  }
}

class _SubjectTag extends StatelessWidget {
  final String text;
  const _SubjectTag({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldSoft,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.bgDeep)),
    );
  }
}

enum _OptionState { idle, correct, wrong, disabled }

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color border = AppColors.gold.withValues(alpha: 0.25);
    Color bg = AppColors.bgCard;
    Color letterBg = AppColors.gold.withValues(alpha: 0.15);
    Color letterColor = AppColors.goldSoft;

    if (state == _OptionState.correct) {
      border = AppColors.quizOk;
      bg = AppColors.quizOk.withValues(alpha: 0.16);
      letterBg = AppColors.quizOk;
      letterColor = const Color(0xFF06203A);
    } else if (state == _OptionState.wrong) {
      border = AppColors.quizErr;
      bg = AppColors.quizErr.withValues(alpha: 0.15);
      letterBg = AppColors.quizErr;
      letterColor = Colors.white;
    }

    return Opacity(
      opacity: state == _OptionState.disabled ? 0.55 : 1,
      child: InkWell(
        onTap: state == _OptionState.idle ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: border,
              width: (state == _OptionState.correct ||
                      state == _OptionState.wrong)
                  ? 2.4
                  : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: letterBg, shape: BoxShape.circle),
                child: Text(letter,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: letterColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 14.5, color: AppColors.cream)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
