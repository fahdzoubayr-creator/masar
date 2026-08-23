import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/features/review/presentation/screens/review_space_screen.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_picker_screen.dart';
import 'package:masar_app/features/history/presentation/screens/history_screen.dart';
import 'package:masar_app/features/exams/presentation/screens/final_exams_screen.dart';
import 'package:masar_app/features/audio_room/presentation/screens/audio_room_lobby_screen.dart';
import 'package:masar_app/features/mindmaps/presentation/screens/mind_maps_screen.dart';
import 'package:masar_app/features/branching/presentation/screens/branching_screen.dart';
import 'package:masar_app/features/splash/presentation/splash_screen.dart';
import 'package:masar_app/core/widgets/page_transitions.dart';

/// نموذج عنصر في شبكة لوحة التحكم
class _DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;

  /// بطاقة مميزة — تُبرز بخلفية ذهبية كاملة (الامتحانات التجريبية).
  final bool featured;

  /// فضاء غير جاهز بعد — يُعرض مقفلاً ولا يمكن الدخول إليه.
  final bool comingSoon;
  final WidgetBuilder builder;
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.featured = false,
    this.comingSoon = false,
  });
}

/// لوحة التحكم الرئيسية — تعرض كل فضاءات التكوين في شبكة واحدة.
class HomeDashboardScreen extends StatelessWidget {
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

  // البطاقتان الرئيسيتان (Hero) أولاً — أكثر ما يقصده الأستاذ عند الفتح.
  static const List<_DashboardItem> _items = [
    _DashboardItem(
      title: 'العدة المتكاملة للتحضير للامتحان المهني',
      subtitle: 'ملخصات شاملة بصيغة PDF',
      icon: Icons.auto_stories_rounded,
      builder: _buildReviewSpace,
    ),
    _DashboardItem(
      title: 'بنك الأسئلة',
      subtitle: 'اختبر معارفك حسب المحاور',
      icon: Icons.gps_fixed_rounded,
      builder: _buildQuizPicker,
    ),
    _DashboardItem(
      title: 'الامتحانات التجريبية',
      subtitle: 'محاكاة للاختبار بمؤقت زمني',
      icon: Icons.timer_rounded,
      featured: true,
      builder: _buildFinalExams,
    ),
    _DashboardItem(
      title: 'مؤشر التقدم',
      subtitle: 'لوحة قياس الأداء والإحصائيات',
      icon: Icons.bar_chart_rounded,
      builder: _buildHistory,
    ),
    _DashboardItem(
      title: 'خرائط ذهنية',
      subtitle: 'خطاطات بيداغوجية مركزة',
      icon: Icons.psychology_rounded,
      comingSoon: true,
      builder: _buildMindMaps,
    ),
    _DashboardItem(
      title: 'قاعات الجلسات',
      subtitle: 'دروس - تفاعل - مناقشات - بين الأساتذة',
      icon: Icons.mic_rounded,
      builder: _buildLiveRoom,
    ),
  ];

  static Widget _buildReviewSpace(BuildContext context) =>
      const ReviewSpaceScreen();
  static Widget _buildQuizPicker(BuildContext context) =>
      const QuizPickerScreen();
  static Widget _buildHistory(BuildContext context) => const HistoryScreen();
  static Widget _buildFinalExams(BuildContext context) =>
      const FinalExamsScreen();
  static Widget _buildMindMaps(BuildContext context) => const MindMapsScreen();
  static Widget _buildLiveRoom(BuildContext context) =>
      const AudioRoomLobbyScreen();

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
                  itemBuilder: (context, i) => _DashboardCard(item: _items[i]),
                ),
              ),
            ],
          ),
        ),
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
            icon: const Icon(Icons.arrow_forward_ios_rounded,
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
  const _DashboardCard({required this.item});

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
              onTap: locked
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: item.builder),
                      ),
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
                        // شارة دائرية هادئة حول الأيقونة — لمسة احترافية موحّدة.
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
                        if (featured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color:
                                      AppColors.goldSoft.withValues(alpha: 0.6)),
                            ),
                            child: const Text('مميز',
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.goldSoft)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: locked
                                  ? AppColors.err.withValues(alpha: 0.18)
                                  : AppColors.cream.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                locked
                                    ? Icons.lock_rounded
                                    : Icons.arrow_forward_ios,
                                color: locked
                                    ? AppColors.err
                                    : AppColors.goldSoft,
                                size: locked ? 13 : 12),
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
