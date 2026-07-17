import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decodes a blank [width]x[height] image.
///
/// Deliberately not `createTestImage`: that one runs inside a
/// [TestAsyncUtils.guard], which does not nest with the guard a `testWidgets`
/// body already holds, so calling it from `setUp` upsets every later test.
Future<ui.Image> makeTestImage(int width, int height) {
  final completer = Completer<ui.Image>();
  final pixels = Uint8List(width * height * 4)
    ..fillRange(0, width * height * 4, 0xFF);
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

/// An [ImageProvider] that resolves synchronously to an image of a known size,
/// so tests can assert on scales computed from it without pumping.
class TestImageProvider extends ImageProvider<TestImageProvider> {
  TestImageProvider(this.image, {this.label = 'test'});

  final ui.Image image;
  final String label;

  @override
  Future<TestImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<TestImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    TestImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())),
  );

  @override
  String toString() => 'TestImageProvider($label)';
}

/// An [ImageProvider] that always fails, for exercising error builders.
class FailingImageProvider extends ImageProvider<FailingImageProvider> {
  const FailingImageProvider();

  @override
  Future<FailingImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FailingImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    FailingImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    Future<ImageInfo>.error(Exception('no such image')),
  );
}

/// Puts [child] in a [size]d box at the top left of the test window, so global
/// tap coordinates and the view's local coordinates are the same.
Widget harness({required Widget child, Size size = const Size(400, 400)}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    );

/// Taps twice at [location], fast enough to register as a double tap.
Future<void> doubleTapAt(WidgetTester tester, Offset location) async {
  await tester.tapAt(location);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(location);
  await tester.pumpAndSettle();
}

/// Sends a mouse wheel scroll of [delta] at [location].
Future<void> scrollAt(
  WidgetTester tester,
  Offset location,
  Offset delta,
) async {
  final pointer = TestPointer(1, PointerDeviceKind.mouse);
  pointer.hover(location);
  await tester.sendEventToBinding(pointer.scroll(delta));
  await tester.pump();
}

/// Matches a double within [epsilon].
Matcher closeToD(double value, [double epsilon = 0.01]) =>
    closeTo(value, epsilon);

/// Matches an [Offset] whose components are both within [epsilon].
Matcher offsetCloseTo(Offset value, [double epsilon = 0.01]) =>
    predicate<Offset>(
      (actual) =>
          (actual.dx - value.dx).abs() < epsilon &&
          (actual.dy - value.dy).abs() < epsilon,
      'is within $epsilon of $value',
    );
