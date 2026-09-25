# Package engineering rules: photo_zoom

Rules-Version: photo_zoom/dfd219b7ee3126921fb7c2ff69184c4a45bd9f08d8a35b291ae71d5ed5951264
Core-Version: 1
Core-Digest: 1825fa7ff346dca23e65b1b3bf9b2e3e06959f1414bae9952d596d2f62f09b8f
Survey-Digest: f90f45c8a172068c3ed3b9488ba5a7cb4e58efa93c380d2d9a70b399349ec35e
Evidence-Revision: e382383
Verified-Revision: unverified

Read CONTRIBUTING.md and docs/engineering/debt.json before editing.

## Current architecture
HEAD e382383 (2026-09-23), version 1.2.4, 40 commits. It is a maintained fork that follows the photo_view API (flutter >=3.32.0, sdk ^3.8.0). The only dependency is the Flutter SDK. The layered structure is as follows. The public widgets (PhotoView, PhotoViewGallery) collect controller ownership and options. ImageWrapper resolves the intrinsic image size from the ImageStream. PhotoViewCore is the single 'engine'. Gesture handling, animation, pointer signals, drag to close, semantics and filter quality live there. Transform math sits in PhotoViewGeometry, ScaleBoundaries and EdgeHitDetector as pure functions. The scale is expressed with the sealed PhotoViewScale value type. Sharing of the gesture arena with ancestor scrollables is done with PhotoViewGestureRecognizer + PhotoViewGestureDetectorScope. There is no hook/ or bin/. AGENTS.md (Purpose/Usage/Contracts/Mistakes/Layout) is written for an agent that uses the package. Its Layout section says not to import lib/src.

## Layers and responsibilities
- lib/photo_zoom.dart: A show-listed export and dartdoc that points to the migration notes from photo_view.
- lib/src/photo_view.dart, lib/src/photo_view_gallery.dart: Constructor API (image and customChild), ownership of controller and scaleStateController, keep-alive, and for the gallery a PageView with per-page options.
- lib/src/image_wrapper.dart, lib/src/default_widgets.dart: Gets the intrinsic size from the ImageStream, handles loading and error states, and provides the default loading and error widgets.
- lib/src/photo_view_core.dart: Drawing with Transform; controller synchronization; settle animation; pinch/pan/double-tap; fling; drag to close; wheel and trackpad signals; semantic zoom actions; hero; filter quality.
- lib/src/photo_view_gesture_detector.dart, lib/src/hit_corners.dart: Arena acceptance with a custom ScaleGestureRecognizer, handoff to the ancestor at the edge, a start anchored to the press point, and an InheritedWidget that reports the axis.
- lib/src/photo_view_geometry.dart, scale_boundaries.dart, photo_view_scale.dart, photo_view_scale_state.dart, photo_view_controller.dart, photo_view_hero_attributes.dart, callbacks.dart: Layout/clamping/focused zoom math, scale resolution, immutable values, ValueNotifier controllers, typedefs and the default double-tap cycle.
- tool/: README figures and the short_pan_matrix measurement script; not library code.
- example/: Gallery and comparison screens; the example tests run in CI.

## Public API and dependency direction
lib/photo_zoom.dart does a show-listed export: LoadingBuilder, PhotoViewImageScaleEndCallback, PhotoViewImageTapDownCallback, PhotoViewImageTapUpCallback, ScaleStateCycle, defaultScaleStateCycle; PhotoView; PhotoViewController, PhotoViewControllerValue, PhotoViewScaleStateController; PhotoViewGallery, PhotoViewGalleryBuilder, PhotoViewGalleryPageChangedCallback, PhotoViewGalleryPageOptions; PhotoViewGestureDetectorScope; PhotoViewHeroAttributes; PhotoViewComputedScale, PhotoViewScale; PhotoViewScaleState. Public names in src that are not exported: PhotoViewCore, ImageWrapper, PhotoViewDefaultError, PhotoViewDefaultLoading, ScaleBoundaries, PhotoViewGeometry, CornersRange, EdgeHitDetector, PhotoViewGestureDetector, PhotoViewGestureRecognizer, AnchoredScaleStartDetails.

photo_view.dart → {callbacks, image_wrapper, photo_view_controller, photo_view_core, photo_view_hero_attributes, photo_view_scale, photo_view_scale_state, scale_boundaries}. photo_view_gallery.dart → {callbacks, photo_view, photo_view_controller, photo_view_gesture_detector, hero_attributes, photo_view_scale, scale_state}. image_wrapper.dart → {callbacks, default_widgets, controller, core, hero_attributes, photo_view_scale, scale_boundaries}. photo_view_core.dart → {callbacks, hit_corners, controller, photo_view_geometry, gesture_detector, hero_attributes, scale_state, scale_boundaries}. photo_view_gesture_detector.dart → hit_corners. hit_corners.dart → photo_view_geometry. photo_view_geometry.dart → scale_boundaries. scale_boundaries.dart → {photo_view_scale, photo_view_scale_state}. callbacks.dart → {controller, scale_state}. photo_view_controller.dart → scale_state. Direction: public widgets → image resolution → engine → gesture recognition → pure geometry and value types. No cycle was seen. Material is imported only in photo_view.dart, photo_view_gallery.dart and default_widgets.dart.

## Error, state and platform contracts
- Immutable value types: @immutable + ==/hashCode, toString where needed (photo_view_controller.dart:6-62; photo_view_scale.dart:21-137; scale_boundaries.dart:13-84; photo_view_geometry.dart:8-29; photo_view_hero_attributes.dart:25-68).
- Sealed PhotoViewScale for scale values: the private _AbsoluteScale and PhotoViewComputedScale (contained/covered, * and / operators).
- Error contract: no custom exception type. Asserts name the parameter and the value (photo_view_scale.dart:36-40, 100-107; photo_view.dart:373-378). Image errors go to errorBuilder. Without a builder they are rethrown in debug (image_wrapper.dart:229-232).
- Configuration: many constructor flags. The gallery uses per-page PhotoViewGalleryPageOptions. Options are passed between layers by hand (debt P2).
- Tuning constants: private consts with the _k prefix and doc comments at the top of the file (photo_view_core.dart:17-30).
- Ownership: `widget.controller ?? _owned`. Swap and listener transfer happen in didUpdateWidget (photo_view.dart:312-362; photo_view_core.dart:250-266).
- Reentrancy guards are _writingController and _writingScaleState. Writes that arrive during build/layout are deferred to post-frame (photo_view_core.dart:197-199, 280-310).
- Platform check: Platform.isX is not used. There is a PointerDeviceKind.trackpad distinction (core.dart:690), plus MediaQuery.disableAnimationsOf and devicePixelRatio (core.dart:243-248).
- Arena cooperation: axis reporting through an InheritedWidget and acceptance controlled by an edge check in the recognizer (gesture_detector.dart:108-227, 251-285). Pointer signals that cannot change the view are not claimed (core.dart:683-728).
- No FFI. Streams/cancellation: the ImageStream listener is added and removed (image_wrapper.dart:169-188). AnimationController and CurvedAnimation are disposed (core.dart:268-276).
- Fix order: first a red test commit, then the fix (2d96e66 → 32c89e6).

## Package rules
### photo_zoom/PZ-01 [MUST]
Export public API only from lib/photo_zoom.dart through explicit show lists. PhotoViewCore, ImageWrapper, ScaleBoundaries, PhotoViewGeometry, EdgeHitDetector, PhotoViewGestureDetector and PhotoViewGestureRecognizer stay unexported.
Reason: Engine and geometry are internal detail. AGENTS.md tells the user 'do not import lib/src/'. The boundary is drawn explicitly today with show lists.
Evidence: lib/photo_zoom.dart:16-40; lib/src/photo_view_core.dart:35-38; AGENTS.md Layout tablosu ('Do not import lib/src/')
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-02 [MUST]
Put transform math (placement, clamping, focal zoom, edge hand-off) in PhotoViewGeometry, ScaleBoundaries or EdgeHitDetector as pure functions of their inputs. _PhotoViewCoreState calls them and does not derive geometry inline.
Reason: The geometry class describes itself as 'pure functions independent of widgets and animation'; the engine only calls these functions. If the math leaks into state, unit tests are lost.
Evidence: lib/src/photo_view_geometry.dart:31-49, 143-210; lib/src/scale_boundaries.dart:7-12, 36-70; lib/src/hit_corners.dart:5-10, 38-69; lib/src/photo_view_core.dart:205-208, 312-314, 392-404, 512-520
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-03 [MUST]
Cover a change to geometry or scale resolution with a unit test in test/geometry_test.dart or test/scale_test.dart, in addition to any widget test.
Reason: Unit tests for the pure layer exist today (24 + 31 cases) and import src deliberately.
Evidence: test/geometry_test.dart:4-5; test/scale_test.dart:4; test/photo_view_test.dart:10-11
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-04 [MUST]
Value types are @immutable and implement == and hashCode over every field.
Reason: All value types are written this way. The comparisons in didUpdateWidget (for example scaleBoundaries !=) rely on it.
Evidence: lib/src/photo_view_controller.dart:6-62; lib/src/photo_view_scale.dart:21-57, 121-129; lib/src/scale_boundaries.dart:13, 72-84; lib/src/photo_view_geometry.dart:8-29; lib/src/photo_view_hero_attributes.dart:25, 51-68; lib/src/photo_view_core.dart:262-265
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-05 [MUST]
Dispose only controllers the widget created. A caller's PhotoViewController, PhotoViewScaleStateController or PageController is never disposed, and a controller swap in didUpdateWidget moves the listeners.
Reason: Dartdoc writes this as a general contract and three widgets follow the same pattern.
Evidence: lib/src/photo_view_controller.dart:93-94, 152; lib/src/photo_view.dart:209-219, 312-362; lib/src/photo_view_gallery.dart:129-133, 180-209; lib/src/photo_view_core.dart:115-119, 250-276
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-06 [MUST]
Reject invalid numeric input in debug with an assert message that names the parameter and the value. NaN is rejected, and infinity is accepted where it means no limit.
Reason: The existing asserts were written to prevent NaN from blowing up far from its source as 'Infinity or NaN toInt'; the rationale is in the dartdoc.
Evidence: lib/src/photo_view_scale.dart:36-40, 89-107; lib/src/photo_view.dart:373-378
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-07 [MUST]
Name tuning constants as private top-level _k constants with a one-line doc giving unit and meaning. Gesture and animation code uses those names, not bare literals.
Reason: Five tuning constants of the engine follow this form (J5). Two exceptions are in debt (P5).
Evidence: lib/src/photo_view_core.dart:17-30; exceptions: :30 (no doc), :564 (bare 1e-6)
Evidence role: both
Existing violation: photo_zoom-D005

### photo_zoom/PZ-08 [MUST]
Honour MediaQuery.disableAnimationsOf: animated moves jump to their target and the dismiss spring-back is skipped.
Reason: Reduced motion is applied today on two animation paths. Any new animation must pass through the same gate.
Evidence: lib/src/photo_view_core.dart:243-248, 418-424, 628-631
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-09 [MUST]
Claim a pointer signal only when it changes the view. Check _canScaleBy or _canPanBy before registering with pointerSignalResolver, and leave the event to an ancestor scrollable otherwise.
Reason: Handing the wheel event to the scrollable list above at the boundary is documented package behavior (README figure wheel-handoff). It is protected by a 14-case test.
Evidence: lib/src/photo_view_core.dart:683-728; lib/src/photo_view.dart:260-266; test/pointer_signal_test.dart; pubspec.yaml screenshots (doc/wheel-handoff.png)
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-10 [MUST]
Start a bug fix from a test that fails on the old code, committed with or before the fix.
Reason: The most recent bug fix followed this order. The red test proves that the bug really exists.
Evidence: git 2d96e66 (test/short_pan_dead_zone_test.dart); git 32c89e6 (lib/src/photo_view_core.dart, lib/src/photo_view_gesture_detector.dart, test/pan_anchor_test.dart)
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-11 [MUST]
Keep CI green on format, flutter analyze and flutter test at the package root and in example/.
Reason: This is the current CI gate. The example tests were added to CI on 2026-09-23.
Evidence: .github/workflows/ci.yaml (root: format, analyze, test; example: pub get, analyze, test); git ee26911
Evidence role: current-pattern
Existing violation: none

### photo_zoom/PZ-12 [SHOULD]
Before adding another PhotoView option, replace the hand-copied relay across PhotoView, ImageWrapper, PhotoViewCore, PhotoViewGallery and PhotoViewGalleryPageOptions with one internal options object. Until that lands, a new option is threaded through every relay site in the same change.
Reason: About 20 options are hand copied in 11 places (debt P2). If a field with a null default is skipped at one forwarding site, nothing fails to compile and the option is silently lost.
Evidence: lib/src/photo_view.dart:75-147, 380-440; lib/src/image_wrapper.dart:20-130, 249-278; lib/src/photo_view_core.dart:41-161; lib/src/photo_view_gallery.dart:55-100, 248-311, 321-370
Evidence role: counterexample
Existing violation: photo_zoom-D002

### photo_zoom/PZ-13 [MUST]
Keep photo_view source compatibility where the README migration notes promise it, and record every intentional difference in README and CHANGELOG.
Reason: The package positions itself as a maintained alternative to photo_view; the migration notes are a contract with the users.
Evidence: lib/photo_zoom.dart:12-13; pubspec.yaml description; example/lib/forwarding_options.dart and example/test/forwarding_options_test.dart (git 9dc282b)
Evidence role: current-pattern
Existing violation: none

## Required verification
- Working directory: repository root; command: flutter pub get; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:22.
- Working directory: repository root; command: dart format --output=none --set-exit-if-changed .; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:23.
- Working directory: repository root; command: flutter analyze; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:24.
- Working directory: repository root; command: flutter test; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:25.
- Working directory: example; command: flutter pub get; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:26.
- Working directory: example; command: flutter analyze; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:28.
- Working directory: example; command: flutter test; conditions: ci.yaml job test; evidence: .github/workflows/ci.yaml:30.
Not verified by the survey:
- Analysis, test and format commands were not run (read only). Whether CI is green today and the GitHub Actions history were not measured (no network).
- The difference between the working tree and HEAD was not measured. Line evidence refers to HEAD e382383.
- Debt P1 was found by static reading (the write sites of the fields were counted one by one with grep). It was not verified by running a gesture test.
- test/photo_view_test.dart (41 KB) was read only in the filter quality section. Only the case counts were measured for the other test files.
- The contents of tool/short_pan_matrix.dart and example/lib were not read.
- The exact match between the migration notes in the README and the code was not verified.
- Test coverage percentage and pub archive contents were not measured.

## Existing debt
The complete register is docs/engineering/debt.json.
- photo_zoom-D001 | small | lib/src/photo_view_core.dart:180-183, 460-463, 945-947 (ilgili: 564) | bug / untested behavior
  Fix: At the end of _onScaleEnd (after the fields are read) and on the dismiss path, set the _start* fields back to null. Test: zoom with two fingers, pumpAndSettle, expect FilterQuality.high. Following the repository pattern, commit the red test first.
  Closure: The _start* fields return to null at the end of _onScaleEnd and on the dismiss path. A test that zooms with two fingers, pumps and settles and expects FilterQuality.high is committed red first.
- photo_zoom-D002 | medium | lib/src/photo_view.dart:75-147, 380-440; lib/src/image_wrapper.dart:20-130, 249-278; lib/src/photo_view_core.dart:41-161; lib/src/photo_view_gallery.dart:55-100, 248-311, 321-370 | duplicate logic / many touch points per change (shotgun surgery)
  Fix: Define an unexported immutable options object in src. Let the PhotoView → ImageWrapper → PhotoViewCore chain carry this object; keep the public constructors unchanged. The existing 159 widget tests act as the safety net; also add a forwarding test that checks 'every option reaches the engine'.
  Closure: PhotoView, ImageWrapper, PhotoViewCore and the gallery carry one internal options object while the public constructors keep their signatures. A forwarding test checks that every option reaches the engine and the widget tests pass.
- photo_zoom-D003 | small | lib/src/photo_view.dart:12-14, 89-91, 105, 126-128, 142; lib/src/photo_view_gallery.dart:59, 74, 84, 99, 329-331, 342, 354-356, 367 | duplicate default value
  Fix: Define private constants in a single src file; let all constructors reference them. Behavior does not change.
  Closure: dismissThreshold, the background decoration and the scale defaults come from private constants in a single src file. The existing tests show no behavior change.
- photo_zoom-D004 | small | lib/src/photo_view_core.dart:915-929, 936 | misplaced dartdoc
  Fix: Move the paragraph to :936; keep a one-line doc on _syncFilterQuality.
  Closure: The sampling paragraph documents _wantedFilterQuality at its definition and _syncFilterQuality keeps a one-line doc.
- photo_zoom-D005 | small | lib/src/photo_view_core.dart:30, 564 | unnamed or undocumented constant (J5)
  Fix: Add a one-line doc to _kSettleDuration; define a named _k constant for the epsilon.
  Closure: _kSettleDuration carries a one-line doc and the 1e-6 epsilon at line 564 is a named _k constant.
- photo_zoom-D006 | large | lib/src/photo_view_core.dart:167-948 | single responsibility (bloated class)
  Fix: Record it. When a section is touched, extract that section into a private helper class (dismiss first, then pointer signals); dismiss_test and pointer_signal_test act as the safety net. Until then do not grow the class.
  Closure: Drag-to-dismiss and pointer signal handling live in private helper classes extracted from _PhotoViewCoreState. dismiss_test and pointer_signal_test pass.
- photo_zoom-D007 | small | lib/src/photo_view_controller.dart:103-114 | duplicate construction
  Fix: Write a private redirecting constructor that takes a single value. The value is immutable; sharing it in two places is safe.
  Closure: The initial PhotoViewControllerValue is constructed once through a private redirecting constructor.
- photo_zoom-D008 | small | .github/workflows/ci.yaml (channel: stable); pubspec.yaml environment | CI coverage gap
  Fix: Add 3.32.0 to the matrix.
  Closure: The CI matrix includes Flutter 3.32.0 beside stable.
