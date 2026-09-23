import 'package:flutter/widgets.dart';
import 'package:photo_zoom/photo_zoom.dart';

/// App-level viewer settings that are handed to every gallery page.
///
/// photo_view accepted `null` for these parameters and fell back to a default
/// inside the view. Here the parameters are non-nullable, and the fields start
/// at the package defaults: a field left out gives the same page as the
/// argument left out.
class ViewerOptions {
  const ViewerOptions({
    this.minScale = const PhotoViewScale.value(0),
    this.maxScale = const PhotoViewScale.value(double.infinity),
    this.initialScale = PhotoViewComputedScale.contained,
    this.basePosition = Alignment.center,
    this.scaleStateCycle = defaultScaleStateCycle,
    this.disableGestures = false,
  });

  final PhotoViewScale minScale;
  final PhotoViewScale maxScale;
  final PhotoViewScale initialScale;
  final Alignment basePosition;
  final ScaleStateCycle scaleStateCycle;
  final bool disableGestures;

  PhotoViewGalleryPageOptions pageOptions(ImageProvider imageProvider) =>
      PhotoViewGalleryPageOptions(
        imageProvider: imageProvider,
        minScale: minScale,
        maxScale: maxScale,
        initialScale: initialScale,
        basePosition: basePosition,
        scaleStateCycle: scaleStateCycle,
        disableGestures: disableGestures,
      );
}
