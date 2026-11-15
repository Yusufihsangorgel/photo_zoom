// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';
import 'package:photo_zoom_example/main.dart';
import 'package:photo_zoom_example/migrating_from_photo_view.dart';

void main() {
  testWidgets('the home screen opens the migration page', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    await tester.tap(find.text('Migration'));
    // Fixed frames, not pumpAndSettle. A bundled image decodes as real async
    // work that the fake clock of a widget test does not wait for. Its section
    // keeps an animated spinner up meanwhile, and pumpAndSettle would time
    // out. The missing asset of the errorBuilder section fails at once.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MigratedPage), findsOneWidget);
    expect(find.text('Migrated from photo_view'), findsOneWidget);
  });

  testWidgets('each section builds as it scrolls in', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MigratedPage()));
    await tester.pump();

    final sections = <String, Finder>{
      'Controller and scale limits': find.byType(Detail),
      'customChild and childSize': find.byWidgetPredicate(
        (widget) => widget is PhotoView && widget.childSize != null,
      ),
      'errorBuilder': find.byWidgetPredicate(
        (widget) => widget is PhotoView && widget.errorBuilder != null,
      ),
      'Tap and scale callbacks': find.byWidgetPredicate(
        (widget) =>
            widget is PhotoView &&
            widget.onTapUp != null &&
            widget.onScaleEnd != null,
      ),
      'Gallery': find.byType(PhotoViewGallery),
      'Swipe to dismiss': find.text('Open a photo you can swipe away'),
      'Sharing a drag with this list': find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is PhotoView &&
              widget.imageProvider == const AssetImage('assets/tower.png'),
        ),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is PhotoViewGestureDetectorScope &&
              widget.axis == Axis.vertical,
        ),
      ),
    };

    for (final title in sections.keys) {
      await reveal(tester, find.text(title));
      expect(find.text(title), findsOneWidget);
      expect(sections[title]!, findsWidgets);
    }
  });

  testWidgets('the dismiss section opens a photo you can swipe away', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MigratedPage()));
    await tester.pump();

    final button = find.text('Open a photo you can swipe away');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is PhotoView && widget.onDismiss != null,
      ),
      findsOneWidget,
    );
    expect(find.text('Swipe down to dismiss'), findsOneWidget);
  });
}

/// Scrolls the page's own list until [finder] is built and on screen.
///
/// A jump of the scroll position, not a drag. The sections sit inside gesture
/// detectors of their own, and a drag would enter their arena. Fixed pumps
/// after each jump, for the reason given above the first test.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final list = find
      .descendant(
        of: find.byType(MigratedPage),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(list).position;

  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty && tester.getTopLeft(finder).dy <= 480) {
      return;
    }
    final next = position.pixels + 200;
    position.jumpTo(
      next > position.maxScrollExtent ? position.maxScrollExtent : next,
    );
    await tester.pump();
  }
  fail('never reached $finder');
}
