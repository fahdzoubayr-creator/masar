import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:masar_app/core/services/game_bank_loader.dart';
import 'package:masar_app/core/services/question_bank_loader.dart';
import 'package:masar_app/core/services/sfx/sfx.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/widgets/unified_background.dart';
import 'package:masar_app/features/splash/presentation/splash_screen.dart';

class RightScrollbarBehavior extends MaterialScrollBehavior {
  const RightScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    if (axisDirectionToAxis(details.direction) != Axis.vertical) return child;
    switch (getPlatform(context)) {
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        assert(details.controller != null);
        return Scrollbar(
          controller: details.controller,
          scrollbarOrientation: ScrollbarOrientation.right,
          child: child,
        );
      default:
        return child;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // تحميل بنوك الأسئلة من JSON — ملف game_challenges.json مُزيل من
  // الشجرة (9f0222f)، فإن غاب لا يمنع الإقلاع: بنك فارغ مثل GameBankLoader.
  try {
    await QuestionBankLoader.init();
  } catch (_) {}
  await GameBankLoader.init();
  // يُبقي شجرة الوصول (Semantics) مفعّلة دائماً — لإتاحة قارئات الشاشة
  // ولتمكين الفحص التلقائي للواجهة.
  SemanticsBinding.instance.ensureSemantics();
  // تحميل مسبق صامت للمؤثرات الصوتية (ويب) — لا يعطل الإقلاع.
  try {
    preloadSfx();
  } catch (_) {}
  runApp(const MasarApp());
}

class MasarApp extends StatelessWidget {
  const MasarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مسار Ehtiraf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      scrollBehavior: const RightScrollbarBehavior(),
      // دعم الكتابة من اليمين إلى اليسار لكامل التطبيق
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // على الشاشات الواسعة (المتصفح/سطح المكتب) يظهر التطبيق
      // بعرض هاتف ثابت في المنتصف بدلاً من التمدد على كامل الشاشة.
      // كما يُصغَّر حجم النصوص العام بنسبة 12% ليكون التصميم أكثر إحكاماً.
      builder: (context, child) {
        final scaledChild = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.88),
          ),
          child: child!,
        );
        final width = MediaQuery.sizeOf(context).width;
        if (width <= 600) return UnifiedBackground(child: scaledChild);
        return ColoredBox(
          color: const Color(0xFF081F1F),
          child: Center(
            child: SizedBox(
              width: 430,
              height: MediaQuery.sizeOf(context).height,
              child: UnifiedBackground(child: scaledChild),
            ),
          ),
        );
      },
      home: const SplashScreen(),
    );
  }
}
