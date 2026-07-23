import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'callbacks.dart';
import 'hit_corners.dart';
import 'photo_view_controller.dart';
import 'photo_view_geometry.dart';
import 'photo_view_gesture_detector.dart';
import 'photo_view_hero_attributes.dart';
import 'photo_view_scale_state.dart';
import 'scale_boundaries.dart';

/// How much of a mouse wheel scroll turns into zoom. A wheel notch of 100
/// logical pixels multiplies the scale by `e^(100/_kScrollZoomDivisor)`.
const double _kScrollZoomDivisor = 200;

/// The distance a fling is carried past the finger, in logical pixels.
const double _kFlingDistance = 100;

/// The velocity below which a pan is not treated as a fling.
const double _kMinFlingVelocity = 400;

/// The factor an accessibility zoom step multiplies the scale by.
const double _kSemanticsZoomStep = 1.5;

const Duration _kSettleDuration = Duration(milliseconds: 200);

/// Renders a child under a pan/zoom/rotate transform and owns the gestures,
/// animations and pointer signals that drive it.
///
/// This is the shared engine behind [PhotoView] and every page of a
/// [PhotoViewGallery]. It is internal: it takes an already-resolved
/// [scaleBoundaries], so it needs the child's intrinsic size up front, which is
/// what [PhotoView] resolves the image provider for.
class PhotoViewCore extends StatefulWidget {
  /// Creates a core displaying an image.
  const PhotoViewCore({
    super.key,
    required this.imageProvider,
    required this.semanticLabel,
    required this.gaplessPlayback,
    required this.filterQuality,
    required this.backgroundDecoration,
    required this.heroAttributes,
    required this.controller,
    required this.scaleStateController,
    required this.scaleBoundaries,
    required this.scaleStateCycle,
    required this.basePosition,
    required this.enableRotation,
    required this.enableScrollZoom,
    required this.enablePanAlways,
    required this.strictScale,
    required this.disableGestures,
    required this.gestureDetectorBehavior,
    required this.onTapUp,
    required this.onTapDown,
    required this.onScaleEnd,
    required this.onDismiss,
    required this.dismissThreshold,
  }) : customChild = null;

  /// Creates a core displaying an arbitrary child.
  const PhotoViewCore.customChild({
    super.key,
    required this.customChild,
    required this.semanticLabel,
    required this.backgroundDecoration,
    required this.heroAttributes,
    required this.controller,
    required this.scaleStateController,
    required this.scaleBoundaries,
    required this.scaleStateCycle,
    required this.basePosition,
    required this.enableRotation,
    required this.enableScrollZoom,
    required this.enablePanAlways,
    required this.strictScale,
    required this.disableGestures,
    required this.gestureDetectorBehavior,
    required this.onTapUp,
    required this.onTapDown,
    required this.onScaleEnd,
    required this.onDismiss,
    required this.dismissThreshold,
  }) : imageProvider = null,
       gaplessPlayback = false,
       filterQuality = null;

  /// The image to display, or `null` when [customChild] is used.
  final ImageProvider? imageProvider;

  /// The widget to display, or `null` when [imageProvider] is used.
  final Widget? customChild;

  /// Mirrors [PhotoView.semanticLabel].
  final String? semanticLabel;

  /// Mirrors [PhotoView.gaplessPlayback].
  final bool gaplessPlayback;

  /// Mirrors [PhotoView.filterQuality].
  final FilterQuality? filterQuality;

  /// Mirrors [PhotoView.backgroundDecoration].
  final Decoration backgroundDecoration;

  /// Mirrors [PhotoView.heroAttributes].
  final PhotoViewHeroAttributes? heroAttributes;

  /// The controller holding the transform. Never disposed here.
  final PhotoViewController controller;

  /// The controller holding the double-tap cycle step. Never disposed here.
  final PhotoViewScaleStateController scaleStateController;

  /// The resolved scale limits and sizes.
  final ScaleBoundaries scaleBoundaries;

  /// Mirrors [PhotoView.scaleStateCycle].
  final ScaleStateCycle scaleStateCycle;

  /// Mirrors [PhotoView.basePosition].
  final Alignment basePosition;

  /// Mirrors [PhotoView.enableRotation].
  final bool enableRotation;

  /// Mirrors [PhotoView.enableScrollZoom].
  final bool enableScrollZoom;

  /// Mirrors [PhotoView.enablePanAlways].
  final bool enablePanAlways;

  /// Mirrors [PhotoView.strictScale].
  final bool strictScale;

  /// Mirrors [PhotoView.disableGestures].
  final bool disableGestures;

  /// Mirrors [PhotoView.gestureDetectorBehavior].
  final HitTestBehavior? gestureDetectorBehavior;

  /// Mirrors [PhotoView.onTapUp].
  final PhotoViewImageTapUpCallback? onTapUp;

  /// Mirrors [PhotoView.onTapDown].
  final PhotoViewImageTapDownCallback? onTapDown;

  /// Mirrors [PhotoView.onScaleEnd].
  final PhotoViewImageScaleEndCallback? onScaleEnd;

  /// Mirrors [PhotoView.onDismiss].
  final VoidCallback? onDismiss;

  /// Mirrors [PhotoView.dismissThreshold].
  final double dismissThreshold;

  @override
  State<PhotoViewCore> createState() => _PhotoViewCoreState();
}

class _PhotoViewCoreState extends State<PhotoViewCore>
    with TickerProviderStateMixin {
  // Built eagerly in initState rather than lazily: a lazy `late final` would be
  // constructed by the first touch, and dispose touches it, so a view that is
  // never gestured on would build a Ticker while its element is deactivated.
  late final AnimationController _settle;
  late final CurvedAnimation _settleCurve;

  Tween<double>? _scaleTween;
  Tween<Offset>? _positionTween;
  Tween<double>? _rotationTween;

  // Snapshot of the transform when the current pinch/pan began.
  Offset? _startFocal;
  double? _startScale;
  Offset? _startPosition;
  double? _startRotation;

  // Where the pending double tap landed, so the cycle can anchor its zoom there.
  Offset? _doubleTapFocal;

  // The running translation of a drag-to-dismiss, or null when none is in
  // progress. While it is non-null the child is drawn offset by it and the
  // background is faded, and the normal pan handling is held off.
  Offset? _dismissOffset;

  // The offset a released, under-threshold dismiss is animating back from, or
  // null when no such return is running. Driven by the settle controller.
  Offset? _dismissReturnFrom;

  // Guards against reacting to the controller writes we make ourselves.
  bool _writingController = false;
  bool _writingScaleState = false;

  // The last transform this state wrote or took in, so an outside write can be
  // told apart field by field.
  late PhotoViewControllerValue _lastValue;

  PhotoViewGeometry get _geometry => PhotoViewGeometry(
    boundaries: widget.scaleBoundaries,
    basePosition: widget.basePosition,
  );

  double get _scale =>
      widget.controller.scale ?? widget.scaleBoundaries.initialScale;

  /// Cached rather than read on demand, because it is needed from gesture
  /// callbacks, where depending on an inherited widget is not allowed.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this, duration: _kSettleDuration)
      ..addListener(_onSettleTick);
    _settleCurve = CurvedAnimation(parent: _settle, curve: Curves.easeOutCubic);
    _lastValue = widget.controller.value;
    widget.controller.addListener(_onControllerChanged);
    widget.scaleStateController.addListener(_onScaleStateChanged);
    _resolveScaleForBoundaries();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(PhotoViewCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _lastValue = widget.controller.value;
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.scaleStateController != widget.scaleStateController) {
      oldWidget.scaleStateController.removeListener(_onScaleStateChanged);
      widget.scaleStateController.addListener(_onScaleStateChanged);
    }
    if (oldWidget.scaleBoundaries != widget.scaleBoundaries ||
        oldWidget.controller != widget.controller) {
      _resolveScaleForBoundaries();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.scaleStateController.removeListener(_onScaleStateChanged);
    _settle.removeListener(_onSettleTick);
    _settleCurve.dispose();
    _settle.dispose();
    super.dispose();
  }

  // --- state plumbing -------------------------------------------------------

  void _writeController(PhotoViewControllerValue value) {
    _writingController = true;
    widget.controller.value = value;
    _lastValue = widget.controller.value;
    _writingController = false;
  }

  void _writeScaleState(PhotoViewScaleState state) {
    if (widget.scaleStateController.value == state) return;
    _writingScaleState = true;
    widget.scaleStateController.value = state;
    _writingScaleState = false;
  }

  Offset _clamp(Offset position, double scale) => widget.enablePanAlways
      ? position
      : _geometry.clampPosition(position: position, scale: scale);

  /// Resolves the scale against the current sizes, on first layout and whenever
  /// the viewport or the child changes size.
  ///
  /// A scale the user reached by hand is kept (only re-clamped), so rotating the
  /// device does not throw away their zoom; a scale that came from the double-tap
  /// cycle is recomputed, because "covering" means something different at a new
  /// size.
  void _resolveScaleForBoundaries() {
    final boundaries = widget.scaleBoundaries;
    final state = widget.scaleStateController.value;
    final current = widget.controller.scale;
    final scale = (current == null || !state.isZooming)
        ? boundaries.scaleForState(state)
        : boundaries.clampScale(current);
    _writeController(
      widget.controller.value.copyWith(
        scale: scale,
        position: _clamp(widget.controller.position, scale),
      ),
    );
  }

  /// Reacts to a write made from outside, by clamping it into range and syncing
  /// the double-tap cycle to whatever scale the caller asked for.
  void _onControllerChanged() {
    if (_writingController) return;
    final boundaries = widget.scaleBoundaries;
    final value = widget.controller.value;
    final scale = boundaries.clampScale(value.scale ?? boundaries.initialScale);
    final position = _clamp(value.position, scale);
    // Only a change of scale can move the view off the cycle. A caller that just
    // panned is still on whatever step it was on.
    if (value.scale != _lastValue.scale) _updateScaleStateFromScale(scale);
    if (scale != value.scale || position != value.position) {
      _writeController(value.copyWith(scale: scale, position: position));
    } else {
      _lastValue = value;
    }
  }

  /// Reacts to a cycle step set from outside or by a double tap, by animating to
  /// the scale that step resolves to.
  void _onScaleStateChanged() {
    if (_writingScaleState) return;
    final target = widget.scaleBoundaries.scaleForState(
      widget.scaleStateController.value,
    );
    final focal = _doubleTapFocal;
    _doubleTapFocal = null;
    // A double tap anchors the zoom where it landed; a programmatic change has
    // no focal point, so the child returns to its resting place. Either way the
    // cycle unwinds any rotation.
    final position = focal == null
        ? _clamp(Offset.zero, target)
        : _clamp(
            _positionForZoom(focal: focal, newScale: target, newRotation: 0),
            target,
          );
    _animateTo(scale: target, position: position, rotation: 0);
  }

  void _updateScaleStateFromScale(double scale) {
    final initial = widget.scaleBoundaries.initialScale;
    _writeScaleState(
      scale == initial
          ? PhotoViewScaleState.initial
          : scale > initial
          ? PhotoViewScaleState.zoomedIn
          : PhotoViewScaleState.zoomedOut,
    );
  }

  /// The position that pins the child point under [focal] in place while the
  /// scale moves from the current one to [newScale], and the rotation from the
  /// current one to [newRotation].
  Offset _positionForZoom({
    required Offset focal,
    required double newScale,
    double? newRotation,
  }) => _geometry.positionForFocalZoom(
    startFocal: focal,
    currentFocal: focal,
    startScale: _scale,
    startPosition: widget.controller.position,
    newScale: newScale,
    startRotation: widget.controller.rotation,
    newRotation: newRotation ?? widget.controller.rotation,
  );

  // --- animation ------------------------------------------------------------

  void _animateTo({double? scale, Offset? position, double? rotation}) {
    final value = widget.controller.value;
    _scaleTween = scale == null ? null : Tween(begin: _scale, end: scale);
    _positionTween = position == null
        ? null
        : Tween(begin: value.position, end: position);
    _rotationTween = rotation == null
        ? null
        : Tween(begin: value.rotation, end: rotation);

    if (_reduceMotion) {
      _settle.stop();
      _writeController(
        value.copyWith(scale: scale, position: position, rotation: rotation),
      );
      return;
    }
    _settle
      ..value = 0
      ..forward();
  }

  void _onSettleTick() {
    final t = _settleCurve.value;
    final returnFrom = _dismissReturnFrom;
    if (returnFrom != null) {
      final done = _settle.isCompleted;
      setState(() {
        _dismissOffset = done ? null : Offset.lerp(returnFrom, Offset.zero, t);
        if (done) _dismissReturnFrom = null;
      });
      return;
    }
    _writeController(
      widget.controller.value.copyWith(
        scale: _scaleTween?.transform(t),
        position: _positionTween?.transform(t),
        rotation: _rotationTween?.transform(t),
      ),
    );
  }

  // --- gestures -------------------------------------------------------------

  void _onScaleStart(ScaleStartDetails details) {
    _settle.stop();
    // A new gesture re-decides dismiss from scratch: drop any in-flight return
    // and the offset it was returning from.
    _dismissReturnFrom = null;
    if (_dismissOffset != null) setState(() => _dismissOffset = null);
    _startFocal = details.localFocalPoint;
    _startScale = _scale;
    _startPosition = widget.controller.position;
    _startRotation = widget.controller.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_maybeDrivesDismiss(details)) return;

    final startScale = _startScale;
    final startFocal = _startFocal;
    final startPosition = _startPosition;
    if (startScale == null || startFocal == null || startPosition == null) {
      return;
    }

    var scale = startScale * details.scale;
    // Without strictScale the pinch may overshoot the limits and springs back on
    // release, which is the softer, more common feel.
    if (widget.strictScale) scale = widget.scaleBoundaries.clampScale(scale);

    final rotation = widget.enableRotation
        ? _startRotation! + details.rotation
        : widget.controller.rotation;

    final position = _geometry.positionForFocalZoom(
      startFocal: startFocal,
      currentFocal: details.localFocalPoint,
      startScale: startScale,
      startPosition: startPosition,
      newScale: scale,
      startRotation: _startRotation!,
      newRotation: rotation,
    );

    // A drag, or a two-finger pan that holds its scale, leaves the cycle step
    // alone; only actually pinching takes the view off it.
    if (scale != startScale) _updateScaleStateFromScale(scale);
    _writeController(
      PhotoViewControllerValue(
        scale: scale,
        position: _clamp(position, scale),
        rotation: rotation,
      ),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_dismissOffset != null) {
      _endDismiss();
      return;
    }

    widget.onScaleEnd?.call(context, details, widget.controller.value);

    final boundaries = widget.scaleBoundaries;
    final scale = _scale;
    final position = widget.controller.position;

    // Spring back into range if the pinch overshot.
    if (scale > boundaries.maxScale || scale < boundaries.minScale) {
      final target = boundaries.clampScale(scale);
      final focal = _startFocal ?? _geometry.transformOrigin;
      _animateTo(
        scale: target,
        position: _clamp(
          _positionForZoom(focal: focal, newScale: target),
          target,
        ),
      );
      return;
    }

    // Carry a pan (but not a pinch) on past the finger.
    final magnitude = details.velocity.pixelsPerSecond.distance;
    final scaled = _startScale != null && (_startScale! - scale).abs() > 1e-6;
    if (!scaled && magnitude >= _kMinFlingVelocity) {
      final direction = details.velocity.pixelsPerSecond / magnitude;
      final target = position + direction * _kFlingDistance;
      _animateTo(position: _clamp(target, scale));
    }
  }

  // --- drag to dismiss ------------------------------------------------------

  /// Whether the child has no room to pan in either axis at the current scale,
  /// so a vertical drag is free to mean "dismiss" instead.
  ///
  /// This is true at the initial (contained) scale, and stays true all the way
  /// down through [PhotoViewScaleState.zoomedOut]: there the child is smaller
  /// still, so there is even less to pan than at rest. It goes false as soon as
  /// either axis overflows the viewport, which is what a pinch or a programmatic
  /// write past the initial scale does.
  bool get _hasNothingToPan {
    final boundaries = widget.scaleBoundaries;
    final scale = _scale;
    return boundaries.childSize.width * scale <= boundaries.outerSize.width &&
        boundaries.childSize.height * scale <= boundaries.outerSize.height;
  }

  /// Handles [details] as a drag-to-dismiss when one is enabled and the gesture
  /// qualifies, returning whether it did.
  ///
  /// A dismiss is a single-pointer, mostly-vertical drag begun with nothing to
  /// pan. Once one is under way it keeps the whole gesture, so adding a second
  /// finger part way through does not turn it back into a pinch.
  bool _maybeDrivesDismiss(ScaleUpdateDetails details) {
    if (widget.onDismiss == null) return false;
    if (_dismissOffset case final offset?) {
      setState(() => _dismissOffset = offset + details.focalPointDelta);
      return true;
    }
    if (details.pointerCount != 1 || !_hasNothingToPan) return false;
    final delta = details.focalPointDelta;
    if (delta.dy.abs() <= delta.dx.abs()) return false;
    setState(() => _dismissOffset = delta);
    return true;
  }

  /// Fraction of the way to the dismiss threshold the child has been dragged,
  /// from 0 at rest to 1 at the point a release would dismiss.
  double _dismissProgress(Offset offset) {
    final distance =
        widget.dismissThreshold * widget.scaleBoundaries.outerSize.height;
    if (distance <= 0) return 1;
    return (offset.dy.abs() / distance).clamp(0.0, 1.0);
  }

  /// Dismisses if the drag passed the threshold, otherwise animates the child
  /// back to rest.
  void _endDismiss() {
    final offset = _dismissOffset!;
    if (_dismissProgress(offset) >= 1) {
      // Clear first, so a caller that does not pop is left at rest rather than
      // frozen mid-drag.
      setState(() => _dismissOffset = null);
      widget.onDismiss!();
      return;
    }
    if (_reduceMotion) {
      setState(() => _dismissOffset = null);
      return;
    }
    _dismissReturnFrom = offset;
    _scaleTween = null;
    _positionTween = null;
    _rotationTween = null;
    _settle
      ..value = 0
      ..forward();
  }

  void _onDoubleTapDown(TapDownDetails details) =>
      _doubleTapFocal = details.localPosition;

  /// Drops the focal recorded by [_onDoubleTapDown] when the double tap it
  /// belonged to is abandoned, most often because the second tap turned into a
  /// drag.
  ///
  /// Without this the focal outlives its gesture and is spent by whatever
  /// changes the cycle step next, including a programmatic change that is meant
  /// to have no focal point at all.
  void _onDoubleTapCancel() => _doubleTapFocal = null;

  void _onDoubleTap() => _nextScaleState();

  /// Advances the double-tap cycle to the next step that actually changes the
  /// scale.
  ///
  /// Steps can collapse onto the same scale (on a square image in a square
  /// viewport, "covering" and "initial" are the same), and stopping there would
  /// make a double tap do nothing.
  void _nextScaleState() {
    final boundaries = widget.scaleBoundaries;
    final current = widget.scaleStateController.value;
    if (current.isZooming) {
      widget.scaleStateController.value = widget.scaleStateCycle(current);
      return;
    }

    final startScale = boundaries.scaleForState(current);
    var next = current;
    for (var i = 0; i < PhotoViewScaleState.values.length; i++) {
      next = widget.scaleStateCycle(next);
      if (boundaries.scaleForState(next) != startScale) {
        widget.scaleStateController.value = next;
        return;
      }
      if (next == current) break;
    }
  }

  // --- pointer signals ------------------------------------------------------

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enableScrollZoom || widget.disableGestures) return;

    switch (event) {
      case final PointerScrollEvent event:
        // A two-finger trackpad scroll reads as panning, not zooming; a mouse
        // wheel reads as zooming.
        if (event.kind == PointerDeviceKind.trackpad) {
          if (!_canPanBy(-event.scrollDelta)) return;
          GestureBinding.instance.pointerSignalResolver.register(
            event,
            _handleTrackpadPan,
          );
          return;
        }
        if (event.scrollDelta.dy == 0) return;
        if (!_canScaleBy(_scaleChangeForScroll(event.scrollDelta.dy))) return;
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          _handleScrollZoom,
        );
      case final PointerScaleEvent event:
        if (!_canScaleBy(event.scale)) return;
        GestureBinding.instance.pointerSignalResolver.register(
          event,
          _handlePointerScale,
        );
      case _:
        return;
    }
  }

  static double _scaleChangeForScroll(double delta) =>
      math.exp(-delta / _kScrollZoomDivisor);

  /// Whether scaling by [factor] would change anything.
  ///
  /// When it would not — the view is pinned at a limit and the user keeps
  /// scrolling that way — the event is left unclaimed so an ancestor scrollable
  /// can use it instead of the scroll dying on the photo.
  bool _canScaleBy(double factor) =>
      widget.scaleBoundaries.clampScale(_scale * factor) != _scale;

  bool _canPanBy(Offset delta) =>
      _clamp(widget.controller.position + delta, _scale) !=
      widget.controller.position;

  void _handleScrollZoom(PointerSignalEvent event) {
    event as PointerScrollEvent;
    _zoomAt(event.localPosition, _scaleChangeForScroll(event.scrollDelta.dy));
  }

  void _handlePointerScale(PointerSignalEvent event) {
    event as PointerScaleEvent;
    _zoomAt(event.localPosition, event.scale);
  }

  void _handleTrackpadPan(PointerSignalEvent event) {
    event as PointerScrollEvent;
    _settle.stop();
    final target = widget.controller.position - event.scrollDelta;
    _writeController(
      widget.controller.value.copyWith(position: _clamp(target, _scale)),
    );
  }

  /// Zooms by [factor] keeping the child point under [focal] in place, with no
  /// animation: a wheel notch should land where it lands.
  void _zoomAt(Offset focal, double factor) {
    _settle.stop();
    final target = widget.scaleBoundaries.clampScale(_scale * factor);
    if (target == _scale) return;
    final position = _positionForZoom(focal: focal, newScale: target);
    _updateScaleStateFromScale(target);
    _writeController(
      widget.controller.value.copyWith(
        scale: target,
        position: _clamp(position, target),
      ),
    );
  }

  void _zoomByStep(double factor) => _zoomAt(_geometry.transformOrigin, factor);

  // --- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PhotoViewControllerValue>(
      valueListenable: widget.controller,
      // The child is passed through rather than rebuilt: an image does not need
      // to be rebuilt or laid out again for every frame of a pinch.
      child: _buildHero(),
      builder: (context, value, child) {
        final boundaries = widget.scaleBoundaries;
        final scale = value.scale ?? boundaries.initialScale;

        final Widget transformed = Transform(
          transform: _geometry.matrixFor(
            scale: scale,
            position: value.position,
            rotation: value.rotation,
          ),
          alignment: widget.basePosition,
          child: OverflowBox(
            alignment: widget.basePosition,
            minWidth: 0,
            maxWidth: double.infinity,
            minHeight: 0,
            maxHeight: double.infinity,
            child: SizedBox.fromSize(size: boundaries.childSize, child: child),
          ),
        );

        // Off the dismiss path the tree is exactly as it was: the background
        // wraps the child directly. During a dismiss the two are split so the
        // child can slide over a fading background.
        final dismiss = _dismissOffset;
        final Widget content = SizedBox.fromSize(
          size: boundaries.outerSize,
          child: dismiss == null
              ? DecoratedBox(
                  decoration: widget.backgroundDecoration,
                  child: transformed,
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: 1 - _dismissProgress(dismiss),
                      child: DecoratedBox(
                        decoration: widget.backgroundDecoration,
                      ),
                    ),
                    Transform.translate(offset: dismiss, child: transformed),
                  ],
                ),
        );

        return _buildSemantics(
          scale: scale,
          child: widget.disableGestures
              ? content
              : Listener(
                  onPointerSignal: _onPointerSignal,
                  child: PhotoViewGestureDetector(
                    behavior: widget.gestureDetectorBehavior,
                    hitDetector: EdgeHitDetector(
                      geometry: _geometry,
                      scale: scale,
                      position: value.position,
                    ),
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    onDoubleTapDown: _onDoubleTapDown,
                    onDoubleTap: _onDoubleTap,
                    onDoubleTapCancel: _onDoubleTapCancel,
                    onTapUp: widget.onTapUp == null
                        ? null
                        : (details) => widget.onTapUp!(context, details, value),
                    onTapDown: widget.onTapDown == null
                        ? null
                        : (details) =>
                              widget.onTapDown!(context, details, value),
                    child: content,
                  ),
                ),
        );
      },
    );
  }

  /// Exposes the zoom level and zoom actions to screen readers.
  ///
  /// The value is a percentage of [ScaleBoundaries.initialScale], so 100% is the
  /// view as it first appeared rather than the image's pixel size, which is what
  /// a reader of the screen is comparing against.
  Widget _buildSemantics({required double scale, required Widget child}) {
    if (widget.disableGestures) {
      return Semantics(label: widget.semanticLabel, image: true, child: child);
    }
    final boundaries = widget.scaleBoundaries;
    String percentOf(double value) =>
        '${(value / boundaries.initialScale * 100).round()}%';
    return Semantics(
      label: widget.semanticLabel,
      image: widget.imageProvider != null,
      value: percentOf(scale),
      // The framework requires a value for an action it is offered alongside.
      increasedValue: percentOf(
        boundaries.clampScale(scale * _kSemanticsZoomStep),
      ),
      decreasedValue: percentOf(
        boundaries.clampScale(scale / _kSemanticsZoomStep),
      ),
      onIncrease: _canScaleBy(_kSemanticsZoomStep)
          ? () => _zoomByStep(_kSemanticsZoomStep)
          : null,
      onDecrease: _canScaleBy(1 / _kSemanticsZoomStep)
          ? () => _zoomByStep(1 / _kSemanticsZoomStep)
          : null,
      child: child,
    );
  }

  Widget _buildHero() {
    final attributes = widget.heroAttributes;
    final child = _buildChild();
    if (attributes == null) return child;
    return Hero(
      tag: attributes.tag,
      createRectTween: attributes.createRectTween,
      flightShuttleBuilder: attributes.flightShuttleBuilder,
      placeholderBuilder: attributes.placeholderBuilder,
      transitionOnUserGestures: attributes.transitionOnUserGestures,
      child: child,
    );
  }

  Widget _buildChild() {
    final customChild = widget.customChild;
    if (customChild != null) return customChild;
    return Image(
      image: widget.imageProvider!,
      gaplessPlayback: widget.gaplessPlayback,
      filterQuality: widget.filterQuality ?? FilterQuality.medium,
      excludeFromSemantics: true,
      fit: BoxFit.contain,
    );
  }
}
