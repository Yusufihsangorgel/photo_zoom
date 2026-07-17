/// The step of the double-tap cycle a [PhotoView] is in.
///
/// The cycle is walked by [PhotoView.scaleStateCycle]; the default is
/// [defaultScaleStateCycle].
enum PhotoViewScaleState {
  /// The child is at [PhotoView.initialScale].
  initial,

  /// The child is scaled to cover the whole viewport.
  covering,

  /// The child is at its intrinsic size (scale `1.0`).
  originalSize,

  /// The user scaled the child above [PhotoView.initialScale] by hand.
  zoomedIn,

  /// The user scaled the child below [PhotoView.initialScale] by hand.
  zoomedOut;

  /// Whether this state was reached by a user gesture rather than by the
  /// double-tap cycle.
  bool get isZooming => this == zoomedIn || this == zoomedOut;
}
