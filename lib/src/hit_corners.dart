import 'package:flutter/widgets.dart';

import 'photo_view_geometry.dart';

/// Decides whether a pan should move the child or be left to an ancestor
/// gesture detector, such as the [PageView] behind a [PhotoViewGallery].
///
/// A photo that is panned to its right edge should hand the next leftward drag
/// to the page view instead of swallowing it; that hand-off is what this class
/// works out.
@immutable
class EdgeHitDetector {
  /// Creates a detector for one transform state.
  const EdgeHitDetector({
    required this.geometry,
    required this.scale,
    required this.position,
  });

  /// The geometry the child is displayed with.
  final PhotoViewGeometry geometry;

  /// The scale the child is displayed at.
  final double scale;

  /// The pan offset the child is displayed at.
  final Offset position;

  /// Whether a pan of [move] along [mainAxis] should move the child.
  ///
  /// [move] is the movement of the viewport relative to the content, i.e. the
  /// negation of the finger movement, matching what
  /// [PhotoViewGestureRecognizer] tracks.
  ///
  /// Returns `false` when the child has no room to pan along [mainAxis], or when
  /// it is already against the edge the pan is heading for. In both cases the
  /// gesture is better handled by whatever is behind the photo.
  bool shouldMove(Offset move, Axis mainAxis) => switch (mainAxis) {
    Axis.horizontal => _shouldMoveAxis(
      move: move.dx,
      position: position.dx,
      range: geometry.cornersX(scale: scale),
      hasRoom:
          geometry.boundaries.childSize.width * scale >
          geometry.boundaries.outerSize.width,
    ),
    Axis.vertical => _shouldMoveAxis(
      move: move.dy,
      position: position.dy,
      range: geometry.cornersY(scale: scale),
      hasRoom:
          geometry.boundaries.childSize.height * scale >
          geometry.boundaries.outerSize.height,
    ),
  };

  static bool _shouldMoveAxis({
    required double move,
    required double position,
    required CornersRange range,
    required bool hasRoom,
  }) {
    if (move == 0 || !hasRoom) return false;
    // A negative `move` means the finger travels towards the positive axis, so
    // `position` grows towards `range.max`, and vice versa.
    if (position >= range.max && move < 0) return false;
    if (position <= range.min && move > 0) return false;
    return true;
  }
}
