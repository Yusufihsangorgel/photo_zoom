import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// A scale value for [PhotoView.minScale], [PhotoView.maxScale] and
/// [PhotoView.initialScale].
///
/// A scale is either an absolute multiplier of the child's intrinsic size
/// ([PhotoViewScale.value]) or a value computed from the child and viewport
/// sizes at layout time ([PhotoViewComputedScale.contained] and
/// [PhotoViewComputedScale.covered]).
///
/// ```dart
/// PhotoView(
///   imageProvider: const AssetImage('assets/photo.jpg'),
///   minScale: PhotoViewComputedScale.contained * 0.8,
///   maxScale: PhotoViewScale.value(4),
/// )
/// ```
@immutable
sealed class PhotoViewScale {
  const PhotoViewScale();

  /// An absolute scale, relative to the child's intrinsic size.
  ///
  /// `PhotoViewScale.value(1)` renders the child at its intrinsic size,
  /// `PhotoViewScale.value(2)` at twice that size.
  const factory PhotoViewScale.value(double scale) = _AbsoluteScale;

  /// Resolves this scale against the sizes of the viewport and the child.
  double resolve(Size outerSize, Size childSize);
}

class _AbsoluteScale extends PhotoViewScale {
  const _AbsoluteScale(this.scale) : assert(scale >= 0, 'scale must be >= 0');

  final double scale;

  @override
  double resolve(Size outerSize, Size childSize) => scale;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _AbsoluteScale && scale == other.scale);

  @override
  int get hashCode => scale.hashCode;

  @override
  String toString() => 'PhotoViewScale.value($scale)';
}

/// A [PhotoViewScale] derived from the child and viewport sizes at layout time.
///
/// Multiply or divide it to offset the computed value:
///
/// ```dart
/// minScale: PhotoViewComputedScale.contained * 0.8,
/// maxScale: PhotoViewComputedScale.covered * 2,
/// ```
class PhotoViewComputedScale extends PhotoViewScale {
  const PhotoViewComputedScale._(this._fit, this.multiplier);

  /// The largest scale at which the whole child fits inside the viewport.
  static const contained = PhotoViewComputedScale._(_Fit.contain, 1);

  /// The smallest scale at which the child covers the whole viewport.
  static const covered = PhotoViewComputedScale._(_Fit.cover, 1);

  final _Fit _fit;

  /// The factor the computed scale is multiplied by. Defaults to `1`.
  final double multiplier;

  /// Returns this scale with its [multiplier] scaled by [multiplier].
  PhotoViewComputedScale operator *(double multiplier) =>
      PhotoViewComputedScale._(_fit, this.multiplier * multiplier);

  /// Returns this scale with its [multiplier] divided by [divider].
  PhotoViewComputedScale operator /(double divider) =>
      PhotoViewComputedScale._(_fit, multiplier / divider);

  @override
  double resolve(Size outerSize, Size childSize) {
    if (childSize.isEmpty || outerSize.isEmpty) return multiplier;
    final widthRatio = outerSize.width / childSize.width;
    final heightRatio = outerSize.height / childSize.height;
    final fitted = switch (_fit) {
      _Fit.contain => math.min(widthRatio, heightRatio),
      _Fit.cover => math.max(widthRatio, heightRatio),
    };
    return fitted * multiplier;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoViewComputedScale &&
          _fit == other._fit &&
          multiplier == other.multiplier);

  @override
  int get hashCode => Object.hash(_fit, multiplier);

  @override
  String toString() {
    final name = _fit == _Fit.contain ? 'contained' : 'covered';
    return multiplier == 1
        ? 'PhotoViewComputedScale.$name'
        : 'PhotoViewComputedScale.$name * $multiplier';
  }
}

enum _Fit { contain, cover }
