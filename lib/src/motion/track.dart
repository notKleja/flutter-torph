import 'easing.dart';

/// A 2D transform of the form `translate(tx, ty) scale(sx, sy)`, which is the
/// only shape upstream ever hands to WAAPI.
class Transform2 {
  const Transform2({this.tx = 0, this.ty = 0, this.sx = 1, this.sy = 1});

  static const Transform2 none = Transform2();

  final double tx;
  final double ty;
  final double sx;
  final double sy;

  Transform2 lerp(Transform2 other, double p) => Transform2(
        tx: tx + (other.tx - tx) * p,
        ty: ty + (other.ty - ty) * p,
        sx: sx + (other.sx - sx) * p,
        sy: sy + (other.sy - sy) * p,
      );

  @override
  String toString() => 'translate(${tx}px, ${ty}px) scale($sx, $sy)';
}

/// One `element.animate(...)` call on one property, with `fill: "both"`.
///
/// A track is pending until the first frame after its creation, which is when
/// WAAPI resolves a play-pending animation's start time — so the first painted
/// frame shows progress 0.
class Track<T> {
  Track({
    required this.from,
    required this.to,
    required this.duration,
    required this.easing,
    this.delay = 0,
    required this.lerp,
  });

  final T from;
  final T to;
  final double duration;
  final double delay;
  final EasingFn easing;
  final T Function(T a, T b, double p) lerp;

  double? startedAt;
  bool cancelled = false;

  /// Resolves the start time; called by the timeline on the first frame.
  void start(double now) => startedAt ??= now;

  double progress(double now) {
    final start = startedAt;
    if (start == null) return 0;
    final local = now - start - delay;
    if (local <= 0) return 0;
    if (local >= duration) return 1;
    return easing(local / duration);
  }

  bool finished(double now) {
    final start = startedAt;
    return start != null && now - start >= delay + duration;
  }

  T valueAt(double now) => lerp(from, to, progress(now));
}

Transform2 lerpTransform(Transform2 a, Transform2 b, double p) => a.lerp(b, p);

double lerpDouble(double a, double b, double p) => a + (b - a) * p;

double linearEasing(double t) => t;

/// An animatable box: the set of tracks WAAPI would hold for one element.
/// The latest non-cancelled track for a property wins (composite: replace).
class AnimatedBox {
  final List<Track<Transform2>> transformTracks = [];
  final List<Track<double>> opacityTracks = [];

  /// The value in effect when no animation targets the property.
  Transform2 underlyingTransform = Transform2.none;
  double underlyingOpacity = 1;

  Track<Transform2>? get _transform =>
      transformTracks.isEmpty ? null : transformTracks.last;
  Track<double>? get _opacity => opacityTracks.isEmpty ? null : opacityTracks.last;

  Transform2 transformAt(double now) =>
      _transform?.valueAt(now) ?? underlyingTransform;

  double opacityAt(double now) => _opacity?.valueAt(now) ?? underlyingOpacity;

  bool get hasAnimations => transformTracks.isNotEmpty || opacityTracks.isNotEmpty;

  /// `element.getAnimations().forEach((a) => a.cancel())`.
  void cancelAll() {
    for (final t in transformTracks) {
      t.cancelled = true;
    }
    for (final t in opacityTracks) {
      t.cancelled = true;
    }
    transformTracks.clear();
    opacityTracks.clear();
  }

  void start(double now) {
    for (final t in transformTracks) {
      t.start(now);
    }
    for (final t in opacityTracks) {
      t.start(now);
    }
  }

  bool settled(double now) =>
      transformTracks.every((t) => t.finished(now)) &&
      opacityTracks.every((t) => t.finished(now));

  Track<Transform2> animateTransform({
    required Transform2 from,
    required Transform2 to,
    required double duration,
    required EasingFn easing,
  }) {
    final track = Track<Transform2>(
      from: from,
      to: to,
      duration: duration,
      easing: easing,
      lerp: lerpTransform,
    );
    transformTracks.add(track);
    return track;
  }

  Track<double> animateOpacity({
    required double from,
    required double to,
    required double duration,
    double delay = 0,
  }) {
    final track = Track<double>(
      from: from,
      to: to,
      duration: duration,
      delay: delay,
      easing: linearEasing,
      lerp: lerpDouble,
    );
    opacityTracks.add(track);
    return track;
  }
}
