import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:masar_app/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('شاشة الترحيب تظهر ثم زر بدء التحضير', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MasarApp());
    await tester.pump();

    expect(find.textContaining('مرحباً بجميع الأستاذات والأساتذة'), findsOneWidget);
    expect(find.textContaining('اختر مباراتك وابدأ التحضير'), findsOneWidget);
  });
}
