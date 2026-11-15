import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The grey both default widgets draw in.
const Color _kGlyphColor = Color(0xFFBDBDBD);

/// Shown by [PhotoView] when an image fails to load and no
/// [PhotoView.errorBuilder] was given.
///
/// The glyph is painted, not taken from an icon font. An app that does not
/// bundle the Material icon font would otherwise show a missing glyph box.
class PhotoViewDefaultError extends StatelessWidget {
  /// Creates the fallback error widget.
  const PhotoViewDefaultError({super.key, required this.decoration});

  /// Painted behind the glyph. The error fills the same box the image would
  /// have.
  final Decoration decoration;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: decoration,
    child: const Center(
      child: CustomPaint(
        size: Size.square(40),
        painter: PhotoViewBrokenImagePainter(color: _kGlyphColor),
      ),
    ),
  );
}

/// Paints a picture frame with a hill in it, crossed out.
class PhotoViewBrokenImagePainter extends CustomPainter {
  /// Creates a painter that draws the glyph in [color].
  const PhotoViewBrokenImagePainter({required this.color});

  /// The stroke colour.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24 unit grid and scaled to the box.
    final unit = size.shortestSide / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * unit
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset at(double x, double y) => Offset(x * unit, y * unit);

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromPoints(at(3, 4), at(21, 20)),
          Radius.circular(2 * unit),
        ),
        paint,
      )
      ..drawPath(
        Path()..addPolygon([
          at(3, 17),
          at(9, 11),
          at(13, 15),
          at(16, 12),
          at(21, 17),
        ], false),
        paint,
      )
      ..drawLine(at(2, 2), at(22, 22), paint);
  }

  @override
  bool shouldRepaint(PhotoViewBrokenImagePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Shown by [PhotoView] while an image loads and no [PhotoView.loadingBuilder]
/// was given.
///
/// A ring that fills clockwise as bytes arrive. When the provider does not
/// report how many bytes to expect, the ring is drawn whole and stays still.
/// Nothing animates, and a `pumpAndSettle` in a widget test returns even if
/// the image never resolves.
class PhotoViewDefaultLoading extends StatelessWidget {
  /// Creates the fallback loading widget.
  const PhotoViewDefaultLoading({super.key, this.event});

  /// The progress reported by the image provider, if it reports any.
  final ImageChunkEvent? event;

  @override
  Widget build(BuildContext context) {
    final expected = event?.expectedTotalBytes;
    final loaded = event?.cumulativeBytesLoaded;
    final value = expected != null && loaded != null && expected > 0
        ? (loaded / expected).clamp(0.0, 1.0)
        : null;
    return Center(
      child: Semantics(
        label: 'Loading image',
        value: value == null ? null : '${(value * 100).round()}%',
        child: SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(
            painter: PhotoViewProgressPainter(
              value: value,
              color: _kGlyphColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints a ring and, when [value] is known, an arc from twelve o'clock that
/// covers [value] of the circle over a faint track.
class PhotoViewProgressPainter extends CustomPainter {
  /// Creates a painter for [value], between 0 and 1, or for unknown progress
  /// when it is `null`.
  const PhotoViewProgressPainter({required this.value, required this.color});

  /// The fraction loaded, or `null` when it is not known.
  final double? value;

  /// The colour of the arc. The track underneath uses it at lower opacity, and
  /// a ring of unknown progress is drawn in it at full opacity.
  final Color color;

  /// The width of the ring, in logical pixels.
  static const double strokeWidth = 2;

  /// The angle the arc covers, in radians. Zero when progress is unknown.
  double get sweepAngle => 2 * math.pi * (value ?? 0);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = value == null ? color : color.withAlpha(0x66);
    canvas.drawCircle(rect.center, rect.shortestSide / 2, paint);
    if (sweepAngle > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        paint
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(PhotoViewProgressPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}
