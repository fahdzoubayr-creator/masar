import 'package:flutter/material.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/models/topic_attempt.dart';
import 'package:masar_app/core/services/question_generator.dart';
import 'package:masar_app/core/services/quiz_attempt_service.dart';
import 'package:masar_app/core/services/review_file_service.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/widgets/app_logo_header.dart';
import 'package:masar_app/features/review/data/review_content.dart';
import 'package:masar_app/features/review/presentation/screens/best_scores_screen.dart';
import 'package:masar_app/features/review/presentation/screens/topic_files_screen.dart';

class ReviewSpaceScreen extends StatefulWidget {
  const ReviewSpaceScreen({super.key});

  @override
  State<ReviewSpaceScreen> createState() => _ReviewSpaceScreenState();
}

class _ReviewSpaceScreenState extends State<ReviewSpaceScreen> {
  bool _loading = true;
  bool _primaryContent = true;
  String _trackTitle = '';

  @override
  void initState() {
    super.initState();
    _loadTrack();
  }

  Future<void> _loadTrack() async {
    final track = await SessionService.getTrack();
    final spec = await SessionService.getSpecialization();
    if (!mounted) return;
    setState(() {
      _trackTitle = (track == null || track.isEmpty)
          ? ''
          : (spec != null && spec.isNotEmpty)
              ? '$track — $spec'
              : track;
      _primaryContent = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // الخلفية الموحدة تُقدَّم من main.dart — لا طبقة معتمة هنا.
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
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
                AppLogoHeader(
                  title: 'اختر فضاء التحضير',
                  subtitle: _trackTitle.isEmpty
                      ? 'اختر فضاءً للتحضير واطلع على ملفات وملخصات PDF'
                      : _trackTitle,
                  logoSize: 64,
                ),
                if (!_primaryContent) ...[
                  const SizedBox(height: 12),
                  _buildComingSoonBanner(),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.goldSoft))
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (final space in reviewSpaces) ...[
                              _SpaceCard(
                                  space: space, placeholder: !_primaryContent),
                              const SizedBox(height: 16),
                            ],
                            const _BestScoresCard(),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hourglass_top_rounded,
              color: AppColors.goldSoft, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'المحتوى في طور الإعداد وسيكون متوفراً قريباً',
              style: TextStyle(fontSize: 12, color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة «أفضل نسبة إنجاز» — تُفتح شاشة سجل كل المحاولات.
class _BestScoresCard extends StatefulWidget {
  const _BestScoresCard();

  @override
  State<_BestScoresCard> createState() => _BestScoresCardState();
}

class _BestScoresCardState extends State<_BestScoresCard> {
  Map<String, TopicAttempt>? attempts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final map = await QuizAttemptService.loadAll();
    if (!mounted) return;
    setState(() => attempts = map);
  }

  @override
  Widget build(BuildContext context) {
    final data = attempts;
    final taken = data == null
        ? <TopicAttempt>[]
        : data.values.where((a) => a.attempts > 0).toList();
    final best =
        taken.fold<int>(0, (acc, a) => a.bestPercentage > acc ? a.bestPercentage : acc);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BestScoresScreen()),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8A6F2F), Color(0xFF5C4A1E)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded,
                  color: AppColors.goldSoft, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أفضل نسبة إنجاز',
                      style: AppTheme.displayFont(
                          size: 14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    taken.isEmpty
                        ? 'سجل محاولاتك في كويزات المحاور الفرعية'
                        : 'أفضل نسبة: $best% · ${taken.length} كويز · '
                            '${taken.fold<int>(0, (acc, a) => acc + a.attempts)} محاولة',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left_rounded,
                color: AppColors.goldSoft, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SpaceCard extends StatefulWidget {
  final ReviewSpace space;
  final bool placeholder;
  const _SpaceCard({required this.space, this.placeholder = false});

  @override
  State<_SpaceCard> createState() => _SpaceCardState();
}

class _SpaceCardState extends State<_SpaceCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final space = widget.space;
    final isFolderSpace = space.folders.isNotEmpty;
    final folderCount = space.folders.length;
    final countText = widget.placeholder
        ? 'المحتوى قيد الإعداد'
        : (isFolderSpace
            ? (folderCount == 1
                ? '1 مجلد'
                : '$folderCount مجلدات')
            : '${space.topics.length} ملفات');
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Ink(
                decoration: BoxDecoration(gradient: space.gradient),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.cream.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(space.icon, color: AppColors.goldSoft, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            space.title,
                            style: AppTheme.displayFont(
                                size: 14.5, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            space.subtitle,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                color: AppColors.muted),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.cream.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(countText,
                                style: const TextStyle(
                                    fontSize: 9.5, color: AppColors.goldSoft)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.goldSoft, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _open
                  ? Container(
                      width: double.infinity,
                      color: AppColors.bgSurface,
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                      child: isFolderSpace
                          ? Column(
                              children: [
                                for (int i = 0; i < space.folders.length; i++)
                                  _FolderAccordion(
                                    folder: space.folders[i],
                                    placeholder: widget.placeholder,
                                    orderIndex: i + 1,
                                  ),
                              ],
                            )
                          : widget.placeholder
                              ? const _EmptyFolder()
                              : Column(
                                  children: [
                                    for (int i = 0; i < space.topics.length; i++)
                                      _TopicRow(
                                          topic: space.topics[i],
                                          folder: null,
                                          orderIndex: i + 1),
                                  ],
                                ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderAccordion extends StatefulWidget {
  final ReviewFolder folder;
  final bool placeholder;
  final int? orderIndex;
  const _FolderAccordion({required this.folder, this.placeholder = false, this.orderIndex});

  @override
  State<_FolderAccordion> createState() => _FolderAccordionState();
}

class _FolderAccordionState extends State<_FolderAccordion> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final hasTopics = folder.topics.isNotEmpty;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(12),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                if (widget.orderIndex != null)
                  SizedBox(
                    width: 26,
                    child: Text(
                      '#${widget.orderIndex}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldSoft.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                if (widget.orderIndex != null) const SizedBox(width: 4),
                Icon(folder.icon, size: 20, color: AppColors.goldSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    folder.title,
                    style:
                        AppTheme.displayFont(size: 14, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cream.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                      widget.placeholder
                          ? 'قيد الإعداد'
                          : '${folder.topics.length}',
                      style: const TextStyle(
                          fontSize: 10.5, color: AppColors.muted)),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.muted, size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: widget.placeholder
                      ? const _EmptyFolder()
                      : hasTopics
                          ? Column(
                              children: [
                                for (int i = 0; i < folder.topics.length; i++)
                                  _TopicRow(
                                      topic: folder.topics[i],
                                      folder: folder,
                                      orderIndex: i + 1),
                              ],
                            )
                          : const _EmptyFolder(),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _EmptyFolder extends StatelessWidget {
  const _EmptyFolder();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.goldSoft.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.hourglass_bottom_rounded,
                color: AppColors.goldSoft, size: 24),
          ),
          const SizedBox(height: 12),
          const Text(
            'المحتوى في طور الإعداد\nوسيكون متوفراً قريباً',
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

/// صف المحور الفرعي: ملف المراجعة + كويز المحور أسفله.
class _TopicRow extends StatefulWidget {
  final ReviewTopic topic;
  final ReviewFolder? folder;
  final int? orderIndex;
  const _TopicRow({required this.topic, this.folder, this.orderIndex});

  @override
  State<_TopicRow> createState() => _TopicRowState();
}

class _TopicRowState extends State<_TopicRow> {
  int? _pdfCount;
  int? _quizCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folder = widget.folder;
    if (folder == null) {
      final bank = QuestionBankLoader.questionsFor(widget.topic.title);
      if (!mounted) return;
      setState(() {
        _quizCount = (bank == null || bank.isEmpty) ? 0 : bank.length;
      });
      return;
    }
    final pdfs = await ReviewFileService.loadFolderPdfs(folder.title,
        topic: widget.topic.title);
    final quizFiles = await ReviewFileService.countFolderQuizFiles(
        folder.title,
        topic: widget.topic.title);
    // مواضيع البنوك الخالصة (بلا ملفات نصية) تبقى كويزاتها متاحة
    // عبر بنوك الأسئلة المدمجة — تُحتسب كأسئلة محور أيضاً.
    final bankCount =
        QuestionGenerator.bankCountFor(folder.title, topic: widget.topic.title);
    if (!mounted) return;
    setState(() {
      _pdfCount = pdfs.length;
      _quizCount = quizFiles + bankCount;
    });
  }

  Future<void> _open(BuildContext context) async {
    final folder = widget.folder;
    final pdfs = folder == null
        ? const <ReviewPdf>[]
        : await ReviewFileService.loadFolderPdfs(folder.title,
            topic: widget.topic.title);
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TopicFilesScreen(
          folderTitle: folder == null ? '' : folder.title,
          topicTitle: widget.topic.title,
          files: pdfs,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFiles = _pdfCount != null && _pdfCount! > 0;
    final hasQuiz = _quizCount != null && _quizCount! > 0;
    final ready = hasFiles || hasQuiz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                if (widget.orderIndex != null)
                  SizedBox(
                    width: 28,
                    child: Text(
                      '#${widget.orderIndex}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.goldSoft.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                if (widget.orderIndex != null) const SizedBox(width: 6),
                Icon(
                    hasQuiz
                        ? Icons.quiz_rounded
                        : (hasFiles
                            ? Icons.insert_drive_file_outlined
                            : Icons.lock_outline),
                    size: 20,
                    color: ready ? AppColors.goldSoft : AppColors.muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.topic.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: ready ? AppColors.cream : AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (hasFiles)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.goldSoft.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$_pdfCount ملفات',
                        style: const TextStyle(
                            fontSize: 9.5, color: AppColors.goldSoft)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


