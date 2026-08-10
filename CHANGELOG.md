## 1.2.2

- A figure for `contained`, `covered` and `1.0`. The scale-limits section
  reached for two computed scales before anything had shown what they do, and
  they are the part of this API people get wrong. Drawn by
  `tool/scale_states_figure.dart`, with the widget tests' own fixture, so the
  2.0 and 4.0 in it are numbers you can check.
- Drops the fractal zoom from the archive. It was a screenshot entry only, and
  pub.dev renders screenshots as still thumbnails, so 3.4 MB bought one static
  frame of something that taught nothing about using the package. The archive
  goes from 4 MB to 997 KB.

## 1.2.1

- Tests for the desktop and web input path, which had none: mouse wheel zoom,
  trackpad two-finger pan, trackpad pinch, and the hand-off where a view
  already pinned at a scale limit leaves the wheel event unclaimed so a list
  it sits inside keeps scrolling. No behaviour changed; all of it was already
  correct, and none of it was pinned.

## 1.2.0

- The sampling filter now follows the zoom. Magnifying and shrinking want
  different filters, and which applies changes as the reader zooms, so it is
  decided per frame from the scale on screen in device pixels:
  `FilterQuality.high` when the image is drawn larger than its own pixels,
  `FilterQuality.medium` when it is not, and `medium` throughout a gesture or a
  fling, where the frame budget matters more than the last of the sharpness.
  Passing `filterQuality` still overrides all of it.
- The recording in the README now shows the drag and the two-finger pinch as
  well as the double tap, and the demonstration keeps moving rather than
  parking on a still frame: a frame diff of the previous cut came back 87%
  unchanged, this one 47%.

## 1.1.0

- Fixed a crash-adjacent error when a `PhotoView` is mounted from inside a
  layout callback while something else listens to the same `PhotoViewController`.
  The view resolves its scale from `initState`, and writing the resolved value
  there notified the listener mid-build, which the framework rejects. The write
  is now held until the frame is done; the frame still paints at the right
  scale. The combination is the one the controller's own documentation
  suggests, so it had to hold.
- The example gained a second screen showing where a double tap sends the zoom,
  on a numbered grid, with a live scale readout. Open it directly with
  `flutter run --dart-define=start=compare`.
- The README leads with that recording and answers `InteractiveViewer` and
  photo_view in its first screen rather than a hundred lines down.

## 1.0.3

- The example demonstrates `enableScrollZoom`. A toolbar button turns it off,
  which is the behaviour `photo_view` has no switch for, and the difference is
  a trackpad gesture away. The feature was the reason to pick this package and
  the example never touched it.

## 1.0.2

- Stop shipping build output in the published archive. This version downloads
  as 3 MB. 1.0.1 downloaded 32,418,118 bytes, and 93,092,107 of its 96,897,275
  unpacked bytes were under `build/`; two
  `build/test_cache/*.cache.dill.track.dill` files account for 92,965,256 of
  those, which is what `flutter test` left on the machine that published the
  release. No library code changed, and `lib/` is byte-identical to 1.0.1.

  The cause was one file in the wrong directory. pub replaces `.gitignore`
  with `.pubignore` per directory rather than layering the two, so a
  `.pubignore` at the repository root switched the root `.gitignore` off for
  the whole tree, and `build/` is named only in `.gitignore`. The rule now
  lives in `doc/.pubignore`, beside the `doc/blog/` directory it was written
  for; `doc/` has no `.gitignore` for it to shadow, so the root one stays in
  force.

  Checked with `build/` on disk rather than absent, since an absent `build/`
  would hide the bug instead of testing the fix: 3 MB here, against 17 MB with
  the old layout restored in a scratch copy.

## 1.0.1

- Call the package an alternative to `photo_view` rather than a drop-in. Moving
  across is usually just a change of import, but the migration table in the
  readme lists cases that need an edit: `minScale: 0.5` becomes
  `minScale: PhotoViewScale.value(0.5)`, the controller is a `ValueNotifier`
  instead of a stream, and `tightMode` is gone. "Drop-in" promised none of that.
  Description only; no code change.

## 1.0.0

First stable release. The API below is what 1.0 freezes.

- **Fix `PhotoViewComputedScale`'s operators accepting scales the absolute
  scale refuses.** `PhotoViewScale.value` has always asserted on a negative or
  a NaN, but `contained * x` and `covered / x` took anything. A NaN — the
  realistic source is a caller's own arithmetic, `contained * (a / b)` with
  both zero — travelled into the widget and came back out as
  `Invalid argument(s): NaN` from `clamp`, or `Unsupported operation: Infinity
  or NaN toInt` from layout, depending on which parameter carried it. Neither
  message names the parameter, so the error surfaces far from its origin. Both
  operators now assert with a message that says which one produced what.
  Infinity stays legal: it is `maxScale`'s default and means "no upper limit".

Verified unchanged for this release, by driving each case rather than reading
for it: a zero-size viewport, an external controller or scale-state controller
disposed before the view, a gallery built with `itemCount: 0`, a gallery whose
`itemCount` shrinks while the last page is showing, writes to a controller that
outlives its view, extreme controller values (scale 0 and 1e9, position 1e9,
rotation 1e9), five double-taps interrupting each other's animations, a dispose
mid-animation, and an orientation change while zoomed in. None misbehaved.

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
