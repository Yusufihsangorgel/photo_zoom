# Gesture matrix

One row per input gesture `PhotoView` and `PhotoViewGallery` answer, with the
widget test that pins the gesture, the input path that test drives, and the
platform the numbers come from. A gesture with no pinning test says "no test"
in its row. Use it to find the test to extend when a gesture changes, and to
see which gestures are pinned only by synthetic events.

Nothing in this table was measured on a device. Every row with a test drives
synthesized pointer events through a widget test, and the repository holds no
device measurement for any of them. The gesture numbers the CHANGELOG does
report, in the 1.2.4 short pan dead zone entry, end with "Not measured on a
device." The 1.2.0 frame-diff percentages describe the synthesized README
recording, and the README says of its own demo that the gestures in it are
synthesized, not performed.

To re-run a row, run its file, for example
`flutter test test/pointer_signal_test.dart`. To run one cited test, pass its
name, for example
`flutter test test/pointer_signal_test.dart --plain-name 'a pinch zooms'`. To
re-run everything the table cites, run `flutter test`.

| Gesture | Pinned by | Input path | Platform |
|---|---|---|---|
| Pinch | `test/photo_view_test.dart` (`a pinch cannot settle above maxScale`, `a pinch cannot settle below minScale`, `strictScale clamps during the pinch, not just at the end`), `test/pan_anchor_test.dart` (`the finger left after a pinch pans from where it is`) | Two synthetic touch pointers started either side of a focal point and moved apart, through the `pinch` helper in `test/photo_view_test.dart` | synthetic events in widget tests, not measured on a device |
| Two-finger rotation (`enableRotation`) | no test | a two-finger twist during a pinch rotates the child when `PhotoView.enableRotation` (`lib/src/photo_view.dart`) is on, and no test drives one | none |
| One-finger pan | `test/pan_anchor_test.dart` (`a short mouse drag moves the image all the way`, `a touch drag within the double-tap slop does not pan`, `a single touch move past the slop pans all the way`, `a short drag along a scope axis still pans all the way`), `test/short_pan_dead_zone_test.dart` (`a zoomed-in touch drag of 24 px moves the image 24 px`), `test/photo_view_test.dart` (`cannot drag the image past its edge`, `cannot pan on an axis where the image fits`, `a drag moves the image with the finger`) | Synthetic touch or mouse drag through `tester.startGesture` and `moveBy` in the `drag` helper of `test/pan_anchor_test.dart`, or `tester.dragFrom` in `cannot drag the image past its edge` | synthetic events in widget tests, not measured on a device |
| Double tap | `test/photo_view_test.dart` (`walks the scale state cycle`, `keeps the tapped part of the image under the finger`, `an abandoned double tap does not leave its focal behind`, `skips cycle steps that would not change the scale`) | Two synthetic touch taps 50 ms apart, through the `doubleTapAt` helper in `test/helpers.dart` | synthetic events in widget tests, not measured on a device |
| Single tap (`onTapUp`, `onTapDown`) | no test | a tap fires the callbacks, wired into a `TapGestureRecognizer` in `PhotoViewGestureDetector.build` (`lib/src/photo_view_gesture_detector.dart`), and no test drives one | none |
| Mouse wheel | `test/pointer_signal_test.dart` (`scrolling up zooms in`, `keeps the point under the cursor in place`, `leaves the event for a scrollable underneath`), `test/photo_view_test.dart` (`a mouse wheel zooms`, `a wheel event it can use is kept from an ancestor scrollable`, `a wheel event it cannot use is left to an ancestor scrollable`) | `PointerScrollEvent` with `kind` mouse, sent with `tester.sendEventToBinding` in the `wheel` helper of `test/pointer_signal_test.dart`, or by the `scrollAt` helper in `test/helpers.dart` holding a `TestPointer(1, PointerDeviceKind.mouse)` | synthetic events in widget tests, not measured on a device |
| Trackpad pan | `test/pointer_signal_test.dart` (`a two-finger scroll pans instead of zooming`, `a pan that would change nothing is left alone`) | `PointerScrollEvent` with `kind` set to `PointerDeviceKind.trackpad`, sent with `tester.sendEventToBinding` in the `wheel` helper of `test/pointer_signal_test.dart` | synthetic events in widget tests, not measured on a device |
| Trackpad zoom | `test/pointer_signal_test.dart` (`a pinch zooms`) | `PointerScaleEvent(position: Offset(200, 200), scale: 1.5)`, sent with `tester.sendEventToBinding` in `a pinch zooms` | synthetic events in widget tests, not measured on a device |
| Pan inside a PageView gallery | `test/gallery_test.dart` (`a zoomed page pans instead of turning the page`, `a page panned to its edge hands the drag to the page view`, `a vertical gallery hands back vertical drags`, `swipes between pages and reports the change`) | Synthetic touch drag over the gallery, `tester.drag(find.byType(PageView), offset)` | synthetic events in widget tests, not measured on a device |
| Nested scroll views | `test/nested_scroll_test.dart` (`a drag pans the photo while it has room, and the list stays put`, `the next drag goes to the list once the photo is at its edge`, `a photo with nothing to pan gives the drag to the list at once`) | Synthetic touch drag inside a vertical `ListView`, with the view wrapped in `PhotoViewGestureDetectorScope(axis: Axis.vertical)` | synthetic events in widget tests, not measured on a device |
| Dismiss | `test/dismiss_test.dart` (`a drag past the threshold dismisses at the rest scale`, `a drag short of the threshold springs back and does not dismiss`, `a drag past the threshold still dismisses once zoomed out below the initial scale`, `a drag pans instead of dismissing once zoomed in enough to have room`) | Synthetic touch drag, `tester.startGesture` plus `moveBy` steps | synthetic events in widget tests, not measured on a device |
