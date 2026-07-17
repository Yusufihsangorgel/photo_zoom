import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'hit_corners.dart';

/// The gesture detector [PhotoView] wires its pan, pinch, tap and double tap
/// handlers to.
///
/// It is not meant to be used directly; the parts worth knowing about are
/// [PhotoViewGestureDetectorScope], which teaches it to share gestures with an
/// ancestor scrollable, and [PhotoViewGestureRecognizer], which does the
/// sharing.
class PhotoViewGestureDetector extends StatelessWidget {
  /// Creates the gesture detector.
  const PhotoViewGestureDetector({
    super.key,
    this.hitDetector,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.onDoubleTap,
    this.onDoubleTapDown,
    this.onDoubleTapCancel,
    this.onTapUp,
    this.onTapDown,
    this.behavior,
    this.child,
  });

  /// Tells whether the child can still pan in a given direction.
  final EdgeHitDetector? hitDetector;

  /// Called when a pinch or pan begins.
  final GestureScaleStartCallback? onScaleStart;

  /// Called as a pinch or pan progresses.
  final GestureScaleUpdateCallback? onScaleUpdate;

  /// Called when a pinch or pan ends.
  final GestureScaleEndCallback? onScaleEnd;

  /// Called on a double tap.
  final GestureDoubleTapCallback? onDoubleTap;

  /// Called on the second tap-down of a double tap, carrying its position.
  final GestureTapDownCallback? onDoubleTapDown;

  /// Called when a double tap that had already reported [onDoubleTapDown] is
  /// abandoned, so anything recorded from it can be dropped.
  final GestureTapCancelCallback? onDoubleTapCancel;

  /// Called on a single tap-up.
  final GestureTapUpCallback? onTapUp;

  /// Called on a single tap-down.
  final GestureTapDownCallback? onTapDown;

  /// The hit test behavior of the underlying [RawGestureDetector].
  final HitTestBehavior? behavior;

  /// The widget gestures are detected on.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final axis = PhotoViewGestureDetectorScope.of(context)?.axis;

    return RawGestureDetector(
      behavior: behavior,
      gestures: <Type, GestureRecognizerFactory>{
        if (onTapDown != null || onTapUp != null)
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(debugOwner: this),
                (instance) => instance
                  ..onTapDown = onTapDown
                  ..onTapUp = onTapUp,
              ),
        DoubleTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
              () => DoubleTapGestureRecognizer(debugOwner: this),
              (instance) => instance
                ..onDoubleTapDown = onDoubleTapDown
                ..onDoubleTap = onDoubleTap
                ..onDoubleTapCancel = onDoubleTapCancel,
            ),
        PhotoViewGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PhotoViewGestureRecognizer>(
              () => PhotoViewGestureRecognizer(debugOwner: this),
              (instance) => instance
                ..hitDetector = hitDetector
                ..validateAxis = axis
                ..dragStartBehavior = DragStartBehavior.start
                ..onStart = onScaleStart
                ..onUpdate = onScaleUpdate
                ..onEnd = onScaleEnd,
            ),
      },
      child: child,
    );
  }
}

/// The [ScaleGestureRecognizer] behind [PhotoView], able to yield to an
/// ancestor scrollable.
///
/// With a [validateAxis] set, every pointer move is checked against
/// [hitDetector]: while the child still has room to pan along that axis, the
/// gesture is claimed eagerly, and once the child is against its edge, the
/// recognizer stays out of the arena so an ancestor [PageView] or [Dismissible]
/// can win. Pinches with two or more pointers are always claimed.
///
/// With [validateAxis] left `null` the recognizer behaves like a plain
/// [ScaleGestureRecognizer].
class PhotoViewGestureRecognizer extends ScaleGestureRecognizer {
  /// Creates the recognizer.
  PhotoViewGestureRecognizer({
    super.debugOwner,
    this.hitDetector,
    this.validateAxis,
  });

  /// Tells whether the child can still pan in a given direction.
  EdgeHitDetector? hitDetector;

  /// The axis an ancestor scrollable scrolls along, if any.
  Axis? validateAxis;

  final Map<int, Offset> _pointerLocations = <int, Offset>{};
  Offset? _previousFocalPoint;
  Offset? _currentFocalPoint;
  bool _tracking = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!_tracking) {
      _tracking = true;
      _pointerLocations.clear();
      _previousFocalPoint = null;
      _currentFocalPoint = null;
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _tracking = false;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (validateAxis != null) {
      _trackPointer(event);
      if (event is PointerMoveEvent) _acceptIfChildCanPan(event);
    }
    super.handleEvent(event);
  }

  void _trackPointer(PointerEvent event) {
    switch (event) {
      case PointerMoveEvent() when !event.synthesized:
      case PointerDownEvent():
        _pointerLocations[event.pointer] = event.position;
      case PointerUpEvent() || PointerCancelEvent():
        _pointerLocations.remove(event.pointer);
      case _:
        return;
    }

    _previousFocalPoint = _currentFocalPoint;
    _currentFocalPoint = _pointerLocations.isEmpty
        ? null
        : _pointerLocations.values.reduce((a, b) => a + b) /
              _pointerLocations.length.toDouble();
  }

  void _acceptIfChildCanPan(PointerMoveEvent event) {
    if (_pointerLocations.length > 1) {
      // A pinch: never hand this to an ancestor scrollable.
      acceptGesture(event.pointer);
      return;
    }
    final previous = _previousFocalPoint;
    final current = _currentFocalPoint;
    if (previous == null || current == null) return;
    if (hitDetector?.shouldMove(previous - current, validateAxis!) ?? false) {
      acceptGesture(event.pointer);
    }
  }
}

/// Tells a descendant [PhotoView] which axis an ancestor scrollable scrolls
/// along, so the two can share drags.
///
/// [PhotoViewGallery] inserts one of these around its [PageView] already. Add
/// one by hand when placing a [PhotoView] inside any other gesture-sensitive
/// parent:
///
/// ```dart
/// PhotoViewGestureDetectorScope(
///   axis: Axis.vertical,
///   child: PhotoView(imageProvider: const AssetImage('assets/photo.jpg')),
/// )
/// ```
///
/// With the scope in place, a drag along [axis] moves the photo while it has
/// room to pan, and falls through to the parent once the photo hits its edge.
class PhotoViewGestureDetectorScope extends InheritedWidget {
  /// Creates a scope declaring that an ancestor scrolls along [axis].
  const PhotoViewGestureDetectorScope({
    super.key,
    required this.axis,
    required super.child,
  });

  /// The nearest scope, or `null` when there is none.
  static PhotoViewGestureDetectorScope? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<PhotoViewGestureDetectorScope>();

  /// The axis the ancestor scrollable scrolls along.
  final Axis axis;

  @override
  bool updateShouldNotify(PhotoViewGestureDetectorScope oldWidget) =>
      axis != oldWidget.axis;
}
