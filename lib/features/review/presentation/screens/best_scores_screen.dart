import 'package:flutter/material.dart';
import 'package:masar_app/core/models/quiz_result.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:masar_app/core/services/progress_service.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/features/review/data/review_content.dart';

/// ملف أفضل نسبة — يُسجَّل فيه كل محاولات المستخدم في كويزات
/// المحاور الفرعية والاختبارات النهائية والكويزات التدريبية للمواد:
/// أفضل نسبة، عدد المحاولات، والحظر (3 ساعات) عند الفشل.
class BestScoresScreen extends StatefulWidget {
  const BestScoresScreen({super.key});

  @override
  State<BestScoresScreen> createState() => _BestScoresScreenState();
}

class _BestScoresScreenState extends State<BestScoresScreen> {
  Map<String, TopicAttempt>? attempts;
  List<QuizResult>? results;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await QuizAttemptService.loadAll();
    final r = await ProgressService.loadResults();
    if (!mounted) return;
    setState(() {
      attempts = a;
      results = r;
    });
  }

  /// يجمع نتائج الكويزات التدريبية (quiz_results_v1) لكل مادة في
  /// [TopicAttempt] اصطناعي يعرض أفضل نسبة وتاريخ المحاولات.
  Map<String, TopicAttempt> _subjectGroups(List<QuizResult> results) {
    final groups = <String, TopicAttempt>{};
    for (final r in results) {
      final cur = groups[r.subject];
      final history = [
        ...?cur?.history,
        {
          'percentage': r.percentage,
          'score': r.score,
          'total': r.total,
          'date': r.date.toIso8601String(),
        },
      ];
      groups[r.subject] = TopicAttempt(
        bestPercentage: cur == null
            ? r.percentage
            : r.percentage > cur.bestPercentage
                ? r.percentage
                : cur.bestPercentage,
        attempts: history.length,
        lockedUntil: null,
        history: history,
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أفضل نسبة إنجاز')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bgDeep.withValues(alpha: 0.80),
              const Color(0xFF0A2A2A).withValues(alpha: 0.85),
            ],
          ),
        ),
        child: attempts == null || results == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.goldSoft))
            : _buildBody(attempts!, results!),
      ),
    );
  }

  Widget _buildBody(Map<String, TopicAttempt> data, List<QuizResult> results) {
    final taken = data.values.where((a) => a.attempts > 0).toList();
    final subjectGroups = _subjectGroups(results);
    final best = taken.fold<int>(
      0,
      (acc, a) => a.bestPercentage > acc ? a.bestPercentage : acc,
    );
    final bestOverall = subjectGroups.values.fold<int>(
      best,
      (acc, a) => a.bestPercentage > acc ? a.bestPercentage : acc,
    );
    final totalAttempts = taken.fold<int>(0, (acc, a) => acc + a.attempts) +
        results.length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              _SummaryItem(
                  icon: Icons.assignment_outlined,
                  label: 'اختبارات مجرّبة',
                  value: '${taken.length + subjectGroups.length}'),
              _SummaryItem(
                  icon: Icons.emoji_events_outlined,
                  label: 'أفضل نسبة',
                  value: '$bestOverall%'),
              _SummaryItem(
                  icon: Icons.insights_outlined,
                  label: 'محاولات',
                  value: '$totalAttempts'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (taken.isEmpty && subjectGroups.isEmpty)
                const _EmptyState()
              else ...[
                if (subjectGroups.isNotEmpty) ..._buildSubjectRows(subjectGroups),
                ..._buildFolders(data),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSubjectRows(Map<String, TopicAttempt> groups) {
    final list = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text('اختبارات المواد والتدريبات',
            style: AppTheme.displayFont(size: 13, weight: FontWeight.w700)),
      ),
    ];
    for (final entry in groups.entries) {
      list.add(_TopicScoreRow(title: entry.key, attempt: entry.value));
    }
    return list;
  }

  List<Widget> _buildFolders(Map<String, TopicAttempt> data) {
    final list = <Widget>[];
    for (final space in reviewSpaces) {
      for (final folder in space.folders) {
        final rows = <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(folder.title,
                style: AppTheme.displayFont(size: 13, weight: FontWeight.w700)),
          ),
        ];
        for (final topic in folder.topics) {
          rows.add(_TopicScoreRow(
            title: topic.title,
            attempt: data[topicQuizId(folder, topic)],
          ));
        }
        list.addAll(rows);
      }
    }
    return list;
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.goldSoft, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: AppTheme.displayFont(
                  size: 17, weight: FontWeight.w800, color: AppColors.goldSoft)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TopicScoreRow extends StatefulWidget {
  final String title;
  final TopicAttempt? attempt;
  const _TopicScoreRow({required this.title, required this.attempt});

  @override
  State<_TopicScoreRow> createState() => _TopicScoreRowState();
}

class _TopicScoreRowState extends State<_TopicScoreRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final attempt = widget.attempt;
    final locked = QuizAttemptService.isLocked(attempt);
    final has = attempt != null && attempt.attempts > 0;

    final Color statusColor = locked
        ? AppColors.err
        : (attempt != null && attempt.bestPercentage >= 80)
            ? AppColors.ok
            : (attempt != null && attempt.bestPercentage >= 30)
                ? AppColors.gold
                : AppColors.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: locked
                ? AppColors.err.withValues(alpha: 0.4)
                : AppColors.gold.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: has ? () => setState(() => _open = !_open) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(locked ? Icons.lock_rounded : Icons.quiz_rounded,
                      size: 18,
                      color: locked ? AppColors.err : AppColors.goldSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontSize: 12.5, color: AppColors.cream)),
                  ),
                  if (!has)
                    const Text('لم تُجرَ بعد',
                        style:
                            TextStyle(fontSize: 10.5, color: AppColors.muted))
                  else if (locked)
                    const Text('ممنوع 3 ساعات',
                        style: TextStyle(fontSize: 10.5, color: AppColors.err))
                  else ...[
                    Text('أفضل: ${attempt.bestPercentage}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor)),
                    const SizedBox(width: 10),
                    Text('${attempt.attempts} محاولة',
                        style: const TextStyle(
                            fontSize: 10.5, color: AppColors.muted)),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _open && has
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Column(
                      children: [
                        const Divider(color: AppColors.cream),
                        ...attempt.history.reversed.map((h) {
                          final pct = h['percentage'] as int? ?? 0;
                          final d = h['date'] as String?;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Icon(pct >= 30
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                    size: 15,
                                    color: pct >= 30
                                        ? AppColors.ok
                                        : AppColors.err),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    d == null ? 'محاولة' : _formatDate(d),
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted),
                                  ),
                                ),
                                Text('$pct%',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: pct >= 30
                                            ? AppColors.ok
                                            : AppColors.err)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return 'محاولة';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${p(d.month)}/${p(d.day)} ${p(d.hour)}:${p(d.minute)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.muted),
          SizedBox(height: 16),
          Text('لا توجد محاولات مسجلة بعد',
              style: TextStyle(color: AppColors.muted)),
          SizedBox(height: 8),
          Text('أنهِ كويز أي محور فرعي وسيُحفظ سجل محاولاتك هنا تلقائياً',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.6)),
        ],
      ),
    );
  }
}
