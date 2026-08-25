import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/models/question.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:masar_app/core/services/generated_quiz_service.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/question_repository.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:masar_app/core/services/review_file_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_screen.dart';
import 'package:masar_app/features/review/presentation/screens/pdf_viewer_screen.dart';

/// Ø´Ø§Ø´Ø© Ù‚Ø§Ø¦Ù…Ø© Ù…Ù„ÙØ§Øª PDF Ù„Ù…Ø­ÙˆØ± ÙØ±Ø¹ÙŠ â€” ØªÙÙØªØ­ Ù…Ù† ØµÙ Ø§Ù„Ù…Ø­ÙˆØ± ÙÙŠ ÙØ¶Ø§Ø¡ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©ØŒ
/// ÙˆØªØ¶Ù… ÙƒÙˆÙŠØ² Ø§Ù„Ù…Ø­ÙˆØ± Ø£Ø³ÙÙ„ Ø§Ù„Ù…Ù„ÙØ§Øª.
/// ÙƒÙˆÙŠØ² Ù…ÙˆÙ„Ù‘Ø¯ Ù…Ù† Ù…Ø­ØªÙˆÙ‰ Ù…Ù„Ù ÙˆØ§Ø­Ø¯ ØªØ­Ø¯ÙŠØ¯Ø§Ù‹ â€” Ù…Ø³ØªÙ‚Ù„ Ø¹Ù† Ø­Ø§Ù„Ø© Ø¨Ø·Ø§Ù‚Ø© Ø§Ù„ÙƒÙˆÙŠØ².
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
            Text('Ø¬Ø§Ø±ÙŠ ØªÙˆÙ„ÙŠØ¯ ÙƒÙˆÙŠØ² Ù…Ù† Ù…Ø­ØªÙˆÙ‰ Ø§Ù„Ù…Ù„Ùâ€¦',
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
        content: Text('ØªØ¹Ø°Ù‘Ø± ØªÙˆÙ„ÙŠØ¯ Ø§Ù„ÙƒÙˆÙŠØ² Ù…Ù† Ù‡Ø°Ø§ Ø§Ù„Ù…Ù„ÙØŒ Ø­Ø§ÙˆÙ„ Ù„Ø§Ø­Ù‚Ø§Ù‹.',
            style: TextStyle(color: Colors.white))));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => QuizScreen(
        questionLoader: () async => generated!,
        testType: 'ÙƒÙˆÙŠØ² Ù…Ù† Ù…Ø­ØªÙˆÙ‰ Ø§Ù„Ø¯Ø±Ø³',
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
        // Ø§Ù„Ø®Ù„ÙÙŠØ© Ø§Ù„Ù…ÙˆØ­Ø¯Ø© ØªÙÙ‚Ø¯ÙŽÙ‘Ù… Ù…Ù† main.dart â€” Ù„Ø§ Ø·Ø¨Ù‚Ø© Ù…Ø¹ØªÙ…Ø© Ù‡Ù†Ø§.
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
                    tooltip: 'Ø±Ø¬ÙˆØ¹',
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
                    ? 'Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ù„ÙØ§Øª Ù…Ø±Ø§Ø¬Ø¹Ø© Ø¨Ø¹Ø¯'
                    : '${files.length} Ù…Ù„ÙØ§Øª Ù„Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©',
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
                                    // ÙƒÙˆÙŠØ² Ù…ÙˆÙ„Ù‘Ø¯ Ù…Ù† Ù…Ø­ØªÙˆÙ‰ Ù‡Ø°Ø§ Ø§Ù„Ù…Ù„Ù ØªØ­Ø¯ÙŠØ¯Ø§Ù‹.
                                    IconButton(
                                      onPressed: () => _openFileQuiz(
                                          context, file, folderTitle, topicTitle),
                                      icon: const Icon(Icons.quiz_outlined,
                                          color: AppColors.goldSoft, size: 20),
                                      tooltip: 'ÙƒÙˆÙŠØ² Ù…Ù† Ù‡Ø°Ø§ Ø§Ù„Ù…Ù„Ù',
                                      constraints: const BoxConstraints(
                                          minWidth: 36, minHeight: 36),
                                    ),
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

/// Ø­Ø§Ù„Ø© Â«Ù„Ø§ Ù…Ù„ÙØ§Øª Ø¨Ø¹Ø¯Â» Ø¯Ø§Ø®Ù„ Ø´Ø§Ø´Ø© Ø§Ù„Ù…Ø­ÙˆØ±.
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
            'Ù…Ù„ÙØ§Øª Ù‡Ø°Ø§ Ø§Ù„Ù…Ø­ÙˆØ± ÙÙŠ Ø·ÙˆØ± Ø§Ù„Ø¥Ø¹Ø¯Ø§Ø¯\nÙˆØ³ÙŠØªÙ… Ø¥Ø¶Ø§ÙØªÙ‡Ø§ Ù‚Ø±ÙŠØ¨Ø§Ù‹',
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

/// Ø¨Ø·Ø§Ù‚Ø© ÙƒÙˆÙŠØ² Ø§Ù„Ù…Ø­ÙˆØ± Ø§Ù„ÙØ±Ø¹ÙŠ â€” Ø£Ø³ÙÙ„ Ù‚Ø§Ø¦Ù…Ø© Ø§Ù„Ù…Ù„ÙØ§Øª ÙÙŠ Ø´Ø§Ø´Ø© Ø§Ù„Ù…Ø­ÙˆØ±ØŒ
/// Ù…Ø¹ Ù…Ù„Ø§Ø­Ø¸Ø© Ø§Ù„Ø­Ø¸Ø± 3 Ø³Ø§Ø¹Ø§Øª Ø¹Ù†Ø¯ Ø§Ù„ÙØ´Ù„ØŒ Ø£ÙØ¶Ù„ Ù†Ø³Ø¨Ø©ØŒ ÙˆØ¹Ø¯Ù‘Ø§Ø¯ ØªÙ†Ø§Ø²Ù„ÙŠ Ø£Ø«Ù†Ø§Ø¡ Ø§Ù„Ø­Ø¸Ø±.
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

  String get _quizId => '${widget.folderTitle} â€º ${widget.topicTitle}';

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
          questionLoader: () async {
            final bankQs = await QuestionGenerator.generateForFolder(
                widget.folderTitle,
                topic: widget.topicTitle);
            if (bankQs.isNotEmpty) return bankQs;
            // Ù…Ø·Ø§Ø¨Ù‚Ø© Ø¨Ù†ÙƒÙŠØ© Ù…Ø±Ù†Ø©: ÙŠÙ„ØªÙ‚Ø· Ø¨Ù†ÙˆÙƒØ§Ù‹ Ù…Ø«Ù„ Â«Ù…Ø¤Ø³Ø³Ø§Øª Ø§Ù„Ø±ÙŠØ§Ø¯Ø© â€” Ù…Ù‚Ø§Ø±Ø¨Ø©â€¦Â»
            final fuzzy =
                await QuestionRepository.instance.loadQuestions(
              subject: widget.topicTitle.isNotEmpty
                  ? widget.topicTitle
                  : widget.folderTitle,
            );
            if (fuzzy.length >= 20) {
              fuzzy.shuffle();
              return fuzzy.take(70).toList();
            }
            // Ù„Ø§ Ø¨Ù†Ùƒ Ù„Ù‡Ø°Ø§ Ø§Ù„Ù…Ø­ÙˆØ±ØŸ ÙˆÙ„Ù‘Ø¯ Ø§Ù„ÙƒÙˆÙŠØ² Ù…Ù† Ù…Ù„ÙØ§Øª Ø§Ù„Ù…Ø­ÙˆØ± Ù†ÙØ³Ù‡Ø§.
            var files = await ReviewFileService.loadFolderPdfs(
                widget.folderTitle,
                topic: widget.topicTitle);
            if (files.isEmpty) {
              files =
                  await ReviewFileService.loadFolderPdfs(widget.folderTitle);
            }
            if (files.isEmpty) return const <Question>[];
            return GeneratedQuizService.fromPdfs(
              files.map((f) => f.assetPath).toList(),
              subject: widget.topicTitle.isNotEmpty
                  ? widget.topicTitle
                  : widget.folderTitle,
            );
          },          testType: 'ÙƒÙˆÙŠØ² Ø§Ù„Ù…Ø­ÙˆØ± Ø§Ù„ÙØ±Ø¹ÙŠ',
          axisName: widget.folderTitle,
          subAxisName: widget.topicTitle,
          onFinished: (result) => QuizAttemptService.record(_quizId, result),
          failureNote:
              'Ù„Ù… ØªØ­ØµÙ„ Ø¹Ù„Ù‰ 50% Ø¹Ù„Ù‰ Ø§Ù„Ø£Ù‚Ù„ â€” ØªÙ… Ù…Ù†Ø¹Ùƒ Ù…Ù† Ø¥Ø¹Ø§Ø¯Ø© Ù‡Ø°Ø§ Ø§Ù„ÙƒÙˆÙŠØ² Ù„Ù…Ø¯Ø© 3 Ø³Ø§Ø¹Ø§Øª.\nØ§Ø±Ø¬Ø¹ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø© Ø£ÙˆÙ„Ø§Ù‹.',
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
                child: Text('ÙƒÙˆÙŠØ² Ù‡Ø°Ø§ Ø§Ù„Ù…Ø­ÙˆØ± Ø§Ù„ÙØ±Ø¹ÙŠ',
                    style: AppTheme.displayFont(
                        size: 13, weight: FontWeight.w700)),
              ),
              if (hasAttempt && !locked) ...[
                Text('Ø£ÙØ¶Ù„ Ù†Ø³Ø¨Ø©: ${_attempt!.bestPercentage}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldSoft)),
                const SizedBox(width: 8),
                Text('${_attempt!.attempts} Ù…Ø­Ø§ÙˆÙ„Ø©',
                    style:
                        const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ø¥Ø°Ø§ Ù„Ù… ØªØ­ØµÙ„ Ø¹Ù„Ù‰ 50% Ø¹Ù„Ù‰ Ø§Ù„Ø£Ù‚Ù„ ÙÙŠ Ø£Ø³Ø¦Ù„Ø© Ù‡Ø°Ø§ Ø§Ù„ÙƒÙˆÙŠØ²ØŒ Ø³ØªÙ…Ù†Ø¹ Ù…Ù† Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø© Ù„Ù…Ø¯Ø© 3 Ø³Ø§Ø¹Ø§Øª â€” Ø§Ø±Ø¬Ø¹ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø© Ø£ÙˆÙ„Ø§Ù‹.',
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
                          ? 'Ø£Ù†Øª Ù…Ù…Ù†ÙˆØ¹ Ù…Ù† Ø§Ù„ÙƒÙˆÙŠØ² â€” Ø§Ø±Ø¬Ø¹ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©'
                          : 'Ø£Ù†Øª Ù…Ù…Ù†ÙˆØ¹ Ù…Ù† Ø§Ù„ÙƒÙˆÙŠØ² â€” Ø§Ø±Ø¬Ø¹ Ø¥Ù„Ù‰ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø© Â· Ù…ØªØ¨Ù‚ÙŠ: $_remaining',
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
                child: const Text('Ø§Ø¨Ø¯Ø£ Ø§Ù„ÙƒÙˆÙŠØ²',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
        ],
      ),
    );
  }
}
