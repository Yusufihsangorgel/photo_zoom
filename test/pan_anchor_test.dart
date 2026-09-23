import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import 'helpers.dart';

const Offset start = Offset(200, 200);
const Duration frame = Duration(milliseconds: 16);

void main() {
  late ui.Image image;

  setUp(() async {
    image = await makeTestImage(1000, 800);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
  });

  // 1000x800 at 1.0 in 400x400: 300 px of room on x and 200 px on y either way.
  Future<PhotoViewController> pumpZoomedIn(
    WidgetTester tester, {
    PhotoViewScaleStateController? scaleStateController,
    Axis? scopeAxis,
  }) async {
    final controller = PhotoViewController();
    addTearDown(controller.dispose);
    Widget photo = PhotoView(
      imageProvider: TestImageProvider(image),
      controller: controller,
      scaleStateController: scaleStateController,
      initialScale: const PhotoViewScale.value(1),
    );
    if (scopeAxis != null) {
      photo = PhotoViewGestureDetectorScope(axis: scopeAxis, child: photo);
    }
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, height: 400, child: photo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.scale, 1);
    expect(controller.position, Offset.zero);
    return controller;
  }

  // Drags [distance] along x in [steps] moves one frame apart and returns how
  // far the image moved before the pointer lifts.
  Future<double> drag(
    WidgetTester tester,
    PhotoViewController controller, {
    required double distance,
    required int steps,
    PointerDeviceKind kind = PointerDeviceKind.touch,
  }) async {
    final gesture = await tester.startGesture(start, kind: kind);
    await tester.pump(frame);
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(distance / steps, 0));
      await tester.pump(frame);
    }
    final moved = controller.position.dx;
    await gesture.up();
    if (kind == PointerDeviceKind.mouse) await gesture.removePointer();
    await tester.pumpAndSettle();
    return moved;
  }

  testWidgets('a short mouse drag moves the image all the way', (tester) async {
    final controller = await pumpZoomedIn(tester);
    final moved = await drag(
      tester,
      controller,
      distance: 8,
      steps: 10,
      kind: PointerDeviceKind.mouse,
    );
    expect(moved, moreOrLessEquals(8, epsilon: 0.01));
  });

  testWidgets('a touch drag within the double-tap slop does not pan', (
    tester,
  ) async {
    final controller = await pumpZoomedIn(tester);
    final moved = await drag(tester, controller, distance: 16, steps: 10);
    expect(moved, 0);
  });

  testWidgets('a single touch move past the slop pans all the way', (
    tester,
  ) async {
    final controller = await pumpZoomedIn(tester);
    final moved = await drag(tester, controller, distance: 20, steps: 1);
    expect(moved, moreOrLessEquals(20, epsilon: 0.01));
  });

  testWidgets('a short drag as the second tap still double taps', (
    tester,
  ) async {
    final scaleStateController = PhotoViewScaleStateController();
    addTearDown(scaleStateController.dispose);
    final controller = await pumpZoomedIn(
      tester,
      scaleStateController: scaleStateController,
    );

    final tap = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    await tap.up();
    await tester.pump(const Duration(milliseconds: 150));
    final moved = await drag(tester, controller, distance: 8, steps: 10);

    expect(moved, 0);
    expect(scaleStateController.scaleState, PhotoViewScaleState.covering);
    expect(controller.position, Offset.zero);
  });

  testWidgets('the finger left after a pinch pans from where it is', (
    tester,
  ) async {
    final controller = await pumpZoomedIn(tester);

    final first = await tester.startGesture(const Offset(150, 200));
    final second = await tester.startGesture(
      const Offset(250, 200),
      pointer: 2,
    );
    await tester.pump(frame);
    for (var i = 0; i < 3; i++) {
      await first.moveBy(const Offset(-10, 0));
      await second.moveBy(const Offset(10, 0));
      await tester.pump(frame);
    }
    expect(controller.scale, greaterThan(1));

    await second.up();
    await tester.pump(frame);
    final lifted = controller.position;
    // The one-finger pan restarts on this move, which the recognizer may not
    // count, but it must not jump.
    await first.moveBy(const Offset(10, 0));
    await tester.pump(frame);
    final restarted = controller.position;
    await first.moveBy(const Offset(10, 0));
    await tester.pump(frame);
    await first.moveBy(const Offset(10, 0));
    await tester.pump(frame);
    final panned = controller.position;
    await first.up();
    await tester.pumpAndSettle();

    expect(restarted.dx - lifted.dx, inInclusiveRange(0, 10));
    expect(restarted.dy, moreOrLessEquals(lifted.dy, epsilon: 0.01));
    expect(panned - restarted, offsetMoreOrLessEquals(const Offset(20, 0)));
  });

  testWidgets('a short drag along a scope axis still pans all the way', (
    tester,
  ) async {
    final controller = await pumpZoomedIn(tester, scopeAxis: Axis.horizontal);
    final moved = await drag(tester, controller, distance: 8, steps: 1);
    expect(moved, moreOrLessEquals(8, epsilon: 0.01));
  });
}
