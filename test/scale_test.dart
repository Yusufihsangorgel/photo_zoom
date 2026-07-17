import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom/src/scale_boundaries.dart';

ScaleBoundaries boundariesFor({
  PhotoViewScale minScale = const PhotoViewScale.value(0),
  PhotoViewScale maxScale = const PhotoViewScale.value(double.infinity),
  PhotoViewScale initialScale = PhotoViewComputedScale.contained,
  Size outerSize = const Size(400, 400),
  Size childSize = const Size(200, 100),
}) => ScaleBoundaries(
  minScale: minScale,
  maxScale: maxScale,
  initialScale: initialScale,
  outerSize: outerSize,
  childSize: childSize,
);

void main() {
  group('PhotoViewScale', () {
    test('an absolute value resolves to itself, whatever the sizes', () {
      const scale = PhotoViewScale.value(2.5);
      expect(scale.resolve(const Size(400, 400), const Size(200, 100)), 2.5);
      expect(scale.resolve(const Size(10, 10), const Size(999, 1)), 2.5);
    });

    test('contained fits the whole child in, covered fills the viewport', () {
      // 200x100 in 400x400: fitting needs 2x, filling needs 4x.
      expect(
        PhotoViewComputedScale.contained.resolve(
          const Size(400, 400),
          const Size(200, 100),
        ),
        2,
      );
      expect(
        PhotoViewComputedScale.covered.resolve(
          const Size(400, 400),
          const Size(200, 100),
        ),
        4,
      );
    });

    test('multiplying and dividing offset the computed value', () {
      const size = Size(400, 400);
      const child = Size(200, 100);
      expect(
        (PhotoViewComputedScale.contained * 0.8).resolve(size, child),
        1.6,
      );
      expect((PhotoViewComputedScale.covered * 2).resolve(size, child), 8);
      expect((PhotoViewComputedScale.contained / 2).resolve(size, child), 1);
    });

    test('equality ignores identity but respects the multiplier', () {
      expect(
        PhotoViewComputedScale.contained,
        PhotoViewComputedScale.contained,
      );
      expect(
        PhotoViewComputedScale.contained * 2,
        PhotoViewComputedScale.contained * 2,
      );
      expect(
        PhotoViewComputedScale.contained * 2,
        isNot(PhotoViewComputedScale.contained),
      );
      expect(
        PhotoViewComputedScale.contained,
        isNot(PhotoViewComputedScale.covered),
      );
      expect(const PhotoViewScale.value(2), const PhotoViewScale.value(2));
      expect(
        const PhotoViewScale.value(2),
        isNot(const PhotoViewScale.value(3)),
      );
      expect(
        PhotoViewComputedScale.contained.hashCode,
        PhotoViewComputedScale.contained.hashCode,
      );
    });

    test('an empty child does not divide by zero', () {
      expect(
        PhotoViewComputedScale.contained.resolve(
          const Size(400, 400),
          Size.zero,
        ),
        1,
      );
    });
  });

  group('ScaleBoundaries', () {
    test('resolves the three limits against the sizes', () {
      final boundaries = boundariesFor(
        minScale: PhotoViewComputedScale.contained * 0.5,
        maxScale: PhotoViewComputedScale.covered * 2,
      );
      expect(boundaries.minScale, 1);
      expect(boundaries.maxScale, 8);
      expect(boundaries.initialScale, 2);
    });

    test('a max below the min collapses to the min rather than inverting', () {
      final boundaries = boundariesFor(
        minScale: const PhotoViewScale.value(3),
        maxScale: const PhotoViewScale.value(1),
      );
      expect(boundaries.minScale, 3);
      expect(boundaries.maxScale, 3);
    });

    test('the initial scale is clamped into range', () {
      expect(
        boundariesFor(
          minScale: const PhotoViewScale.value(3),
          initialScale: PhotoViewComputedScale.contained,
        ).initialScale,
        3,
      );
      expect(
        boundariesFor(
          maxScale: const PhotoViewScale.value(1.5),
          initialScale: PhotoViewComputedScale.contained,
        ).initialScale,
        1.5,
      );
    });

    test('maps each cycle step to a scale', () {
      final boundaries = boundariesFor();
      expect(boundaries.scaleForState(PhotoViewScaleState.initial), 2);
      expect(boundaries.scaleForState(PhotoViewScaleState.covering), 4);
      expect(boundaries.scaleForState(PhotoViewScaleState.originalSize), 1);
      // A hand-made zoom has no scale of its own; it resolves to the initial one,
      // which is where the cycle picks back up.
      expect(boundaries.scaleForState(PhotoViewScaleState.zoomedIn), 2);
      expect(boundaries.scaleForState(PhotoViewScaleState.zoomedOut), 2);
    });

    test('clamps a scale into range', () {
      final boundaries = boundariesFor(
        minScale: const PhotoViewScale.value(1),
        maxScale: const PhotoViewScale.value(3),
      );
      expect(boundaries.clampScale(0.1), 1);
      expect(boundaries.clampScale(2), 2);
      expect(boundaries.clampScale(99), 3);
    });

    test('equality tracks the sizes, so a resize is noticed', () {
      expect(boundariesFor(), boundariesFor());
      expect(boundariesFor().hashCode, boundariesFor().hashCode);
      expect(
        boundariesFor(outerSize: const Size(400, 401)),
        isNot(boundariesFor()),
      );
      expect(
        boundariesFor(childSize: const Size(201, 100)),
        isNot(boundariesFor()),
      );
    });

    test(
      'a square child in a square viewport folds contained onto covered',
      () {
        final boundaries = boundariesFor(
          outerSize: const Size(300, 300),
          childSize: const Size(300, 300),
        );
        expect(boundaries.initialScale, 1);
        expect(boundaries.coveringScale, 1);
        expect(boundaries.originalScale, 1);
      },
    );
  });

  group('PhotoViewControllerValue', () {
    test('copyWith replaces only what it is given', () {
      const value = PhotoViewControllerValue(
        position: Offset(1, 2),
        scale: 3,
        rotation: 4,
      );
      expect(value.copyWith(scale: 5).scale, 5);
      expect(value.copyWith(scale: 5).position, const Offset(1, 2));
      expect(value.copyWith(position: Offset.zero).scale, 3);
      // A null scale means "leave it alone", not "clear it".
      expect(value.copyWith().scale, 3);
    });

    test('withUnresolvedScale clears the scale and keeps the rest', () {
      const value = PhotoViewControllerValue(
        position: Offset(1, 2),
        scale: 3,
        rotation: 4,
      );
      expect(value.withUnresolvedScale().scale, isNull);
      expect(value.withUnresolvedScale().position, const Offset(1, 2));
      expect(value.withUnresolvedScale().rotation, 4);
    });

    test('equality covers every field', () {
      const value = PhotoViewControllerValue(
        position: Offset(1, 2),
        scale: 3,
        rotation: 4,
      );
      expect(value, value.copyWith());
      expect(value.hashCode, value.copyWith().hashCode);
      expect(value, isNot(value.copyWith(scale: 9)));
      expect(value, isNot(value.copyWith(position: Offset.zero)));
      expect(value, isNot(value.copyWith(rotation: 9)));
    });
  });

  group('PhotoViewController', () {
    test('starts at the transform it was created with', () {
      final controller = addTearDown2(
        PhotoViewController(
          initialPosition: const Offset(5, 6),
          initialScale: 2,
          initialRotation: 0.5,
        ),
      );
      expect(controller.position, const Offset(5, 6));
      expect(controller.scale, 2);
      expect(controller.rotation, 0.5);
    });

    test('leaves the scale unresolved by default', () {
      expect(addTearDown2(PhotoViewController()).scale, isNull);
    });

    test('notifies on each setter', () {
      final controller = addTearDown2(PhotoViewController());
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.position = const Offset(1, 1);
      controller.scale = 2;
      controller.rotation = 3;
      expect(notifications, 3);

      // A write that changes nothing still notifies only when the value differs.
      controller.scale = 2;
      expect(notifications, 3);
    });

    test('updateMultiple notifies once', () {
      final controller = addTearDown2(PhotoViewController());
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.updateMultiple(
        position: const Offset(1, 1),
        scale: 2,
        rotation: 3,
      );
      expect(notifications, 1);
      expect(controller.position, const Offset(1, 1));
      expect(controller.scale, 2);
      expect(controller.rotation, 3);
    });

    test('reset restores the starting transform', () {
      final controller = addTearDown2(
        PhotoViewController(
          initialPosition: const Offset(5, 6),
          initialScale: 2,
        ),
      );
      controller.updateMultiple(position: const Offset(50, 60), scale: 9);
      controller.reset();
      expect(controller.position, const Offset(5, 6));
      expect(controller.scale, 2);
    });

    test('the scale state controller cycles and resets', () {
      final controller = addTearDown2(PhotoViewScaleStateController());
      expect(controller.scaleState, PhotoViewScaleState.initial);
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.scaleState = PhotoViewScaleState.covering;
      expect(controller.scaleState, PhotoViewScaleState.covering);
      expect(notifications, 1);
      controller.reset();
      expect(controller.scaleState, PhotoViewScaleState.initial);
      expect(notifications, 2);
    });
  });

  group('defaultScaleStateCycle', () {
    test('walks initial to covering to original size and back', () {
      expect(
        defaultScaleStateCycle(PhotoViewScaleState.initial),
        PhotoViewScaleState.covering,
      );
      expect(
        defaultScaleStateCycle(PhotoViewScaleState.covering),
        PhotoViewScaleState.originalSize,
      );
      expect(
        defaultScaleStateCycle(PhotoViewScaleState.originalSize),
        PhotoViewScaleState.initial,
      );
    });

    test('brings a hand-made zoom back to the start of the cycle', () {
      expect(
        defaultScaleStateCycle(PhotoViewScaleState.zoomedIn),
        PhotoViewScaleState.initial,
      );
      expect(
        defaultScaleStateCycle(PhotoViewScaleState.zoomedOut),
        PhotoViewScaleState.initial,
      );
    });

    test('isZooming marks only the hand-made states', () {
      expect(PhotoViewScaleState.zoomedIn.isZooming, isTrue);
      expect(PhotoViewScaleState.zoomedOut.isZooming, isTrue);
      expect(PhotoViewScaleState.initial.isZooming, isFalse);
      expect(PhotoViewScaleState.covering.isZooming, isFalse);
      expect(PhotoViewScaleState.originalSize.isZooming, isFalse);
    });
  });
}

/// Registers [notifier] for disposal at the end of the test.
T addTearDown2<T extends ChangeNotifier>(T notifier) {
  addTearDown(notifier.dispose);
  return notifier;
}
