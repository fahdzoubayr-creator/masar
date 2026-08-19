import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:masar_app/features/review/presentation/widgets/zoom_controls_overlay.dart';

void main() {
  testWidgets('ZoomControlsOverlay يعرض أزرار التكبير والنسبة الحالية', (tester) async {
    var zoomIn = 0;
    var zoomOut = 0;
    var reset = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ZoomControlsOverlay(
                zoomRatio: 1.5,
                onZoomIn: () => zoomIn++,
                onZoomOut: () => zoomOut++,
                onReset: () => reset++,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('150%'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.tap(find.byIcon(Icons.remove_rounded));
    await tester.tap(find.byIcon(Icons.restart_alt_rounded));
    expect(zoomIn, 1);
    expect(zoomOut, 1);
    expect(reset, 1);
  });
}
