// A measurement, not a guard: it drives synthesized drags of known length
// through a zoomed-in PhotoView and prints how far the image actually moved.
// It never fails on what it finds; the matching assertions live in
// test/short_pan_dead_zone_test.dart and test/pan_anchor_test.dart.
//
// Run with `flutter test tool/short_pan_matrix.dart`.
//
// ignore_for_file: avoid_print

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import '../test/helpers.dart';

const List<double> distances = [
  8, 12, 16, 17, 18, 19, 20, 24, 28, 32, 35, 36, 37, 40, 48, 64, //
];

const Offset start = Offset(200, 200);
const Duration frame = Duration(milliseconds: 16);

enum Pre { none, tapBefore, doubleTapZoom, scopeH }

String preLabel(Pre p) => switch (p) {
  Pre.none => 'none',
  Pre.tapBefore => 'tap 150ms before',
  Pre.doubleTapZoom => 'after double-tap zoom',
  Pre.scopeH => 'in Scope(axis: h)',
};

class Cell {
  Cell(this.moved, this.scaleAfter, this.startScale);
  final double moved;
  final double scaleAfter;
  final double startScale;
  bool get scaleChanged => (scaleAfter - startScale).abs() > 1e-6;
}

// Toggles initial <-> originalSize, so a double tap on a 1000x800 image in a
// 400x400 viewport goes from 0.4 (contained, nothing to pan) to 1.0, where
// there are 300 px of room on x and 200 px on y each way.
PhotoViewScaleState cycle(PhotoViewScaleState s) =>
    s == PhotoViewScaleState.originalSize
    ? PhotoViewScaleState.initial
    : PhotoViewScaleState.originalSize;

void main() {
  late ui.Image image;

  setUp(() async {
    image = await makeTestImage(1000, 800);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
  });

  Duration clock = Duration.zero;

  Future<void> advance(WidgetTester tester, Duration d) async {
    clock += d;
    await tester.pump(d);
  }

  Future<void> tap(WidgetTester tester, PointerDeviceKind kind) async {
    final g = await tester.createGesture(kind: kind);
    await g.down(start, timeStamp: clock);
    await advance(tester, const Duration(milliseconds: 50));
    await g.up(timeStamp: clock);
    if (kind == PointerDeviceKind.mouse) await g.removePointer();
  }

  Future<Cell> measure(
    WidgetTester tester, {
    required PointerDeviceKind kind,
    required Pre pre,
    required Offset direction,
    required double distance,
    required int steps,
  }) async {
    final controller = PhotoViewController();
    final scaleStateController = PhotoViewScaleStateController();
    Widget photo = PhotoView(
      key: UniqueKey(),
      imageProvider: TestImageProvider(image),
      controller: controller,
      scaleStateController: scaleStateController,
      scaleStateCycle: cycle,
    );
    if (pre == Pre.scopeH) {
      photo = PhotoViewGestureDetectorScope(
        axis: Axis.horizontal,
        child: photo,
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, height: 400, child: photo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    if (pre == Pre.doubleTapZoom) {
      await tap(tester, kind);
      await advance(tester, const Duration(milliseconds: 100));
      await tap(tester, kind);
      await tester.pumpAndSettle();
    } else {
      scaleStateController.scaleState = PhotoViewScaleState.originalSize;
      await tester.pumpAndSettle();
    }
    // Let any double-tap timer from the set-up run out.
    await advance(tester, const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final startScale = controller.scale!;
    expect(startScale, 1.0, reason: 'set-up must reach the zoomed scale');
    expect(controller.position, Offset.zero);

    if (pre == Pre.tapBefore) {
      await tap(tester, kind);
      await advance(tester, const Duration(milliseconds: 150));
    }

    final before = controller.position;
    final g = await tester.createGesture(kind: kind);
    await g.down(start, timeStamp: clock);
    await advance(tester, frame);
    final step = direction * (distance / steps);
    for (var i = 0; i < steps; i++) {
      await g.moveBy(step, timeStamp: clock);
      await advance(tester, frame);
    }
    final delta = controller.position - before;
    final moved = delta.dx * direction.dx + delta.dy * direction.dy;
    await g.up(timeStamp: clock);
    if (kind == PointerDeviceKind.mouse) await g.removePointer();
    await tester.pumpAndSettle();
    await advance(tester, const Duration(milliseconds: 500));
    final scaleAfter = controller.scale!;

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    scaleStateController.dispose();
    return Cell(moved, scaleAfter, startScale);
  }

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('short pan matrix, ${kind.name}', (tester) async {
      final out = StringBuffer();
      for (final steps in [1, 10]) {
        out
          ..writeln()
          ..writeln(
            '### ${kind.name}, $steps step${steps == 1 ? '' : 's'}'
            '${steps == 1 ? '' : ' (16 ms apart)'}: '
            'image displacement along the drag, px (expected = D)',
          )
          ..writeln();
        final header = StringBuffer('| D |');
        final rule = StringBuffer('|---:|');
        for (final pre in Pre.values) {
          for (final axis in ['x', 'y']) {
            header.write(' ${preLabel(pre)} $axis |');
            rule.write('---:|');
          }
        }
        out
          ..writeln(header)
          ..writeln(rule);
        for (final d in distances) {
          final row = StringBuffer('| $d |');
          for (final pre in Pre.values) {
            for (final dir in const [Offset(1, 0), Offset(0, 1)]) {
              final c = await measure(
                tester,
                kind: kind,
                pre: pre,
                direction: dir,
                distance: d,
                steps: steps,
              );
              final mark = c.scaleChanged
                  ? ' (scale ${c.startScale}->${c.scaleAfter.toStringAsFixed(2)})'
                  : '';
              row.write(' ${c.moved.toStringAsFixed(1)}$mark |');
            }
          }
          out.writeln(row);
        }
      }
      print(out);
    });
  }

  // The mechanism in isolation, with no photo_zoom code: where does a scale
  // recognizer's onStart place the focal point, with and without a double-tap
  // recognizer beside it in the arena?
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
      'mechanism: onStart focal with and without a DTGR, ${kind.name}',
      (tester) async {
        final out = StringBuffer()
          ..writeln()
          ..writeln(
            '### mechanism: plain ScaleGestureRecognizer(dragStartBehavior: start), '
            '${kind.name}, 10 steps along x',
          )
          ..writeln()
          ..writeln(
            '| D | SGR alone: onStart dx | SGR alone: last onUpdate dx '
            '| SGR+DTGR: onStart dx | SGR+DTGR: last onUpdate dx |',
          )
          ..writeln('|---:|---:|---:|---:|---:|');
        for (final d in distances) {
          final cells = <String>[];
          for (final withDoubleTap in [false, true]) {
            double? startDx;
            double? lastDx;
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              Directionality(
                textDirection: TextDirection.ltr,
                child: RawGestureDetector(
                  key: UniqueKey(),
                  behavior: HitTestBehavior.opaque,
                  gestures: <Type, GestureRecognizerFactory>{
                    if (withDoubleTap)
                      DoubleTapGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            DoubleTapGestureRecognizer
                          >(
                            DoubleTapGestureRecognizer.new,
                            (i) => i.onDoubleTap = () {},
                          ),
                    ScaleGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          ScaleGestureRecognizer
                        >(
                          ScaleGestureRecognizer.new,
                          (i) => i
                            ..dragStartBehavior = DragStartBehavior.start
                            ..onStart = (s) {
                              startDx = s.focalPoint.dx - start.dx;
                            }
                            ..onUpdate = (u) {
                              lastDx = u.focalPoint.dx - start.dx;
                            },
                        ),
                  },
                  child: const SizedBox(width: 400, height: 400),
                ),
              ),
            );
            final g = await tester.createGesture(kind: kind);
            await g.down(start, timeStamp: clock);
            await advance(tester, frame);
            for (var i = 0; i < 10; i++) {
              await g.moveBy(Offset(d / 10, 0), timeStamp: clock);
              await advance(tester, frame);
            }
            await g.up(timeStamp: clock);
            if (kind == PointerDeviceKind.mouse) await g.removePointer();
            await tester.pumpAndSettle();
            await advance(tester, const Duration(milliseconds: 500));
            cells
              ..add(startDx?.toStringAsFixed(1) ?? 'no start')
              ..add(lastDx?.toStringAsFixed(1) ?? '-');
          }
          out.writeln('| $d | ${cells.join(' | ')} |');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        print(out);
      },
    );
  }
}
