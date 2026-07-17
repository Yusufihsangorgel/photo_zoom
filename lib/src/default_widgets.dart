import 'package:flutter/material.dart';

/// Shown by [PhotoView] when an image fails to load and no
/// [PhotoView.errorBuilder] was given.
class PhotoViewDefaultError extends StatelessWidget {
  /// Creates the fallback error widget.
  const PhotoViewDefaultError({super.key, required this.decoration});

  /// Painted behind the icon, so the error fills the same box the image would
  /// have.
  final Decoration decoration;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: decoration,
    child: const Center(
      child: Icon(Icons.broken_image, color: Color(0xFFBDBDBD), size: 40),
    ),
  );
}

/// Shown by [PhotoView] while an image loads and no [PhotoView.loadingBuilder]
/// was given.
class PhotoViewDefaultLoading extends StatelessWidget {
  /// Creates the fallback loading widget.
  const PhotoViewDefaultLoading({super.key, this.event});

  /// The progress reported by the image provider, if it reports any.
  final ImageChunkEvent? event;

  @override
  Widget build(BuildContext context) {
    final expected = event?.expectedTotalBytes;
    final loaded = event?.cumulativeBytesLoaded;
    return Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: expected != null && loaded != null && expected > 0
              ? loaded / expected
              : null,
        ),
      ),
    );
  }
}
