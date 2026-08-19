import 'dart:ui';
import 'package:flutter/material.dart';
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
  final LinearGradient gradient;
  final WidgetBuilder builder;
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.builder,
  });
}

/// لوحة التحكم الرئيسية — تعرض كل فضاءات التكوين في شبكة واحدة.
class HomeDashboardScreen extends StatelessWidget {
  const HomeDashboardScreen({super.key});

  static const List<_DashboardItem> _items = [
    _DashboardItem(
      title: 'فضاء المراجعة والتحضير',
      subtitle: 'ملفات وملخصات PDF',
      icon: Icons.menu_book_rounded,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E6B6B), Color(0xFF134847)],
      ),
      builder: _buildReviewSpace,
    ),
    _DashboardItem(
      title: 'الكويزات والتدريبات',
      subtitle: 'أسئلة متداولة وشائعة حسب المادة',
      icon: Icons.quiz_rounded,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3D6E5A), Color(0xFF1B4B3C)],
      ),
      builder: _buildQuizPicker,
    ),
    _DashboardItem(
      title: 'أفضل نسبة إنجاز',
      subtitle: 'إحصائيات وتحليل',
      icon: Icons.emoji_events_rounded,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8A6F2F), Color(0xFF5C4A1E)],
      ),
      builder: _buildHistory,
    ),
    _DashboardItem(
      title: 'الاختبارات النهائية العامة',
      subtitle: 'نماذج شاملة بمؤقّت',
      icon: Icons.timer_rounded,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3D4E6E), Color(0xFF1E2B40)],
      ),
      builder: _buildFinalExams,
    ),
    _DashboardItem(
      title: 'الخطاطات الذهنية',
      subtitle: 'ملخصات بصرية',
      icon: Icons.hub_rounded,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6E4E8A), Color(0xFF40295C)],
      ),
      builder: _buildMindMaps,
    ),
    _DashboardItem(
      title: 'القاعات الصوتية',
      subtitle: 'جلسات مباشرة صوت وشات',
      icon: Icons.record_voice_over_rounded,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3F5B8A), Color(0xFF1E2F4A)],
      ),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgDeep, Color(0xFF0A2A2A)],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: AppColors.cream.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: item.builder),
            ),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.cream.withValues(alpha: 0.14), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    decoration: BoxDecoration(
                      gradient: item.gradient,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, color: AppColors.goldSoft, size: 22),
                        const Spacer(),
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
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.displayFont(
                                  size: 14, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(item.subtitle,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
