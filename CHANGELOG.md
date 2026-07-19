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
