import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/models/quiz_result.dart';
import 'package:masar_app/core/services/progress_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<QuizResult>? results;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await ProgressService.loadResults();
    if (!mounted) return;
    setState(() => results = list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل النتائج')),
      body: results == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : results!.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history, size: 56, color: AppColors.muted),
                        const SizedBox(height: 16),
                        const Text('لا توجد نتائج محفوظة بعد',
                            style: TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 8),
                        const Text('أنهِ أي اختبار وسيُحفظ هنا تلقائياً',
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.gold, width: 1.5),
                            foregroundColor: AppColors.goldSoft,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100)),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: const Text('العودة للرئيسية'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _StatsCard(results: results!),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                        itemCount: _groups.length,
                        itemBuilder: (context, i) => _ResultGroupCard(group: _groups[i]),
                      ),
                    ),
                  ],
                ),
    );
  }

  List<_ResultGroup> get _groups {
    final map = <String, _ResultGroup>{};
    for (final r in results!) {
      final key = '${_testTypeOf(r)}\u0000${_axisOf(r)}\u0000${_subAxisOf(r) ?? ''}';
      map.putIfAbsent(key, () => _ResultGroup.fromResult(r));
      map[key]!.add(r);
    }
    final list = map.values.toList()
      ..sort((a, b) => (b.lastDate ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.lastDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return list;
  }

  static String _testTypeOf(QuizResult r) =>
      r.testType ?? (r.subject == 'كويز المحور الفرعي' ? 'كويز المحور الفرعي' : 'اختبار تدريبي');

  static String _axisOf(QuizResult r) => r.axis ?? r.subject;

  static String? _subAxisOf(QuizResult r) => r.subAxis;
}

class _ResultGroup {
  final String displayName;
  final String testType;
  final String axis;
  final String? subAxis;
  final List<QuizResult> attempts = [];
  DateTime? lastDate;

  _ResultGroup.fromResult(QuizResult r)
      : displayName = r.subAxis ?? r.axis ?? r.subject,
        testType = _HistoryScreenState._testTypeOf(r),
        axis = _HistoryScreenState._axisOf(r),
        subAxis = r.subAxis;

  void add(QuizResult r) {
    attempts.add(r);
    final d = lastDate;
    if (d == null || r.date.isAfter(d)) lastDate = r.date;
  }

  int get bestPercentage {
    int best = 0;
    for (final a in attempts) {
      if (a.percentage > best) best = a.percentage;
    }
    return best;
  }

  int get exclusionCount => attempts.where((a) => a.percentage < 50).length;
}

class _StatsCard extends StatelessWidget {
  final List<QuizResult> results;
  const _StatsCard({required this.results});

  @override
  Widget build(BuildContext context) {
    int best = 0;
    int exclusions = 0;
    for (final r in results) {
      if (r.percentage > best) best = r.percentage;
      if (r.percentage < 50) exclusions++;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(22, 16, 22, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 1.5),
      ),
      child: Row(
        children: [
          _StatItem(label: 'اختبارات', value: '${results.length}', icon: Icons.assignment_outlined),
          _StatItem(label: 'أفضل نسبة', value: '$best%', icon: Icons.emoji_events_outlined),
          _StatItem(label: 'استبعادات', value: '$exclusions', icon: Icons.lock_clock_outlined),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatItem({required this.label, required this.value, required this.icon});

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

class _ResultGroupCard extends StatefulWidget {
  final _ResultGroup group;
  const _ResultGroupCard({required this.group});

  @override
  State<_ResultGroupCard> createState() => _ResultGroupCardState();
}

class _ResultGroupCardState extends State<_ResultGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final lastPct = g.attempts.first.percentage;
    final color = lastPct >= 80
        ? AppColors.ok
        : lastPct >= 50
            ? AppColors.gold
            : AppColors.err;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18), width: 1.5),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle),
                        child: Text('${g.bestPercentage}%',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.displayName,
                                style: AppTheme.displayFont(
                                    size: 14, weight: FontWeight.w700)),
                            const SizedBox(height: 3),
                            _InfoChip(
                                icon: Icons.category_outlined,
                                text: 'نوع الاختبار: ${g.testType}'),
                            const SizedBox(height: 2),
                            _InfoChip(
                                icon: Icons.menu_book_outlined,
                                text: 'المحور: ${g.axis}'),
                          ],
                        ),
                      ),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppColors.muted),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _MiniStat(label: 'عدد المحاولات', value: '${g.attempts.length}'),
                      _MiniStat(label: 'النسبة', value: '${g.bestPercentage}%'),
                      _MiniStat(label: 'الاستبعادات (3 ساعات)', value: '${g.exclusionCount}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, thickness: 1, color: AppColors.gold.withValues(alpha: 0.12)),
            ...g.attempts.map((a) => _AttemptRow(attempt: a)),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTheme.displayFont(
                  size: 15, weight: FontWeight.w800, color: AppColors.goldSoft)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _AttemptRow extends StatelessWidget {
  final QuizResult attempt;
  const _AttemptRow({required this.attempt});

  @override
  Widget build(BuildContext context) {
    final color = attempt.percentage >= 80
        ? AppColors.ok
        : attempt.percentage >= 50
            ? AppColors.gold
            : AppColors.err;
    final excluded = attempt.percentage < 50;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Text('${attempt.percentage}%',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${attempt.score}/${attempt.total}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.cream)),
                const SizedBox(height: 2),
                Text(_formatDate(attempt.date),
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ),
          if (excluded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.err.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.err.withValues(alpha: 0.4)),
              ),
              child: const Text('استبعاد 3 ساعات',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.err)),
            )
          else
            const Text('ناجح',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.ok)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${pad(d.month)}/${pad(d.day)} ${pad(d.hour)}:${pad(d.minute)}';
  }
}
