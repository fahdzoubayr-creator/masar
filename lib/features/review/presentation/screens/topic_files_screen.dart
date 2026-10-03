import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:masar_app/core/services/generated_quiz_service.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/question_repository.dart';
import 'package:masar_app/core/services/question_validator.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:masar_app/core/services/review_file_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_screen.dart';
import 'package:masar_app/features/review/presentation/screens/pdf_viewer_screen.dart';

/// شاشة قائمة ملفات PDF لمحور فرعي — تُفتح من صف المحور في فضاء المراجعة،
/// وتضم كويز المحور أسفل الملفات.
/// كويز مولّد من محتوى ملف واحد تحديداً — مستقل عن حالة بطاقة الكويز.
Future<void> _openFileQuiz(
  BuildContext context,
  ReviewPdf file,
  String folderTitle,
  String topicTitle,
) async {
  playSfx(Sfx.select);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: AppColors.gold),
            SizedBox(height: 14),
            Text('جاري توليد كويز من محتوى الملف…',
                style: TextStyle(color: AppColors.cream, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
  List<Question>? generated;
  try {
    generated = await GeneratedQuizService.fromPdf(
      file.assetPath,
      subject: topicTitle.isNotEmpty ? topicTitle : folderTitle,
      sourceName: file.displayName,
    );
  } catch (_) {
    generated = null;
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
  if (generated == null || generated.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.err,
        content: Text('تعذّر توليد الكويز من هذا الملف، حاول لاحقاً.',
            style: TextStyle(color: Colors.white))));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        questionLoader: () async => generated!,
        testType: 'كويز من محتوى الدرس',
        axisName: folderTitle,
        subAxisName: topicTitle.isNotEmpty ? topicTitle : file.displayName,
      ),
    ),
  );
}

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
                const SizedBox(height: 12),
                // زر فتح كل ملفات المحور في عارض PDF واحد (متسلسلة).
                if (files.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        playSfx(Sfx.select);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PdfViewerScreen(
                              assetPath: files.first.assetPath,
                              title: topicTitle,
                              assetPaths: files
                                  .map((f) => f.assetPath)
                                  .toList(growable: false),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_rounded,
                          color: AppColors.goldSoft, size: 18),
                      label: const Text('فتح كل الملفات'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.goldSoft,
                        side: const BorderSide(
                            color: AppColors.gold, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
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
                                    // كويز مولّد من محتوى هذا الملف تحديداً.
                                    IconButton(
                                      onPressed: () => _openFileQuiz(
                                          context, file, folderTitle, topicTitle),
                                      icon: const Icon(Icons.quiz_outlined,
                                          color: AppColors.goldSoft, size: 20),
                                      tooltip: 'كويز من هذا الملف',
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    ),
                                    // سهم تقدّم: chevron_right تنعكس في RTL فتشير يسارًا.
                                    const Icon(Icons.chevron_right_rounded,
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
            'ملفات هذا المحور في طور الإعداد\nوستُضاف قريباً',
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

    // ===== الحالة المشتركة بين التحميل الأول والاستكمال =====
    String? jobRef; // مهمة التوليد الجارية في الخلفية
    bool genFailed = false; // فشل التوليد => نكمل من البنك فقط
    final delivered = <String>{}; // ما استلمناه سابقاً، لتفادي التكرار
    var bankQueue = <Question>[]; // بنك احتياطي يكمل العدد عند الحاجة
    int bankCursor = 0; // موضع القراءة في طابور بنك الأسئلة
    var bankOffset = 0;
    const bankHead = 10; // أسئلة البنك التي تُعرض فوراً
    const totalTarget = 50;

    final subject = widget.topicTitle.isNotEmpty
        ? widget.topicTitle
        : widget.folderTitle;

    // ملفات المحور التي يُولَّد منها.
    var files = await ReviewFileService.loadFolderPdfs(
        widget.folderTitle,
        topic: widget.topicTitle);
    if (files.isEmpty) {
      files = await ReviewFileService.loadFolderPdfs(widget.folderTitle);
    }

    // بدء التوليد في الخلفية فوراً، دون أي انتظار.
    if (files.isNotEmpty && jobRef == null) {
      unawaited(() async {
        try {
          final start = await GeneratedQuizService.startProgressive(
            files.first.assetPath,
            subject: subject,
            sub: widget.topicTitle,
            sourceName: files.first.displayName,
          );
          jobRef = start.jobId;
          for (final q in start.first) {
            delivered.add(q.text.trim());
          }
        } catch (_) {
          genFailed = true;
        }
      }());
    } else if (files.isEmpty) {
      genFailed = true;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          questionLoader: () async {
            // ===== فتح فوري: أول 10 أسئلة من البنك =====
            var head = await QuestionGenerator.generateForFolder(
              widget.folderTitle,
              topic: widget.topicTitle,
              count: bankHead + 20,
            );
            if (head.length < bankHead) {
              final fuzzy =
                  await QuestionRepository.instance.loadQuestions(
                subject: subject,
              );
              final seen = <String>{...head.map((q) => q.text.trim())};
              for (final q in fuzzy) {
                if (head.length >= bankHead) break;
                if (seen.add(q.text.trim())) head.add(q);
              }
            }
            head = head
                .map(QuestionGenerator.withShuffledOptions)
                .take(bankHead)
                .toList();
            for (final q in head) {
              delivered.add(q.text.trim());
            }
            return head;
          },
          restLoader: () async {
            // لا نصل إلى الهدف أبداً قبل 50 سؤالاً.
            if (delivered.length >= totalTarget) return const <Question>[];

            // ===== 1) أسئلة مولَّدة، واحداً تلو الآخر =====
            if (!genFailed && jobRef != null && jobRef!.isNotEmpty) {
              final snap = await GeneratedQuizService.pollSnapshot(jobRef!);
              for (final q in snap) {
                if (delivered.length >= totalTarget) break;
                final key = q.text.trim();
                if (!delivered.add(key)) continue;
                if (QuestionValidator.filterValid([q]).isEmpty) continue;
                return <Question>[q]; // سؤال واحد => العدّاد يتحرّك
              }
              if (await GeneratedQuizService.jobWorking(jobRef!)) {
                await Future.delayed(const Duration(milliseconds: 700));
                return const <Question>[];
              }
            }

            // ===== 2) بنك الأسئلة: يملأ حتى reaches 50، بلا سقف بعدد واحد =====
            while (bankQueue.isEmpty) {
              if (delivered.length >= totalTarget) return const <Question>[];
              final need = totalTarget - delivered.length;
              bankQueue = await QuestionGenerator.generateForFolder(
                widget.folderTitle,
                topic: widget.topicTitle,
                count: need + 40,
              );
              // لا بنك متبقٍ بعد إعادة السحب => انتهى كل شيء.
              if (bankQueue.isEmpty) {
                if (jobRef == null || jobRef!.isEmpty) {
                  final fuzzy =
                      await QuestionRepository.instance.loadQuestions(
                    subject: subject,
                  );
                  bankQueue = fuzzy;
                }
                if (bankQueue.isEmpty) return const <Question>[];
                break;
              }
              bankOffset += 0;
            }

            // نأخذ السؤال التالي من الطابور (توزيع متنوّع: قفزات منتظمة).
            while (bankCursor < bankQueue.length) {
              if (delivered.length >= totalTarget) return const <Question>[];
              final q = bankQueue[bankCursor];
              bankCursor++;
              final key = q.text.trim();
              if (!delivered.add(key)) continue;
              if (QuestionValidator.filterValid([q]).isEmpty) continue;
              return <Question>[QuestionGenerator.withShuffledOptions(q)];
            }
            // استُهلك الطابور => نكمل من جديد في النداء القادم.
            bankQueue = [];
            return const <Question>[];
          },
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
            'إذا لم تحصل على 50% على الأقل في أسئلة هذا الكويز، سيتم منعك من إعادة المحاولة لمدة 3 ساعات.',
            style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6),
          ),
          const SizedBox(height: 10),
          // تذكير قبل بدء الكويز — بارز، بلون أحمر، في وسط الإطار.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.err.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.err.withValues(alpha: 0.55), width: 1.5),
            ),
            child: const Text(
              'هل أنت متأكد من مراجعة هذا المحور بشكل جيد؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFF8A73),
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                          ? 'أنت ممنوع من الكويز — راجع المحور ثم انتظر'
                          : 'أنت ممنوع من الكويز — راجع المحور · متبقي: $_remaining',
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
