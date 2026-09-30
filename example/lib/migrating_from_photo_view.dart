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
          builder: (context, value, child) => Text('${value.scale ?? '--'}'),
        ),
      ],
    );
  }
}

/// A gallery page list built from URLs, as in the migration guide.
Widget gallery(List<String> urls) => PhotoViewGallery.builder(
  itemCount: urls.length,
  builder: (context, index) => PhotoViewGalleryPageOptions(
    imageProvider: NetworkImage(urls[index]),
    heroAttributes: PhotoViewHeroAttributes(tag: urls[index]),
    minScale: PhotoViewComputedScale.contained * 0.8,
    maxScale: const PhotoViewScale.value(4),
  ),
);

/// Shows both widgets on one screen so the file can be run as a page.
class MigratedPage extends StatelessWidget {
  const MigratedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Migrated from photo_view')),
      body: const Detail(),
    );
  }
}
