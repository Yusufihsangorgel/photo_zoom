import 'package:flutter/widgets.dart';

import 'photo_view_controller.dart';
import 'photo_view_scale_state.dart';

/// Signature for [PhotoView.onTapUp].
typedef PhotoViewImageTapUpCallback =
    void Function(
      BuildContext context,
      TapUpDetails details,
      PhotoViewControllerValue controllerValue,
    );

/// Signature for [PhotoView.onTapDown].
typedef PhotoViewImageTapDownCallback =
    void Function(
      BuildContext context,
      TapDownDetails details,
      PhotoViewControllerValue controllerValue,
    );

/// Signature for [PhotoView.onScaleEnd].
typedef PhotoViewImageScaleEndCallback =
    void Function(
      BuildContext context,
      ScaleEndDetails details,
      PhotoViewControllerValue controllerValue,
    );

/// Signature for [PhotoView.scaleStateCycle]: given the current step of the
/// double-tap cycle, returns the next one.
///
/// See [defaultScaleStateCycle].
typedef ScaleStateCycle =
    PhotoViewScaleState Function(PhotoViewScaleState actual);

/// Signature for [PhotoView.loadingBuilder].
///
/// [event] is `null` until the image provider reports progress, and stays `null`
/// for providers that do not report any, such as [AssetImage].
typedef LoadingBuilder =
    Widget Function(BuildContext context, ImageChunkEvent? event);

/// The double-tap cycle [PhotoView] uses when [PhotoView.scaleStateCycle] is
/// left unset.
///
/// It walks initial to covering to original size and back to initial. Steps that
/// resolve to a scale the view is already at are skipped, so a double tap always
/// changes the scale.
PhotoViewScaleState defaultScaleStateCycle(PhotoViewScaleState actual) =>
    switch (actual) {
      PhotoViewScaleState.initial => PhotoViewScaleState.covering,
      PhotoViewScaleState.covering => PhotoViewScaleState.originalSize,
      PhotoViewScaleState.originalSize => PhotoViewScaleState.initial,
      PhotoViewScaleState.zoomedIn ||
      PhotoViewScaleState.zoomedOut => PhotoViewScaleState.initial,
    };
