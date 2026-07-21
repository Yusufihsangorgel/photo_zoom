import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import 'helpers.dart';

void main() {
  // A 200x100 image in a 400x400 viewport rests at the contained scale, where it
  // fills the width and has nothing to pan, so a vertical drag is free to
  // dismiss. The 400-tall viewport puts the default 0.2 threshold at 80 pixels.
  late ui.Image image;

  setUp(() async {
    image = await makeTestImage(200, 100);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
  });

  Future<void> pumpView(
    WidgetTester tester, {
    required VoidCallback onDismiss,
  }) async {
    await tester.pumpWidget(
      harness(
        child: PhotoView(
          imageProvider: TestImageProvider(image),
          onDismiss: onDismiss,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a drag past the threshold dismisses at the rest scale', (
    tester,
  ) async {
    var dismissed = 0;
    await pumpView(tester, onDismiss: () => dismissed++);

    final gesture = await tester.startGesture(const Offset(200, 200));
    // Well past the 80 pixel threshold, even after the pan slop is spent.
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dismissed, 1);
  });

  testWidgets(
    'a drag short of the threshold springs back and does not dismiss',
    (tester) async {
      var dismissed = 0;
      await pumpView(tester, onDismiss: () => dismissed++);

      final rest = tester.getTopLeft(find.byType(Image));

      final gesture = await tester.startGesture(const Offset(200, 200));
      // Under the 80 pixel threshold, but past the pan slop, so the image moves.
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(Image)).dy, greaterThan(rest.dy));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(dismissed, 0);
      expect(tester.getTopLeft(find.byType(Image)), offsetCloseTo(rest));
    },
  );
}
