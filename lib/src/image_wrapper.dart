import 'package:flutter/widgets.dart';

import 'callbacks.dart';
import 'default_widgets.dart';
import 'photo_view_controller.dart';
import 'photo_view_core.dart';
import 'photo_view_hero_attributes.dart';
import 'photo_view_scale.dart';
import 'scale_boundaries.dart';

/// Resolves [imageProvider] far enough to learn the image's intrinsic size,
/// then hands over to [PhotoViewCore].
///
/// The size has to be known before anything can be drawn, because
/// [PhotoViewComputedScale.contained] and [PhotoViewComputedScale.covered] are
/// ratios between the image and the viewport. Until it is known, the loading
/// builder is shown.
class ImageWrapper extends StatefulWidget {
  /// Creates a wrapper around [imageProvider].
  const ImageWrapper({
    super.key,
    required this.imageProvider,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.backgroundDecoration,
    required this.semanticLabel,
    required this.gaplessPlayback,
    required this.filterQuality,
    required this.heroAttributes,
    required this.controller,
    required this.scaleStateController,
    required this.minScale,
    required this.maxScale,
    required this.initialScale,
    required this.outerSize,
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
  });

  /// The image to resolve and display.
  final ImageProvider imageProvider;

  /// Shown while the image resolves.
  final LoadingBuilder? loadingBuilder;

  /// Shown when the image fails to resolve.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// Painted behind the image.
  final Decoration backgroundDecoration;

  /// Describes the image to screen readers.
  final String? semanticLabel;

  /// Whether to keep the old image on screen while a new one resolves.
  final bool gaplessPlayback;

  /// The sampling quality of the image.
  final FilterQuality? filterQuality;

  /// The hero configuration, if any.
  final PhotoViewHeroAttributes? heroAttributes;

  /// The transform controller.
  final PhotoViewController controller;

  /// The double-tap cycle controller.
  final PhotoViewScaleStateController scaleStateController;

  /// The smallest allowed scale.
  final PhotoViewScale minScale;

  /// The largest allowed scale.
  final PhotoViewScale maxScale;

  /// The scale before any gesture.
  final PhotoViewScale initialScale;

  /// The viewport size.
  final Size outerSize;

  /// The double-tap cycle.
  final ScaleStateCycle scaleStateCycle;

  /// Where the image rests inside the viewport.
  final Alignment basePosition;

  /// Whether two-finger rotation is enabled.
  final bool enableRotation;

  /// Whether wheel and trackpad zoom are enabled.
  final bool enableScrollZoom;

  /// Whether panning is allowed past the viewport edges.
  final bool enablePanAlways;

  /// Whether a pinch is hard-clamped rather than allowed to overshoot.
  final bool strictScale;

  /// Whether all gestures are off.
  final bool disableGestures;

  /// The hit test behavior of the gesture detector.
  final HitTestBehavior? gestureDetectorBehavior;

  /// Called on tap up.
  final PhotoViewImageTapUpCallback? onTapUp;

  /// Called on tap down.
  final PhotoViewImageTapDownCallback? onTapDown;

  /// Called when a pinch or pan ends.
  final PhotoViewImageScaleEndCallback? onScaleEnd;

  @override
  State<ImageWrapper> createState() => _ImageWrapperState();
}

class _ImageWrapperState extends State<ImageWrapper> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageChunkEvent? _progress;
  Size? _imageSize;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(ImageWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageProvider != oldWidget.imageProvider) {
      if (!widget.gaplessPlayback) {
        _imageSize = null;
        _error = null;
        _stackTrace = null;
      }
      _resolveImage();
    }
  }

  @override
  void dispose() {
    _stopStream();
    super.dispose();
  }

  void _resolveImage() {
    final stream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) return;
    _stopStream();
    _stream = stream;
    _listener = ImageStreamListener(
      _handleFrame,
      onChunk: _handleChunk,
      onError: _handleError,
    );
    stream.addListener(_listener!);
  }

  void _stopStream() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _listener = null;
  }

  void _handleFrame(ImageInfo info, bool synchronousCall) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    // Only the dimensions are needed here; the [Image] inside [PhotoViewCore]
    // resolves its own handle from the cache. Holding on to this one would leak
    // it for as long as the view lives.
    info.dispose();

    void apply() {
      _imageSize = size;
      _progress = null;
      _error = null;
      _stackTrace = null;
    }

    if (synchronousCall) {
      apply();
    } else if (mounted) {
      setState(apply);
    }
  }

  void _handleChunk(ImageChunkEvent event) {
    if (!mounted) return;
    setState(() {
      _progress = event;
      _error = null;
    });
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (!mounted) return;
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
      _progress = null;
    });
    assert(() {
      if (widget.errorBuilder == null) throw error;
      return true;
    }());
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error, _stackTrace) ??
          PhotoViewDefaultError(decoration: widget.backgroundDecoration);
    }

    final imageSize = _imageSize;
    if (imageSize == null) {
      return widget.loadingBuilder?.call(context, _progress) ??
          PhotoViewDefaultLoading(event: _progress);
    }

    return PhotoViewCore(
      imageProvider: widget.imageProvider,
      semanticLabel: widget.semanticLabel,
      gaplessPlayback: widget.gaplessPlayback,
      filterQuality: widget.filterQuality,
      backgroundDecoration: widget.backgroundDecoration,
      heroAttributes: widget.heroAttributes,
      controller: widget.controller,
      scaleStateController: widget.scaleStateController,
      scaleBoundaries: ScaleBoundaries(
        minScale: widget.minScale,
        maxScale: widget.maxScale,
        initialScale: widget.initialScale,
        outerSize: widget.outerSize,
        childSize: imageSize,
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
}
