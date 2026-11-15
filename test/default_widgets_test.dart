import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom/src/default_widgets.dart';

import 'helpers.dart';

void main() {
  tearDown(() => PaintingBinding.instance.imageCache.clear());

  group('library imports', () {
    // Any import or export of the Material or Cupertino libraries, including
    // their `src/` files.
    final designLibrary = RegExp(
      r'''^\s*(import|export)\s+['"]package:flutter/(src/)?(material|cupertino)[./]''',
      multiLine: true,
    );

    test('the pattern catches the imports it is meant to', () {
      expect(
        designLibrary.hasMatch("import 'package:flutter/material.dart';"),
        isTrue,
      );
      expect(
        designLibrary.hasMatch('export "package:flutter/cupertino.dart";'),
        isTrue,
      );
      expect(
        designLibrary.hasMatch(
          "import 'package:flutter/src/material/colors.dart';",
        ),
        isTrue,
      );
      expect(
        designLibrary.hasMatch("import 'package:flutter/widgets.dart';"),
        isFalse,
      );
    });

    test('no file in lib imports Material or Cupertino', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      final offenders = [
        for (final file in files)
          if (designLibrary.hasMatch(file.readAsStringSync())) file.path,
      ];
      expect(offenders, isEmpty);
    });
  });

  group('default error', () {
    testWidgets('renders without a Material ancestor or an icon font', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(child: const PhotoView(imageProvider: FailingImageProvider())),
      );
      await tester.pumpAndSettle();
      // With no errorBuilder the error is rethrown in debug builds.
      expect(tester.takeException(), isException);

      final error = find.byType(PhotoViewDefaultError);
      expect(error, findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      // An icon from a font is drawn as text. Nothing here is.
      expect(
        find.descendant(of: error, matching: find.byType(RichText)),
        findsNothing,
      );
      final glyph = find.descendant(
        of: error,
        matching: find.byType(CustomPaint),
      );
      expect(glyph, findsOneWidget);
      expect(
        tester.widget<CustomPaint>(glyph).painter,
        isA<PhotoViewBrokenImagePainter>(),
      );
      expect(tester.getSize(glyph), const Size.square(40));
      expect(
        tester.renderObject(glyph),
        paints
          ..rrect(style: PaintingStyle.stroke)
          ..path(style: PaintingStyle.stroke)
          ..line(),
      );
    });
  });

  group('default loading', () {
    testWidgets('settles while an image never resolves', (tester) async {
      // Before 1.3.0 the default was an indeterminate spinner, and
      // pumpAndSettle timed out on any screen that had one.
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: _ChunkImageProvider(_ChunkCompleter()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewDefaultLoading), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('settles when the expected size is unknown', (tester) async {
      final completer = _ChunkCompleter();
      await tester.pumpWidget(
        harness(
          child: PhotoView(imageProvider: _ChunkImageProvider(completer)),
        ),
      );
      completer.chunk(
        const ImageChunkEvent(
          cumulativeBytesLoaded: 10,
          expectedTotalBytes: null,
        ),
      );
      await tester.pumpAndSettle();

      final painter = _painterIn(tester);
      expect(painter.value, isNull);
      expect(painter.sweepAngle, 0);
      expect(
        tester.renderObject(_ringFinder),
        isNot(paints..arc()),
        reason: 'unknown progress draws the ring only',
      );
      expect(
        tester.renderObject(_ringFinder),
        paints..circle(style: PaintingStyle.stroke, color: _glyphGrey),
        reason: 'the ring is drawn at full opacity when progress is unknown',
      );
    });

    testWidgets('fills in proportion to the bytes loaded', (tester) async {
      final handle = tester.ensureSemantics();
      final completer = _ChunkCompleter();
      await tester.pumpWidget(
        harness(
          child: PhotoView(imageProvider: _ChunkImageProvider(completer)),
        ),
      );

      completer.chunk(
        const ImageChunkEvent(
          cumulativeBytesLoaded: 30,
          expectedTotalBytes: 120,
        ),
      );
      await tester.pumpAndSettle();
      expect(_painterIn(tester).value, 0.25);
      expect(
        tester.renderObject(_ringFinder),
        paints
          ..circle(
            style: PaintingStyle.stroke,
            color: _glyphGrey.withAlpha(0x66),
          )
          ..arc(
            startAngle: -math.pi / 2,
            sweepAngle: math.pi / 2,
            color: _glyphGrey,
          ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Loading image')).value,
        '25%',
      );

      completer.chunk(
        const ImageChunkEvent(
          cumulativeBytesLoaded: 90,
          expectedTotalBytes: 120,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.renderObject(_ringFinder),
        paints
          ..circle()
          ..arc(startAngle: -math.pi / 2, sweepAngle: 3 * math.pi / 2),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Loading image')).value,
        '75%',
      );

      handle.dispose();
    });

    testWidgets('has a label and no value while progress is unknown', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          child: PhotoView(
            imageProvider: _ChunkImageProvider(_ChunkCompleter()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(find.bySemanticsLabel('Loading image'));
      expect(node.value, isEmpty);

      handle.dispose();
    });
  });

  group('painters', () {
    const grey = Color(0xFF808080);

    test('the progress painter repaints when its value or colour changes', () {
      const old = PhotoViewProgressPainter(value: 0.2, color: grey);

      expect(
        const PhotoViewProgressPainter(
          value: 0.6,
          color: grey,
        ).shouldRepaint(old),
        isTrue,
      );
      expect(
        const PhotoViewProgressPainter(
          value: null,
          color: grey,
        ).shouldRepaint(old),
        isTrue,
      );
      expect(
        const PhotoViewProgressPainter(
          value: 0.2,
          color: Color(0xFF000000),
        ).shouldRepaint(old),
        isTrue,
      );
      expect(
        const PhotoViewProgressPainter(
          value: 0.2,
          color: grey,
        ).shouldRepaint(old),
        isFalse,
      );
    });

    test('the broken image painter repaints when its colour changes', () {
      const old = PhotoViewBrokenImagePainter(color: grey);

      expect(
        const PhotoViewBrokenImagePainter(
          color: Color(0xFF000000),
        ).shouldRepaint(old),
        isTrue,
      );
      expect(
        const PhotoViewBrokenImagePainter(color: grey).shouldRepaint(old),
        isFalse,
      );
    });

    testWidgets('the ring paints the new arc when the progress changes', (
      tester,
    ) async {
      final completer = _ChunkCompleter();
      await tester.pumpWidget(
        harness(
          child: PhotoView(imageProvider: _ChunkImageProvider(completer)),
        ),
      );

      completer.chunk(
        const ImageChunkEvent(
          cumulativeBytesLoaded: 20,
          expectedTotalBytes: 100,
        ),
      );
      await tester.pump();
      expect(
        tester.renderObject(_ringFinder),
        paints..arc(sweepAngle: 2 * math.pi * 0.2),
      );

      completer.chunk(
        const ImageChunkEvent(
          cumulativeBytesLoaded: 60,
          expectedTotalBytes: 100,
        ),
      );
      await tester.pump();
      expect(
        tester.renderObject(_ringFinder),
        paints..arc(sweepAngle: 2 * math.pi * 0.6),
      );
    });
  });
}

const Color _glyphGrey = Color(0xFFBDBDBD);

final Finder _ringFinder = find.descendant(
  of: find.byType(PhotoViewDefaultLoading),
  matching: find.byType(CustomPaint),
);

PhotoViewProgressPainter _painterIn(WidgetTester tester) =>
    tester.widget<CustomPaint>(_ringFinder).painter!
        as PhotoViewProgressPainter;

/// An image stream that only ever reports what the test tells it to.
class _ChunkCompleter extends ImageStreamCompleter {
  void chunk(ImageChunkEvent event) => reportImageChunkEvent(event);
}

class _ChunkImageProvider extends ImageProvider<_ChunkImageProvider> {
  _ChunkImageProvider(this.completer);

  final _ChunkCompleter completer;

  @override
  Future<_ChunkImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ChunkImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _ChunkImageProvider key,
    ImageDecoderCallback decode,
  ) => completer;
}
