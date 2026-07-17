import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_zoom/photo_zoom.dart';

import 'helpers.dart';

void main() {
  // A 200x100 image in a 400x400 page: contained is 2.0, covered is 4.0.
  late ui.Image image;

  setUp(() async {
    image = await makeTestImage(200, 100);
  });

  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    image.dispose();
  });

  Future<void> pumpGallery(
    WidgetTester tester, {
    required Widget gallery,
    Size size = const Size(400, 400),
  }) async {
    await tester.pumpWidget(harness(size: size, child: gallery));
    await tester.pump();
  }

  group('paging', () {
    testWidgets('builds pages from a list', (tester) async {
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery(
          pageOptions: [
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
          ],
        ),
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(PhotoView), findsOneWidget);
    });

    testWidgets('builds pages on demand', (tester) async {
      final built = <int>[];
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery.builder(
          itemCount: 100,
          builder: (context, index) {
            built.add(index);
            return PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            );
          },
        ),
      );
      // A hundred pages, but only the visible one built.
      expect(built, isNot(contains(50)));
      expect(built, contains(0));
    });

    testWidgets('swipes between pages and reports the change', (tester) async {
      final changed = <int>[];
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery.builder(
          itemCount: 3,
          onPageChanged: changed.add,
          builder: (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: TestImageProvider(image),
          ),
        ),
      );

      // At the contained scale the photo has no room to pan sideways, so the
      // drag belongs to the page view.
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(changed, [1]);

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(changed, [1, 2]);
    });

    testWidgets('a custom child page renders', (tester) async {
      await pumpGallery(
        tester,
        gallery: const PhotoViewGallery(
          pageOptions: [
            PhotoViewGalleryPageOptions.customChild(
              child: Text('page one'),
              childSize: Size(200, 100),
            ),
          ],
        ),
      );
      expect(find.text('page one'), findsOneWidget);
    });
  });

  group('per page state', () {
    testWidgets('each page zooms on its own', (tester) async {
      final first = PhotoViewController();
      final second = PhotoViewController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      await pumpGallery(
        tester,
        gallery: PhotoViewGallery(
          pageOptions: [
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
              controller: first,
            ),
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
              controller: second,
            ),
          ],
        ),
      );

      expect(first.scale, 2);
      first.scale = 4;
      await tester.pumpAndSettle();

      expect(first.scale, 4);
      // The second page never resolved its own scale, and certainly did not take
      // the first page's.
      expect(second.scale, isNot(4));
    });

    testWidgets('a page without a controller makes its own', (tester) async {
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery(
          pageOptions: [
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
          ],
        ),
      );
      await doubleTapAt(tester, const Offset(200, 200));

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      // The second page comes up at its own contained scale, not the first
      // page's zoom, and nothing threw on the way.
      expect(tester.takeException(), isNull);
      expect(find.byType(PhotoView), findsOneWidget);
    });
  });

  group('gesture priority', () {
    testWidgets('a zoomed page pans instead of turning the page', (
      tester,
    ) async {
      final changed = <int>[];
      final controller = PhotoViewController();
      addTearDown(controller.dispose);

      await pumpGallery(
        tester,
        gallery: PhotoViewGallery(
          onPageChanged: changed.add,
          pageOptions: [
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
              controller: controller,
              // 4x: 800 wide in a 400 wide page, so +/-200 to pan.
              initialScale: PhotoViewComputedScale.covered,
            ),
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
          ],
        ),
      );
      expect(controller.scale, 4);

      await tester.drag(find.byType(PageView), const Offset(-100, 0));
      await tester.pumpAndSettle();

      expect(controller.position.dx, lessThan(0));
      expect(changed, isEmpty);
    });

    testWidgets('a page panned to its edge hands the drag to the page view', (
      tester,
    ) async {
      final changed = <int>[];
      final controller = PhotoViewController();
      addTearDown(controller.dispose);

      await pumpGallery(
        tester,
        gallery: PhotoViewGallery(
          onPageChanged: changed.add,
          pageOptions: [
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
              controller: controller,
              initialScale: PhotoViewComputedScale.covered,
            ),
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
          ],
        ),
      );

      // Pan all the way to the right-hand edge of the photo.
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(controller.position.dx, closeToD(-200));
      expect(changed, isEmpty);

      // With the photo against its edge, the next drag is the page view's.
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(changed, [1]);
    });

    testWidgets('a vertical gallery hands back vertical drags', (tester) async {
      final changed = <int>[];
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery.builder(
          scrollDirection: Axis.vertical,
          itemCount: 3,
          onPageChanged: changed.add,
          builder: (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: TestImageProvider(image),
          ),
        ),
      );

      await tester.drag(find.byType(PageView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(changed, [1]);
    });

    testWidgets('the gallery scope tells pages which axis to yield on', (
      tester,
    ) async {
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery.builder(
          scrollDirection: Axis.vertical,
          itemCount: 1,
          builder: (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: TestImageProvider(image),
          ),
        ),
      );
      final scope = tester.widget<PhotoViewGestureDetectorScope>(
        find.byType(PhotoViewGestureDetectorScope),
      );
      expect(scope.axis, Axis.vertical);
    });
  });

  group('lifecycle', () {
    testWidgets('does not dispose a page controller it did not create', (
      tester,
    ) async {
      final pageController = PageController();
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery.builder(
          itemCount: 3,
          pageController: pageController,
          builder: (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: TestImageProvider(image),
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox());
      // A disposed ScrollController throws from addListener.
      expect(() => pageController.addListener(() {}), returnsNormally);
      pageController.dispose();
    });

    testWidgets('tears down its own page controller', (tester) async {
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery.builder(
          itemCount: 3,
          builder: (context, index) => PhotoViewGalleryPageOptions(
            imageProvider: TestImageProvider(image),
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox());
      // A leaked PageController would trip the binding's leak checks here.
      expect(tester.takeException(), isNull);
    });

    testWidgets('wantKeepAlive holds a page zoom across a swipe', (
      tester,
    ) async {
      final controller = PhotoViewController();
      addTearDown(controller.dispose);
      await pumpGallery(
        tester,
        gallery: PhotoViewGallery(
          wantKeepAlive: true,
          pageOptions: [
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
              controller: controller,
            ),
            PhotoViewGalleryPageOptions(
              imageProvider: TestImageProvider(image),
            ),
          ],
        ),
      );

      controller.scale = 3;
      await tester.pumpAndSettle();

      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(400, 0));
      await tester.pumpAndSettle();

      expect(controller.scale, 3);
    });
  });
}
