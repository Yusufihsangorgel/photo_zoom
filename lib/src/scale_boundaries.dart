import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'photo_view_scale.dart';
import 'photo_view_scale_state.dart';

/// The resolved scale limits for a child of [childSize] inside a viewport of
/// [outerSize].
///
/// The three [PhotoViewScale] inputs are resolved lazily, because
/// [PhotoViewComputedScale] depends on both sizes, which are only known at
/// layout time.
@immutable
class ScaleBoundaries {
  /// Creates the scale limits for one child/viewport size pair.
  const ScaleBoundaries({
    required PhotoViewScale minScale,
    required PhotoViewScale maxScale,
    required PhotoViewScale initialScale,
    required this.outerSize,
    required this.childSize,
  }) : _minScale = minScale,
       _maxScale = maxScale,
       _initialScale = initialScale;

  final PhotoViewScale _minScale;
  final PhotoViewScale _maxScale;
  final PhotoViewScale _initialScale;

  /// The size of the viewport the child is displayed in.
  final Size outerSize;

  /// The intrinsic size of the child.
  final Size childSize;

  /// The smallest scale the child may be displayed at.
  double get minScale => _minScale.resolve(outerSize, childSize);

  /// The largest scale the child may be displayed at.
  ///
  /// Never smaller than [minScale]: if the two resolve to a crossed range,
  /// [minScale] wins.
  double get maxScale =>
      _maxScale.resolve(outerSize, childSize).clamp(minScale, double.infinity);

  /// The scale the child is displayed at before any gesture, clamped into
  /// [[minScale], [maxScale]].
  double get initialScale =>
      _initialScale.resolve(outerSize, childSize).clamp(minScale, maxScale);

  /// The scale at which the child covers the whole viewport, clamped into
  /// [[minScale], [maxScale]].
  double get coveringScale => PhotoViewComputedScale.covered
      .resolve(outerSize, childSize)
      .clamp(minScale, maxScale);

  /// The child's intrinsic scale, clamped into [[minScale], [maxScale]].
  double get originalScale => 1.0.clamp(minScale, maxScale);

  /// The scale that [scaleState] corresponds to.
  double scaleForState(PhotoViewScaleState scaleState) => switch (scaleState) {
    PhotoViewScaleState.initial ||
    PhotoViewScaleState.zoomedIn ||
    PhotoViewScaleState.zoomedOut => initialScale,
    PhotoViewScaleState.covering => coveringScale,
    PhotoViewScaleState.originalSize => originalScale,
  };

  /// Returns [scale] clamped into [[minScale], [maxScale]].
  double clampScale(double scale) => scale.clamp(minScale, maxScale);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScaleBoundaries &&
          _minScale == other._minScale &&
          _maxScale == other._maxScale &&
          _initialScale == other._initialScale &&
          outerSize == other.outerSize &&
          childSize == other.childSize);

  @override
  int get hashCode =>
      Object.hash(_minScale, _maxScale, _initialScale, outerSize, childSize);
}
