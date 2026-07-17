import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'scale_boundaries.dart';

/// A closed range of allowed values along one axis.
@immutable
class CornersRange {
  /// Creates a range from [min] to [max].
  const CornersRange(this.min, this.max);

  /// The lowest allowed value.
  final double min;

  /// The highest allowed value.
  final double max;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CornersRange && min == other.min && max == other.max);

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'CornersRange($min, $max)';
}

/// The pure geometry of a [PhotoView]: how a child of a given size is placed,
/// scaled and panned inside a viewport.
///
/// Every method here is a pure function of [boundaries] and [basePosition],
/// which keeps the transform math independent of widgets and animations.
///
/// ## The model
///
/// The child is laid out at its intrinsic size inside a box the size of the
/// viewport, aligned by [basePosition]. It is then transformed by
/// `translate(position) * scale(scale) * rotateZ(rotation)`, about the anchor
/// point [transformOrigin]. A child point `c` therefore lands at
///
/// ```text
/// viewport = origin + scale * (childOffset + c - origin) + position
/// ```
///
/// which is what [childToViewport] and [viewportToChild] implement, and what
/// [positionForFocalZoom] inverts.
@immutable
class PhotoViewGeometry {
  /// Creates the geometry for one child/viewport pair.
  const PhotoViewGeometry({
    required this.boundaries,
    required this.basePosition,
  });

  /// The resolved scale limits and the child/viewport sizes.
  final ScaleBoundaries boundaries;

  /// The alignment of the child inside the viewport, and the anchor the
  /// transform is applied about.
  final Alignment basePosition;

  Size get _outerSize => boundaries.outerSize;
  Size get _childSize => boundaries.childSize;

  /// The point the transform is anchored at, in viewport coordinates.
  Offset get transformOrigin => basePosition.alongSize(_outerSize);

  /// Where the untransformed child's top-left sits in viewport coordinates.
  Offset get childOffset => basePosition.alongOffset(
    Offset(
      _outerSize.width - _childSize.width,
      _outerSize.height - _childSize.height,
    ),
  );

  /// The transform matrix for [scale], [position] and [rotation]:
  /// `translate(position) * scale(scale) * rotateZ(rotation)`.
  ///
  /// It is applied about [transformOrigin], which is what
  /// `Transform(alignment: basePosition)` does when the transformed box is the
  /// size of the viewport.
  Matrix4 matrixFor({
    required double scale,
    required Offset position,
    double rotation = 0,
  }) {
    // `scale * rotateZ` leaves the translation column at zero, so the leading
    // translate is just that column.
    final matrix = Matrix4.diagonal3Values(scale, scale, scale)
      ..multiply(Matrix4.rotationZ(rotation))
      ..setTranslationRaw(position.dx, position.dy, 0);
    return matrix;
  }

  /// Rotates [offset] about the origin by [radians].
  static Offset rotateOffset(Offset offset, double radians) {
    if (radians == 0) return offset;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(
      offset.dx * cos - offset.dy * sin,
      offset.dx * sin + offset.dy * cos,
    );
  }

  /// Maps a point in child coordinates to viewport coordinates.
  Offset childToViewport(
    Offset childPoint, {
    required double scale,
    required Offset position,
    double rotation = 0,
  }) {
    final origin = transformOrigin;
    return origin +
        rotateOffset((childOffset + childPoint - origin) * scale, rotation) +
        position;
  }

  /// Maps a point in viewport coordinates to child coordinates. The inverse of
  /// [childToViewport].
  Offset viewportToChild(
    Offset viewportPoint, {
    required double scale,
    required Offset position,
    double rotation = 0,
  }) {
    final origin = transformOrigin;
    return origin +
        rotateOffset(viewportPoint - origin - position, -rotation) / scale -
        childOffset;
  }

  /// The range [position]'s `dx` may take at [scale] before the child's edges
  /// pull away from the viewport.
  ///
  /// Derived from the placement model: with `k = (basePosition.x + 1) / 2` and
  /// `diff = childWidth * scale - viewportWidth`, the child covers the viewport
  /// exactly while `dx` is in `[diff * (k - 1), diff * k]`. For a centred base
  /// position that is the symmetric `[-diff / 2, diff / 2]`.
  CornersRange cornersX({required double scale}) {
    final diff = _childSize.width * scale - _outerSize.width;
    final k = (basePosition.x + 1) / 2;
    return CornersRange(diff * (k - 1), diff * k);
  }

  /// The range [position]'s `dy` may take at [scale]. The vertical counterpart
  /// of [cornersX].
  CornersRange cornersY({required double scale}) {
    final diff = _childSize.height * scale - _outerSize.height;
    final k = (basePosition.y + 1) / 2;
    return CornersRange(diff * (k - 1), diff * k);
  }

  /// Clamps [position] so the child never pans away from the viewport edges.
  ///
  /// Along an axis where the scaled child is smaller than the viewport there is
  /// nothing to pan, so the position collapses to `0` and the child stays put at
  /// [basePosition].
  Offset clampPosition({required Offset position, required double scale}) {
    final x = _childSize.width * scale > _outerSize.width
        ? position.dx.clamp(
            cornersX(scale: scale).min,
            cornersX(scale: scale).max,
          )
        : 0.0;
    final y = _childSize.height * scale > _outerSize.height
        ? position.dy.clamp(
            cornersY(scale: scale).min,
            cornersY(scale: scale).max,
          )
        : 0.0;
    return Offset(x, y);
  }

  /// The position that keeps the child point under [startFocal] pinned under
  /// [currentFocal] while the scale goes from [startScale] to [newScale].
  ///
  /// This is what makes zoom follow the fingers, the double tap, or the pointer,
  /// instead of always converging on [basePosition]. Passing the same value for
  /// [startFocal] and [currentFocal] anchors a pure zoom at that point; passing
  /// an equal [startScale] and [newScale] degenerates to a plain pan.
  ///
  /// [startRotation] and [newRotation] keep the anchor honest when the child is
  /// also turning, as it is during a pinch with [PhotoView.enableRotation] on.
  ///
  /// The result is not clamped; pass it through [clampPosition] to keep the
  /// child inside the viewport.
  Offset positionForFocalZoom({
    required Offset startFocal,
    required Offset currentFocal,
    required double startScale,
    required Offset startPosition,
    required double newScale,
    double startRotation = 0,
    double newRotation = 0,
  }) {
    if (startScale == 0) return startPosition;
    final origin = transformOrigin;
    final ratio = newScale / startScale;
    // Where the grabbed child point sits relative to the origin, carried through
    // the change in scale and rotation.
    final grabbed = rotateOffset(
      (startFocal - origin - startPosition) * ratio,
      newRotation - startRotation,
    );
    return (currentFocal - origin) - grabbed;
  }
}
