import 'package:flutter/widgets.dart';

import 'photo_view_scale_state.dart';

/// The transform a [PhotoView] applies to its child.
@immutable
class PhotoViewControllerValue {
  /// Creates a transform value.
  const PhotoViewControllerValue({
    this.position = Offset.zero,
    this.scale,
    this.rotation = 0,
  });

  /// The pan offset, in logical pixels, away from the resting place set by
  /// [PhotoView.basePosition].
  final Offset position;

  /// The multiplier applied to the child's intrinsic size.
  ///
  /// `null` means "not resolved yet": the view has not been laid out, so
  /// [PhotoView.initialScale] could not be computed. It is replaced by a
  /// concrete scale on the first layout.
  final double? scale;

  /// The rotation, in radians, applied about [PhotoView.basePosition].
  final double rotation;

  /// Returns a copy with the given fields replaced.
  ///
  /// Passing `scale: null` keeps the current scale; use [withUnresolvedScale]
  /// to clear it.
  PhotoViewControllerValue copyWith({
    Offset? position,
    double? scale,
    double? rotation,
  }) => PhotoViewControllerValue(
    position: position ?? this.position,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
  );

  /// Returns a copy whose [scale] is `null`, to be resolved on the next layout.
  PhotoViewControllerValue withUnresolvedScale() =>
      PhotoViewControllerValue(position: position, rotation: rotation);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoViewControllerValue &&
          position == other.position &&
          scale == other.scale &&
          rotation == other.rotation);

  @override
  int get hashCode => Object.hash(position, scale, rotation);

  @override
  String toString() =>
      'PhotoViewControllerValue(position: $position, scale: $scale, '
      'rotation: $rotation)';
}

/// Reads and drives the transform of a [PhotoView].
///
/// It is a [ValueNotifier], so it can be listened to directly or fed to a
/// [ValueListenableBuilder]:
///
/// ```dart
/// final controller = PhotoViewController();
///
/// @override
/// void dispose() {
///   controller.dispose();
///   super.dispose();
/// }
///
/// // Read the live scale:
/// ValueListenableBuilder(
///   valueListenable: controller,
///   builder: (context, value, _) => Text('${value.scale}'),
/// );
///
/// // Or drive the view:
/// controller.scale = 2;
/// controller.reset();
/// ```
///
/// Writes are applied to the view on the next frame and are clamped to
/// [PhotoView.minScale], [PhotoView.maxScale] and the pan bounds, so the value
/// read back may differ from the value written.
///
/// Whoever creates a controller is responsible for [dispose]ing it. A
/// [PhotoView] never disposes a controller it did not create.
class PhotoViewController extends ValueNotifier<PhotoViewControllerValue> {
  /// Creates a controller, optionally with a starting transform.
  ///
  /// Leaving [initialScale] `null` defers to [PhotoView.initialScale].
  PhotoViewController({
    Offset initialPosition = Offset.zero,
    double initialRotation = 0,
    double? initialScale,
  }) : _initialValue = PhotoViewControllerValue(
         position: initialPosition,
         scale: initialScale,
         rotation: initialRotation,
       ),
       super(
         PhotoViewControllerValue(
           position: initialPosition,
           scale: initialScale,
           rotation: initialRotation,
         ),
       );

  final PhotoViewControllerValue _initialValue;

  /// The pan offset. See [PhotoViewControllerValue.position].
  Offset get position => value.position;
  set position(Offset position) => value = value.copyWith(position: position);

  /// The scale multiplier, or `null` before the first layout. See
  /// [PhotoViewControllerValue.scale].
  double? get scale => value.scale;
  set scale(double? scale) => value = scale == null
      ? value.withUnresolvedScale()
      : value.copyWith(scale: scale);

  /// The rotation in radians. See [PhotoViewControllerValue.rotation].
  double get rotation => value.rotation;
  set rotation(double rotation) => value = value.copyWith(rotation: rotation);

  /// Updates several fields, notifying listeners once.
  void updateMultiple({Offset? position, double? scale, double? rotation}) =>
      value = value.copyWith(
        position: position,
        scale: scale,
        rotation: rotation,
      );

  /// Restores the transform this controller was created with.
  void reset() => value = _initialValue;
}

/// Reads and drives the double-tap cycle step of a [PhotoView].
///
/// Setting [scaleState] animates the view to the matching scale. Reading it
/// tells which step of [PhotoView.scaleStateCycle] the view is on, or whether
/// the user has taken it off the cycle by hand
/// ([PhotoViewScaleState.zoomedIn] and [PhotoViewScaleState.zoomedOut]).
///
/// Whoever creates a controller is responsible for [dispose]ing it.
class PhotoViewScaleStateController extends ValueNotifier<PhotoViewScaleState> {
  /// Creates a controller starting at [PhotoViewScaleState.initial].
  PhotoViewScaleStateController() : super(PhotoViewScaleState.initial);

  /// The current step of the cycle.
  PhotoViewScaleState get scaleState => value;
  set scaleState(PhotoViewScaleState scaleState) => value = scaleState;

  /// Returns to [PhotoViewScaleState.initial].
  void reset() => value = PhotoViewScaleState.initial;
}
