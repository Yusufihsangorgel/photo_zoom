import 'package:flutter/material.dart';
import 'package:photo_zoom/photo_zoom.dart';

void main() => runApp(const ExampleApp());

/// The photos the gallery shows. The aspect ratios differ on purpose, so the
/// difference between a contained and a covered scale is visible.
const photos = <Photo>[
  Photo('canyon', 'assets/canyon.png', Size(1200, 800), 'Canyon, 1200x800'),
  Photo('tower', 'assets/tower.png', Size(800, 1200), 'Tower, 800x1200'),
  Photo(
    'shoreline',
    'assets/shoreline.png',
    Size(1600, 900),
    'Shoreline, 1600x900',
  ),
  Photo('mosaic', 'assets/mosaic.png', Size(900, 900), 'Mosaic, 900x900'),
];

/// One photo in the gallery.
class Photo {
  const Photo(this.id, this.asset, this.size, this.label);

  final String id;
  final String asset;
  final Size size;
  final String label;

  ImageProvider get provider => AssetImage(asset);
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'photo_zoom',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    darkTheme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      brightness: Brightness.dark,
    ),
    home: const GridPage(),
  );
}

/// A grid of thumbnails that opens the gallery at the tapped photo.
class GridPage extends StatelessWidget {
  const GridPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('photo_zoom')),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => GalleryPage(initialIndex: index),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              // The same tag as the gallery page, so the thumbnail flies into it.
              child: Hero(
                tag: photo.id,
                child: Image(image: photo.provider, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The full screen gallery: swipe between photos, pinch or double tap to zoom.
class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key, required this.initialIndex});

  final int initialIndex;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );

  /// One controller per page, so each photo keeps its own zoom and the readout
  /// can follow whichever page is showing.
  late final List<PhotoViewController> _controllers = [
    for (final _ in photos) PhotoViewController(),
  ];

  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(photo.label, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(
            tooltip: 'Reset zoom',
            icon: const Icon(Icons.zoom_out_map),
            onPressed: () => _controllers[_index].reset(),
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _index = index),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, index) {
              final photo = photos[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: photo.provider,
                controller: _controllers[index],
                semanticLabel: photo.label,
                heroAttributes: PhotoViewHeroAttributes(tag: photo.id),
                minScale: PhotoViewComputedScale.contained * 0.8,
                maxScale: PhotoViewComputedScale.covered * 3,
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: _ZoomReadout(controller: _controllers[_index]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Follows a [PhotoViewController] and prints its scale, to show that the
/// controller is a plain [ValueNotifier] you can build against.
class _ZoomReadout extends StatelessWidget {
  const _ZoomReadout({required this.controller});

  final PhotoViewController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PhotoViewControllerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        final scale = value.scale;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              scale == null ? '--' : '${(scale * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      },
    );
  }
}
