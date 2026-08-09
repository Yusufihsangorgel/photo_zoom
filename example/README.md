# photo_zoom example

A small app with two screens.

**Gallery** is the ordinary use: a grid of thumbnails that fly into a full
screen `PhotoViewGallery`, with a live zoom readout driven by the controller,
a switch for `enableScrollZoom`, and photos of four different aspect ratios so
the difference between a contained and a covered scale is visible.

**Compare** puts `photo_view` and `photo_zoom` side by side on the same image
and sends a single synthetic double tap into both panes at the same position,
on the same frame. Neither side is tapped by hand, so what happens next comes
from the packages rather than from how steady the hand was. It runs on a loop;
the buttons stop the loop and hand the viewers back to you.

```sh
flutter create --platforms=ios,android,macos .   # once, for the platform folders
flutter run

flutter run --dart-define=start=compare          # straight to the comparison
```

`flutter create` is needed because the platform folders are generated rather
than carried in the repository.
