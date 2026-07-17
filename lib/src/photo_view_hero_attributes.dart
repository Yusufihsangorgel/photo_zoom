import 'package:flutter/widgets.dart';

/// The [Hero] configuration for a [PhotoView].
///
/// Pass it to [PhotoView.heroAttributes] to have the view take part in a hero
/// transition. Leave it `null` and no [Hero] is inserted at all.
///
/// The source route needs a [Hero] with the same [tag]:
///
/// ```dart
/// // Source route:
/// Hero(tag: 'photo-1', child: Image.asset('assets/photo.jpg'))
///
/// // Destination route:
/// PhotoView(
///   imageProvider: const AssetImage('assets/photo.jpg'),
///   heroAttributes: const PhotoViewHeroAttributes(tag: 'photo-1'),
/// )
/// ```
///
/// The image provider must resolve synchronously (an [AssetImage] already
/// resolved, or a cached [NetworkImage]) for the flight to look right; a hero
/// that is still showing [PhotoView.loadingBuilder] when the flight starts will
/// animate an empty box.
@immutable
class PhotoViewHeroAttributes {
  /// Creates a hero configuration.
  const PhotoViewHeroAttributes({
    required this.tag,
    this.createRectTween,
    this.flightShuttleBuilder,
    this.placeholderBuilder,
    this.transitionOnUserGestures = false,
  });

  /// Mirrors [Hero.tag].
  final Object tag;

  /// Mirrors [Hero.createRectTween].
  final CreateRectTween? createRectTween;

  /// Mirrors [Hero.flightShuttleBuilder].
  final HeroFlightShuttleBuilder? flightShuttleBuilder;

  /// Mirrors [Hero.placeholderBuilder].
  final HeroPlaceholderBuilder? placeholderBuilder;

  /// Mirrors [Hero.transitionOnUserGestures].
  final bool transitionOnUserGestures;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoViewHeroAttributes &&
          tag == other.tag &&
          createRectTween == other.createRectTween &&
          flightShuttleBuilder == other.flightShuttleBuilder &&
          placeholderBuilder == other.placeholderBuilder &&
          transitionOnUserGestures == other.transitionOnUserGestures);

  @override
  int get hashCode => Object.hash(
    tag,
    createRectTween,
    flightShuttleBuilder,
    placeholderBuilder,
    transitionOnUserGestures,
  );
}
