import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import 'helpers.dart';

void main() {
  late ui.Image image;

  setUp(() async {
    image = await makeTestImage(1000, 800);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
  });

  testWidgets('a zoomed-in touch drag of 24 px moves the image 24 px', (
    tester,
  ) async {
    final controller = PhotoViewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 400,
            // 1000x800 at 1.0 in 400x400: 300 px of room on x either way.
            child: PhotoView(
              imageProvider: TestImageProvider(image),
              controller: controller,
              initialScale: const PhotoViewScale.value(1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.scale, 1);
    expect(controller.position, Offset.zero);

    // Ten 2.4 px moves one frame apart, the way a finger delivers a short pan.
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(2.4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final panned = controller.position.dx;
    await gesture.up();
    await tester.pumpAndSettle();

    expect(panned, moreOrLessEquals(24, epsilon: 0.01));
  });
}
