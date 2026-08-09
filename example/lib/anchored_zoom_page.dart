import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_zoom/photo_zoom.dart';

/// Shows where a double tap sends the zoom.
///
/// A marker is drawn on the image, a double tap is sent to exactly that point,
/// and the tile under the marker is the same tile afterwards. That is the whole
/// claim, and a numbered grid is what makes it checkable: with a photograph of
/// a sky you could not tell whether the zoom kept its place.
///
/// The tap is synthesised rather than performed, so the recording in the README
/// lands on the same pixel every time and the reader is not being asked to
/// trust a steady hand.
class AnchoredZoomPage extends StatefulWidget {
  const AnchoredZoomPage({super.key, this.autoPlay = true});

  /// Whether the demonstration repeats on its own. Off leaves the viewer alone
  /// to be pinched and dragged by hand.
  final bool autoPlay;

  @override
  State<AnchoredZoomPage> createState() => _AnchoredZoomPageState();
}

class _AnchoredZoomPageState extends State<AnchoredZoomPage> {
  static const _asset = AssetImage('assets/detail.png');

  /// The size of that asset, as `tool/make_demo_asset.dart` writes it.
  static const _imageSize = Size(900, 1125);

  /// Where the tap lands **on the image**, as a fraction of it. Anchoring to
  /// the image rather than to the viewer matters: at a contained fit the image
  /// does not fill a landscape viewer, and a point picked in viewer
  /// coordinates can land on the letterbox, where there is no tile to check.
  ///
  /// The grid is four across and five down, so (0.30, 0.30) is tile 6.
  static const _imagePoint = Offset(0.30, 0.30);
  static const _tileName = 'tile 6';

  final _viewerKey = GlobalKey();
  final _controller = PhotoViewController();
  final _scaleState = PhotoViewScaleStateController();

  /// Wall clock for the synthetic events. Recognizers time gestures from
  /// `event.timeStamp`, and a run of events all stamped zero is not a gesture
  /// any of them can make sense of.
  final _clock = Stopwatch()..start();

  /// The marker is always drawn, brighter while a tap is in flight, so the
  /// reader sees where the tap will land before it lands.
  bool _showMarker = true;

  /// The two finger positions while a pinch is in flight, in viewer
  /// coordinates, or null when no pinch is running.
  (Offset, Offset?)? _fingers;
  late bool _loop = widget.autoPlay;
  bool _disposed = false;
  String _caption = 'Double tap on $_tileName';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runLoop());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller.dispose();
    _scaleState.dispose();
    super.dispose();
  }

  Future<void> _runLoop() async {
    // Kept moving on purpose. A loop that parks on a still frame for a second
    // and a half reads as a broken image rather than a demonstration, and a
    // frame-by-frame diff of the first cut of this recording came back 87%
    // unchanged. Every beat now either animates or hands over to the next one.
    while (!_disposed && _loop) {
      await _say('Double tap on $_tileName', 450);
      if (!_alive) return;
      await _doubleTap();
      await _say('$_tileName is still under the marker', 550);
      if (!_alive) return;

      await _say('Drag to pan', 60);
      await _drag(const Offset(-150, -70), millis: 620);
      if (!_alive) return;
      await _drag(const Offset(150, 70), millis: 520);
      if (!_alive) return;

      await _say('Pinch out from the same point', 60);
      await _pinch(from: 70, to: 280, millis: 560);
      await _say('Still $_tileName, and sharper the closer it gets', 700);
      if (!_alive) return;

      await _pinch(from: 280, to: 70, millis: 520);
      if (!_alive) return;
      await _say('Back to a contained fit', 60);
      _reset();
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }
  }

  bool get _alive => !_disposed && _loop;

  Future<void> _say(String text, int millis) async {
    if (!mounted) return;
    setState(() => _caption = text);
    await Future<void>.delayed(Duration(milliseconds: millis));
  }

  /// Where [_imagePoint] sits inside a viewer of [size], with the image at a
  /// contained fit. That is the resting state, which is when the tap happens.
  Offset _markerIn(Size size) {
    final scale = math.min(
      size.width / _imageSize.width,
      size.height / _imageSize.height,
    );
    return size.center(Offset.zero) +
        Offset(
          (_imagePoint.dx - 0.5) * _imageSize.width * scale,
          (_imagePoint.dy - 0.5) * _imageSize.height * scale,
        );
  }

  /// Sends a double tap to the marker.
  Future<void> _doubleTap() async {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final point = box.localToGlobal(Offset.zero) + _markerIn(box.size);

    setState(() => _showMarker = true);
    _tap(point, pointer: 101);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    _tap(point, pointer: 102);
  }

  /// Drags one finger by [by], drawn while it moves.
  Future<void> _drag(Offset by, {required int millis}) async {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final start = origin + box.size.center(Offset.zero);

    final steps = (millis / 16).round();
    var t = _clock.elapsed;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: 301, position: start, timeStamp: t),
    );
    setState(() => _fingers = (start - origin, null));

    for (var i = 1; i <= steps; i++) {
      if (!mounted || _disposed) break;
      final progress = 1 - math.pow(1 - i / steps, 3);
      final at = start + by * progress.toDouble();
      t += const Duration(milliseconds: 16);
      GestureBinding.instance.handlePointerEvent(
        PointerMoveEvent(pointer: 301, position: at, timeStamp: t),
      );
      setState(() => _fingers = (at - origin, null));
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(
        pointer: 301,
        position: start + by,
        timeStamp: t + const Duration(milliseconds: 16),
      ),
    );
    if (mounted) setState(() => _fingers = null);
  }

  /// Spreads two fingers apart on the marker, from [from] to [to] logical
  /// pixels of separation, and draws them while they move.
  Future<void> _pinch({
    required double from,
    required double to,
    int millis = 560,
  }) async {
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero);
    final local = _markerIn(box.size);
    final focal = origin + local;

    // Along a diagonal, so both axes move and the spread is unmistakable.
    const axis = Offset(0.707, 0.707);
    Offset a(double gap) => focal - axis * (gap / 2);
    Offset b(double gap) => focal + axis * (gap / 2);

    final steps = (millis / 16).round();
    var t = _clock.elapsed;
    void send(
      PointerEvent Function(int pointer, Offset at, Duration ts) make,
      double gap,
    ) {
      GestureBinding.instance
        ..handlePointerEvent(make(201, a(gap), t))
        ..handlePointerEvent(make(202, b(gap), t));
    }

    setState(() => _fingers = (a(from) - origin, b(from) - origin));
    send(
      (p, at, ts) => PointerDownEvent(pointer: p, position: at, timeStamp: ts),
      from,
    );

    for (var i = 1; i <= steps; i++) {
      if (!mounted || _disposed) break;
      // Ease out, so it reads as a hand rather than a slider.
      final progress = 1 - math.pow(1 - i / steps, 3);
      final gap = from + (to - from) * progress;
      t += const Duration(milliseconds: 16);
      send(
        (p, at, ts) =>
            PointerMoveEvent(pointer: p, position: at, timeStamp: ts),
        gap,
      );
      setState(() => _fingers = (a(gap) - origin, b(gap) - origin));
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    t += const Duration(milliseconds: 16);
    send(
      (p, at, ts) => PointerUpEvent(pointer: p, position: at, timeStamp: ts),
      to,
    );
    if (mounted) setState(() => _fingers = null);
  }

  void _tap(Offset position, {required int pointer}) {
    final down = _clock.elapsed;
    final binding = GestureBinding.instance
      ..handlePointerEvent(
        PointerDownEvent(pointer: pointer, position: position, timeStamp: down),
      );
    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: position,
        timeStamp: down + const Duration(milliseconds: 40),
      ),
    );
  }

  void _reset() {
    _controller.reset();
    _scaleState.scaleState = PhotoViewScaleState.initial;
    if (mounted) setState(() => _showMarker = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    key: _viewerKey,
                    fit: StackFit.expand,
                    children: [
                      PhotoView(
                        imageProvider: _asset,
                        controller: _controller,
                        scaleStateController: _scaleState,
                        backgroundDecoration: const BoxDecoration(
                          color: Color(0xFF14161C),
                        ),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 3,
                      ),
                      IgnorePointer(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final at = _markerIn(constraints.biggest);
                            final fingers = _fingers;
                            return Stack(
                              children: [
                                Positioned(
                                  left: at.dx - 22,
                                  top: at.dy - 22,
                                  child: _Marker(visible: _showMarker),
                                ),
                                if (fingers != null) ...[
                                  _finger(fingers.$1),
                                  if (fingers.$2 != null) _finger(fingers.$2!),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: _Badge(
                            child: ValueListenableBuilder(
                              valueListenable: _controller,
                              builder: (context, value, _) => Text(
                                value.scale == null
                                    ? '×--'
                                    : '×${value.scale!.toStringAsFixed(2)}',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        _caption,
                        key: ValueKey(_caption),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _loop = false);
                      _doubleTap();
                    },
                    icon: const Icon(Icons.touch_app, size: 18),
                    label: const Text('Double tap'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _loop = false);
                      _reset();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One drawn fingertip, for the pinch.
Widget _finger(Offset at) => Positioned(
  left: at.dx - 19,
  top: at.dy - 19,
  child: Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
    ),
  ),
);

/// The ring drawn where the tap lands.
class _Marker extends StatelessWidget {
  const _Marker({required this.visible});

  /// Whether a tap is in flight. The marker stays on either way; this only
  /// brightens it, so the reader can see the gesture happen.
  final bool visible;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0.45,
    duration: const Duration(milliseconds: 140),
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.lightGreenAccent, width: 3),
        color: Colors.lightGreenAccent.withValues(alpha: 0.18),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(9),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(
        color: Colors.lightGreenAccent,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      child: child,
    ),
  );
}
