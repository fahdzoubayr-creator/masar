import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/services/session_service.dart';
import 'package:masar_app/core/widgets/page_transitions.dart';
import 'cosmic_intro.dart';
import 'tap_sound_stub.dart'
    if (dart.library.js_interop) 'tap_sound_web.dart';
import 'package:masar_app/features/branching/presentation/screens/branching_screen.dart';
import 'package:masar_app/features/home/presentation/screens/home_dashboard_screen.dart';
import 'package:masar_app/features/audio_room/presentation/screens/audio_room_screen.dart';
import 'package:masar_app/features/review/presentation/screens/review_space_screen.dart';
import 'package:masar_app/features/splash/presentation/splash_web_url_cleaner_stub.dart'
    if (dart.library.js_interop) 'package:masar_app/features/splash/presentation/splash_web_url_cleaner.dart';

class SplashScreen extends StatefulWidget {
  /// عند الرجوع إليها عبر زر رجوع (وليست أول شاشة عند الإقلاع)
  /// يُمنع التخطّي التلقائي حتى لا ينقلك للتسجيل/اللوحة مباشرة.
  final bool fromBack;
  const SplashScreen({super.key, this.fromBack = false});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // هل انتهينا من تحديد إن كانت المقدّمة الكونية ستُعرض؟
  bool _decided = false;
  // مشهد الانفجار الكوني يُعرض مرة واحدة فقط: أول افتتاح بعد التثبيت.
  bool _showIntro = false;
  // بوارة تؤجّل التنقل التلقائي حتى ينتهي المشهد الكوني.
  final Completer<void> _introPlayed = Completer<void>();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// يقرر إن كانت هذه أول جلسة بعد التثبيت ليُعرض مشهد الانفجار الكوني،
  /// ثم يشغّل منطق التخطّي التلقائي (بعد انتهاء المشهد إن وُجد).
  Future<void> _boot() async {
    if (!widget.fromBack) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final seen = await SessionService.isCosmicIntroSeen();
      if (!mounted) return;
      if (!seen && !reduceMotion) {
        // يُعلَّم العلم فوراً حتى لا يتكرر المشهد لو أُغلق التطبيق مفاجئاً.
        await SessionService.markCosmicIntroSeen();
        if (!mounted) return;
        setState(() {
          _decided = true;
          _showIntro = true;
        });
        _autoSkip();
        return;
      }
    }
    if (!mounted) return;
    setState(() => _decided = true);
    _introPlayed.complete();
    _autoSkip();
  }

  void _onIntroFinished() {
    if (!_introPlayed.isCompleted) _introPlayed.complete();
    if (mounted) setState(() => _showIntro = false);
  }

  Future<void> _autoSkip() async {
    await _introPlayed.future;
    if (widget.fromBack) return;
    // يبدأ التطبيق دائمًا من واجهة الترحيب ولا يقفز تلقائيًا إلى اللوحة.
    // الاستثناء الوحيد روابط القاعة العميقة (`?room=`) لأنها نية مشاركة صريحة.
    if ((Uri.base.queryParameters['room'] ?? '').trim().isNotEmpty) {
      await _goHomeOrRoom();
    }
  }

  void _startBranching() {
    // نقرة ضغط مسموعة فور اللمس ثم الانتقال — الصوت لا يعيق التنقل.
    playTapSound();
    Navigator.of(context).push(fadeRoute(const BranchingScreen()));
  }

  /// يتوجه إما إلى لوحة الرئيسية أو مباشرة إلى قاعة صوتية عبر رابط عميق
  /// (`?room=...`) يعيد توجيه الدخول إلى القاعة.
  Future<void> _goHomeOrRoom() async {
    final query = Uri.base.queryParameters;
    final roomId = (query['room'] ?? '').trim();
    if (roomId.isNotEmpty) {
      // استهلاك الرابط العميق مرة واحدة: يُحذف من شريط العنوان فوراً
      // حتى لا يعيد «واصل» دخول الجلسة في كل مرة.
      _clearDeepLinkQuery();
      final name = await SessionService.resolveUserName();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AudioRoomScreen(
            room: roomId,
            displayName: name,
            isCoordinator: false,
          ),
        ),
        (route) => false,
      );
      return;
    }
    // الرجوع من شاشة عرض الملف (viewer.html) إلى المحاور الفرعية مباشرة.
    final review = (query['review'] ?? '').trim();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
      (route) => false,
    );
    if (review.isNotEmpty) {
      _clearDeepLinkQuery();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReviewSpaceScreen()),
      );
    }
  }

  /// يزيل معاملات الرابط العميق (`?room=&code=`) من عنوان المتصفح عبر
  /// `history.replaceState` دون إعادة تحميل الصفحة (لا يعمل على المنصات الأخرى).
  void _clearDeepLinkQuery() {
    if (!kIsWeb) return;
    final clean = Uri.base.replace(queryParameters: {});
    clearDeepLinkQuery(clean.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (!_decided) {
      // فراغ داكن لحظة القرار — يمهّد بصرياً لبداية المشهد الكوني.
      return const ColoredBox(color: Color(0xFF04070E));
    }
    final body = Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/خلفية_الترحيب.jpg'),
            fit: BoxFit.cover,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xE611151B),
              Color(0xD90A2A2A),
              Color(0xE60A2A2A),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 2, 24, 22),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/bismillah.png',
                  height: 64,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(height: 14),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFFFFE9A8),
                      Color(0xFFF5C542),
                      Color(0xFFD4962A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: const Text(
                    'مرحباً بجميع الأستاذات والأساتذة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.3,
                        letterSpacing: 0.5),
                  ),
                ),
                const Spacer(flex: 4),
                const Text(
                  'فضاؤك الشامل للتحضير لمباريات وامتحانات المنظومة التربوية',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13, color: Colors.white, height: 1.6),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF06201F),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _startBranching,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('اختر مباراتك وابدأ التحضير',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14.5)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('معاً نحو النجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      );
    if (_showIntro) {
      // أول افتتاح: مشهد الانفجار الكوني يحتضن واجهة الترحيب كاملة.
      return CosmicIntro(
        onFinished: _onIntroFinished,
        child: Scaffold(body: body),
      );
    }
    return Scaffold(body: body);
  }
}
