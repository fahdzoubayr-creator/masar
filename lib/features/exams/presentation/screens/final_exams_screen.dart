import 'dart:async';

import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:masar_app/core/services/exam_question_service.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_screen.dart';

/// الاختبارات النهائية العامة — نماذج اختبارات شاملة بمؤقّت (70 سؤالاً).
///
/// كل نموذج:
///  - يتكوّن من 70 سؤالاً بالضبط (من بنك الأسئلة الشائعة + البنك الثابت).
///  - يُخاض بمؤقّت (60 دقيقة) مع عدّاد تنازلي وإرسال تلقائي عند انتهاء الوقت.
///  - من يحصل على أقل من 50% يُمنع من إعادة الاختبار لمدة 3 ساعات.
class FinalExamsScreen extends StatefulWidget {
  const FinalExamsScreen({super.key});

  @override
  State<FinalExamsScreen> createState() => _FinalExamsScreenState();
}

class _FinalExamsScreenState extends State<FinalExamsScreen> {
  static const List<_ExamOption> _options = [
    _ExamOption(
      quizId: 'الاختبار النهائي الشامل',
      title: 'الاختبار النهائي الشامل',
      subjectFilter: 'الاختبار النهائي الشامل',
      description: '70 سؤالاً من جميع المواد',
      icon: Icons.auto_awesome_rounded,
      comprehensive: true,
    ),
    _ExamOption(
      quizId: 'الاختبار النهائي: علوم التربية والبيداغوجيا',
      title: 'علوم التربية والبيداغوجيا',
      subjectFilter: 'علوم التربية والبيداغوجيا',
      description: '70 سؤالاً',
      icon: Icons.school_outlined,
    ),
    _ExamOption(
      quizId: 'الاختبار النهائي: اللغة العربية',
      title: 'اللغة العربية',
      subjectFilter: 'اللغة العربية',
      description: '70 سؤالاً',
      icon: Icons.menu_book_outlined,
    ),
    _ExamOption(
      quizId: 'الاختبار النهائي: اللغة الفرنسية',
      title: 'اللغة الفرنسية',
      subjectFilter: 'الفرنسية',
      description: '70 سؤالاً',
      icon: Icons.translate_outlined,
    ),
    _ExamOption(
      quizId: 'الاختبار النهائي: الرياضيات',
      title: 'الرياضيات',
      subjectFilter: 'الرياضيات',
      description: '70 سؤالاً',
      icon: Icons.calculate_outlined,
    ),
    _ExamOption(
      quizId: 'الاختبار النهائي: التشريع المدرسي والإداري',
      title: 'التشريع المدرسي والإداري',
      subjectFilter: 'التشريع المدرسي والإداري',
      description: '70 سؤالاً',
      icon: Icons.account_balance_outlined,
    ),
    _ExamOption(
      quizId: 'الاختبار النهائي: النشاط العلمي',
      title: 'النشاط العلمي',
      subjectFilter: 'النشاط العلمي',
      description: '70 سؤالاً',
      icon: Icons.biotech_outlined,
    ),
  ];

  Map<String, TopicAttempt>? _attempts;
  Timer? _timer;

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
    final attempts = await QuizAttemptService.loadAll();
    if (!mounted) return;
    setState(() => _attempts = attempts);
    _syncTimer();
  }

  void _syncTimer() {
    _timer?.cancel();
    final anyLocked = _options.any((o) =>
        QuizAttemptService.isLocked(_attempts?[o.quizId]));
    if (!anyLocked) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _openExam(BuildContext context, _ExamOption option) async {
    playSfx(Sfx.select);
    final locked = QuizAttemptService.isLocked(_attempts?[option.quizId]);
    if (locked) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          subjectFilter: option.subjectFilter,
          questionLoader: option.comprehensive
              ? ExamQuestionService.buildComprehensiveExam
              : () => ExamQuestionService.buildExam(option.subjectFilter!),
          examDuration: ExamQuestionService.examDuration,
          testType: 'الاختبارات العامة',
          axisName: option.title,
          onFinished: (result) =>
              QuizAttemptService.record(option.quizId, result),
          failureNote:
              'لم تحصل على 50% على الأقل في الاختبار النهائي — تم منعك من إعادة هذا الاختبار لمدة 3 ساعات.\nارجع إلى المراجعة أولاً.',
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
    return Scaffold(
      appBar: AppBar(title: const Text('الاختبارات النهائية العامة')),
      body: SafeArea(
        child: _attempts == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _ExamCard(
                  option: _options[i],
                  attempt: _attempts![_options[i].quizId],
                  onTap: () => _openExam(context, _options[i]),
                ),
              ),
      ),
    );
  }
}

class _ExamOption {
  final String quizId;
  final String title;
  final String? subjectFilter;
  final String description;
  final IconData icon;
  final bool comprehensive;
  const _ExamOption({
    required this.quizId,
    required this.title,
    this.subjectFilter,
    required this.description,
    required this.icon,
    this.comprehensive = false,
  });
}

class _ExamCard extends StatelessWidget {
  final _ExamOption option;
  final TopicAttempt? attempt;
  final VoidCallback onTap;
  const _ExamCard({
    required this.option,
    required this.attempt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = QuizAttemptService.isLocked(attempt);
    final remaining = QuizAttemptService.remainingLock(attempt);
    final hasAttempt = attempt != null && attempt!.attempts > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: locked
              ? AppColors.err.withValues(alpha: 0.45)
              : AppColors.gold.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.goldSoft.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(option.icon, color: AppColors.goldSoft, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        style: AppTheme.displayFont(
                            size: 14, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(option.description,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              if (hasAttempt && !locked) ...[
                Text('أفضل نسبة: ${attempt!.bestPercentage}%',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.goldSoft)),
                const SizedBox(width: 8),
                Text('${attempt!.attempts} محاولة',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
              SizedBox(width: 5),
              Text('المدة: 60 دقيقة · 70 سؤالاً',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          if (locked)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      remaining == null
                          ? 'أنت ممنوع من هذا الاختبار — ارجع إلى المراجعة'
                          : 'أنت ممنوع من هذا الاختبار — ارجع إلى المراجعة · متبقي: ${_FinalExamsScreenState._fmt(remaining)}',
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
                onPressed: onTap,
                child: const Text('ابدأ الاختبار',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ),
        ],
      ),
    );
  }
}
