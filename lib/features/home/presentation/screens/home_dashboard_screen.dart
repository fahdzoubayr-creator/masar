import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:masar_app/core/services/presence_service.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/widgets/page_transitions.dart';
import 'package:masar_app/features/branching/presentation/screens/branching_screen.dart';
import 'package:masar_app/features/home/presentation/screens/dashboard_spaces.dart';
import 'package:masar_app/features/splash/presentation/splash_screen.dart';

/// نموذج عنصر في شبكة لوحة التحكم
class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;

  /// بطاقة مميزة — تُبرز بخلفية ذهبية كاملة.
  final bool featured;

  /// عبارة «لعبة» حمراء فوق العنوان (وسم فضاء مميّز).
  final bool pill;

  /// فضاء غير جاهز بعد — يُعرض مقفلاً ولا يمكن الدخول إليه.
  final bool comingSoon;

  /// ملاحظة بارزة تظهر تحت الوصف بلون أحمر.
  final String? note;

  /// الفضاء المرتبط بهذه البطاقة.
  final DashboardSpace space;

  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.space,
    this.featured = false,
    this.comingSoon = false,
    this.pill = false,
    this.note,
  });
}

/// لوحة التحكم الرئيسية — تعرض كل فضاءات التكوين في شبكة واحدة.
///
/// تحت كل بطاقة يظهر عدد المستخدمين المتصلين الآن في الفضاء نفسه،
/// وتُحدَّث الأعداد دورياً من الخادم.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  // شريط علوي موحّد لكل البطاقات — درجات زيتية هادئة من هوية التطبيق.
  static const _headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E5F54), Color(0xFF12443C)],
  );

  // شريط ذهبي دافئ للبطاقة المميزة فقط.
  static const _featuredHeaderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA8842F), Color(0xFF6E5520)],
  );

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  /// أعداد الحاضرين الآن لكل فضاء (المفتاح = معرّف الفضاء).
  Map<String, int> _counts = const {};

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // نبضة حضور دورية تُبقي تسجيلنا حيّاً، مع استدعاء الخادم لأحدث الأعداد.
    _poll = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _refreshCounts(),
    );
    unawaited(_bootstrapPresence());
  }

  /// أول نبضة + قراءة الأعداد — لتظهر الشارات مباشرةً عند فتح اللوحة.
  Future<void> _bootstrapPresence() async {
    await PresenceService.start();
    if (!mounted) return;
    setState(() => _counts = PresenceService.counts);
  }

  @override
  void dispose() {
    _poll?.cancel();
    PresenceService.stop();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    final counts = await PresenceService.fetch();
    if (!mounted) return;
    setState(() => _counts = counts);
  }

  /// يسجّل دخول المستخدم في الفضاء، ويعيده إلى البهو عند خروجه.
  Future<void> _enterSpace(DashboardSpace space) async {
    await PresenceService.setSpace(space.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => space.build()),
    );
    if (!mounted) return;
    await PresenceService.setSpace(PresenceSpace.lobby);
    await _refreshCounts();
  }

  // البطاقتان الرئيسيتان (Hero) أولاً — أكثر ما يقصده الأستاذ عند الفتح.
  static const List<_DashboardItem> _items = [
    _DashboardItem(
      title: 'العدة المتكاملة للتحضير للامتحان المهني',
      subtitle: 'ملخصات شاملة بصيغة PDF',
      icon: Icons.auto_stories_rounded,
      space: DashboardSpace.review,
    ),
    _DashboardItem(
      title: 'بنك الأسئلة',
      subtitle: 'اختبر معارفك حسب المحاور',
      icon: Icons.gps_fixed_rounded,
      note: 'توليد تلقائي للأسئلة غير محدود',
      space: DashboardSpace.quiz,
    ),
    _DashboardItem(
      title: 'جواهر الكفاءة',
      subtitle: 'تحدّي المراحل — منافسة بين الزملاء',
      icon: Icons.sports_esports_rounded,
      pill: true,
      space: DashboardSpace.jawaaher,
    ),
    _DashboardItem(
      title: 'مؤشر التقدم',
      subtitle: 'لوحة قياس الأداء والإحصائيات',
      icon: Icons.bar_chart_rounded,
      space: DashboardSpace.history,
    ),
    _DashboardItem(
      title: 'خرائط ذهنية',
      subtitle: 'خطاطات بيداغوجية مركزة',
      icon: Icons.psychology_rounded,
      space: DashboardSpace.mindMaps,
    ),
    _DashboardItem(
      title: 'قاعات الجلسات',
      subtitle: 'دروس - تفاعل - مناقشات - بين الأساتذة',
      icon: Icons.mic_rounded,
      space: DashboardSpace.liveRoom,
    ),
  ];

  // لم تعد مطلوبة (كل البطاقة تُربط مباشرة بالفضاء عبر space.build)
  // البنيات احتفظت بها للتوافق التاريخي إن لزم الأمر، لكن غير مُستخدمة.

  Future<void> _logout(BuildContext context) async {
    await SessionService.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  void _goBack(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      fadeRoute(const BranchingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // الخلفية الموحدة تُقدَّم من main.dart — لا طبقة معتمة هنا.
        child: SafeArea(
          child: Column(
            children: [
              _DashboardHeader(
                onBack: () => _goBack(context),
                onLogout: () => _logout(context),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.98,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) => _DashboardCard(
                    item: _items[i],
                    liveCount: _counts[_items[i].space.id] ?? 0,
                    hasPresence: _counts.isNotEmpty,
                    onOpen: () => _enterSpace(_items[i].space),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شارة «المتصلون الآن» أسفل البطاقة — عدد المستخدمين الموجودين
/// في الفضاء نفسه، بنقطة نابضة توحي بالحيوية.
class _LiveBadge extends StatefulWidget {
  final int count;
  const _LiveBadge({required this.count});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// صياغة عربية سليمة للعدد (مفرد/مثنى/جمع).
  String _label(int n) {
    if (n <= 0) return 'لا أحد متصل الآن';
    if (n == 1) return 'متصل واحد الآن';
    if (n == 2) return 'متصلان الآن';
    if (n <= 10) return '$n متصلون الآن';
    return '$n متصلاً الآن';
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.count;
    final alive = n > 0;
    final dotColor = alive ? const Color(0xFF3ED598) : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dotColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: dotColor.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = alive ? _pulse.value : 0.0;
              return Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: alive
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.25 + 0.45 * t),
                            blurRadius: 3 + 4 * t,
                            spreadRadius: 0.5 + 1.2 * t,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            _label(n),
            style: GoogleFonts.tajawal(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: alive ? const Color(0xFF7FE7C0) : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onBack;
  const _DashboardHeader({required this.onLogout, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            // سهم رجوع: في RTL تنعكس arrow_back لتشير يمينًا (اتجاه العودة).
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.goldSoft, size: 18),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اختر فضاء التحضير مع احتراف',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ],
            ),
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded,
                color: AppColors.goldSoft, size: 19),
            tooltip: 'تسجيل الخروج',
          ),
          const SizedBox(width: 6),
          ClipOval(
            child: Image.asset(
              'assets/images/شعار التطبيق1.png',
              width: 46,
              height: 46,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final _DashboardItem item;

  /// عدد المتصلين الآن في الفضاء (0 = لا أحد).
  final int liveCount;

  /// هل وصلتنا أعداد من الخادم؟ (false = الخادم غير متاح فلا نُظهر الشارة)
  final bool hasPresence;

  /// يُستدعى عند فتح البطاقة.
  final Future<void> Function() onOpen;

  const _DashboardCard({
    required this.item,
    required this.liveCount,
    required this.hasPresence,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final featured = item.featured;
    final locked = item.comingSoon;
    return Opacity(
      opacity: locked ? 0.62 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            // البطاقة المميزة تحصل على توهج ذهبي كامل لإبرازها.
            color: featured
                ? AppColors.gold.withValues(alpha: 0.14)
                : AppColors.cream.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              // الفضاء غير الجاهز مقفل — لا فتح ولا استجابة للضغط.
              // القاعات الصوتية فضاء صامت تماماً: بلا مؤثرات إطلاقاً.
              onTap: locked
                  ? null
                  : () async {
                      // الفضاء غير الجاهز مقفل — لا فتح ولا استجابة للضغط.
                      // القاعات الصوتية فضاء صامت تماماً: بلا مؤثرات إطلاقاً.
                      if (item.space != DashboardSpace.liveRoom) {
                        playSfx(Sfx.select);
                      }
                      // تسجيل تلقائي عند أول دخول — يحفظ بيانات المستخدم
                      // لربطها بجميع البطاقات دون عرض واجهة التسجيل.
                      await SessionService.ensureRegistered();
                      if (!context.mounted) return;
                      await onOpen();
                    },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: featured
                        ? AppColors.gold.withValues(alpha: 0.55)
                        : AppColors.cream.withValues(alpha: 0.14),
                    width: featured ? 1.2 : 1,
                  ),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      gradient: featured
                          ? HomeDashboardScreen._featuredHeaderGradient
                          : HomeDashboardScreen._headerGradient,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        // شارة دائرية هادئة حول الأيقونة — لمسة احترافية موحّدة
                        // (بقيت في مكانها الأصلي لكل البطاقات بما فيها المميزة).
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.cream.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon,
                              color: AppColors.goldSoft, size: 21),
                        ),
                        const Spacer(),
                        if (locked)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.err.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded,
                                color: AppColors.err, size: 13),
                          )
                        else if (featured) ...[
                          // شارة «مميز» بخط غليظ أبيض وسط شعلة لهب متدرج —
                          // رمز الذروة والأهمية القصوى، مع هالة توهج دافئة.
                          SizedBox(
                            width: 48,
                            height: 46,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x73FF8A3C),
                                        blurRadius: 14,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Color(0xFFD2664F),
                                      Color(0xFFFF9A3C),
                                      AppColors.goldSoft,
                                    ],
                                  ).createShader(bounds),
                                  child: const Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 42,
                                      color: Colors.white),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text('مميز',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          height: 1,
                                          letterSpacing: 0.3,
                                          shadows: [
                                            Shadow(
                                              color: const Color(0xFF5C1A00)
                                                  .withValues(alpha: 0.55),
                                              blurRadius: 3,
                                              offset: const Offset(0, 0.5),
                                            ),
                                          ])),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: AppColors.cream.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios,
                                color: AppColors.goldSoft, size: 12),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      // عرض كامل إلزامي حتى يتمدد عمود النص على كامل البطاقة
                      // وإلا انكمش على عرض النص وبطل التوسيط بلا أثر.
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (item.pill) ...[
                              // وسم «لعبة» أحمر بارز فوق العنوان.
                              Text('لعبة',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.tajawal(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      height: 1.05,
                                      letterSpacing: 0.5,
                                      color: AppColors.err,
                                      shadows: const [
                                        Shadow(
                                          color: Color(0x33000000),
                                          blurRadius: 3,
                                          offset: Offset(0, 0.5),
                                        ),
                                      ])),
                              const SizedBox(height: 4),
                            ],
                            Text(item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.tajawal(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                    color: featured
                                        ? AppColors.goldSoft
                                        : AppColors.cream)),
                            const SizedBox(height: 5),
                            Text(item.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                    color:
                                        AppColors.cream.withValues(alpha: 0.75))),
                            if (item.note != null) ...[
                              const SizedBox(height: 6),
                              Text(item.note!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.tajawal(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                      color: AppColors.err)),
                            ],
                            // شارة الحضور: عدد المتصلين الآن في هذا الفضاء.
                            if (hasPresence) ...[
                              const SizedBox(height: 8),
                              _LiveBadge(count: liveCount),
                            ],
                            if (locked) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.err.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: AppColors.err
                                          .withValues(alpha: 0.55)),
                                ),
                                child: const Text('في طور الإعداد',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.err)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                 ],
               ),
             ),
           ),
         ),
       ),
     ),
   );
  }
}
