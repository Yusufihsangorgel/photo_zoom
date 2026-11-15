// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:photo_zoom/photo_zoom.dart';

/// The "after" half of `doc/migrating-from-photo_view.md`.
///
/// The photo_view version read the controller through `outputStateStream` and
/// passed `0.5` and `4.0` as scales. Here the controller is a [ValueNotifier]
/// and the scales are [PhotoViewScale] values.
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
          builder: (context, value, child) => Text(
            '${value.scale ?? '--'}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// A gallery built from a list of assets, as in the migration guide.
Widget gallery(List<String> assets) => PhotoViewGallery.builder(
  itemCount: assets.length,
  builder: (context, index) => PhotoViewGalleryPageOptions(
    imageProvider: AssetImage(assets[index]),
    heroAttributes: PhotoViewHeroAttributes(tag: assets[index]),
    minScale: PhotoViewComputedScale.contained * 0.8,
    maxScale: const PhotoViewScale.value(4),
  ),
);

/// Bundled photos for the gallery section. The page works without the network.
const _assets = [
  'assets/canyon.png',
  'assets/tower.png',
  'assets/shoreline.png',
];

/// The photo_zoom side of the migration guide, on one scrolling page.
///
/// Each section is one piece of the photo_view API a typical app uses, with a
/// note about what changed in the move. The example app's home screen opens
/// this page.
class MigratedPage extends StatelessWidget {
  const MigratedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Migrated from photo_view')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _Section(
            title: 'Controller and scale limits',
            note:
                'The controller is a ValueNotifier now. The photo_view stream '
                'became a ValueListenableBuilder, and a minScale of 0.5 became '
                'PhotoViewScale.value(0.5).',
            child: PhotoViewGestureDetectorScope(
              axis: Axis.vertical,
              child: Detail(),
            ),
          ),
          _Section(
            title: 'customChild and childSize',
            note:
                'The customChild constructor keeps its name and still takes '
                'childSize. The computed scales are measured against that '
                'size.',
            child: PhotoViewGestureDetectorScope(
              axis: Axis.vertical,
              child: PhotoView.customChild(
                childSize: const Size(300, 200),
                maxScale: const PhotoViewScale.value(4),
                backgroundDecoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                ),
                child: const _BarChart(),
              ),
            ),
          ),
          _Section(
            title: 'errorBuilder',
            note:
                'This asset is missing from the bundle on purpose. The load '
                'fails and errorBuilder shows, with the signature photo_view '
                'already had.',
            child: PhotoViewGestureDetectorScope(
              axis: Axis.vertical,
              child: PhotoView(
                imageProvider: const AssetImage('assets/missing.png'),
                backgroundDecoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                ),
                errorBuilder: (context, error, stackTrace) =>
                    Center(child: Text('Could not load the image: $error')),
              ),
            ),
          ),
          _Section(
            title: 'Tap and scale callbacks',
            note:
                'The callbacks onTapDown, onTapUp and onScaleEnd keep their '
                'names and signatures. The caption is the latest event.',
            child: PhotoViewGestureDetectorScope(
              axis: Axis.vertical,
              child: _TapEventsSection(),
            ),
          ),
          _Section(
            title: 'Gallery',
            note:
                'The builder, the hero attributes and the computed scales '
                'carry over. A maxScale of 4.0 became PhotoViewScale.value(4).',
            height: 320,
            child: gallery(_assets),
          ),
          _Section(
            title: 'Swipe to dismiss',
            note:
                'The onDismiss and dismissThreshold parameters are new. A drag '
                'past a set fraction of the height pops the route, 0.35 here '
                'against the 0.2 default.',
            height: null,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const _DismissiblePhotoPage(),
                ),
              ),
              icon: const Icon(Icons.swipe_down),
              label: const Text('Open a photo you can swipe away'),
            ),
          ),
          _Section(
            title: 'Sharing a drag with this list',
            note:
                'This page is a vertical ListView. The scope hands a vertical '
                'drag to the list once the photo is against its own edge. '
                'Every viewer above is wrapped the same way, apart from the '
                'gallery, which brings its own scope on a horizontal axis.',
            child: PhotoViewGestureDetectorScope(
              axis: Axis.vertical,
              child: PhotoView(
                imageProvider: const AssetImage('assets/tower.png'),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled demo with a heading, a note about what changed, and the viewer
/// in a bounded box.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.note,
    required this.child,
    this.height = 240,
  });

  final String title;
  final String note;

  /// The height of the viewer box. Null leaves the child to size itself.
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (height != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: height, width: double.infinity, child: child),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            note,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}

/// A bar chart, for the customChild section. No image provider involved.
class _BarChart extends StatelessWidget {
  const _BarChart();

  static const _values = [0.35, 0.6, 1.0, 0.75, 0.5];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final value in _values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: FractionallySizedBox(
                        heightFactor: value,
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('Zoom me. I am a widget, not an image.'),
        ],
      ),
    );
  }
}

/// Reports the tap and scale callbacks in a caption over the photo.
class _TapEventsSection extends StatefulWidget {
  const _TapEventsSection();

  @override
  State<_TapEventsSection> createState() => _TapEventsSectionState();
}

class _TapEventsSectionState extends State<_TapEventsSection> {
  String _last = 'Tap or drag the photo';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PhotoView(
          imageProvider: const AssetImage('assets/mosaic.png'),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          onTapDown: (context, details, value) =>
              setState(() => _last = 'tap down at ${details.localPosition}'),
          onTapUp: (context, details, value) => setState(
            () => _last = 'tap up at scale ${value.scale?.toStringAsFixed(2)}',
          ),
          onScaleEnd: (context, details, value) => setState(() {
            _last =
                'scale end at '
                '${details.velocity.pixelsPerSecond.distance.toStringAsFixed(0)}'
                ' px/s';
          }),
        ),
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// A photo on its own route, dismissed by a swipe, as an app usually wants.
class _DismissiblePhotoPage extends StatelessWidget {
  const _DismissiblePhotoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Swipe down to dismiss')),
      body: PhotoView(
        imageProvider: const AssetImage('assets/shoreline.png'),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        onDismiss: () => Navigator.of(context).pop(),
        dismissThreshold: 0.35,
      ),
    );
  }
}
