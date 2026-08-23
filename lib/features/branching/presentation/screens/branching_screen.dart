import 'package:flutter/material.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/widgets/page_transitions.dart';
import 'package:masar_app/features/auth/presentation/screens/dummy_auth_screen.dart';
import 'package:masar_app/features/splash/presentation/splash_screen.dart';

class _Slate {
  static const bgTop = Color(0xFF11151B);
  static const bgBottom = Color(0xFF1B232E);
  static const card = Color(0xFF232D3A);
  static const cardDim = Color(0xFF171E28);
  static const accent = Color(0xFF33D6C0);
  static const accentGlow = Color(0x4433D6C0);
  static const text = Color(0xFFF2F5F7);
  static const textMuted = Color(0xFF9AA7B5);
  static const border = Color(0xFF2A3442);
}

enum ExamBranch { inspection, management, competence, planning }

class _Exam {
  final ExamBranch branch;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  const _Exam(this.branch, this.title, this.subtitle, this.icon,
      {this.enabled = true});
}

const List<_Exam> _exams = [
  _Exam(ExamBranch.competence, 'امتحانات الكفاءة المهنية',
      'اختر السلك التعليمي وابدأ التحضير', Icons.assignment_outlined),
  _Exam(ExamBranch.management, 'سلك الإدارة التربوية',
      'اختر السلك الأصلي لتخصيص النماذج', Icons.account_balance_outlined,
      enabled: false),
  _Exam(ExamBranch.inspection, 'مباراة التفتيش التربوي',
      'تخصصّ حسب السلك والمادة', Icons.verified_user_outlined,
      enabled: false),
  _Exam(
      ExamBranch.planning,
      'مباراة التخطيط والتوجيه التربوي',
      'اختر المسلك (توجيه أو تخطيط) لتخصيص امتحانات الدخول',
      Icons.route_outlined,
      enabled: false),
];

class _PlanningTrack {
  final String title;
  final String subtitle;
  final IconData icon;
  const _PlanningTrack(this.title, this.subtitle, this.icon);
}

const List<_PlanningTrack> _planningTracks = [
  _PlanningTrack(
      'التوجيه التربوي',
      'امتحانات دخول مخصصة لمباراة المستشار في التوجيه',
      Icons.compass_calibration_outlined),
  _PlanningTrack('التخطيط التربوي',
      'امتحانات دخول مخصصة لمباراة التخطيط التربوي', Icons.fact_check_outlined),
];

class _LevelOption {
  final String key;
  final String title;
  final IconData icon;
  final bool enabled;
  const _LevelOption(this.key, this.title, this.icon, {this.enabled = true});
}

const List<_LevelOption> _competenceLevels = [
  _LevelOption('primary', 'التعليم الابتدائي', Icons.school_outlined),
  _LevelOption('middle', 'التعليم الثانوي الإعدادي', Icons.local_library_outlined,
      enabled: false),
  _LevelOption('high', 'التعليم الثانوي التأهيلي', Icons.account_balance_outlined,
      enabled: false),
];

const List<_LevelOption> _managementLevels = [
  _LevelOption('primary', 'التعليم الابتدائي', Icons.school_outlined),
  _LevelOption('middle', 'التعليم الإعدادي', Icons.local_library_outlined),
  _LevelOption(
      'high', 'التعليم الثانوي التأهيلي', Icons.account_balance_outlined),
];

class _SpecOption {
  final String title;
  final IconData icon;
  const _SpecOption(this.title, this.icon);
}

const List<_SpecOption> _inspectionSpecs = [
  _SpecOption('اللغة العربية', Icons.auto_stories_outlined),
  _SpecOption('الرياضيات', Icons.calculate_outlined),
  _SpecOption('الفيزياء والكيمياء', Icons.science_outlined),
  _SpecOption('علوم الحياة والأرض', Icons.eco_outlined),
  _SpecOption('الاجتماعيات', Icons.public_outlined),
  _SpecOption('الفرنسية', Icons.translate_outlined),
  _SpecOption('الإنجليزية', Icons.language_outlined),
];

class BranchingScreen extends StatefulWidget {
  const BranchingScreen({super.key});

  @override
  State<BranchingScreen> createState() => _BranchingScreenState();
}

class _BranchingScreenState extends State<BranchingScreen> {
  int _step = 1;
  ExamBranch? _exam;
  String? _selectedLabel;
  String? _inspectionLevel;
  bool _navigating = false;

  void _goBack() {
    if (_step == 2) {
      setState(() {
        _step = 1;
        _exam = null;
        _inspectionLevel = null;
        _selectedLabel = null;
      });
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const SplashScreen(fromBack: true)),
      (route) => false,
    );
  }

  Future<void> _tapCard(String label, Future<void> Function() action) async {
    playSfx(Sfx.select);
    if (_navigating) return;
    setState(() => _selectedLabel = label);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _navigating = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  Future<void> _goRegistration() async {
    final track = await SessionService.getTrack();
    if (!mounted) return;
    Navigator.of(context).push(
      fadeRoute(DummyAuthScreen(trackTitle: track)),
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: _Slate.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text('«$title» في طور الإعداد — سيتم تفعيلها قريباً',
                    style: const TextStyle(
                        fontSize: 13, color: _Slate.text)),
              ),
            ],
          ),
          backgroundColor: _Slate.card,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _selectExam(_Exam exam) {
    if (!exam.enabled) {
      _showComingSoon(exam.title);
      return Future.value();
    }
    return _tapCard(exam.title, () async {
      await SessionService.setTrack(exam.title);
      if (!mounted) return;
      setState(() {
        _exam = exam.branch;
        _step = 2;
        _selectedLabel = null;
      });
    });
  }

  Future<void> _selectCompetenceLevel(_LevelOption level) {
    if (!level.enabled) {
      _showComingSoon(level.title);
      return Future.value();
    }
    return _tapCard(level.title, () async {
      await SessionService.setLevel(level.key);
      await _goRegistration();
    });
  }

  Future<void> _selectInspectionLevel(_LevelOption level) {
    return _tapCard(level.title, () async {
      await SessionService.setLevel(level.key);
      if (level.key == 'primary') {
        await _goRegistration();
      } else {
        setState(() {
          _inspectionLevel = level.key;
          _selectedLabel = null;
        });
      }
    });
  }

  Future<void> _selectInspectionSpec(_SpecOption spec) {
    return _tapCard(spec.title, () async {
      await SessionService.setSpecialization(spec.title);
      await _goRegistration();
    });
  }

  Future<void> _selectManagementLevel(_LevelOption level) {
    return _tapCard(level.title, () async {
      await SessionService.setLevel(level.key);
      await _goRegistration();
    });
  }

  Future<void> _selectPlanningTrack(_PlanningTrack track) {
    return _tapCard(track.title, () async {
      await SessionService.setSpecialization(track.title);
      await _goRegistration();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // الخلفية الموحدة تُقدَّم من main.dart — لا طبقة معتمة هنا.
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProgressHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.02),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: _step == 1 ? _buildStep1() : _buildStep2(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _Slate.text, size: 18),
          tooltip: 'رجوع',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الخطوة $_step من 2',
                  style:
                      const TextStyle(fontSize: 11, color: _Slate.textMuted)),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _step == 1 ? 0.5 : 1.0,
                  minHeight: 5,
                  backgroundColor: _Slate.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(_Slate.accent),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _title(String title, [String? subtitle]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _Slate.text)),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: _Slate.textMuted, height: 1.5)),
        ],
      ],
    );
  }

  Widget _buildStep1() {
    return ListView(
      key: const ValueKey('step1'),
      padding: EdgeInsets.zero,
      children: [
        _title('اختر نوع المباراة',
            'حدّد المباراة المستهدفة لنخصّص لك مسار التحضير'),
        const SizedBox(height: 18),
        ..._exams.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _optionCard(
              icon: e.icon,
              title: e.title,
              subtitle: e.subtitle,
              badge: e.enabled ? null : 'في طور الإعداد',
              highlighted: _selectedLabel == e.title,
              onTap: () => _selectExam(e),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    switch (_exam) {
      case ExamBranch.competence:
        return _buildCompetenceBranch();
      case ExamBranch.inspection:
        return _buildInspectionBranch();
      case ExamBranch.management:
        return _buildManagementBranch();
      case ExamBranch.planning:
        return _buildPlanningBranch();
      case null:
        return _buildStep1();
    }
  }

  Widget _buildCompetenceBranch() {
    return ListView(
      key: const ValueKey('step2-competence'),
      padding: EdgeInsets.zero,
      children: [
        _title('اختر السلك التعليمي'),
        const SizedBox(height: 18),
        ..._competenceLevels.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _optionCard(
              icon: l.icon,
              title: l.title,
              badge: l.enabled ? null : 'في طور الإعداد',
              highlighted: _selectedLabel == l.title,
              onTap: () => _selectCompetenceLevel(l),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInspectionBranch() {
    if (_inspectionLevel == null) {
      return ListView(
        key: const ValueKey('step2-inspection-level'),
        padding: EdgeInsets.zero,
        children: [
          _title('اختر السلك والتخصص'),
          const SizedBox(height: 18),
          _optionCard(
            icon: Icons.school_outlined,
            title: 'التعليم الابتدائي',
            highlighted: _selectedLabel == 'التعليم الابتدائي',
            onTap: () => _selectInspectionLevel(const _LevelOption(
                'primary', 'التعليم الابتدائي', Icons.school_outlined)),
          ),
          const SizedBox(height: 13),
          _optionCard(
            icon: Icons.local_library_outlined,
            title: 'التعليم الثانوي (إعدادي وتأهيلي)',
            highlighted: _selectedLabel == 'التعليم الثانوي (إعدادي وتأهيلي)',
            onTap: () => _selectInspectionLevel(const _LevelOption(
                'secondary',
                'التعليم الثانوي (إعدادي وتأهيلي)',
                Icons.local_library_outlined)),
          ),
        ],
      );
    }
    return ListView(
      key: const ValueKey('step2-inspection-spec'),
      padding: EdgeInsets.zero,
      children: [
        _title('اختر التخصص', 'حدّد تخصصك للوصول إلى محتوى مخصص'),
        const SizedBox(height: 18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: _inspectionSpecs.length,
          itemBuilder: (context, i) => _specCard(_inspectionSpecs[i]),
        ),
      ],
    );
  }

  Widget _buildManagementBranch() {
    return ListView(
      key: const ValueKey('step2-management'),
      padding: EdgeInsets.zero,
      children: [
        _title('اختر السلك الحالي', 'اختياري — لتخصيص النماذج والمحتوى'),
        const SizedBox(height: 18),
        ..._managementLevels.map(
          (l) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _optionCard(
              icon: l.icon,
              title: l.title,
              highlighted: _selectedLabel == l.title,
              onTap: () => _selectManagementLevel(l),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _Slate.accent,
              side: const BorderSide(color: _Slate.accent, width: 1.3),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _tapCard('متابعة مباشر', _goRegistration),
            child: const Text('متابعة مباشر',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanningBranch() {
    return ListView(
      key: const ValueKey('step2-planning'),
      padding: EdgeInsets.zero,
      children: [
        _title('حدد المسلك المطلوب',
            'امتحانات الدخول (الكتابي والشفوي) مخصصة بحسب خيارك'),
        const SizedBox(height: 18),
        ..._planningTracks.map(
          (t) => Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _optionCard(
              icon: t.icon,
              title: t.title,
              subtitle: t.subtitle,
              highlighted: _selectedLabel == t.title,
              onTap: () => _selectPlanningTrack(t),
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    String? subtitle,
    String? badge,
    required VoidCallback onTap,
    required bool highlighted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: highlighted ? _Slate.card : _Slate.cardDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? _Slate.accent : _Slate.border,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? const [
                BoxShadow(
                    color: _Slate.accentGlow, blurRadius: 14, spreadRadius: 1),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _Slate.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _Slate.accent.withValues(alpha: 0.35), width: 1),
                  ),
                  child: Icon(icon, color: _Slate.accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _Slate.text)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w300,
                                color: _Slate.textMuted)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (badge != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _Slate.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _Slate.accent.withValues(alpha: 0.35),
                          width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.hourglass_bottom_rounded,
                            color: _Slate.accent, size: 12),
                        const SizedBox(width: 5),
                        Text(badge,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _Slate.accent)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.arrow_forward_ios,
                    color: _Slate.textMuted, size: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _specCard(_SpecOption spec) {
    final highlighted = _selectedLabel == spec.title;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: highlighted ? _Slate.card : _Slate.cardDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? _Slate.accent : _Slate.border,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? const [
                BoxShadow(
                    color: _Slate.accentGlow, blurRadius: 14, spreadRadius: 1),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectInspectionSpec(spec),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(spec.icon, color: _Slate.accent, size: 22),
                const SizedBox(height: 8),
                Text(
                  spec.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _Slate.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
