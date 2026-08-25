import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'dart:math';

/// شاشة خوض مرحلة واحدة من مسار التحدي.
///
/// - أسئلة بنك المسار الحقيقية (10 لكل مرحلة).
/// - كشف فوري للإجابة الصحيحة/الخاطئة مع الشرح.
/// - نقاط = (صحيح × 100) + بونص سرعة، ونجوم حسب النسبة (50/70/90).
class QuizLevelPlayScreen extends StatefulWidget {
  final int levelNumber;
  final List<Question> questions;
  final void Function(int score, int timeSeconds, int stars) onCompleted;

  const QuizLevelPlayScreen({
    super.key,
    required this.levelNumber,
    required this.questions,
    required this.onCompleted,
  });

  @override
  State<QuizLevelPlayScreen> createState() => _QuizLevelPlayScreenState();
}

class _QuizLevelPlayScreenState extends State<QuizLevelPlayScreen> {
  int _index = 0;
  int _correctCount = 0;
  int? _selected;
  bool _revealed = false;
  late final Stopwatch _stopwatch;

  Question get _q => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
  }

  void _answer(int selectedIndex) {
    if (_revealed) return;
    final correct = selectedIndex == _q.correctIndex;
    playSfx(correct ? Sfx.success : Sfx.error);
    setState(() {
      _selected = selectedIndex;
      _revealed = true;
      if (correct) _correctCount++;
    });
    Timer(const Duration(milliseconds: 1400), _advance);
  }

  void _advance() {
    if (!mounted) return;
    if (_index < widget.questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _revealed = false;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    _stopwatch.stop();
    final seconds = max<int>(1, _stopwatch.elapsed.inSeconds);
    final percentage =
        (_correctCount / widget.questions.length) * 100;
    var stars = 0;
    if (percentage >= 90) {
      stars = 3;
    } else if (percentage >= 70) {
      stars = 2;
    } else if (percentage >= 50) {
      stars = 1;
    }
    final score = (_correctCount * 100) + max<int>(0, 100 - seconds);
    playSfx(stars > 0 ? Sfx.victory : Sfx.defeat);
    widget.onCompleted(score, seconds, stars);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        passed: stars > 0,
        stars: stars,
        score: score,
        correct: _correctCount,
        total: widget.questions.length,
        seconds: seconds,
        onRetry: () {
          Navigator.of(ctx).pop();
          setState(() {
            _index = 0;
            _correctCount = 0;
            _selected = null;
            _revealed = false;
          });
          _stopwatch
            ..reset()
            ..start();
        },
        onClose: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_index + (_revealed ? 1 : 0)) /
                      widget.questions.length,
                  minHeight: 5,
                  backgroundColor: AppColors.cream.withValues(alpha: 0.12),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.gold),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  if ((_q.situation ?? '').trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cream.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.25)),
                      ),
                      child: Text(_q.situation!.trim(),
                          style: GoogleFonts.tajawal(
                              fontSize: 12.5,
                              height: 1.7,
                              color: AppColors.cream.withValues(alpha: 0.85))),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(_q.text,
                      style: GoogleFonts.tajawal(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                          color: AppColors.cream)),
                  if (_revealed &&
                      _selected != _q.correctIndex &&
                      _q.explanation.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('التوضيح: ${_q.explanation.trim()}',
                        style: GoogleFonts.tajawal(
                            fontSize: 12,
                            height: 1.6,
                            color: AppColors.muted)),
                  ],
                  const SizedBox(height: 18),
                  ...List.generate(_q.options.length, (i) {
                    final isCorrect = i == _q.correctIndex;
                    final isPicked = i == _selected;
                    Color bg = AppColors.bgCard;
                    Color border =
                        AppColors.gold.withValues(alpha: 0.22);
                    Color text = AppColors.cream;
                    IconData? trailing;
                    if (_revealed && isCorrect) {
                      bg = AppColors.quizOk.withValues(alpha: 0.16);
                      border = AppColors.quizOk;
                      trailing = Icons.check_circle_rounded;
                    } else if (_revealed && isPicked && !isCorrect) {
                      bg = AppColors.quizErr.withValues(alpha: 0.14);
                      border = AppColors.quizErr;
                      trailing = Icons.cancel_rounded;
                    } else if (_revealed) {
                      text = AppColors.cream.withValues(alpha: 0.45);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Material(
                        color: bg,
                        borderRadius: BorderRadius.circular(13),
                        child: InkWell(
                          onTap: _revealed ? null : () => _answer(i),
                          borderRadius: BorderRadius.circular(13),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: border, width: 1.2),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(_q.options[i],
                                      style: GoogleFonts.tajawal(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          height: 1.5,
                                          color: text)),
                                ),
                                if (trailing != null)
                                  Icon(trailing,
                                      color: isCorrect
                                          ? AppColors.quizOk
                                          : AppColors.quizErr,
                                      size: 19),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.goldSoft, size: 20),
            tooltip: 'خروج',
          ),
          Expanded(
            child: Text('المرحلة ${widget.levelNumber}',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.goldSoft)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('${_index + 1}/${widget.questions.length}',
                style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.cream)),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final bool passed;
  final int stars;
  final int score;
  final int correct;
  final int total;
  final int seconds;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _ResultDialog({
    required this.passed,
    required this.stars,
    required this.score,
    required this.correct,
    required this.total,
    required this.seconds,
    required this.onRetry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgCard, AppColors.bgSurface],
          ),
          border: Border.all(
              color: passed
                  ? AppColors.gold.withValues(alpha: 0.55)
                  : AppColors.err.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(passed ? 'أحسنت! اجتزت المرحلة' : 'لم تجتز المرحلة',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: passed ? AppColors.goldSoft : AppColors.err)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final lit = i < stars;
                return Icon(Icons.star_rounded,
                    size: 38,
                    color: lit ? Colors.amber : Colors.white24);
              }),
            ),
            const SizedBox(height: 14),
            Text('$correct / $total إجابات صحيحة',
                style: GoogleFonts.tajawal(
                    fontSize: 13, color: AppColors.cream)),
            const SizedBox(height: 4),
            Text('النقاط: $score · الوقت: $seconds ثانية',
                style: GoogleFonts.tajawal(
                    fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.goldSoft,
                      side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('إعادة المحاولة',
                        style: GoogleFonts.tajawal(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    borderRadius: BorderRadius.circular(12),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.goldSoft]),
                      ),
                      child: InkWell(
                        onTap: onClose,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 11),
                          child: Center(
                            child: Text('متابعة',
                                style: GoogleFonts.tajawal(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF06201F))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
