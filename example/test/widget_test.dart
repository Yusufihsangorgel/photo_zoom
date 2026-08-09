import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom_example/anchored_zoom_page.dart';
import 'package:photo_zoom_example/main.dart';

void main() {
  testWidgets('the grid opens the gallery at the tapped photo', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.byType(GridPage), findsOneWidget);

    await tester.tap(find.byType(GestureDetector).first);
    // Fixed frames rather than pumpAndSettle: the gallery shows a spinner
    // while an image resolves, and in a test the asset never does, so settling
    // never happens.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PhotoViewGallery), findsOneWidget);
  });

  testWidgets('the anchored zoom screen builds', (tester) async {
    // The screen asks for the long edge, so give it one.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: AnchoredZoomPage(autoPlay: false)),
    );
    await tester.pump();

    expect(find.byType(PhotoView), findsOneWidget);
    expect(find.text('Double tap on tile 6'), findsOneWidget);
  });
}
