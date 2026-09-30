# Migrating from photo_view

This guide moves an app from `photo_view` to `photo_zoom`. It was written
against photo_view 0.15.0 (the newest version on pub.dev on 2026-09-30,
published 2024-04-17) and the code in this repository. Every row below was read
from both sources. Nothing here was measured on a device.

The API is the same one. Most of the work is the import and a few compile
errors. Run `dart analyze` after each step and let the errors tell you which
row of the table to read.

## Steps

1. In `pubspec.yaml`, replace `photo_view` with `photo_zoom`. This package needs
   Dart `^3.8.0` and Flutter `>=3.32.0`. photo_view 0.15.0 declares Dart
   `>=2.12.0 <4.0.0` and Flutter `>=1.6.0`. An app pinned to an older
   Flutter cannot move yet.
2. Replace both photo_view imports with one:

   ```dart
   // before
   import 'package:photo_view/photo_view.dart';
   import 'package:photo_view/photo_view_gallery.dart';

   // after
   import 'package:photo_zoom/photo_zoom.dart';
   ```

3. Fix what the analyzer reports, using the tables below.
4. Run the app and double tap a photo. It now zooms at the tap. If you have
   screenshots or tests recorded against photo_view's centre zoom, they will
   change.

## Mapping

### Classes

| photo_view 0.15.0 | photo_zoom | Notes |
|---|---|---|
| `PhotoView`, `PhotoView.customChild` | same names | The constructors are `const`. `PhotoView.customChild` also takes `semanticLabel`, `enableScrollZoom`, `onDismiss` and `dismissThreshold`. photo_view's has no `semanticLabel`. |
| `PhotoViewGallery`, `PhotoViewGallery.builder` | same names | Adds `enableScrollZoom`, `onDismiss` and `dismissThreshold`. |
| `PhotoViewGalleryPageOptions`, `.customChild` | same names | The constructors are `const` and have no `key` parameter. Remove a `key:` argument. Adds `enablePanAlways`, `strictScale`, `onDismiss` and `dismissThreshold`. |
| `PhotoViewController` | `PhotoViewController` | Now a `ValueNotifier<PhotoViewControllerValue>`. See the controller table. |
| `PhotoViewControllerBase` | removed | The `controller` parameter takes a `PhotoViewController`. |
| `PhotoViewScaleStateController` | `PhotoViewScaleStateController` | Now a `ValueNotifier<PhotoViewScaleState>`. See the controller table. |
| `PhotoViewComputedScale`, `PhotoViewScaleState`, `PhotoViewHeroAttributes`, `PhotoViewGestureDetectorScope` | same names | See the parameter table for `PhotoViewGestureDetectorScope.axis`. |
| `ScaleStateCycle`, `defaultScaleStateCycle`, `LoadingBuilder`, `PhotoViewImageTapUpCallback`, `PhotoViewImageTapDownCallback`, `PhotoViewImageScaleEndCallback` | same names | Exported from `photo_zoom.dart`. |
| n/a | `PhotoViewScale` | The type of `minScale`, `maxScale` and `initialScale`. `PhotoViewComputedScale` extends it. |

### Parameters of PhotoView and PhotoViewGalleryPageOptions

| photo_view 0.15.0 | photo_zoom | Notes |
|---|---|---|
| `minScale: 0.5` (`dynamic`, a `double` or a `PhotoViewComputedScale`) | `minScale: PhotoViewScale.value(0.5)` | The same change applies to `maxScale` and `initialScale`. A computed scale such as `PhotoViewComputedScale.contained * 0.8` compiles unchanged. A negative or NaN `PhotoViewScale.value` asserts when it is built. |
| `backgroundDecoration: BoxDecoration?` | `backgroundDecoration: Decoration` | Not nullable. The default is the opaque black photo_view used for `null`. A `BoxDecoration` literal compiles. A nullable variable does not. |
| `controller: PhotoViewControllerBase?` | `controller: PhotoViewController?` | |
| `null` passed to `minScale`, `maxScale`, `initialScale`, `basePosition`, `scaleStateCycle`, `disableGestures`, `enablePanAlways` or `strictScale` | pass the default or leave the argument out | These are not nullable here. Each default is the value photo_view used for `null`. |
| `tightMode: true` | removed | A `SizedBox` around the view is the closest replacement. It is not the same. `tightMode` sized the background to the child and followed the zoom. A `SizedBox` stays the size you give it. |
| `filterQuality` on `PhotoView.customChild` and `PhotoViewGalleryPageOptions.customChild` | removed | `PhotoView.new` and `PhotoViewGalleryPageOptions.new` still take it. A custom child draws whatever the child draws. |
| `PhotoViewGestureDetectorScope(axis: null)` | `axis` is required | photo_view's `axis` is nullable. |
| `loadingBuilder`, `errorBuilder`, `wantKeepAlive`, `semanticLabel`, `gaplessPlayback`, `heroAttributes`, `scaleStateChangedCallback`, `enableRotation`, `basePosition`, `scaleStateCycle`, `customSize`, `gestureDetectorBehavior`, `onTapUp`, `onTapDown`, `onScaleEnd`, `filterQuality`, `disableGestures`, `enablePanAlways`, `strictScale` | same names | |
| n/a | `enableScrollZoom` | Mouse wheel zoom and trackpad pan. On by default. |
| n/a | `onDismiss`, `dismissThreshold` | Swipe to dismiss. Off until `onDismiss` is set. |

Gallery parameters (`pageOptions`, `itemCount`, `builder`, `pageController`,
`onPageChanged`, `scrollDirection`, `scrollPhysics`, `reverse`, `pageSnapping`,
`allowImplicitScrolling`, `loadingBuilder`, `backgroundDecoration`,
`gaplessPlayback`, `wantKeepAlive`, `enableRotation`, `customSize`,
`scaleStateChangedCallback`) keep their names. The gallery adds
`enableScrollZoom`, `onDismiss` and `dismissThreshold`.

### Controllers

| photo_view 0.15.0 | photo_zoom |
|---|---|
| `controller.outputStateStream.listen(fn)` | `controller.addListener(fn)`, or a `ValueListenableBuilder` |
| `scaleStateController.outputScaleStateStream` | `scaleStateController.addListener(fn)`, or a `ValueListenableBuilder` |
| `controller.position`, `scale`, `rotation`, `value`, `reset()`, `updateMultiple(...)`, `dispose()` | same names |
| `controller.prevValue`, `controller.initial` | removed |
| `controller.rotationFocusPoint`, `PhotoViewControllerValue.rotationFocusPoint`, and the `rotationFocusPoint` argument of `updateMultiple` | removed |
| `controller.setScaleInvisibly`, `addIgnorableListener`, `removeIgnorableListener` | removed |
| `scaleStateController.scaleState`, `reset()`, `dispose()` | same names |
| `scaleStateController.prevScaleState`, `hasChanged`, `isZooming`, `setInvisibly`, `addIgnorableListener`, `removeIgnorableListener` | removed. `PhotoViewScaleState.isZooming` still exists on the enum. |
| `PhotoViewScaleState.isScaleStateZooming` | `PhotoViewScaleState.isZooming` |

Whoever creates a controller disposes it, in both packages.

## Before and after

Before, with photo_view 0.15.0. This half was read against the 0.15.0 source and
was not compiled here.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  final _controller = PhotoViewController();
  StreamSubscription<PhotoViewControllerValue>? _subscription;
  double? _scale;

  @override
  void initState() {
    super.initState();
    _subscription = _controller.outputStateStream.listen(
      (value) => setState(() => _scale = value.scale),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PhotoView(
          imageProvider: const AssetImage('assets/canyon.png'),
          controller: _controller,
          minScale: 0.5,
          maxScale: PhotoViewComputedScale.covered * 3,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
        Text('${_scale ?? '--'}'),
      ],
    );
  }
}

Widget gallery(List<String> urls) => PhotoViewGallery.builder(
  itemCount: urls.length,
  builder: (context, index) => PhotoViewGalleryPageOptions(
    imageProvider: NetworkImage(urls[index]),
    heroAttributes: PhotoViewHeroAttributes(tag: urls[index]),
    minScale: PhotoViewComputedScale.contained * 0.8,
    maxScale: 4.0,
  ),
);
```

After, with photo_zoom. The full file is
[`example/lib/migrating_from_photo_view.dart`](../example/lib/migrating_from_photo_view.dart).
The changes are the import, the stream becoming a `ValueListenableBuilder`, and
the two `double` scales becoming `PhotoViewScale.value`.

```dart
import 'package:flutter/material.dart';
import 'package:photo_zoom/photo_zoom.dart';

class Detail extends StatefulWidget {
  const Detail({super.key});

  @override
  State<Detail> createState() => _DetailState();
}

class _DetailState extends State<Detail> {
  final _controller = PhotoViewController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PhotoView(
          imageProvider: const AssetImage('assets/canyon.png'),
          controller: _controller,
          minScale: const PhotoViewScale.value(0.5),
          maxScale: PhotoViewComputedScale.covered * 3,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
        ValueListenableBuilder<PhotoViewControllerValue>(
          valueListenable: _controller,
          builder: (context, value, child) => Text('${value.scale ?? '--'}'),
        ),
      ],
    );
  }
}

Widget gallery(List<String> urls) => PhotoViewGallery.builder(
  itemCount: urls.length,
  builder: (context, index) => PhotoViewGalleryPageOptions(
    imageProvider: NetworkImage(urls[index]),
    heroAttributes: PhotoViewHeroAttributes(tag: urls[index]),
    minScale: PhotoViewComputedScale.contained * 0.8,
    maxScale: const PhotoViewScale.value(4),
  ),
);
```

## Differences

What photo_view does that this package does not:

- `tightMode`, and `filterQuality` on the two `customChild` constructors.
- Streams. Both controllers are `ValueNotifier`s here, with no
  `outputStateStream` or `outputScaleStateStream`.
- The controller internals: `prevValue`, `initial`, `rotationFocusPoint`,
  `setScaleInvisibly`, `setInvisibly`, the ignorable listeners, and the
  `PhotoViewControllerBase` interface for writing your own controller.
- `null` for the options listed in the parameter table. They are non-nullable
  here.
- A bare `double` for `minScale`, `maxScale` and `initialScale`.
- Older toolchains. photo_view 0.15.0 declares Dart `>=2.12.0 <4.0.0` and
  Flutter `>=1.6.0`. This package needs Dart `^3.8.0` and Flutter `>=3.32.0`.

What this package does that photo_view does not:

- A double tap zooms at the tap. In photo_view 0.15.0 a double tap changes the
  scale state, and the handler for that animates the position to
  `Offset.zero` (`animateOnScaleStateUpdate` in `photo_view_core.dart`). The
  zoom goes towards `basePosition`. Here the tapped point stays under the finger.
  A pinch and the mouse wheel are anchored the same way.
- Mouse wheel and trackpad. `enableScrollZoom` is on by default. An event the
  view cannot use, such as zooming in at `maxScale`, goes on to an ancestor
  scrollable. photo_view 0.15.0 has no `PointerSignalEvent` handling in its
  `lib/`.
- Swipe to dismiss through `onDismiss` and `dismissThreshold`. photo_view 0.15.0
  has no such parameter.
- Sampling. With `filterQuality` left `null`, photo_view 0.15.0 uses
  `FilterQuality.none`. Here the filter follows the scale on screen, and a
  `filterQuality` you pass is used as given.
- Accessibility. The zoom level is exposed to screen readers with increase and
  decrease actions, and zoom changes jump to their target when the platform asks
  for reduced motion. photo_view 0.15.0 has no `Semantics` widget and does not
  read `MediaQuery.disableAnimations`.
- `strictScale`. In photo_view 0.15.0 a scale update past a limit returns early,
  which also drops that update's pan. Here the scale is clamped and the pan
  continues.
- `PhotoViewComputedScale` equality counts the multiplier here. In photo_view
  0.15.0 two values with the same base compare equal whatever they were
  multiplied by.
- `PhotoViewGalleryPageOptions` takes `enablePanAlways` and `strictScale`.
  photo_view 0.15.0's page options have neither.

Sources, checked 2026-09-30: photo_view 0.15.0 as published on pub.dev
(`lib/photo_view.dart`, `lib/photo_view_gallery.dart`,
`lib/src/controller/`, `lib/src/core/photo_view_core.dart`,
`lib/src/photo_view_wrappers.dart`) and this repository's `lib/` and `test/`.
