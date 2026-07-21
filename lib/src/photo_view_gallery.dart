import 'package:flutter/material.dart';

import 'callbacks.dart';
import 'photo_view.dart';
import 'photo_view_controller.dart';
import 'photo_view_gesture_detector.dart';
import 'photo_view_hero_attributes.dart';
import 'photo_view_scale.dart';
import 'photo_view_scale_state.dart';

/// Signature for [PhotoViewGallery.onPageChanged].
typedef PhotoViewGalleryPageChangedCallback = void Function(int index);

/// Signature for [PhotoViewGallery.builder].
typedef PhotoViewGalleryBuilder =
    PhotoViewGalleryPageOptions Function(BuildContext context, int index);

/// A swipeable series of [PhotoView]s in a [PageView].
///
/// Each page keeps its own zoom, and a page only gives a drag to the page view
/// once its photo has been panned to the edge, so panning a zoomed photo does
/// not flip the page out from under it.
///
/// With a fixed list of pages:
///
/// ```dart
/// PhotoViewGallery(
///   pageOptions: [
///     PhotoViewGalleryPageOptions(
///       imageProvider: const AssetImage('assets/1.jpg'),
///       heroAttributes: const PhotoViewHeroAttributes(tag: 'photo-1'),
///     ),
///     PhotoViewGalleryPageOptions(
///       imageProvider: const AssetImage('assets/2.jpg'),
///       maxScale: PhotoViewComputedScale.covered * 2,
///     ),
///   ],
/// )
/// ```
///
/// Or built lazily, which is what a gallery of any size wants:
///
/// ```dart
/// PhotoViewGallery.builder(
///   itemCount: photos.length,
///   builder: (context, index) => PhotoViewGalleryPageOptions(
///     imageProvider: NetworkImage(photos[index].url),
///     heroAttributes: PhotoViewHeroAttributes(tag: photos[index].id),
///   ),
///   onPageChanged: (index) => setState(() => _current = index),
/// )
/// ```
class PhotoViewGallery extends StatefulWidget {
  /// Creates a gallery from a fixed list of [pageOptions].
  const PhotoViewGallery({
    super.key,
    required List<PhotoViewGalleryPageOptions> this.pageOptions,
    this.loadingBuilder,
    this.backgroundDecoration = const BoxDecoration(color: Color(0xFF000000)),
    this.wantKeepAlive = false,
    this.gaplessPlayback = false,
    this.reverse = false,
    this.pageController,
    this.onPageChanged,
    this.scaleStateChangedCallback,
    this.enableRotation = false,
    this.enableScrollZoom = true,
    this.scrollPhysics,
    this.scrollDirection = Axis.horizontal,
    this.customSize,
    this.allowImplicitScrolling = false,
    this.pageSnapping = true,
    this.onDismiss,
    this.dismissThreshold = 0.2,
  }) : itemCount = null,
       builder = null;

  /// Creates a gallery whose [itemCount] pages are built on demand by [builder].
  const PhotoViewGallery.builder({
    super.key,
    required int this.itemCount,
    required PhotoViewGalleryBuilder this.builder,
    this.loadingBuilder,
    this.backgroundDecoration = const BoxDecoration(color: Color(0xFF000000)),
    this.wantKeepAlive = false,
    this.gaplessPlayback = false,
    this.reverse = false,
    this.pageController,
    this.onPageChanged,
    this.scaleStateChangedCallback,
    this.enableRotation = false,
    this.enableScrollZoom = true,
    this.scrollPhysics,
    this.scrollDirection = Axis.horizontal,
    this.customSize,
    this.allowImplicitScrolling = false,
    this.pageSnapping = true,
    this.onDismiss,
    this.dismissThreshold = 0.2,
  }) : pageOptions = null;

  /// The pages, when built from a fixed list.
  final List<PhotoViewGalleryPageOptions>? pageOptions;

  /// The number of pages, when built lazily.
  final int? itemCount;

  /// Builds a page, when built lazily.
  final PhotoViewGalleryBuilder? builder;

  /// Mirrors [PhotoView.loadingBuilder], for every page.
  final LoadingBuilder? loadingBuilder;

  /// Mirrors [PhotoView.backgroundDecoration], for every page.
  final Decoration backgroundDecoration;

  /// Mirrors [PhotoView.wantKeepAlive], for every page.
  ///
  /// `true` keeps each page's zoom while the user swipes away and back, at the
  /// cost of holding the pages in memory.
  final bool wantKeepAlive;

  /// Mirrors [PhotoView.gaplessPlayback], for every page.
  final bool gaplessPlayback;

  /// Mirrors [PageView.reverse].
  final bool reverse;

  /// Controls the underlying [PageView].
  ///
  /// When null, one is created internally and disposed with the gallery. When
  /// given, it belongs to the caller and is never disposed here.
  final PageController? pageController;

  /// Called when the visible page changes.
  final PhotoViewGalleryPageChangedCallback? onPageChanged;

  /// Mirrors [PhotoView.scaleStateChangedCallback], for every page.
  final ValueChanged<PhotoViewScaleState>? scaleStateChangedCallback;

  /// Mirrors [PhotoView.enableRotation], for every page.
  final bool enableRotation;

  /// Mirrors [PhotoView.enableScrollZoom], for every page.
  final bool enableScrollZoom;

  /// Mirrors [PhotoView.customSize], for every page.
  final Size? customSize;

  /// Mirrors [PageView.physics].
  final ScrollPhysics? scrollPhysics;

  /// Mirrors [PageView.scrollDirection]. Defaults to [Axis.horizontal].
  ///
  /// This is also the axis pages hand their edge drags back on.
  final Axis scrollDirection;

  /// Mirrors [PageView.allowImplicitScrolling].
  final bool allowImplicitScrolling;

  /// Mirrors [PageView.pageSnapping].
  final bool pageSnapping;

  /// Mirrors [PhotoView.onDismiss], for every page that does not set its own on
  /// its [PhotoViewGalleryPageOptions]. Swiping any page away calls this, so it
  /// usually pops the gallery route.
  final VoidCallback? onDismiss;

  /// Mirrors [PhotoView.dismissThreshold], used with the gallery-wide
  /// [onDismiss].
  final double dismissThreshold;

  /// The number of pages in the gallery.
  int get itemLength => itemCount ?? pageOptions!.length;

  @override
  State<PhotoViewGallery> createState() => _PhotoViewGalleryState();
}

class _PhotoViewGalleryState extends State<PhotoViewGallery> {
  PageController? _ownedController;

  PageController get _pageController =>
      widget.pageController ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.pageController == null) _ownedController = PageController();
  }

  @override
  void didUpdateWidget(PhotoViewGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageController != oldWidget.pageController) {
      if (widget.pageController != null) {
        _ownedController?.dispose();
        _ownedController = null;
      } else {
        _ownedController ??= PageController();
      }
    }
  }

  @override
  void dispose() {
    _ownedController?.dispose();
    super.dispose();
  }

  PhotoViewGalleryPageOptions _optionsFor(BuildContext context, int index) =>
      widget.builder?.call(context, index) ?? widget.pageOptions![index];

  @override
  Widget build(BuildContext context) {
    // Tells each page which axis it should hand its edge drags back on.
    return PhotoViewGestureDetectorScope(
      axis: widget.scrollDirection,
      child: PageView.builder(
        reverse: widget.reverse,
        controller: _pageController,
        onPageChanged: widget.onPageChanged,
        itemCount: widget.itemLength,
        scrollDirection: widget.scrollDirection,
        physics: widget.scrollPhysics,
        allowImplicitScrolling: widget.allowImplicitScrolling,
        pageSnapping: widget.pageSnapping,
        itemBuilder: _buildPage,
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index) {
    final options = _optionsFor(context, index);
    final child = options.child;

    // The key keeps each page's state, and so its zoom, tied to its index
    // rather than to its slot in the page view.
    final key = ValueKey(index);

    // A page's own onDismiss wins; failing that the gallery-wide one applies,
    // with the threshold that belongs to whichever won.
    final onDismiss = options.onDismiss ?? widget.onDismiss;
    final dismissThreshold = options.onDismiss != null
        ? options.dismissThreshold
        : widget.dismissThreshold;

    return ClipRect(
      child: child != null
          ? PhotoView.customChild(
              key: key,
              childSize: options.childSize,
              backgroundDecoration: widget.backgroundDecoration,
              wantKeepAlive: widget.wantKeepAlive,
              semanticLabel: options.semanticLabel,
              heroAttributes: options.heroAttributes,
              scaleStateChangedCallback: widget.scaleStateChangedCallback,
              controller: options.controller,
              scaleStateController: options.scaleStateController,
              minScale: options.minScale,
              maxScale: options.maxScale,
              initialScale: options.initialScale,
              basePosition: options.basePosition,
              scaleStateCycle: options.scaleStateCycle,
              customSize: widget.customSize,
              enableRotation: widget.enableRotation,
              enableScrollZoom: widget.enableScrollZoom,
              enablePanAlways: options.enablePanAlways,
              strictScale: options.strictScale,
              disableGestures: options.disableGestures,
              gestureDetectorBehavior: options.gestureDetectorBehavior,
              onTapUp: options.onTapUp,
              onTapDown: options.onTapDown,
              onScaleEnd: options.onScaleEnd,
              onDismiss: onDismiss,
              dismissThreshold: dismissThreshold,
              child: child,
            )
          : PhotoView(
              key: key,
              imageProvider: options.imageProvider,
              loadingBuilder: widget.loadingBuilder,
              errorBuilder: options.errorBuilder,
              backgroundDecoration: widget.backgroundDecoration,
              wantKeepAlive: widget.wantKeepAlive,
              semanticLabel: options.semanticLabel,
              gaplessPlayback: widget.gaplessPlayback,
              filterQuality: options.filterQuality,
              heroAttributes: options.heroAttributes,
              scaleStateChangedCallback: widget.scaleStateChangedCallback,
              controller: options.controller,
              scaleStateController: options.scaleStateController,
              minScale: options.minScale,
              maxScale: options.maxScale,
              initialScale: options.initialScale,
              basePosition: options.basePosition,
              scaleStateCycle: options.scaleStateCycle,
              customSize: widget.customSize,
              enableRotation: widget.enableRotation,
              enableScrollZoom: widget.enableScrollZoom,
              enablePanAlways: options.enablePanAlways,
              strictScale: options.strictScale,
              disableGestures: options.disableGestures,
              gestureDetectorBehavior: options.gestureDetectorBehavior,
              onTapUp: options.onTapUp,
              onTapDown: options.onTapDown,
              onScaleEnd: options.onScaleEnd,
              onDismiss: onDismiss,
              dismissThreshold: dismissThreshold,
            ),
    );
  }
}

/// The settings of a single page of a [PhotoViewGallery].
///
/// Everything here is per page; the settings that belong to the gallery as a
/// whole live on [PhotoViewGallery] itself.
class PhotoViewGalleryPageOptions {
  /// Creates a page showing the image behind [imageProvider].
  const PhotoViewGalleryPageOptions({
    required ImageProvider this.imageProvider,
    this.errorBuilder,
    this.semanticLabel,
    this.filterQuality,
    this.heroAttributes,
    this.controller,
    this.scaleStateController,
    this.minScale = const PhotoViewScale.value(0),
    this.maxScale = const PhotoViewScale.value(double.infinity),
    this.initialScale = PhotoViewComputedScale.contained,
    this.basePosition = Alignment.center,
    this.scaleStateCycle = defaultScaleStateCycle,
    this.enablePanAlways = false,
    this.strictScale = false,
    this.disableGestures = false,
    this.gestureDetectorBehavior,
    this.onTapUp,
    this.onTapDown,
    this.onScaleEnd,
    this.onDismiss,
    this.dismissThreshold = 0.2,
  }) : child = null,
       childSize = null;

  /// Creates a page showing an arbitrary [child].
  const PhotoViewGalleryPageOptions.customChild({
    required Widget this.child,
    this.childSize,
    this.semanticLabel,
    this.heroAttributes,
    this.controller,
    this.scaleStateController,
    this.minScale = const PhotoViewScale.value(0),
    this.maxScale = const PhotoViewScale.value(double.infinity),
    this.initialScale = PhotoViewComputedScale.contained,
    this.basePosition = Alignment.center,
    this.scaleStateCycle = defaultScaleStateCycle,
    this.enablePanAlways = false,
    this.strictScale = false,
    this.disableGestures = false,
    this.gestureDetectorBehavior,
    this.onTapUp,
    this.onTapDown,
    this.onScaleEnd,
    this.onDismiss,
    this.dismissThreshold = 0.2,
  }) : imageProvider = null,
       errorBuilder = null,
       filterQuality = null;

  /// Mirrors [PhotoView.imageProvider].
  final ImageProvider? imageProvider;

  /// Mirrors [PhotoView.child].
  final Widget? child;

  /// Mirrors [PhotoView.childSize].
  final Size? childSize;

  /// Mirrors [PhotoView.errorBuilder].
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Mirrors [PhotoView.semanticLabel].
  final String? semanticLabel;

  /// Mirrors [PhotoView.filterQuality].
  final FilterQuality? filterQuality;

  /// Mirrors [PhotoView.heroAttributes].
  final PhotoViewHeroAttributes? heroAttributes;

  /// Mirrors [PhotoView.controller].
  ///
  /// Leave it null and the page makes and disposes its own, which is what a
  /// lazily built gallery wants.
  final PhotoViewController? controller;

  /// Mirrors [PhotoView.scaleStateController].
  final PhotoViewScaleStateController? scaleStateController;

  /// Mirrors [PhotoView.minScale].
  final PhotoViewScale minScale;

  /// Mirrors [PhotoView.maxScale].
  final PhotoViewScale maxScale;

  /// Mirrors [PhotoView.initialScale].
  final PhotoViewScale initialScale;

  /// Mirrors [PhotoView.basePosition].
  final Alignment basePosition;

  /// Mirrors [PhotoView.scaleStateCycle].
  final ScaleStateCycle scaleStateCycle;

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

  /// Mirrors [PhotoView.onDismiss], overriding [PhotoViewGallery.onDismiss] for
  /// this page. When both are `null`, the page cannot be swiped away.
  final VoidCallback? onDismiss;

  /// Mirrors [PhotoView.dismissThreshold], used with this page's [onDismiss].
  final double dismissThreshold;
}
