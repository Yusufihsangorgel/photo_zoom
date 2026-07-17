import 'package:flutter/material.dart';

import 'callbacks.dart';
import 'image_wrapper.dart';
import 'photo_view_controller.dart';
import 'photo_view_core.dart';
import 'photo_view_hero_attributes.dart';
import 'photo_view_scale.dart';
import 'photo_view_scale_state.dart';
import 'scale_boundaries.dart';

const BoxDecoration _kDefaultDecoration = BoxDecoration(
  color: Color(0xFF000000),
);

/// A pannable, zoomable, optionally rotatable view of a single image or widget.
///
/// It fills the space it is given, so it needs a bounded box: a [Scaffold] body,
/// a [SizedBox], an [Expanded], or a route of its own.
///
/// ```dart
/// PhotoView(imageProvider: const AssetImage('assets/photo.jpg'))
/// ```
///
/// Drag to pan, pinch to zoom, and double tap to walk the
/// [scaleStateCycle]. On desktop and web the mouse wheel zooms at the pointer
/// and a two-finger trackpad scroll pans; see [enableScrollZoom].
///
/// ## Scale limits
///
/// [minScale], [maxScale] and [initialScale] take a [PhotoViewScale]: either an
/// absolute [PhotoViewScale.value], or a [PhotoViewComputedScale] resolved
/// against the image and viewport sizes at layout time.
///
/// ```dart
/// PhotoView(
///   imageProvider: const AssetImage('assets/photo.jpg'),
///   minScale: PhotoViewComputedScale.contained * 0.8,
///   maxScale: PhotoViewComputedScale.covered * 3,
///   initialScale: PhotoViewComputedScale.contained,
/// )
/// ```
///
/// ## Driving it from outside
///
/// Pass a [controller] to read or write the transform, and a
/// [scaleStateController] to read or write the double-tap cycle. Both are
/// [ValueNotifier]s, and both must be disposed by whoever created them.
///
/// ```dart
/// final controller = PhotoViewController();
///
/// PhotoView(imageProvider: provider, controller: controller);
///
/// controller.scale = 2;   // zooms in
/// controller.reset();     // back to the start
/// ```
///
/// ## A widget instead of an image
///
/// [PhotoView.customChild] zooms any widget. It needs a [childSize] to compute
/// [PhotoViewComputedScale] against.
///
/// See also:
///
///  * [PhotoViewGallery], for a swipeable series of these.
///  * [InteractiveViewer], Flutter's built-in pan/zoom widget, which has no
///    image loading, double-tap cycle, or gallery.
class PhotoView extends StatefulWidget {
  /// Creates a view of the image behind [imageProvider].
  ///
  /// The image is resolved before anything is drawn, because its intrinsic size
  /// is what [PhotoViewComputedScale] is computed against; [loadingBuilder] is
  /// shown until then.
  const PhotoView({
    super.key,
    required this.imageProvider,
    this.loadingBuilder,
    this.errorBuilder,
    this.backgroundDecoration = _kDefaultDecoration,
    this.wantKeepAlive = false,
    this.semanticLabel,
    this.gaplessPlayback = false,
    this.filterQuality,
    this.heroAttributes,
    this.scaleStateChangedCallback,
    this.controller,
    this.scaleStateController,
    this.minScale = const PhotoViewScale.value(0),
    this.maxScale = const PhotoViewScale.value(double.infinity),
    this.initialScale = PhotoViewComputedScale.contained,
    this.basePosition = Alignment.center,
    this.scaleStateCycle = defaultScaleStateCycle,
    this.customSize,
    this.enableRotation = false,
    this.enableScrollZoom = true,
    this.enablePanAlways = false,
    this.strictScale = false,
    this.disableGestures = false,
    this.gestureDetectorBehavior,
    this.onTapUp,
    this.onTapDown,
    this.onScaleEnd,
  }) : child = null,
       childSize = null;

  /// Creates a view of an arbitrary [child], such as a diagram, a map, or an
  /// SVG.
  ///
  /// [childSize] is the child's intrinsic size, which [PhotoViewComputedScale]
  /// is computed against. Leaving it `null` falls back to the viewport size,
  /// which makes [PhotoViewComputedScale.contained] resolve to `1.0`.
  const PhotoView.customChild({
    super.key,
    required this.child,
    this.childSize,
    this.backgroundDecoration = _kDefaultDecoration,
    this.wantKeepAlive = false,
    this.semanticLabel,
    this.heroAttributes,
    this.scaleStateChangedCallback,
    this.controller,
    this.scaleStateController,
    this.minScale = const PhotoViewScale.value(0),
    this.maxScale = const PhotoViewScale.value(double.infinity),
    this.initialScale = PhotoViewComputedScale.contained,
    this.basePosition = Alignment.center,
    this.scaleStateCycle = defaultScaleStateCycle,
    this.customSize,
    this.enableRotation = false,
    this.enableScrollZoom = true,
    this.enablePanAlways = false,
    this.strictScale = false,
    this.disableGestures = false,
    this.gestureDetectorBehavior,
    this.onTapUp,
    this.onTapDown,
    this.onScaleEnd,
  }) : imageProvider = null,
       loadingBuilder = null,
       errorBuilder = null,
       gaplessPlayback = false,
       filterQuality = null;

  /// The image to display. Non-null for [PhotoView.new], null for
  /// [PhotoView.customChild].
  final ImageProvider? imageProvider;

  /// The widget to display. Non-null for [PhotoView.customChild], null for
  /// [PhotoView.new].
  final Widget? child;

  /// The intrinsic size of [child], used to compute [PhotoViewComputedScale].
  ///
  /// Defaults to the viewport size.
  final Size? childSize;

  /// Shown while [imageProvider] resolves.
  ///
  /// Defaults to a small centred [CircularProgressIndicator]. The
  /// [ImageChunkEvent] is `null` for providers that do not report progress, such
  /// as [AssetImage].
  final LoadingBuilder? loadingBuilder;

  /// Shown when [imageProvider] fails to resolve.
  ///
  /// Defaults to a broken-image icon. When this is `null`, the error is also
  /// rethrown in debug builds so it is not swallowed silently.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Painted behind the image, filling the viewport.
  ///
  /// Defaults to opaque black.
  final Decoration backgroundDecoration;

  /// Whether to keep this view alive when it scrolls out of a lazy list.
  ///
  /// In a [PhotoViewGallery], `true` keeps each page's zoom while the user swipes
  /// away and back. Defaults to `false`.
  final bool wantKeepAlive;

  /// Describes the content to screen readers.
  ///
  /// The current zoom level is exposed alongside it automatically, as a
  /// percentage of [initialScale].
  final String? semanticLabel;

  /// Whether to keep showing the old image while a new [imageProvider] resolves,
  /// rather than falling back to [loadingBuilder]. Defaults to `false`.
  final bool gaplessPlayback;

  /// The sampling quality of the image. Defaults to [FilterQuality.medium].
  ///
  /// Ignored by [PhotoView.customChild], which draws whatever the child draws.
  final FilterQuality? filterQuality;

  /// The [Hero] configuration, or `null` for no hero transition.
  final PhotoViewHeroAttributes? heroAttributes;

  /// Called whenever the step of [scaleStateCycle] changes.
  ///
  /// For the transform itself, listen to a [controller] instead.
  final ValueChanged<PhotoViewScaleState>? scaleStateChangedCallback;

  /// Reads and drives the transform.
  ///
  /// When null, one is created internally and disposed with the view. When
  /// given, it belongs to the caller and is never disposed here.
  final PhotoViewController? controller;

  /// Reads and drives the step of [scaleStateCycle].
  ///
  /// When null, one is created internally and disposed with the view. When
  /// given, it belongs to the caller and is never disposed here.
  final PhotoViewScaleStateController? scaleStateController;

  /// The smallest scale a gesture may reach. Defaults to no lower limit.
  final PhotoViewScale minScale;

  /// The largest scale a gesture may reach. Defaults to no upper limit.
  ///
  /// If it resolves below [minScale], [minScale] wins.
  final PhotoViewScale maxScale;

  /// The scale before any gesture. Defaults to [PhotoViewComputedScale.contained],
  /// so the whole image is visible.
  ///
  /// Clamped into [[minScale], [maxScale]].
  final PhotoViewScale initialScale;

  /// Where the child rests inside the viewport, and the point zoom and rotation
  /// are anchored to. Defaults to [Alignment.center].
  final Alignment basePosition;

  /// The double-tap cycle. Defaults to [defaultScaleStateCycle].
  ///
  /// ```dart
  /// // Double tap toggles between fit and 2x, skipping original size:
  /// scaleStateCycle: (actual) => switch (actual) {
  ///   PhotoViewScaleState.initial => PhotoViewScaleState.covering,
  ///   _ => PhotoViewScaleState.initial,
  /// },
  /// ```
  final ScaleStateCycle scaleStateCycle;

  /// Overrides the viewport size [PhotoViewComputedScale] and the pan bounds are
  /// computed against. Defaults to the size this widget is given.
  final Size? customSize;

  /// Whether a two-finger twist rotates the child. Defaults to `false`.
  ///
  /// Rotation is anchored at [basePosition], and is reset to zero by the
  /// double-tap cycle.
  final bool enableRotation;

  /// Whether a mouse wheel zooms at the pointer and a two-finger trackpad scroll
  /// pans. Defaults to `true`.
  ///
  /// Events that would change nothing — a scroll-to-zoom-in while already at
  /// [maxScale], a trackpad pan with nowhere to pan — are left to an ancestor
  /// scrollable rather than swallowed.
  final bool enableScrollZoom;

  /// Whether the child may be panned past the viewport edges. Defaults to
  /// `false`, which keeps the child's edges pinned to the viewport once it is
  /// larger than it.
  final bool enablePanAlways;

  /// Whether a pinch is clamped to [minScale] and [maxScale] as it happens,
  /// rather than being allowed to overshoot and spring back on release.
  /// Defaults to `false`.
  final bool strictScale;

  /// Whether to drop the gesture detector entirely. Defaults to `false`.
  ///
  /// Useful when the child brings its own gestures, or the view is decorative.
  final bool disableGestures;

  /// The [HitTestBehavior] of the internal gesture detector.
  final HitTestBehavior? gestureDetectorBehavior;

  /// Called when a tap lands on the view, with the transform at that moment.
  final PhotoViewImageTapUpCallback? onTapUp;

  /// Called when a pointer contacts the view, with the transform at that moment.
  final PhotoViewImageTapDownCallback? onTapDown;

  /// Called when a pinch or pan ends, with the transform at that moment.
  final PhotoViewImageScaleEndCallback? onScaleEnd;

  @override
  State<PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<PhotoView>
    with AutomaticKeepAliveClientMixin {
  PhotoViewController? _ownedController;
  PhotoViewScaleStateController? _ownedScaleStateController;

  PhotoViewController get _controller => widget.controller ?? _ownedController!;
  PhotoViewScaleStateController get _scaleStateController =>
      widget.scaleStateController ?? _ownedScaleStateController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownedController = PhotoViewController();
    if (widget.scaleStateController == null) {
      _ownedScaleStateController = PhotoViewScaleStateController();
    }
    _scaleStateController.addListener(_onScaleStateChanged);
  }

  @override
  void didUpdateWidget(PhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      if (widget.controller != null) {
        _ownedController?.dispose();
        _ownedController = null;
      } else {
        _ownedController ??= PhotoViewController();
      }
    }

    if (widget.scaleStateController != oldWidget.scaleStateController) {
      _scaleStateController.removeListener(_onScaleStateChanged);
      if (widget.scaleStateController != null) {
        _ownedScaleStateController?.dispose();
        _ownedScaleStateController = null;
      } else {
        _ownedScaleStateController ??= PhotoViewScaleStateController();
      }
      _scaleStateController.addListener(_onScaleStateChanged);
    }
  }

  @override
  void dispose() {
    _scaleStateController.removeListener(_onScaleStateChanged);
    _ownedController?.dispose();
    _ownedScaleStateController?.dispose();
    super.dispose();
  }

  void _onScaleStateChanged() =>
      widget.scaleStateChangedCallback?.call(_scaleStateController.value);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final outerSize = widget.customSize ?? constraints.biggest;
        assert(
          outerSize.isFinite,
          'PhotoView was given unbounded constraints ($constraints) and no '
          'customSize, so it cannot work out how big the viewport is. Put it in '
          'a box with a bounded size, or pass customSize.',
        );

        final child = widget.child;
        if (child != null) {
          return PhotoViewCore.customChild(
            customChild: child,
            semanticLabel: widget.semanticLabel,
            backgroundDecoration: widget.backgroundDecoration,
            heroAttributes: widget.heroAttributes,
            controller: _controller,
            scaleStateController: _scaleStateController,
            scaleBoundaries: ScaleBoundaries(
              minScale: widget.minScale,
              maxScale: widget.maxScale,
              initialScale: widget.initialScale,
              outerSize: outerSize,
              childSize: widget.childSize ?? outerSize,
            ),
            scaleStateCycle: widget.scaleStateCycle,
            basePosition: widget.basePosition,
            enableRotation: widget.enableRotation,
            enableScrollZoom: widget.enableScrollZoom,
            enablePanAlways: widget.enablePanAlways,
            strictScale: widget.strictScale,
            disableGestures: widget.disableGestures,
            gestureDetectorBehavior: widget.gestureDetectorBehavior,
            onTapUp: widget.onTapUp,
            onTapDown: widget.onTapDown,
            onScaleEnd: widget.onScaleEnd,
          );
        }

        return ImageWrapper(
          imageProvider: widget.imageProvider!,
          loadingBuilder: widget.loadingBuilder,
          errorBuilder: widget.errorBuilder,
          backgroundDecoration: widget.backgroundDecoration,
          semanticLabel: widget.semanticLabel,
          gaplessPlayback: widget.gaplessPlayback,
          filterQuality: widget.filterQuality,
          heroAttributes: widget.heroAttributes,
          controller: _controller,
          scaleStateController: _scaleStateController,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          initialScale: widget.initialScale,
          outerSize: outerSize,
          scaleStateCycle: widget.scaleStateCycle,
          basePosition: widget.basePosition,
          enableRotation: widget.enableRotation,
          enableScrollZoom: widget.enableScrollZoom,
          enablePanAlways: widget.enablePanAlways,
          strictScale: widget.strictScale,
          disableGestures: widget.disableGestures,
          gestureDetectorBehavior: widget.gestureDetectorBehavior,
          onTapUp: widget.onTapUp,
          onTapDown: widget.onTapDown,
          onScaleEnd: widget.onScaleEnd,
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => widget.wantKeepAlive;
}
