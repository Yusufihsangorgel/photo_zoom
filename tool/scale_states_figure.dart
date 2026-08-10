// Draws what `contained`, `covered` and a plain `1.0` do to the same image.
//
//   dart run tool/scale_states_figure.dart
//
// The first code sample in the README reaches for
// `PhotoViewComputedScale.contained * 0.8` and `.covered * 3` before anything
// has shown what those two words mean, and they are the part of this API people
// get wrong. A picture settles it faster than a paragraph.
//
// The numbers are not illustrative. A 200x100 image in a 400x400 viewport is
// the fixture the widget tests use, and its three scales really are 2.0, 4.0
// and 1.0 -- so anyone who doubts the figure can read `test/photo_view_test.dart`
// and get the same numbers.
import 'dart:io';

/// The fixture: the widget tests decode exactly this, in exactly this box.
const imageW = 200.0;
const imageH = 100.0;
const viewport = 400.0;

/// Fits the whole image inside the viewport, letterboxing what is left over.
double get contained => (viewport / imageW) < (viewport / imageH)
    ? viewport / imageW
    : viewport / imageH;

/// Fills the viewport, pushing what does not fit outside it.
double get covered => (viewport / imageW) > (viewport / imageH)
    ? viewport / imageW
    : viewport / imageH;

const bg = '#14161C';
const panel = '#1d212b';
const edge = '#39414f';
const ink = '#d8dee9';
const dim = '#8b93a3';
const accent = '#7fb3ff';
const crop = '#ff8f6b';

/// One panel: a viewport, the image inside it at [scale], and what falls
/// outside drawn faint so it is clear the pixels exist and are simply not on
/// screen.
///
/// Everything is clipped to the panel's own column. At `covered` the image is
/// twice the viewport's width, and without that clip it runs across the panel
/// beside it -- which is what the first version of this figure did.
String panelSvg(
  int i,
  double x,
  String id,
  String title,
  List<String> lines,
  double scale,
) {
  const box = 190.0;
  const top = 62.0;
  final k = box / viewport; // viewport units -> figure units
  final w = imageW * scale * k;
  final h = imageH * scale * k;
  final ix = x + (box - w) / 2;
  final iy = top + (box - h) / 2;

  final b = StringBuffer()
    ..writeln(
      '  <text x="${x + box / 2}" y="26" fill="$ink" font-size="16" '
      'font-family="Menlo, monospace" text-anchor="middle">$title</text>',
    );
  for (var n = 0; n < lines.length; n++) {
    b.writeln(
      '  <text x="${x + box / 2}" y="${44 + n * 15}" fill="$dim" '
      'font-size="11.5" font-family="Menlo, monospace" '
      'text-anchor="middle">${lines[n]}</text>',
    );
  }
  b
    // The column this panel may draw in, so a wide image cannot spill sideways.
    ..writeln(
      '  <clipPath id="col$id"><rect x="${x - 12}" y="${top - 12}" '
      'width="${box + 24}" height="${box + 24}"/></clipPath>',
    )
    ..writeln(
      '  <clipPath id="view$id"><rect x="$x" y="$top" '
      'width="$box" height="$box"/></clipPath>',
    )
    ..writeln('  <g clip-path="url(#col$id)">')
    // Outside the viewport: faint, dashed.
    ..writeln(
      '    <rect x="$ix" y="$iy" width="$w" height="$h" fill="$crop" '
      'fill-opacity="0.16" stroke="$crop" stroke-opacity="0.55" '
      'stroke-dasharray="4 3" stroke-width="1"/>',
    )
    ..writeln('  </g>')
    // Inside it: solid.
    ..writeln('  <g clip-path="url(#view$id)">')
    ..writeln(
      '    <rect x="$ix" y="$iy" width="$w" height="$h" fill="$accent" '
      'fill-opacity="0.6"/>',
    )
    ..writeln('  </g>')
    ..writeln(
      '  <rect x="$x" y="$top" width="$box" height="$box" fill="none" '
      'stroke="$edge" stroke-width="1.5"/>',
    );
  return b.toString();
}

void main() {
  const gap = 40.0;
  const box = 190.0;
  final width = box * 3 + gap * 4;
  const height = 320.0;

  final svg = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${width.toStringAsFixed(0)}" '
      'height="${height.toStringAsFixed(0)}" '
      'viewBox="0 0 ${width.toStringAsFixed(0)} '
      '${height.toStringAsFixed(0)}">',
    )
    ..writeln('  <rect width="100%" height="100%" fill="$bg"/>')
    ..write(
      panelSvg(0, gap, 'a', 'contained', [
        'scale ${contained.toStringAsFixed(1)}',
        'all of it, letterboxed',
      ], contained),
    )
    ..write(
      panelSvg(1, gap * 2 + box, 'b', 'covered', [
        'scale ${covered.toStringAsFixed(1)}',
        'no gaps, edges cropped',
      ], covered),
    )
    ..write(
      panelSvg(2, gap * 3 + box * 2, 'c', '1.0', [
        'scale 1.0',
        'one source pixel each',
      ], 1),
    )
    ..writeln(
      '  <text x="${width / 2}" y="298" fill="$dim" font-size="11.5" '
      'font-family="Menlo, monospace" text-anchor="middle">'
      'a ${imageW.toInt()}x${imageH.toInt()} image in a '
      '${viewport.toInt()}x${viewport.toInt()} viewport; '
      'dashed means outside the viewport</text>',
    )
    ..writeln('</svg>');

  File('doc/scale-states.svg').writeAsStringSync(svg.toString());
  stdout.writeln('wrote doc/scale-states.svg');
  stdout.writeln(
    '  contained ${contained.toStringAsFixed(1)}  '
    'covered ${covered.toStringAsFixed(1)}  original 1.0',
  );
  stdout.writeln(
    'render: rsvg-convert -z 2 doc/scale-states.svg '
    '-o doc/scale-states.png',
  );
}
