## 0.2.1

- Fix swipe to dismiss going dead once the view is zoomed out below the
  initial scale. The gate compared the scale to `scaleBoundaries.initialScale`
  instead of checking whether the child had room to pan, and the default
  `minScale` is `PhotoViewScale.value(0)`, so a pinch or a controller write
  into `zoomedOut` left the drag unable to dismiss. It also could not pan:
  `clampPosition` collapses every write to `Offset.zero` once the child no
  longer overflows the viewport, so the drag produced no visible feedback
  either.

## 0.2.0

- Add opt-in swipe to dismiss. Pass `onDismiss` to `PhotoView`,
  `PhotoViewGallery` or `PhotoViewGalleryPageOptions` and a single-finger drag at
  the rest scale slides the image and fades the background; releasing past
  `dismissThreshold` (a fraction of the viewport height, 0.2 by default) calls it,
  usually to pop the route, and a shorter drag springs back. A drag while zoomed
  still pans. Off by default: with no `onDismiss` nothing changes.

## 0.1.4

- Declare the demo in `pubspec.yaml` so pub.dev shows it on the package page.
  The recording was already in the repository and in the README, but pub.dev
  only renders what the `screenshots:` field points at, so anyone landing on
  the page from search saw text where the demo should have been.

## 0.1.3

- Docs: sharpen the pub.dev description to lead with the value and the terms people search.

## 0.1.2

- Docs: tightened the README wording and visuals.

## 0.1.1

- Correct the migration table. Only the double tap recenters in photo_view:
  a pinch updates the scale state through `setInvisibly`, which notifies no
  listener, so it never reaches the recentering path. The table claimed both.

## 0.1.0

Initial release.

- `PhotoView`: pan, pinch zoom, double tap cycle, optional rotation, hero
  transitions, loading and error builders, and `PhotoView.customChild` for
  zooming an arbitrary widget.
- `PhotoViewGallery`: a `PageView` of photos, from a list or built on demand.
  Each page keeps its own zoom, and hands a drag to the page view once its photo
  is panned to the edge.
- `PhotoViewController` and `PhotoViewScaleStateController`: `ValueNotifier`s
  that read and drive the transform and the double tap cycle.
- `PhotoViewScale`: typed scale limits, either `PhotoViewScale.value` or a
  `PhotoViewComputedScale.contained` / `.covered`, with `*` and `/` to offset
  them.
- Zoom anchors at the touch, pointer or tap, rather than at `basePosition`.
- `enableScrollZoom`: mouse wheel zooms at the pointer and a two-finger trackpad
  scroll pans. Events that would change nothing are left to an ancestor
  scrollable.
- Zoom level and zoom actions exposed to screen readers; reduced motion honoured.

The API follows the photo_view package by Renan C. Araújo. See "Migrating from
photo_view" in the README for the differences.
