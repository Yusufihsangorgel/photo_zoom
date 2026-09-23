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
    final onScaleStart = this.onScaleStart;

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
                ..onStart = onScaleStart == null
                    ? null
                    : ((details) =>
                          onScaleStart(instance._anchorFirstStart(details)))
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

  // The down of the contact's first pointer, kept until the contact's first
  // onStart or until that pointer lifts.
  PointerDownEvent? _firstDown;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!_tracking) {
      _tracking = true;
      _pointerLocations.clear();
      _previousFocalPoint = null;
      _currentFocalPoint = null;
      _firstDown = event;
    }
    super.addAllowedPointer(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _tracking = false;
    _firstDown = null;
    super.didStopTrackingLastPointer(pointer);
  }

  /// Moves the contact's first single-pointer [details] back to where that
  /// pointer went down.
  ///
  /// The recognizer is often accepted only once a double tap is ruled out,
  /// which on touch takes more than 18 px of travel, and it starts at wherever
  /// the pointer is by then. A pan measured from there drops that travel.
  /// Later starts in the same contact, such as the one after a pinch drops to
  /// one finger, are passed through untouched.
  ScaleStartDetails _anchorFirstStart(ScaleStartDetails details) {
    final down = _firstDown;
    _firstDown = null;
    if (down == null || details.pointerCount != 1) return details;
    return AnchoredScaleStartDetails(
      focalPoint: down.position,
      localFocalPoint: down.localPosition,
      pointerCount: details.pointerCount,
      sourceTimeStamp: details.sourceTimeStamp,
      kind: details.kind,
      acceptedLocalFocalPoint: details.localFocalPoint,
    );
  }

  @override
  void handleEvent(PointerEvent event) {
    if ((event is PointerUpEvent || event is PointerCancelEvent) &&
        event.pointer == _firstDown?.pointer) {
      _firstDown = null;
    }
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

/// A [ScaleStartDetails] placed where the gesture's pointer went down rather
/// than where the recognizer was accepted.
///
/// [PhotoViewGestureRecognizer] reports the first start of a single-pointer
/// contact this way, so a pan can be measured from the pointer-down.
class AnchoredScaleStartDetails extends ScaleStartDetails {
  /// Creates the details, with [focalPoint] and [localFocalPoint] at the
  /// pointer-down.
  AnchoredScaleStartDetails({
    super.focalPoint,
    super.localFocalPoint,
    super.pointerCount,
    super.sourceTimeStamp,
    super.kind,
    required this.acceptedLocalFocalPoint,
  });

  /// Where the pointer was when the recognizer was accepted, in local
  /// coordinates.
  final Offset acceptedLocalFocalPoint;
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
