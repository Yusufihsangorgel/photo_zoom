import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom/src/photo_view_geometry.dart';
import 'package:photo_zoom/src/scale_boundaries.dart';

import 'helpers.dart';

/// A 200x100 child in a 400x400 viewport, so that contained (2.0), covered (4.0)
/// and original size (1.0) are all different.
PhotoViewGeometry geometryFor({
  Alignment basePosition = Alignment.center,
  Size outerSize = const Size(400, 400),
  Size childSize = const Size(200, 100),
}) => PhotoViewGeometry(
  boundaries: ScaleBoundaries(
    minScale: const PhotoViewScale.value(0),
    maxScale: const PhotoViewScale.value(double.infinity),
    initialScale: PhotoViewComputedScale.contained,
    outerSize: outerSize,
    childSize: childSize,
  ),
  basePosition: basePosition,
);

void main() {
  group('placement', () {
    test('transform origin follows basePosition', () {
      expect(geometryFor().transformOrigin, const Offset(200, 200));
      expect(
        geometryFor(basePosition: Alignment.topLeft).transformOrigin,
        Offset.zero,
      );
      expect(
        geometryFor(basePosition: Alignment.bottomRight).transformOrigin,
        const Offset(400, 400),
      );
    });

    test('a centred child rests in the middle of the viewport', () {
      // A 200x100 child in a 400x400 viewport leaves 200 and 300 to share.
      expect(geometryFor().childOffset, const Offset(100, 150));
    });

    test('a top-left child rests in the corner', () {
      expect(
        geometryFor(basePosition: Alignment.topLeft).childOffset,
        Offset.zero,
      );
    });
  });

  group('viewport/child mapping', () {
    test('round trips through the transform', () {
      final geometry = geometryFor();
      const childPoint = Offset(37, 61);
      final viewport = geometry.childToViewport(
        childPoint,
        scale: 2.7,
        position: const Offset(-13, 21),
      );
      expect(
        geometry.viewportToChild(
          viewport,
          scale: 2.7,
          position: const Offset(-13, 21),
        ),
        offsetCloseTo(childPoint),
      );
    });

    test(
      'at scale 1 with no pan, a child point lands at its resting offset',
      () {
        final geometry = geometryFor();
        expect(
          geometry.childToViewport(
            Offset.zero,
            scale: 1,
            position: Offset.zero,
          ),
          offsetCloseTo(geometry.childOffset),
        );
      },
    );
  });

  group('pan bounds', () {
    test('are symmetric about a centred base position', () {
      // At scale 4 the 200-wide child is 800 wide, 400 wider than the viewport.
      final range = geometryFor().cornersX(scale: 4);
      expect(range.min, -200);
      expect(range.max, 200);
    });

    test('are one-sided about a top-left base position', () {
      // Anchored at the left edge, the child can only be dragged left.
      final range = geometryFor(
        basePosition: Alignment.topLeft,
      ).cornersX(scale: 4);
      expect(range.min, -400);
      expect(range.max, 0);
    });

    test('collapse to zero on an axis where the child fits', () {
      // At contained scale the child fits, so there is nothing to pan.
      final geometry = geometryFor();
      expect(
        geometry.clampPosition(position: const Offset(50, 50), scale: 2),
        Offset.zero,
      );
    });

    test(
      'hold the child against the edge once it is larger than the viewport',
      () {
        final geometry = geometryFor();
        // Covered scale: 800x400. Horizontally pannable by +/-200, vertically flush.
        expect(
          geometry.clampPosition(position: const Offset(9999, 9999), scale: 4),
          const Offset(200, 0),
        );
        expect(
          geometry.clampPosition(
            position: const Offset(-9999, -9999),
            scale: 4,
          ),
          const Offset(-200, 0),
        );
      },
    );

    test('leave an in-range position alone', () {
      expect(
        geometryFor().clampPosition(position: const Offset(120, 0), scale: 4),
        const Offset(120, 0),
      );
    });
  });

  group('focal zoom', () {
    test('pins the point under the focal in place', () {
      final geometry = geometryFor();
      const focal = Offset(350, 200);
      const startScale = 2.0;
      const startPosition = Offset.zero;
      const newScale = 4.0;

      final before = geometry.viewportToChild(
        focal,
        scale: startScale,
        position: startPosition,
      );
      final position = geometry.positionForFocalZoom(
        startFocal: focal,
        currentFocal: focal,
        startScale: startScale,
        startPosition: startPosition,
        newScale: newScale,
      );
      final after = geometry.viewportToChild(
        focal,
        scale: newScale,
        position: position,
      );

      expect(after, offsetCloseTo(before));
    });

    test('zooming at a corner does not drift towards the centre', () {
      // The bug this package exists to fix: photo_view animates the position to
      // Offset.zero on every zoom, so a zoom anywhere lands on basePosition.
      // See bluefireteam/photo_view#82, #394 and #538.
      final geometry = geometryFor();
      const focal = Offset(350, 200);
      final position = geometry.positionForFocalZoom(
        startFocal: focal,
        currentFocal: focal,
        startScale: 2,
        startPosition: Offset.zero,
        newScale: 4,
      );
      expect(position, offsetCloseTo(const Offset(-150, 0)));
      expect(position, isNot(Offset.zero));
    });

    test('zooming at the transform origin only scales the existing pan', () {
      final geometry = geometryFor();
      final position = geometry.positionForFocalZoom(
        startFocal: geometry.transformOrigin,
        currentFocal: geometry.transformOrigin,
        startScale: 2,
        startPosition: const Offset(30, -10),
        newScale: 4,
      );
      expect(position, offsetCloseTo(const Offset(60, -20)));
    });

    test('degenerates to a plain pan when the scale does not change', () {
      final geometry = geometryFor();
      final position = geometry.positionForFocalZoom(
        startFocal: const Offset(100, 100),
        currentFocal: const Offset(130, 90),
        startScale: 3,
        startPosition: const Offset(5, 5),
        newScale: 3,
      );
      expect(position, offsetCloseTo(const Offset(35, -5)));
    });

    test('holds the anchor while the child also turns', () {
      final geometry = geometryFor();
      const startFocal = Offset(300, 120);
      const currentFocal = Offset(220, 260);
      const startScale = 2.0;
      const startPosition = Offset(4, 9);
      const startRotation = 0.3;
      const newScale = 3.5;
      const newRotation = 1.2;

      final grabbed = geometry.viewportToChild(
        startFocal,
        scale: startScale,
        position: startPosition,
        rotation: startRotation,
      );
      final position = geometry.positionForFocalZoom(
        startFocal: startFocal,
        currentFocal: currentFocal,
        startScale: startScale,
        startPosition: startPosition,
        newScale: newScale,
        startRotation: startRotation,
        newRotation: newRotation,
      );

      expect(
        geometry.viewportToChild(
          currentFocal,
          scale: newScale,
          position: position,
          rotation: newRotation,
        ),
        offsetCloseTo(grabbed),
      );
    });

    test('round trips through a rotated transform', () {
      final geometry = geometryFor();
      const childPoint = Offset(140, 22);
      final viewport = geometry.childToViewport(
        childPoint,
        scale: 1.7,
        position: const Offset(8, -4),
        rotation: 0.9,
      );
      expect(
        geometry.viewportToChild(
          viewport,
          scale: 1.7,
          position: const Offset(8, -4),
          rotation: 0.9,
        ),
        offsetCloseTo(childPoint),
      );
    });

    test('tracks a focal point that moves while the scale changes', () {
      final geometry = geometryFor();
      const startFocal = Offset(120, 300);
      const currentFocal = Offset(260, 180);
      const startScale = 1.5;
      const startPosition = Offset(11, -7);
      const newScale = 3.25;

      final grabbed = geometry.viewportToChild(
        startFocal,
        scale: startScale,
        position: startPosition,
      );
      final position = geometry.positionForFocalZoom(
        startFocal: startFocal,
        currentFocal: currentFocal,
        startScale: startScale,
        startPosition: startPosition,
        newScale: newScale,
      );
      // The child point grabbed at the start ends up under the finger's new spot.
      expect(
        geometry.viewportToChild(
          currentFocal,
          scale: newScale,
          position: position,
        ),
        offsetCloseTo(grabbed),
      );
    });
  });

  group('matrix', () {
    test('composes translate, scale and rotate', () {
      final geometry = geometryFor();
      final matrix = geometry.matrixFor(
        scale: 2,
        position: const Offset(10, 20),
        rotation: 0,
      );
      final reference = referenceMatrix(2, const Offset(10, 20), 0);
      expect(matrix.storage, reference.storage);
    });

    test('rotates about the origin, then translates', () {
      final geometry = geometryFor();
      final matrix = geometry.matrixFor(
        scale: 1.5,
        position: const Offset(3, 4),
        rotation: 1.1,
      );
      final reference = referenceMatrix(1.5, const Offset(3, 4), 1.1);
      for (var i = 0; i < 16; i++) {
        expect(matrix.storage[i], closeToD(reference.storage[i]));
      }
    });
  });
}

/// The matrix photo_view builds, written the way photo_view writes it.
///
/// [PhotoViewGeometry.matrixFor] composes the same transform out of constructors
/// that are not deprecated and that exist in every supported vector_math, so
/// this is what it is checked against.
Matrix4 referenceMatrix(double scale, Offset position, double rotation) =>
    // ignore: deprecated_member_use
    Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(position.dx, position.dy)
      // ignore: deprecated_member_use
      ..scale(scale)
      ..rotateZ(rotation);
