// Draws where a mouse wheel goes when a photo sits inside a feed.
//
//   dart run tool/wheel_handoff_figure.dart
//
// This is the behaviour nobody knows to look for, because the packages that
// lack it fail silently in two different ways. A viewer that always claims the
// wheel traps the user: the feed will not scroll past the photo. One that
// never claims it cannot zoom on desktop at all -- measured, `photo_view
// 0.15.0` has no PointerSignal handling anywhere in its lib.
//
// The third option is to take the event while zooming is still possible and
// leave it alone once it is not, which is what `_canScaleBy` decides
// (`lib/src/photo_view_core.dart:696`). Eleven tests in
// `test/pointer_signal_test.dart` pin it, including the hand-off itself.
//
// The scales are the widget tests' own fixture: a 200x100 image in a 400x400
// viewport is contained at 2.0, so a floor of 2.0 starts the view pinned.
import 'dart:io';

const bg = '#14161C';
const ink = '#d8dee9';
const dim = '#8b93a3';
const edge = '#39414f';
const card = '#1b1f28';
const photo = '#31405c';
const active = '#7fb3ff'; // where the event went
const idle = '#4a5568';

const panelW = 300.0;
const panelH = 250.0;

/// One column: a feed with a photo in it, and an arrow showing where the wheel
/// event landed.
String panel(double x, String title, String subtitle, {required bool toPhoto}) {
  const top = 96.0;
  const rowH = 34.0;
  final b = StringBuffer()
    ..writeln(
      '  <text x="${x + panelW / 2}" y="36" fill="$ink" font-size="14" '
      'font-family="Menlo, monospace" text-anchor="middle">$title</text>',
    )
    ..writeln(
      '  <text x="${x + panelW / 2}" y="56" fill="$dim" '
      'font-size="11.5" font-family="Menlo, monospace" '
      'text-anchor="middle">$subtitle</text>',
    )
    // The feed.
    ..writeln(
      '  <rect x="$x" y="$top" width="$panelW" height="$panelH" '
      'fill="$card" stroke="${toPhoto ? edge : active}" '
      'stroke-width="${toPhoto ? 1.2 : 2.2}" rx="4"/>',
    );

  // Two rows of text, the photo, two more rows.
  var y = top + 14;
  for (final isPhoto in [false, false, true, false, false]) {
    if (isPhoto) {
      b
        ..writeln(
          '    <rect x="${x + 16}" y="$y" width="${panelW - 32}" '
          'height="96" fill="$photo" stroke="${toPhoto ? active : edge}" '
          'stroke-width="${toPhoto ? 2.2 : 1.2}" rx="3"/>',
        )
        ..writeln(
          '    <text x="${x + panelW / 2}" y="${y + 54}" '
          'fill="${toPhoto ? active : dim}" font-size="11" '
          'font-family="Menlo, monospace" text-anchor="middle">the photo</text>',
        );
      y += 96 + 12;
    } else {
      b.writeln(
        '    <rect x="${x + 16}" y="$y" width="${panelW - 60}" '
        'height="10" rx="2" fill="$idle" fill-opacity="0.6"/>',
      );
      y += rowH;
    }
  }

  // The wheel, and where its event ended up.
  // The wheel comes in at the photo either way; only the outcome differs, and
  // that is said below the panel so it never lands on a row of the feed.
  final wheelY = top + 14 + rowH * 2 + 48;
  b
    ..writeln(
      '  <path d="M ${x + panelW + 30} $wheelY l -24 0" '
      'stroke="$dim" stroke-width="1.5"/>',
    )
    ..writeln(
      '  <text x="${x + panelW + 36} " y="${wheelY + 4}" fill="$dim" '
      'font-size="11" font-family="Menlo, monospace">wheel</text>',
    )
    ..writeln(
      '  <text x="${x + panelW / 2}" y="${top + panelH + 26}" '
      'fill="$active" font-size="12.5" font-family="Menlo, monospace" '
      'text-anchor="middle">${toPhoto ? 'the photo zooms' : 'the feed scrolls'}'
      '</text>',
    );
  return b.toString();
}

void main() {
  const left = 40.0, gap = 120.0;
  final width = left + panelW * 2 + gap + 110;
  const height = 460.0;

  final svg = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${width.toStringAsFixed(0)}" height="${height.toInt()}" '
      'viewBox="0 0 ${width.toStringAsFixed(0)} ${height.toInt()}">',
    )
    ..writeln('  <rect width="100%" height="100%" fill="$bg"/>')
    ..write(
      panel(
        left,
        'it can still zoom in',
        'scale 2.0, ceiling not reached',
        toPhoto: true,
      ),
    )
    ..write(
      panel(
        left + panelW + gap,
        'it is pinned at the limit',
        'scale 2.0, and 2.0 is the floor',
        toPhoto: false,
      ),
    )
    ..writeln(
      '  <text x="${width / 2}" y="${height - 34}" fill="$ink" '
      'font-size="12.5" font-family="Menlo, monospace" '
      'text-anchor="middle">the same gesture; the photo decides only whether '
      'it has anything left to do with it</text>',
    )
    ..writeln(
      '  <text x="${width / 2}" y="${height - 14}" fill="$dim" '
      'font-size="11" font-family="Menlo, monospace" text-anchor="middle">'
      'always claiming it traps the reader in the post; never claiming it '
      'means no zoom on a desktop</text>',
    )
    ..writeln('</svg>');

  File('doc/wheel-handoff.svg').writeAsStringSync(svg.toString());
  stdout
    ..writeln('wrote doc/wheel-handoff.svg')
    ..writeln(
      'render: rsvg-convert -z 2 doc/wheel-handoff.svg '
      '-o doc/wheel-handoff.png',
    );
}
