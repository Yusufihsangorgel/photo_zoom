import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import 'helpers.dart';

/// The desktop and web input path: a mouse wheel, a trackpad two-finger
/// scroll, and a trackpad pinch.
///
/// This is the whole of `enableScrollZoom`, and nothing tested it. The part
/// most worth pinning is not that a wheel zooms — it is what happens when it
/// cannot: at a scale limit the event is deliberately left unclaimed, so a
/// list the photo sits inside keeps scrolling instead of the gesture dying on
/// the image. That behaviour is invisible until someone puts a photo in a
/// feed, which is where it would be found.
void main() {
  late ui.Image image;

  setUp(() async {
    image = await makeTestImage(200, 100);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
  });

  PhotoViewController newController() {
    final controller = PhotoViewController();
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pump(
    WidgetTester tester, {
    required PhotoViewController controller,
    PhotoViewScale? minScale,
    PhotoViewScale? maxScale,
    bool enableScrollZoom = true,
    bool disableGestures = false,
    ScrollController? outerScroll,
  }) async {
    final photo = SizedBox.fromSize(
      size: const Size(400, 400),
      child: PhotoView(
        imageProvider: TestImageProvider(image),
        controller: controller,
        minScale: minScale ?? const PhotoViewScale.value(0),
        maxScale: maxScale ?? const PhotoViewScale.value(double.infinity),
        initialScale: PhotoViewComputedScale.contained,
        enableScrollZoom: enableScrollZoom,
        disableGestures: disableGestures,
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: outerScroll == null
              ? photo
              : SizedBox(
                  height: 400,
                  width: 400,
                  child: ListView(
                    controller: outerScroll,
                    children: [photo, const SizedBox(height: 2000)],
                  ),
                ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Sends one wheel notch at the centre of the view.
  ///
  /// `sendEventToBinding` rather than a gesture helper, because a pointer
  /// signal is not a pointer sequence: it arrives on its own and is routed
  /// through the resolver, which is the mechanism under test.
  Future<void> wheel(
    WidgetTester tester,
    double dy, {
    PointerDeviceKind kind = PointerDeviceKind.mouse,
    Offset at = const Offset(200, 200),
  }) async {
    await tester.sendEventToBinding(
      PointerScrollEvent(position: at, scrollDelta: Offset(0, dy), kind: kind),
    );
    await tester.pump();
  }

  group('mouse wheel', () {
    testWidgets('scrolling up zooms in', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller);
      final before = controller.scale!;

      await wheel(tester, -100);

      expect(controller.scale, greaterThan(before));
    });

    testWidgets('scrolling down zooms out', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller);
      await wheel(tester, -300); // zoom in first, so there is room to leave
      final zoomedIn = controller.scale!;

      await wheel(tester, 100);

      expect(controller.scale, lessThan(zoomedIn));
    });

    testWidgets('keeps the point under the cursor in place', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller);

      // Off-centre on purpose: zooming about the centre would hold this point
      // by accident and the test would pass on a broken implementation.
      await wheel(tester, -200, at: const Offset(320, 120));

      expect(
        controller.position,
        isNot(Offset.zero),
        reason: 'an off-centre zoom has to move the image to hold that point',
      );
    });

    testWidgets('a purely horizontal wheel does nothing', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller);
      final before = controller.value;

      await tester.sendEventToBinding(
        const PointerScrollEvent(
          position: Offset(200, 200),
          scrollDelta: Offset(80, 0),
        ),
      );
      await tester.pump();

      expect(controller.value, before);
    });

    testWidgets('does nothing when enableScrollZoom is off', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller, enableScrollZoom: false);
      final before = controller.value;

      await wheel(tester, -100);

      expect(controller.value, before);
    });

    testWidgets('does nothing when gestures are disabled', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller, disableGestures: true);
      final before = controller.value;

      await wheel(tester, -100);

      expect(controller.value, before);
    });
  });

  group('at a scale limit', () {
    testWidgets('scrolling further does not move the scale', (tester) async {
      final controller = newController();
      await pump(
        tester,
        controller: controller,
        maxScale: const PhotoViewScale.value(2),
      );

      await wheel(tester, -2000); // well past the ceiling
      final atCeiling = controller.scale;
      await wheel(tester, -2000);

      expect(controller.scale, atCeiling);
      expect(controller.scale, 2.0);
    });

    testWidgets('leaves the event for a scrollable underneath', (tester) async {
      final outer = ScrollController();
      addTearDown(outer.dispose);
      final controller = newController();
      // A 200x100 image in a 400x400 box is contained at 2.0, so a floor of 2
      // starts the view pinned at its minimum with nowhere to zoom out to.
      // The direction matters: a list at offset zero cannot scroll up, so
      // pinning at the ceiling and scrolling up would show nothing either way.
      await pump(
        tester,
        controller: controller,
        minScale: const PhotoViewScale.value(2),
        outerScroll: outer,
      );
      expect(controller.scale, 2.0);

      // Control, in the direction that should be claimed: zooming in is still
      // possible, so the photo takes the event and the list stays put.
      await wheel(tester, -50, at: const Offset(200, 200));
      expect(controller.scale, greaterThan(2.0));
      expect(outer.offset, 0, reason: 'the photo should have taken this one');

      await wheel(
        tester,
        4000,
        at: const Offset(200, 200),
      ); // back to the floor
      expect(controller.scale, 2.0);
      final beforeHandoff = outer.offset;

      await wheel(tester, 200, at: const Offset(200, 200));

      expect(
        outer.offset,
        greaterThan(beforeHandoff),
        reason: 'pinned at min scale, the wheel belongs to the list',
      );
    });
  });

  group('trackpad', () {
    testWidgets('a two-finger scroll pans instead of zooming', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller);
      await wheel(tester, -400); // zoom in, so there is somewhere to pan to
      final scale = controller.scale;
      final position = controller.position;

      await wheel(tester, 60, kind: PointerDeviceKind.trackpad);

      expect(
        controller.scale,
        scale,
        reason: 'a trackpad scroll is not a zoom',
      );
      expect(controller.position, isNot(position));
    });

    testWidgets('a pinch zooms', (tester) async {
      final controller = newController();
      await pump(tester, controller: controller);
      final before = controller.scale!;

      await tester.sendEventToBinding(
        const PointerScaleEvent(position: Offset(200, 200), scale: 1.5),
      );
      await tester.pump();

      expect(controller.scale, greaterThan(before));
    });

    testWidgets('a pan that would change nothing is left alone', (
      tester,
    ) async {
      // Contained, so there is nothing to pan: the image already fits.
      final controller = newController();
      await pump(tester, controller: controller);
      final before = controller.value;

      await wheel(tester, 60, kind: PointerDeviceKind.trackpad);

      expect(controller.value, before);
    });
  });
}
