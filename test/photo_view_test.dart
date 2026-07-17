import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom/src/photo_view_geometry.dart';
import 'package:photo_zoom/src/scale_boundaries.dart';

import 'helpers.dart';

void main() {
  // A 200x100 image in a 400x400 viewport, so contained (2.0), covered (4.0) and
  // original size (1.0) are all different and can be told apart in assertions.
  late ui.Image image;
  // A square image in a square viewport, where all three fold onto 1.0.
  late ui.Image squareImage;

  // Decoded here rather than inside a test body: a `testWidgets` body runs in a
  // fake async zone, where the decode callback never gets a chance to fire.
  setUp(() async {
    image = await makeTestImage(200, 100);
    squareImage = await makeTestImage(300, 300);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
    squareImage.dispose();
  });

  PhotoViewController newController() {
    final controller = PhotoViewController();
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pumpPhotoView(
    WidgetTester tester, {
    PhotoViewController? controller,
    PhotoViewScaleStateController? scaleStateController,
    Size size = const Size(400, 400),
    PhotoViewScale? minScale,
    PhotoViewScale? maxScale,
    PhotoViewScale? initialScale,
    Alignment basePosition = Alignment.center,
    bool disableGestures = false,
    bool enableScrollZoom = true,
    bool disableAnimations = false,
    String? semanticLabel,
    PhotoViewHeroAttributes? heroAttributes,
  }) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: size,
              child: PhotoView(
                imageProvider: TestImageProvider(image),
                controller: controller,
                scaleStateController: scaleStateController,
                minScale: minScale ?? const PhotoViewScale.value(0),
                maxScale:
                    maxScale ?? const PhotoViewScale.value(double.infinity),
                initialScale: initialScale ?? PhotoViewComputedScale.contained,
                basePosition: basePosition,
                disableGestures: disableGestures,
                enableScrollZoom: enableScrollZoom,
                semanticLabel: semanticLabel,
                heroAttributes: heroAttributes,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('rendering', () {
    testWidgets('shows the image at the contained scale once it resolves', (
      tester,
    ) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      expect(find.byType(Image), findsOneWidget);
      expect(controller.scale, 2);
      expect(controller.position, Offset.zero);
    });

    testWidgets('shows the loading builder until the image resolves', (
      tester,
    ) async {
      final completer = Completer<ImageInfo>();
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: _PendingImageProvider(completer.future),
            loadingBuilder: (context, event) => const Text('loading'),
          ),
        ),
      );
      expect(find.text('loading'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      completer.complete(ImageInfo(image: image.clone()));
      await tester.pumpAndSettle();
      expect(find.text('loading'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('shows a default loading indicator when none is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: _PendingImageProvider(Completer<ImageInfo>().future),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the error builder when the image fails', (tester) async {
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: const FailingImageProvider(),
            errorBuilder: (context, error, stack) => const Text('broken'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('broken'), findsOneWidget);
    });

    testWidgets('customChild scales a widget against its childSize', (
      tester,
    ) async {
      final controller = newController();
      await tester.pumpWidget(
        harness(
          child: PhotoView.customChild(
            controller: controller,
            childSize: const Size(200, 100),
            child: const Text('hello'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
      expect(controller.scale, 2);
    });

    testWidgets('disableGestures drops the gesture detector', (tester) async {
      await pumpPhotoView(tester, disableGestures: true);
      expect(find.byType(RawGestureDetector), findsNothing);

      await pumpPhotoView(tester);
      expect(find.byType(RawGestureDetector), findsOneWidget);
    });
  });

  group('double tap', () {
    testWidgets('walks the scale state cycle', (tester) async {
      final scaleStateController = PhotoViewScaleStateController();
      addTearDown(scaleStateController.dispose);
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      expect(scaleStateController.scaleState, PhotoViewScaleState.initial);
      expect(controller.scale, 2);

      await doubleTapAt(tester, const Offset(200, 200));
      expect(scaleStateController.scaleState, PhotoViewScaleState.covering);
      expect(controller.scale, closeToD(4));

      await doubleTapAt(tester, const Offset(200, 200));
      expect(scaleStateController.scaleState, PhotoViewScaleState.originalSize);
      expect(controller.scale, closeToD(1));
    });

    testWidgets('zooms at the tap point rather than the centre', (
      tester,
    ) async {
      // The headline fix. photo_view animates the position to Offset.zero on
      // every scale state change, so a double tap anywhere lands on
      // basePosition. See bluefireteam/photo_view#82, #394 and #538.
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);
      expect(controller.scale, 2);
      expect(controller.position, Offset.zero);

      await doubleTapAt(tester, const Offset(350, 200));

      expect(controller.scale, closeToD(4));
      expect(controller.position, offsetCloseTo(const Offset(-150, 0)));
    });

    testWidgets('keeps the tapped part of the image under the finger', (
      tester,
    ) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      const geometry = PhotoViewGeometry(
        boundaries: ScaleBoundaries(
          minScale: PhotoViewScale.value(0),
          maxScale: PhotoViewScale.value(double.infinity),
          initialScale: PhotoViewComputedScale.contained,
          outerSize: Size(400, 400),
          childSize: Size(200, 100),
        ),
        basePosition: Alignment.center,
      );
      const tap = Offset(350, 200);
      final before = geometry.viewportToChild(
        tap,
        scale: controller.scale!,
        position: controller.position,
      );

      await doubleTapAt(tester, tap);

      final after = geometry.viewportToChild(
        tap,
        scale: controller.scale!,
        position: controller.position,
      );
      expect(after, offsetCloseTo(before));
    });

    testWidgets('an abandoned double tap does not leave its focal behind', (
      tester,
    ) async {
      // onDoubleTapDown records where the tap landed before the gesture is
      // settled. If the double tap is then abandoned, that focal must go with
      // it, or the next thing to move the cycle spends it: a programmatic
      // change would zoom at a point the user touched some time ago.
      final scaleStateController = PhotoViewScaleStateController();
      addTearDown(scaleStateController.dispose);
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      // Tap once, then let the second tap-down turn into a drag.
      await tester.tapAt(const Offset(350, 200));
      await tester.pump(const Duration(milliseconds: 50));
      final gesture = await tester.startGesture(const Offset(350, 200));
      await gesture.moveBy(const Offset(0, 80));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.scale, 2, reason: 'the double tap should not have run');

      // A programmatic change has no focal point, so the child returns to its
      // resting place rather than to where that abandoned tap landed.
      scaleStateController.scaleState = PhotoViewScaleState.covering;
      await tester.pumpAndSettle();
      expect(controller.scale, closeToD(4));
      expect(controller.position, offsetCloseTo(Offset.zero));
    });

    testWidgets('respects a custom cycle', (tester) async {
      final controller = newController();
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: TestImageProvider(image),
            controller: controller,
            // Straight to original size, skipping covering.
            scaleStateCycle: (actual) => actual == PhotoViewScaleState.initial
                ? PhotoViewScaleState.originalSize
                : PhotoViewScaleState.initial,
          ),
        ),
      );
      await tester.pump();
      await doubleTapAt(tester, const Offset(200, 200));
      expect(controller.scale, closeToD(1));
    });

    testWidgets('skips cycle steps that would not change the scale', (
      tester,
    ) async {
      // A square image in a square viewport: contained, covered and original
      // size all resolve to 1.0, so no step of the cycle changes anything and a
      // double tap must be a no-op rather than an infinite walk.
      final controller = newController();
      await tester.pumpWidget(
        harness(
          size: const Size(300, 300),
          child: PhotoView(
            imageProvider: TestImageProvider(squareImage),
            controller: controller,
          ),
        ),
      );
      await tester.pump();
      expect(controller.scale, 1);
      await doubleTapAt(tester, const Offset(150, 150));
      expect(controller.scale, 1);
    });
  });

  group('scale limits', () {
    testWidgets('a pinch cannot settle above maxScale', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        maxScale: const PhotoViewScale.value(3),
      );

      await pinch(tester, focal: const Offset(200, 200), from: 40, to: 200);
      await tester.pumpAndSettle();

      expect(controller.scale, closeToD(3));
    });

    testWidgets('a pinch cannot settle below minScale', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        minScale: const PhotoViewScale.value(1.5),
      );

      await pinch(tester, focal: const Offset(200, 200), from: 200, to: 20);
      await tester.pumpAndSettle();

      expect(controller.scale, closeToD(1.5));
    });

    testWidgets('strictScale clamps during the pinch, not just at the end', (
      tester,
    ) async {
      final controller = newController();
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: TestImageProvider(image),
            controller: controller,
            strictScale: true,
            maxScale: const PhotoViewScale.value(3),
          ),
        ),
      );
      await tester.pump();

      final gesture1 = await tester.startGesture(const Offset(160, 200));
      final gesture2 = await tester.startGesture(const Offset(240, 200));
      await gesture1.moveTo(const Offset(0, 200));
      await gesture2.moveTo(const Offset(400, 200));
      // Mid-gesture, before any spring-back had a chance to run.
      expect(controller.scale, closeToD(3));
      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(controller.scale, closeToD(3));
    });
  });

  group('pan', () {
    testWidgets('cannot drag the image past its edge', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        initialScale: PhotoViewComputedScale.covered,
      );
      expect(controller.scale, 4);

      // At 4x the 200-wide image is 800 wide, so it can pan +/-200.
      await tester.dragFrom(const Offset(200, 200), const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(controller.position.dx, closeToD(200));

      await tester.dragFrom(const Offset(200, 200), const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(controller.position.dx, closeToD(-200));
    });

    testWidgets('cannot pan on an axis where the image fits', (tester) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);
      // At the contained scale the image is 400x200 in a 400x400 box: no room.
      await tester.dragFrom(const Offset(200, 200), const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(controller.position, Offset.zero);
    });

    testWidgets('a drag moves the image with the finger', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        initialScale: PhotoViewComputedScale.covered,
      );

      final gesture = await tester.startGesture(const Offset(200, 200));
      // The first move is eaten by the pan slop before the recogniser starts,
      // so the pan being measured has to be a later one.
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      final panned = controller.position.dx;
      await gesture.up();
      await tester.pumpAndSettle();

      expect(panned, closeToD(50));
      expect(controller.position.dx, greaterThan(0));
    });
  });

  group('controller', () {
    testWidgets('drives the scale from outside', (tester) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      controller.scale = 3;
      await tester.pumpAndSettle();
      expect(controller.scale, 3);

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.getMaxScaleOnAxis(), closeToD(3));
    });

    testWidgets('clamps a write that is out of range', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        maxScale: const PhotoViewScale.value(3),
        minScale: const PhotoViewScale.value(1),
      );

      controller.scale = 99;
      await tester.pumpAndSettle();
      expect(controller.scale, 3);

      controller.scale = 0.01;
      await tester.pumpAndSettle();
      expect(controller.scale, 1);
    });

    testWidgets('reset returns the view to where it started', (tester) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      await doubleTapAt(tester, const Offset(350, 200));
      expect(controller.scale, closeToD(4));

      controller.reset();
      await tester.pumpAndSettle();
      expect(controller.scale, 2);
      expect(controller.position, Offset.zero);
    });

    testWidgets('an external write syncs the scale state', (tester) async {
      final scaleStateController = PhotoViewScaleStateController();
      addTearDown(scaleStateController.dispose);
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      controller.scale = 3;
      await tester.pumpAndSettle();
      expect(scaleStateController.scaleState, PhotoViewScaleState.zoomedIn);

      controller.scale = 1;
      await tester.pumpAndSettle();
      expect(scaleStateController.scaleState, PhotoViewScaleState.zoomedOut);
    });

    testWidgets('a pan does not knock the view off the cycle', (tester) async {
      final scaleStateController = PhotoViewScaleStateController();
      addTearDown(scaleStateController.dispose);
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      await doubleTapAt(tester, const Offset(200, 200));
      expect(scaleStateController.scaleState, PhotoViewScaleState.covering);

      // Dragging the covering photo around is not a zoom, so the cycle stays put
      // and the next double tap goes on to the next step.
      await tester.dragFrom(const Offset(200, 200), const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(scaleStateController.scaleState, PhotoViewScaleState.covering);

      await doubleTapAt(tester, const Offset(200, 200));
      expect(scaleStateController.scaleState, PhotoViewScaleState.originalSize);
    });

    testWidgets('a position-only write does not knock it off the cycle', (
      tester,
    ) async {
      final scaleStateController = PhotoViewScaleStateController();
      addTearDown(scaleStateController.dispose);
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      await doubleTapAt(tester, const Offset(200, 200));
      expect(scaleStateController.scaleState, PhotoViewScaleState.covering);

      controller.position = const Offset(-50, 0);
      await tester.pumpAndSettle();
      expect(scaleStateController.scaleState, PhotoViewScaleState.covering);
    });

    testWidgets('setting the scale state animates the view', (tester) async {
      final scaleStateController = PhotoViewScaleStateController();
      addTearDown(scaleStateController.dispose);
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      scaleStateController.scaleState = PhotoViewScaleState.covering;
      await tester.pumpAndSettle();
      expect(controller.scale, closeToD(4));
    });

    testWidgets('scaleStateChangedCallback reports each step', (tester) async {
      final states = <PhotoViewScaleState>[];
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: TestImageProvider(image),
            scaleStateChangedCallback: states.add,
          ),
        ),
      );
      await tester.pump();
      await doubleTapAt(tester, const Offset(200, 200));
      expect(states, contains(PhotoViewScaleState.covering));
    });
  });

  group('lifecycle', () {
    testWidgets('does not dispose a controller it did not create', (
      tester,
    ) async {
      final controller = PhotoViewController();
      final scaleStateController = PhotoViewScaleStateController();
      await pumpPhotoView(
        tester,
        controller: controller,
        scaleStateController: scaleStateController,
      );

      await tester.pumpWidget(const SizedBox());

      // Still usable: a disposed ValueNotifier throws from addListener.
      expect(() => controller.addListener(() {}), returnsNormally);
      expect(() => scaleStateController.addListener(() {}), returnsNormally);
      expect(controller.scale, 2);

      controller.dispose();
      scaleStateController.dispose();
    });

    testWidgets('tears down cleanly while an animation is running', (
      tester,
    ) async {
      await pumpPhotoView(tester);

      await tester.tapAt(const Offset(350, 200));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(350, 200));
      // Halfway through the settle animation, with the ticker live.
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      // A ticker or animation controller left behind would fail the test here.
      expect(tester.takeException(), isNull);
    });

    testWidgets('lets go of the image handle it resolved for sizing', (
      tester,
    ) async {
      // The view resolves the provider a second time, on its own, purely to
      // learn the image's size, and the stream hands every listener its own
      // ImageInfo to dispose. Holding that one would pin the decoded image for
      // as long as the view lives.
      //
      // Measured against a plain Image on the same provider rather than against
      // zero: a resolved provider always leaves its completer's own ImageInfo
      // behind until the cache lets go of it, and that one is not this
      // package's to dispose. What is being asserted is that the view adds no
      // leak of its own on top of what the framework already does.
      Future<int> leakedFor(Widget Function(ImageProvider) build) async {
        final tracker = DisposalTracker<ImageInfo>();
        await tester.pumpWidget(
          harness(child: build(TestImageProvider(image))),
        );
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        await tester.pump();
        final leaked = tracker.leaked.length;
        tracker.stop();
        return leaked;
      }

      final baseline = await leakedFor((provider) => Image(image: provider));
      final view = await leakedFor(
        (provider) => PhotoView(imageProvider: provider),
      );

      expect(view, baseline);
    });

    testWidgets('survives swapping the controller out', (tester) async {
      final first = newController();
      final second = newController();

      await pumpPhotoView(tester, controller: first);
      expect(first.scale, 2);

      await pumpPhotoView(tester, controller: second);
      expect(second.scale, 2);

      second.scale = 3;
      await tester.pumpAndSettle();
      expect(second.scale, 3);
      expect(tester.takeException(), isNull);
    });
  });

  group('resize', () {
    testWidgets('keeps a hand-made zoom when the viewport changes size', (
      tester,
    ) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      controller.scale = 3;
      await tester.pumpAndSettle();
      expect(controller.scale, 3);

      // Rotating the device, in effect.
      await pumpPhotoView(
        tester,
        controller: controller,
        size: const Size(300, 300),
      );
      await tester.pumpAndSettle();
      expect(controller.scale, 3);
    });

    testWidgets('recomputes a cycle-driven scale for the new size', (
      tester,
    ) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);
      expect(controller.scale, 2);

      // 200x100 contained in 300x300 is 1.5x, not 2x.
      await pumpPhotoView(
        tester,
        controller: controller,
        size: const Size(300, 300),
      );
      await tester.pumpAndSettle();
      expect(controller.scale, 1.5);
    });

    testWidgets('pulls the pan back in range when the viewport grows', (
      tester,
    ) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        initialScale: PhotoViewComputedScale.covered,
      );
      await tester.dragFrom(const Offset(200, 200), const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(controller.position.dx, closeToD(200));

      // A wider viewport leaves less to pan, so the old position is out of range.
      await pumpPhotoView(
        tester,
        controller: controller,
        size: const Size(400, 200),
      );
      await tester.pumpAndSettle();

      final geometry = PhotoViewGeometry(
        boundaries: const ScaleBoundaries(
          minScale: PhotoViewScale.value(0),
          maxScale: PhotoViewScale.value(double.infinity),
          initialScale: PhotoViewComputedScale.covered,
          outerSize: Size(400, 200),
          childSize: Size(200, 100),
        ),
        basePosition: Alignment.center,
      );
      final range = geometry.cornersX(scale: controller.scale!);
      expect(controller.position.dx, lessThanOrEqualTo(range.max + 0.01));
      expect(controller.position.dx, greaterThanOrEqualTo(range.min - 0.01));
    });
  });

  group('reduced motion', () {
    testWidgets('jumps to the new scale without animating', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        disableAnimations: true,
      );

      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();

      // Already there on the first frame, with nothing left to draw: no
      // animation ran at all, rather than one that ran quickly.
      expect(controller.scale, closeToD(4));
      expect(tester.binding.hasScheduledFrame, isFalse);

      // Let the double tap recogniser's timer expire before the test ends.
      await tester.pump(kDoubleTapTimeout);
    });

    testWidgets('still animates when motion is not reduced', (tester) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      await tester.tapAt(const Offset(200, 200));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // Underway, but nowhere near the 4.0 it is heading for.
      expect(controller.scale, greaterThan(2));
      expect(controller.scale, lessThan(4));
      await tester.pumpAndSettle();
      expect(controller.scale, closeToD(4));
    });
  });

  group('hero', () {
    testWidgets('inserts a Hero only when heroAttributes are given', (
      tester,
    ) async {
      await pumpPhotoView(tester);
      expect(find.byType(Hero), findsNothing);

      await pumpPhotoView(
        tester,
        heroAttributes: const PhotoViewHeroAttributes(tag: 'photo'),
      );
      expect(find.byType(Hero), findsOneWidget);
      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'photo');
    });

    testWidgets('flies between routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        body: PhotoView(
                          imageProvider: TestImageProvider(image),
                          heroAttributes: const PhotoViewHeroAttributes(
                            tag: 'photo',
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Hero(
                    tag: 'photo',
                    child: Image(image: TestImageProvider(image), width: 50),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(Image));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Mid-flight the hero has left the source and not yet landed.
      expect(find.byType(PhotoView), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(PhotoView), findsOneWidget);
    });
  });

  group('semantics', () {
    testWidgets('exposes the zoom level as a percentage of the initial scale', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        semanticLabel: 'a photo',
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('a photo')).value,
        '100%',
      );

      controller.scale = 4;
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('a photo')).value,
        '200%',
      );

      handle.dispose();
    });

    testWidgets('offers zoom actions that work', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        semanticLabel: 'a photo',
        minScale: const PhotoViewScale.value(1),
        maxScale: const PhotoViewScale.value(8),
      );

      final node = tester.getSemantics(find.bySemanticsLabel('a photo'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        isTrue,
      );

      tester.semantics.performAction(
        find.semantics.byLabel('a photo'),
        SemanticsAction.increase,
      );
      await tester.pumpAndSettle();
      expect(controller.scale, closeToD(3));

      handle.dispose();
    });

    testWidgets('drops the zoom actions at the scale limits', (tester) async {
      final handle = tester.ensureSemantics();
      // Pinned: contained is the only scale allowed.
      await pumpPhotoView(
        tester,
        semanticLabel: 'a photo',
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained,
      );

      final node = tester.getSemantics(find.bySemanticsLabel('a photo'));
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isFalse,
      );
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.decrease),
        isFalse,
      );

      handle.dispose();
    });
  });

  group('scroll zoom', () {
    testWidgets('a mouse wheel zooms', (tester) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);
      expect(controller.scale, 2);

      // Scrolling up zooms in.
      await scrollAt(tester, const Offset(200, 200), const Offset(0, -100));
      expect(controller.scale, greaterThan(2));

      final zoomedIn = controller.scale!;
      // Scrolling back down zooms out again.
      await scrollAt(tester, const Offset(200, 200), const Offset(0, 100));
      expect(controller.scale, lessThan(zoomedIn));
    });

    testWidgets('a mouse wheel zooms at the pointer, not the centre', (
      tester,
    ) async {
      final controller = newController();
      await pumpPhotoView(tester, controller: controller);

      const pointer = Offset(350, 200);
      const geometry = PhotoViewGeometry(
        boundaries: ScaleBoundaries(
          minScale: PhotoViewScale.value(0),
          maxScale: PhotoViewScale.value(double.infinity),
          initialScale: PhotoViewComputedScale.contained,
          outerSize: Size(400, 400),
          childSize: Size(200, 100),
        ),
        basePosition: Alignment.center,
      );
      final before = geometry.viewportToChild(
        pointer,
        scale: controller.scale!,
        position: controller.position,
      );

      await scrollAt(tester, pointer, const Offset(0, -100));

      final after = geometry.viewportToChild(
        pointer,
        scale: controller.scale!,
        position: controller.position,
      );
      expect(after, offsetCloseTo(before));
      expect(controller.position, isNot(Offset.zero));
    });

    testWidgets('enableScrollZoom: false ignores the wheel', (tester) async {
      final controller = newController();
      await pumpPhotoView(
        tester,
        controller: controller,
        enableScrollZoom: false,
      );

      await scrollAt(tester, const Offset(200, 200), const Offset(0, -100));
      expect(controller.scale, 2);
    });

    testWidgets(
      'a wheel event it can use is kept from an ancestor scrollable',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);
        await tester.pumpWidget(
          harness(
            size: const Size(400, 600),
            child: ListView(
              controller: scrollController,
              children: [
                SizedBox(
                  height: 400,
                  child: PhotoView(imageProvider: TestImageProvider(image)),
                ),
                const SizedBox(height: 2000),
              ],
            ),
          ),
        );
        await tester.pump();

        await scrollAt(tester, const Offset(200, 200), const Offset(0, -100));
        // The photo zoomed, so the list stayed put.
        expect(scrollController.offset, 0);
      },
    );

    testWidgets('a wheel event it cannot use is left to an ancestor scrollable', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      await tester.pumpWidget(
        harness(
          size: const Size(400, 600),
          child: ListView(
            controller: scrollController,
            children: [
              SizedBox(
                height: 400,
                child: PhotoView(
                  imageProvider: TestImageProvider(image),
                  // Pinned at the contained scale: no wheel event can do anything.
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained,
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );
      await tester.pump();

      await scrollAt(tester, const Offset(200, 200), const Offset(0, 100));
      // Nothing to zoom, so the scroll fell through and the list moved.
      expect(scrollController.offset, greaterThan(0));
    });
  });
}

/// Pinches [focal] from [from] to [to] pixels of separation.
Future<void> pinch(
  WidgetTester tester, {
  required Offset focal,
  required double from,
  required double to,
}) async {
  final gesture1 = await tester.startGesture(focal - Offset(from / 2, 0));
  final gesture2 = await tester.startGesture(focal + Offset(from / 2, 0));
  await gesture1.moveTo(focal - Offset(to / 2, 0));
  await gesture2.moveTo(focal + Offset(to / 2, 0));
  await tester.pump();
  await gesture1.up();
  await gesture2.up();
  await tester.pump();
}

class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  _PendingImageProvider(this.future);

  final Future<ImageInfo> future;

  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_PendingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(future);
}
