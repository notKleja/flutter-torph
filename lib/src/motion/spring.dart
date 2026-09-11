import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;

import 'carry.dart' show sampleEasing;
import 'easing.dart';

class SpringParams {
  const SpringParams({
    this.stiffness = 100,
    this.damping = 10,
    this.mass = 1,
    this.precision = 0.001,
  });

  final double stiffness;
  final double damping;
  final double mass;
  final double precision;

  @override
  bool operator ==(Object other) =>
      other is SpringParams &&
      other.stiffness == stiffness &&
      other.damping == damping &&
      other.mass == mass &&
      other.precision == precision;

  @override
  int get hashCode => Object.hash(stiffness, damping, mass, precision);

  @override
  String toString() =>
      'SpringParams(stiffness: $stiffness, damping: $damping, mass: $mass, precision: $precision)';
}

class SpringResult {
  const SpringResult(this.easing, this.duration);

  /// A CSS `linear(...)` easing string, exactly as upstream hands to WAAPI.
  final String easing;

  final int duration;
}

double springPosition(double t, double omega0, double zeta) {
  if (zeta < 1) {
    final omegaD = omega0 * math.sqrt(1 - zeta * zeta);
    return 1 -
        math.exp(-zeta * omega0 * t) *
            (math.cos(omegaD * t) +
                ((zeta * omega0) / omegaD) * math.sin(omegaD * t));
  }

  // Overdamped (includes near-critically-damped)
  final s = math.sqrt(zeta * zeta - 1);
  final r1 = -omega0 * (zeta + s);
  final r2 = -omega0 * (zeta - s);
  final b = -r1 / (r2 - r1);
  final a = 1 - b;
  return 1 - a * math.exp(r1 * t) - b * math.exp(r2 * t);
}

int computeDuration(double omega0, double zeta, double precision) {
  const step = 0.001;
  const maxDuration = 10.0;
  var settledSince = 0.0;

  for (var t = 0.0; t < maxDuration; t += step) {
    if ((springPosition(t, omega0, zeta) - 1).abs() > precision) {
      settledSince = 0;
    } else {
      settledSince += step;
      if (settledSince > 0.1) {
        return ((t - settledSince + step) * 1000).ceil();
      }
    }
  }

  return (maxDuration * 1000).ceil();
}

final Map<SpringParams, SpringResult> _cache = {};

SpringResult spring([SpringParams params = const SpringParams()]) {
  final cached = _cache[params];
  if (cached != null) return cached;

  final stiffness = params.stiffness;
  final damping = params.damping;
  final mass = params.mass;
  final precision = params.precision;

  final omega0 = math.sqrt(stiffness / mass);
  final zeta = damping / (2 * math.sqrt(stiffness * mass));

  final duration = computeDuration(omega0, zeta, precision);
  final numPoints = math.min(100, math.max(32, jsRound(duration / 15).toInt()));

  final points = <String>[];
  for (var i = 0; i < numPoints; i++) {
    final t = (i / (numPoints - 1)) * (duration / 1000);
    final value = i == numPoints - 1 ? 1.0 : springPosition(t, omega0, zeta);
    points.add(jsNumberToString(jsRound(value * 10000) / 10000));
  }

  // Trim trailing "1" values (keep at least 2)
  while (points.length > 2 && points[points.length - 2] == '1') {
    points.removeAt(points.length - 2);
  }

  final result = SpringResult('linear(${points.join(', ')})', duration);
  _cache[params] = result;
  return result;
}

class ResolvedEase {
  const ResolvedEase(this.ease, this.duration);

  final String ease;

  /// Milliseconds.
  final int duration;
}

/// A spring settles on its own physics; a string keeps the caller's duration.
ResolvedEase resolveEase(Object ease, int fallbackDuration) {
  if (ease is SpringParams) {
    final resolved = spring(ease);
    return ResolvedEase(resolved.easing, resolved.duration);
  }
  if (ease is Curve) {
    return ResolvedEase(
      sampleEasing(ease.transform, fallbackDuration.toDouble()),
      fallbackDuration,
    );
  }
  if (ease is String) return ResolvedEase(ease, fallbackDuration);
  throw ArgumentError.value(
    ease,
    'ease',
    'must be a CSS easing String, a Curve, or SpringParams',
  );
}
