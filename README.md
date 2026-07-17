# photo_zoom

Pan, zoom and rotate images, and swipe through a gallery of them.

```dart
import 'package:photo_zoom/photo_zoom.dart';

PhotoView(imageProvider: const AssetImage('assets/photo.jpg'))
```

Drag to pan, pinch to zoom, double tap to cycle through fit, fill and actual
size. On desktop and web the mouse wheel zooms at the pointer and a two-finger
trackpad scroll pans.

The API follows the [photo_view] package by Renan C. Araújo, which is MIT
licensed. Class names and most parameters are the same, so moving across is
mostly a change of import; [the differences](#migrating-from-photo_view) are
listed below.

[photo_view]: https://pub.dev/packages/photo_view

## Zoom lands where you put it

Zooming, by any means, keeps the point you started from under your finger or
pointer:

```dart
PhotoView(
  imageProvider: const NetworkImage('https://example.com/map.png'),
  minScale: PhotoViewComputedScale.contained * 0.8,
  maxScale: PhotoViewComputedScale.covered * 3,
)
```

Double tap a corner and that corner zooms, rather than the middle of the image
sliding into view. The same anchoring applies to a pinch and to a wheel scroll.

## Gallery

```dart
PhotoViewGallery.builder(
  itemCount: photos.length,
  onPageChanged: (index) => setState(() => _current = index),
  builder: (context, index) => PhotoViewGalleryPageOptions(
    imageProvider: NetworkImage(photos[index].url),
    heroAttributes: PhotoViewHeroAttributes(tag: photos[index].id),
  ),
)
```

Each page keeps its own zoom. A drag pans the photo while it has room to move,
and turns the page once the photo is against its edge, so panning a zoomed photo
does not flip the page out from under it.

## Parts

| Class | Role |
|---|---|
| `PhotoView` | One zoomable image, or any widget via `PhotoView.customChild` |
| `PhotoViewGallery` | A `PageView` of them, from a list or built on demand |
| `PhotoViewController` | Reads and drives the transform; a `ValueNotifier` |
| `PhotoViewScaleStateController` | Reads and drives the double tap cycle |
| `PhotoViewScale` | `PhotoViewScale.value(2)`, or a `PhotoViewComputedScale` |
| `PhotoViewHeroAttributes` | The `Hero` configuration for a view |
| `PhotoViewGestureDetectorScope` | Shares drags with a gesture-sensitive parent |

## Driving it from code

`PhotoViewController` is a `ValueNotifier`, so read it with a
`ValueListenableBuilder` and write to it directly:

```dart
final controller = PhotoViewController();

PhotoView(imageProvider: provider, controller: controller);

controller.scale = 2;   // clamped into minScale..maxScale
controller.reset();     // back to the start

ValueListenableBuilder(
  valueListenable: controller,
  builder: (context, value, _) => Text('${value.scale}'),
);
```

Whoever creates a controller disposes it. A controller you do not pass is
created and disposed by the view itself.

## Desktop and web

`enableScrollZoom` (on by default) wires up the mouse wheel and trackpad. Events
the view cannot act on are left alone rather than swallowed: a scroll-to-zoom-in
while already at `maxScale`, or a trackpad pan with nowhere left to pan, falls
through to an ancestor scrollable, so a photo in a scrolling page does not trap
the wheel.

## Accessibility

The current zoom is exposed to screen readers as a percentage of `initialScale`,
alongside `semanticLabel`, with increase and decrease actions that zoom in steps.
When the platform asks for reduced motion, zoom changes jump to their target
instead of animating.

## Limits

- The view fills the box it is given, so it needs a bounded one. In an unbounded
  parent, pass `customSize`.
- `PhotoView.customChild` transforms a widget; it does not arbitrate with
  gestures inside that widget. A child with its own pan or tap handlers will
  fight the view. Use `disableGestures: true` and drive the controller yourself.
- Rotation (`enableRotation`) turns the child about `basePosition`, not about the
  centre of the pinch. The double tap cycle unwinds it back to zero.
- No video, and no widget-per-frame content. `imageProvider` resolves once to
  learn the image's size; an animated GIF plays, but its first frame sets the
  size.
- `filterQuality` applies to `PhotoView.new` only. `PhotoView.customChild` draws
  whatever the child draws.
- The gallery does not loop; page 0 is the first page.
- `tightMode` from photo_view is not carried over. Wrap the view in a `SizedBox`
  of the size you want instead.

## Migrating from photo_view

Most code moves across with the import alone. What differs:

| photo_view | photo_zoom | Why |
|---|---|---|
| `photo_view.dart` + `photo_view_gallery.dart` | one `photo_zoom.dart` | One entry point |
| `minScale: 0.5` | `minScale: PhotoViewScale.value(0.5)` | `dynamic` became a type, so a bad value is a compile error, not a runtime assert |
| `minScale: PhotoViewComputedScale.contained * 0.8` | unchanged | |
| `controller.outputStateStream.listen(fn)` | `controller.addListener(fn)`, or a `ValueListenableBuilder` | The controller is a `ValueNotifier`; no stream, and updates land on the same frame |
| `PhotoViewControllerBase`, `addIgnorableListener`, `setScaleInvisibly`, `setInvisibly` | removed | Internals that leaked into the public API |
| `PhotoViewControllerValue.rotationFocusPoint` | removed | It was stored and streamed but never reached the transform |
| `PhotoViewScaleState.isScaleStateZooming` | `.isZooming` | |
| `tightMode: true` | removed | Wrap in a `SizedBox` |
| `PhotoViewGestureDetectorScope(axis: null)` | `axis` is required | A scope without an axis did nothing |
| `PhotoViewGallery(..., scaleStateChangedCallback:)` | unchanged | |
| double tap and pinch zoom towards `basePosition` | they zoom at the touch | [#82], [#394], [#538] |
| mouse wheel ignored | wheel zooms, trackpad pans | [#481] |
| `strictScale` freezes the whole gesture past a limit | the scale clamps, the pan keeps working | |
| n/a | `enableScrollZoom` | New |

[#82]: https://github.com/bluefireteam/photo_view/issues/82
[#394]: https://github.com/bluefireteam/photo_view/issues/394
[#538]: https://github.com/bluefireteam/photo_view/issues/538
[#481]: https://github.com/bluefireteam/photo_view/issues/481

Controllers behave the same in one respect worth repeating: whoever creates one
disposes it.

## Example

`example/` is a gallery: a grid of thumbnails that fly into a full screen
`PhotoViewGallery` with a live zoom readout.

```sh
cd example && flutter run
```

## License

MIT. The API and the scale and pan behaviour are derived from
[photo_view], also MIT, by Renan C. Araújo.
