# photo_zoom

## Purpose

`PhotoView` pans, pinches, and double-taps one image (or any widget via `PhotoView.customChild`), zooming at the contact point rather than the centre. `PhotoViewGallery` is a `PageView` of those views: each page keeps its own zoom, and a drag turns the page only after the photo is against its edge.

Do not reach for this when `InteractiveViewer` already covers the case. `InteractiveViewer` pans and pinches; it has no double-tap scale cycle, no contained/covered/1.0 limits (`PhotoViewComputedScale`), no gallery, no image-edge pan clamp (it clamps against the wrapping widget, so a letterboxed image can be dragged into the empty margin), and no mouse-wheel or trackpad zoom (`PhotoView.enableScrollZoom`). Skip both for a decorative `Image` with `BoxFit`.

## Usage

Import `package:photo_zoom/photo_zoom.dart` only. `PhotoView` fills a finite box; a `Scaffold` body is one. Asset and scale limits from `example/lib/anchored_zoom_page.dart`:

```dart
Scaffold(
  body: PhotoView(
    imageProvider: const AssetImage('assets/detail.png'),
    minScale: PhotoViewComputedScale.contained,
    maxScale: PhotoViewComputedScale.covered * 3,
  ),
)
```

A gallery, from `example/lib/main.dart`. Callers who create `_controllers` and `_pageController` dispose them:

```dart
PhotoViewGallery.builder(
  itemCount: photos.length,
  pageController: _pageController,
  onPageChanged: (index) => setState(() => _index = index),
  builder: (context, index) {
    final photo = photos[index];
    return PhotoViewGalleryPageOptions(
      imageProvider: photo.provider,
      controller: _controllers[index],
      heroAttributes: PhotoViewHeroAttributes(tag: photo.id),
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 3,
    );
  },
)
```

## Contracts

**Controller ownership** — `PhotoView.controller` (`PhotoViewController`) and `PhotoView.scaleStateController` (`PhotoViewScaleStateController`). Both are `ValueNotifier`s. Null: the view creates and disposes them. Non-null: the caller creates them and must call `dispose()`; the view never disposes a controller it did not create. Same rule for `pageController` on `PhotoViewGallery` and for `controller` / `scaleStateController` on `PhotoViewGalleryPageOptions`. `scale` on `PhotoViewController` is `null` until first layout; writes are clamped into `minScale`..`maxScale`. `reset()` restores the constructor's starting transform.

**Parent sizes the viewport** — `PhotoView` fills the box it is given. `PhotoView.customSize` overrides that box. It must be finite: `Scaffold` body, `SizedBox`, `Expanded`, or a route. Unbounded constraints and no `customSize` assert. `PhotoView.customChild` needs `PhotoView.childSize` (the child's intrinsic size); leaving it null uses the viewport, so `PhotoViewComputedScale.contained` resolves to `1.0`.

**Gestures vs an enclosing scrollable** — `PhotoViewGallery` wraps its `PageView` in a `PhotoViewGestureDetectorScope` whose `axis` is `scrollDirection` (default `Axis.horizontal`). A lone `PhotoView` inside a `ListView`, `PageView`, or `Dismissible` does not. Wrap it; `axis` is required and must match the ancestor:

```dart
PhotoViewGestureDetectorScope(
  axis: Axis.vertical,
  child: PhotoView(imageProvider: const AssetImage('assets/detail.png')),
)
```

Without the scope the view does not yield the drag. Wheel and trackpad: `PhotoView.enableScrollZoom` defaults to `true`; an event that cannot change scale or pan is left unclaimed for an ancestor scrollable. `PhotoView.onDismiss` (default `null`) enables swipe-to-dismiss only while the photo has nothing to pan; a drag while zoomed still pans. `PhotoView.dismissThreshold` defaults to `0.2`. `PhotoView.customChild` does not share the arena with gestures inside the child.

**Scale limits** — `PhotoView.minScale`, `PhotoView.maxScale`, `PhotoView.initialScale` are `PhotoViewScale`, not `double`. Defaults: `minScale` = `PhotoViewScale.value(0)` (no floor), `maxScale` = `PhotoViewScale.value(double.infinity)` (no ceiling), `initialScale` = `PhotoViewComputedScale.contained`. `PhotoViewComputedScale.contained` is the largest scale that still shows the whole child; `PhotoViewComputedScale.covered` is the smallest that leaves no gaps; `PhotoViewScale.value(1)` is one source pixel per logical pixel. Offset a computed scale with `*` (`contained * 0.8`). If `maxScale` resolves below `minScale`, `minScale` wins; `initialScale` is clamped into that range.

## Mistakes

- **`PhotoView` in a `Column` or `ListView` with no height.** Symptom: debug assert `PhotoView was given unbounded constraints` (release: infinite viewport, broken layout). Fix: `Expanded`, a height-bounded `SizedBox`, or `customSize`. A gesture scope does not replace a bounded box.
- **`PhotoView` inside `ListView`/`PageView` without `PhotoViewGestureDetectorScope`.** Symptom: parent scroll and photo pan claim the same drag — paging a zoomed image, or a list that will not move. No exception. Fix: wrap with the scope, `axis` matching the parent. For paging photos, use `PhotoViewGallery` instead of a hand-rolled `PageView`.
- **`PhotoView` wrapped in `InteractiveViewer`, or a `customChild` that pans or taps.** Symptom: pinch and pan fight. No exception. Fix: do not nest the two. For a child with its own handlers, `PhotoView.disableGestures: true` and drive `PhotoViewController`.
- **Caller-created controller not disposed, or disposed while the view is mounted.** Symptom: leak, or `ValueNotifier` used after dispose. Fix: `dispose()` in the creating `State`, after the view is gone. If the caller does not need the controller, omit it.
- **`minScale: 0.8` (a `double`).** Symptom: compile error. Fix: `PhotoViewScale.value(0.8)` or `PhotoViewComputedScale.contained * 0.8`.
- **`PhotoView.customChild` without `childSize`.** Symptom: contained/covered ignore the child's intrinsic size; zoom looks like a no-op around `1.0`. Fix: pass `childSize`.
- **Gallery zoom reset after a swipe.** Symptom: leaving a page drops an internally-owned transform. Fix: pass a per-page `PhotoViewController` the caller owns (as in `example/lib/main.dart`), or `wantKeepAlive: true` on `PhotoViewGallery`.

## Layout

| Path | Role |
|------|------|
| `lib/photo_zoom.dart` | Public API (`package:photo_zoom/photo_zoom.dart`). Do not import `lib/src/`. |
| `lib/src/` | Implementation. |
| `test/` | Widget tests. |
| `example/lib/main.dart` | Gallery. |
| `example/lib/anchored_zoom_page.dart` | Single-view compare screen. |
| `tool/` | README figures, not the library. |

```sh
flutter test
cd example && flutter run
cd example && flutter run --dart-define=start=compare
```

If `example/` has no platform folders: `cd example && flutter create --platforms=ios,android,macos .`
