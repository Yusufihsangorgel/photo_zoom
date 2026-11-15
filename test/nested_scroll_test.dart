import 'dart:ui' as ui;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import 'helpers.dart';

/// A zoomed photo inside a vertical scroll view, wrapped in a
/// [PhotoViewGestureDetectorScope], as that class's documentation asks for any
/// gesture-sensitive parent.
///
/// The hand-off is decided per move by `PhotoViewGestureRecognizer`, which
/// checks the scope's axis against the `EdgeHitDetector`. While the child has
/// room to pan along that axis the drag is claimed. Once the child is against
/// its edge the recognizer stays out and the ancestor scrollable wins.
void main() {
  // A 1000x800 image at 1.0 in a 400x400 viewport is 800 px tall, leaving 200
  // px of pan on y either way. A 200x100 image at its contained scale of 2 is
  // 400x200, with nothing to pan vertically at all.
  late ui.Image zoomedImage;
  late ui.Image fittedImage;

  setUp(() async {
    zoomedImage = await makeTestImage(1000, 800);
    fittedImage = await makeTestImage(200, 100);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    zoomedImage.dispose();
    fittedImage.dispose();
  });

  // Puts the photo in a vertical ListView with 2000 px of content below it,
  // as a photo sits in a scrolling page.
  Future<PhotoViewController> pumpInList(
    WidgetTester tester, {
    required ui.Image image,
    required PhotoViewScale initialScale,
    required ScrollController outerScroll,
  }) async {
    final controller = PhotoViewController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        size: const Size(400, 600),
        child: ListView(
          controller: outerScroll,
          children: [
            SizedBox.fromSize(
              size: const Size(400, 400),
              child: PhotoViewGestureDetectorScope(
                axis: Axis.vertical,
                child: PhotoView(
                  imageProvider: TestImageProvider(image),
                  controller: controller,
                  initialScale: initialScale,
                ),
              ),
            ),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  // Drags [dy] along y in [steps] moves one frame apart, then lifts.
  // Each step stays under the 18 px touch slop, as real finger events do. The
  // list's drag recognizer can then win the arena.
  Future<void> dragY(WidgetTester tester, double dy, int steps) async {
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a drag pans the photo while it has room, and the list stays put',
    (tester) async {
      final outer = ScrollController();
      addTearDown(outer.dispose);
      final controller = await pumpInList(
        tester,
        image: zoomedImage,
        initialScale: const PhotoViewScale.value(1),
        outerScroll: outer,
      );
      expect(controller.scale, 1);
      expect(controller.position, Offset.zero);

      // A drag past the 200 px of room clamps at the child's bottom edge.
      await dragY(tester, -400, 40);

      expect(controller.position.dy, closeToD(-200));
      expect(outer.offset, 0);
    },
  );

  testWidgets('the next drag goes to the list once the photo is at its edge', (
    tester,
  ) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    final controller = await pumpInList(
      tester,
      image: zoomedImage,
      initialScale: const PhotoViewScale.value(1),
      outerScroll: outer,
    );

    await dragY(tester, -400, 40);
    expect(controller.position.dy, closeToD(-200));
    expect(outer.offset, 0);

    // The child is against its bottom edge, and the same upward drag is the
    // list's to take.
    await dragY(tester, -200, 20);

    expect(controller.position.dy, closeToD(-200));
    expect(outer.offset, greaterThan(0));
  });

  testWidgets(
    'a photo with nothing to pan gives the drag to the list at once',
    (tester) async {
      final outer = ScrollController();
      addTearDown(outer.dispose);
      final controller = await pumpInList(
        tester,
        image: fittedImage,
        initialScale: PhotoViewComputedScale.contained,
        outerScroll: outer,
      );
      expect(controller.scale, 2);
      expect(controller.position, Offset.zero);

      await dragY(tester, -200, 20);

      expect(controller.position, Offset.zero);
      expect(outer.offset, greaterThan(0));
    },
  );
}
