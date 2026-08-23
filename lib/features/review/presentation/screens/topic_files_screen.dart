import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:masar_app/core/services/review_file_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_screen.dart';
import 'package:masar_app/features/review/presentation/screens/pdf_viewer_screen.dart';

/// شاشة قائمة ملفات PDF لمحور فرعي — تُفتح من صف المحور في فضاء المراجعة،
/// وتضم كويز المحور أسفل الملفات.
class TopicFilesScreen extends StatelessWidget {
  final String folderTitle;
  final String topicTitle;
  final List<ReviewPdf> files;

  const TopicFilesScreen({
    super.key,
    required this.folderTitle,
    required this.topicTitle,
    required this.files,
  });

  String _fileName(ReviewPdf file) => file.displayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // الخلفية الموحدة تُقدَّم من main.dart — لا طبقة معتمة هنا.
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppColors.goldSoft, size: 18),
                    tooltip: 'رجوع',
                    constraints:
                        const BoxConstraints(minWidth: 44, minHeight: 44),
                  ),
                ),
                const SizedBox(height: 4),
                Text(folderTitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(topicTitle,
                    style: AppTheme.displayFont(
                        size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(files.isEmpty
                    ? 'لا توجد ملفات مراجعة بعد'
                    : '${files.length} ملفات للمراجعة',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.goldSoft)),
                const SizedBox(height: 16),
                Expanded(
                  child: files.isEmpty
                      ? const _EmptyFilesState()
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: files.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final file = files[i];
                            return InkWell(
                              onTap: () {
                                playSfx(Sfx.select);
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewerScreen(
                                      assetPath: file.assetPath,
                                      title: _fileName(file),
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Ink(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.bgCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.18)),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '#${i + 1}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.goldSoft
                                              .withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.goldSoft
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                          Icons.picture_as_pdf_rounded,
                                          color: AppColors.goldSoft, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _fileName(file),
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.cream,
                                            height: 1.4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_left_rounded,
                                        color: AppColors.muted, size: 22),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 14),
                TopicQuizCard(folderTitle: folderTitle, topicTitle: topicTitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// حالة «لا ملفات بعد» داخل شاشة المحور.
class _EmptyFilesState extends StatelessWidget {
  const _EmptyFilesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.goldSoft.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.folder_off_outlined,
                color: AppColors.goldSoft, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            'ملفات هذا المحور في طور الإعداد\nوسيتم إضافتها قريباً',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة كويز المحور الفرعي — أسفل قائمة الملفات في شاشة المحور،
/// مع ملاحظة الحظر 3 ساعات عند الفشل، أفضل نسبة، وعدّاد تنازلي أثناء الحظر.
class TopicQuizCard extends StatefulWidget {
  final String folderTitle;
  final String topicTitle;
  const TopicQuizCard({
    super.key,
    required this.folderTitle,
    required this.topicTitle,
  });

  @override
  State<TopicQuizCard> createState() => _TopicQuizCardState();
}

class _TopicQuizCardState extends State<TopicQuizCard> {
  TopicAttempt? _attempt;
  bool _loading = true;
  Timer? _timer;
  String _remaining = '';

  String get _quizId => '${widget.folderTitle} › ${widget.topicTitle}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final attempt = await QuizAttemptService.load(_quizId);
    if (!mounted) return;
    setState(() {
      _attempt = attempt;
      _loading = false;
    });
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    final remaining = QuizAttemptService.remainingLock(_attempt);
    if (remaining != null) {
      setState(() => _remaining = _fmt(remaining));
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        final r = QuizAttemptService.remainingLock(_attempt);
        if (r == null) {
          _timer?.cancel();
          setState(() => _remaining = '');
        } else {
          setState(() => _remaining = _fmt(r));
        }
      });
    } else {
      setState(() => _remaining = '');
    }
  }

  Future<void> _openQuiz(BuildContext context) async {
    final locked = QuizAttemptService.isLocked(_attempt);
    if (locked) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questionLoader: () => QuestionGenerator.generateForFolder(
              widget.folderTitle,
              topic: widget.topicTitle),
          testType: 'كويز المحور الفرعي',
          axisName: widget.folderTitle,
          subAxisName: widget.topicTitle,
          onFinished: (result) => QuizAttemptService.record(_quizId, result),
          failureNote:
              'لم تحصل على 50% على الأقل — تم منعك من إعادة هذا الكويز لمدة 3 ساعات.\nارجع إلى المراجعة أولاً.',
        ),
      ),
    );
    await _load();
  }

  static String _fmt(Duration d) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(d.inHours)}:${p(d.inMinutes % 60)}:${p(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final locked = QuizAttemptService.isLocked(_attempt);
    final hasAttempt = _attempt != null && _attempt!.attempts > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: locked
                ? AppColors.err.withValues(alpha: 0.45)
                : AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_rounded, size: 20, color: AppColors.goldSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text('كويز هذا المحور الفرعي',
                    style: AppTheme.displayFont(
                        size: 13, weight: FontWeight.w700)),
              ),
              if (hasAttempt && !locked) ...[
                Text('أفضل نسبة: ${_attempt!.bestPercentage}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldSoft)),
                const SizedBox(width: 8),
                Text('${_attempt!.attempts} محاولة',
                    style:
                        const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'إذا لم تحصل على 50% على الأقل في أسئلة هذا الكويز، ستمنع من إعادة المحاولة لمدة 3 ساعات — ارجع إلى المراجعة أولاً.',
            style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.goldSoft)))
          else if (locked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.err.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.err.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded,
                      color: AppColors.err, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _remaining.isEmpty
                          ? 'أنت ممنوع من الكويز — ارجع إلى المراجعة'
                          : 'أنت ممنوع من الكويز — ارجع إلى المراجعة · متبقي: $_remaining',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.err, height: 1.5),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF06201F),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _openQuiz(context),
                child: const Text('ابدأ الكويز',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
        ],
      ),
    );
  }
}
