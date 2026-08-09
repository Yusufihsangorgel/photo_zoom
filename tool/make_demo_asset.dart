// Writes the image the comparison screen zooms into.
//
//   dart run tool/make_demo_asset.dart
//   rsvg-convert -w 900 example/assets/detail.svg -o example/assets/detail.png
//
// The point of the image is that every part of it is identifiable. A gradient
// or a photograph of a sky cannot show whether a zoom kept the spot you tapped,
// because every part of it looks like every other part. A numbered grid can:
// either the tile under the marker is still the tile you tapped, or it is not.
import 'dart:io';
import 'dart:math' as math;

/// Tiles across and down. Twenty is enough for a tapped tile to have
/// neighbours on every side, so drift in any direction is visible. The sheet
/// is taller than it is wide on purpose: in a landscape box that makes the
/// step from a contained fit to a covered one a real jump rather than a
/// few percent, which is what the comparison needs to be legible.
const columns = 4;
const rows = 5;
const width = 900;
const tile = width / columns;
final height = (tile * rows).round();

void main() {
  final buffer = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="$width" height="$height" viewBox="0 0 $width $height">',
    )
    ..writeln('  <defs>');

  for (var i = 0; i < columns * rows; i++) {
    final hue = (i * 360 / (columns * rows) + 205) % 360;
    buffer
      ..writeln('    <linearGradient id="g$i" x1="0" y1="0" x2="1" y2="1">')
      ..writeln('      <stop offset="0" stop-color="${_hsl(hue, 58, 46)}"/>')
      ..writeln('      <stop offset="1" stop-color="${_hsl(hue, 62, 30)}"/>')
      ..writeln('    </linearGradient>');
  }
  buffer.writeln('  </defs>');

  for (var row = 0; row < rows; row++) {
    for (var column = 0; column < columns; column++) {
      final i = row * columns + column;
      final x = column * tile;
      final y = row * tile;
      buffer
        ..writeln(
          '  <rect x="$x" y="$y" width="$tile" height="$tile" '
          'fill="url(#g$i)"/>',
        )
        ..writeln(
          '  <rect x="${x + 4}" y="${y + 4}" '
          'width="${tile - 8}" height="${tile - 8}" fill="none" '
          'stroke="#ffffff" stroke-opacity="0.22" stroke-width="2"/>',
        )
        // The number is the whole point, so it is large and high contrast.
        ..writeln(
          '  <text x="${x + tile / 2}" y="${y + tile / 2}" '
          'font-family="Helvetica,Arial,sans-serif" font-size="${tile * 0.42}" '
          'font-weight="700" fill="#ffffff" fill-opacity="0.93" '
          'text-anchor="middle" dominant-baseline="central">${i + 1}</text>',
        )
        // A ring of dots gives the zoom something fine to resolve, so a
        // magnified frame looks magnified rather than just cropped.
        ..writeln(_dots(x, y, tile, i));
    }
  }

  buffer.writeln('</svg>');

  final file = File('example/assets/detail.svg')
    ..createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());
  stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
  stdout.writeln(
    'now: rsvg-convert -w $width ${file.path} -o example/assets/detail.png',
  );
}

/// A small arc of dots in the corner of a tile, distinct per tile.
String _dots(double x, double y, double tile, int index) {
  final out = StringBuffer();
  final count = 3 + index % 4;
  for (var d = 0; d < count; d++) {
    final angle = math.pi / 4 + d * 0.34;
    final cx = x + tile * 0.5 + math.cos(angle) * tile * 0.34;
    final cy = y + tile * 0.5 + math.sin(angle) * tile * 0.34;
    out.writeln(
      '  <circle cx="${cx.toStringAsFixed(1)}" '
      'cy="${cy.toStringAsFixed(1)}" r="${(tile * 0.022).toStringAsFixed(1)}" '
      'fill="#ffffff" fill-opacity="0.55"/>',
    );
  }
  return out.toString().trimRight();
}

String _hsl(double hue, int saturation, int lightness) =>
    'hsl(${hue.toStringAsFixed(0)}, $saturation%, $lightness%)';
