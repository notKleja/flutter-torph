import 'carry.dart';
import 'easing.dart';
import 'track.dart';

/// One axis of the container in flight: what it is animating between, the
/// easing WAAPI is actually applying (a `linear()` string when carried), and
/// the analytic curve used to read velocity back.
class Axis {
  Axis({
    required this.from,
    required this.to,
    required this.easing,
    required this.curve,
    required this.duration,
    required this.startedAt,
  }) : _fn = parseEasing(easing) ?? linearEasing;

  final double from;
  final double to;
  final String easing;
  final EasingFn? curve;
  final double duration;

  /// When the curve notionally began, so elapsed survives a resume.
  final double startedAt;

  final EasingFn _fn;
  bool cancelled = false;

  double valueAt(double now) {
    final run = now - startedAt;
    if (run <= 0) return from;
    if (run >= duration) return to;
    return from + (to - from) * _fn(run / duration);
  }

  bool finished(double now) => now - startedAt >= duration;
}

/// An axis mid-flight: where it was headed, how far it got, how fast it was
/// going.
class AxisState {
  const AxisState({
    required this.from,
    required this.to,
    required this.easing,
    required this.curve,
    required this.elapsed,
    required this.velocity,
  });

  final double from;
  final double to;
  final String easing;
  final EasingFn? curve;

  /// null once settled or cancelled — nothing to resume or carry.
  final double? elapsed;

  /// px per ms.
  final double velocity;
}

AxisState axisState(Axis axis, double duration, double now) {
  final run = now - axis.startedAt;
  final settled = axis.cancelled || !run.isFinite || run >= duration || run < 0;
  final elapsed = settled ? null : run;
  final curve = axis.curve;
  return AxisState(
    from: axis.from,
    to: axis.to,
    easing: axis.easing,
    curve: curve,
    elapsed: elapsed,
    velocity: elapsed == null || curve == null
        ? 0
        : ((axis.to - axis.from) * slopeAt(curve, elapsed / duration)) /
              duration,
  );
}

Axis animateAxis({
  required double from,
  required double to,
  required AxisState? previous,
  required double duration,
  required String ease,
  required EasingFn? base,
  required double now,
}) {
  Axis run(
    double from,
    double to,
    String easing,
    EasingFn? curve, [
    double? seek,
  ]) => Axis(
    from: from,
    to: to,
    easing: easing,
    curve: curve,
    duration: duration,
    startedAt: now - (seek ?? 0),
  );

  // The target has not moved, so the curve already in flight is still the
  // right one — resumed at the phase it had reached rather than started over.
  if (previous != null &&
      previous.elapsed != null &&
      (previous.to - to).abs() < sameTarget) {
    return run(
      previous.from,
      previous.to,
      previous.easing,
      previous.curve,
      previous.elapsed,
    );
  }

  final delta = to - from;
  var easing = ease;
  var curve = base;

  if (base != null && delta.abs() > carryMinDelta) {
    final carried = carry(base, ((previous?.velocity ?? 0) * duration) / delta);
    if (carried.k > 0) {
      curve = carried.curve;
      easing = sampleEasing(carried.curve, duration);
    }
  }

  return run(from, to, easing, curve);
}

/// The root's width/height transition, or a hold. Mirrors the `pending`
/// WeakMap entry upstream keeps per element.
class ContainerTransition {
  ContainerTransition._({
    required this.width,
    required this.height,
    required this.held,
    required this.duration,
    required this.startedAt,
    this.onComplete,
    this.onCancel,
  });

  final Axis? width;
  final Axis? height;

  /// A hold pins the size; there is no motion to hand on.
  final ({double width, double height})? held;
  final double duration;
  final double startedAt;
  final void Function()? onComplete;
  final void Function()? onCancel;

  bool _stopped = false;

  double widthAt(double now) => held?.width ?? width!.valueAt(now);
  double heightAt(double now) => held?.height ?? height!.valueAt(now);

  /// Read before the abort, while the animations are still running.
  ({AxisState width, AxisState height}) snapshot(double now) {
    final h = held;
    if (h != null) {
      AxisState pinned(double value) => AxisState(
        from: value,
        to: value,
        easing: 'linear',
        curve: null,
        elapsed: null,
        velocity: 0,
      );
      return (width: pinned(h.width), height: pinned(h.height));
    }
    return (
      width: axisState(width!, duration, now),
      height: axisState(height!, duration, now),
    );
  }

  /// Whether the width animation (the one carrying `onfinish`) has run out.
  bool finished(double now) =>
      held != null ? now - startedAt >= duration : width!.finished(now);

  void stop() {
    _stopped = true;
    width?.cancelled = true;
    height?.cancelled = true;
  }

  bool get stopped => _stopped;

  static ContainerTransition transition({
    required double oldWidth,
    required double oldHeight,
    required double newWidth,
    required double newHeight,
    required ({AxisState width, AxisState height})? previous,
    required double duration,
    required String ease,
    required double now,
    void Function()? onComplete,
    void Function()? onCancel,
  }) {
    final base = parseEasing(ease);

    // One per axis: each carries its own momentum, so they need their own curves.
    final width = animateAxis(
      from: oldWidth,
      to: newWidth,
      previous: previous?.width,
      duration: duration,
      ease: ease,
      base: base,
      now: now,
    );
    final height = animateAxis(
      from: oldHeight,
      to: newHeight,
      previous: previous?.height,
      duration: duration,
      ease: ease,
      base: base,
      now: now,
    );

    return ContainerTransition._(
      width: width,
      height: height,
      held: null,
      duration: duration,
      startedAt: now,
      onComplete: onComplete,
      onCancel: onCancel,
    );
  }

  static ContainerTransition hold({
    required double width,
    required double height,
    required double duration,
    required double now,
    void Function()? onComplete,
    void Function()? onCancel,
  }) => ContainerTransition._(
    width: null,
    height: null,
    held: (width: width, height: height),
    duration: duration,
    startedAt: now,
    onComplete: onComplete,
    onCancel: onCancel,
  );
}
