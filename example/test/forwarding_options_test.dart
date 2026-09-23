import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom_example/forwarding_options.dart';

PhotoViewScaleState cycle(PhotoViewScaleState actual) =>
    PhotoViewScaleState.initial;

void main() {
  const provider = AssetImage('assets/detail.png');

  test('fields left out match arguments left out', () {
    final wrapped = const ViewerOptions().pageOptions(provider);
    const plain = PhotoViewGalleryPageOptions(imageProvider: provider);
    expect(wrapped.minScale, plain.minScale);
    expect(wrapped.maxScale, plain.maxScale);
    expect(wrapped.initialScale, plain.initialScale);
    expect(wrapped.basePosition, plain.basePosition);
    expect(wrapped.scaleStateCycle, plain.scaleStateCycle);
    expect(wrapped.disableGestures, plain.disableGestures);
  });

  test('fields that are set reach the page options', () {
    final wrapped = ViewerOptions(
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: const PhotoViewScale.value(1),
      basePosition: Alignment.topLeft,
      scaleStateCycle: cycle,
      disableGestures: true,
    ).pageOptions(provider);
    expect(wrapped.minScale, PhotoViewComputedScale.contained * 0.8);
    expect(wrapped.maxScale, PhotoViewComputedScale.covered * 3);
    expect(wrapped.initialScale, const PhotoViewScale.value(1));
    expect(wrapped.basePosition, Alignment.topLeft);
    expect(wrapped.scaleStateCycle, cycle);
    expect(wrapped.disableGestures, true);
  });
}
