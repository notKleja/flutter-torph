import 'dart:math' as math;

import 'easing.dart';

// A share of the morph, never a fixed length — a cap here leaves a character
// opaque and motionless for the rest of a long duration.
double fadeDuration(double duration, double fraction) => duration * fraction;

// Normalised velocity is distance-relative, so a near-zero distance would
// launch the box across the screen. These bound that, and the overshoot the
// carry can produce.
const double carryMax = 8;
const double carryOvershoot = 0.1;
const double carryMinDelta = 0.5;

// Measurement noise, not a moved target.
const double sameTarget = 0.5;

class Carried {
  const Carried(this.curve, this.k);

  final EasingFn curve;
  final double k;
}

/// The author's curve, leaving at the speed the box is already travelling.
/// Momentum is only ever added, never subtracted.
Carried carry(EasingFn base, double normalisedVelocity) {
  // `Math.max(0, NaN)` is NaN and `NaN <= 0` is false, so the guard has to be positive.
  final k = _jsMax(0, _jsMin(carryMax, normalisedVelocity) - slopeAt(base, 0));
  if (!(k > 0)) return Carried(base, 0);

  final bump = math.max(3, (k / (math.e * carryOvershoot)).ceil() - 1);
  return Carried(
    (t) => t >= 1 ? 1 : base(t) + k * t * math.pow(1 - t, bump),
    k,
  );
}

// JS Math.min/max propagate NaN; Dart's math.min/max do not.
double _jsMin(double a, double b) =>
    (a.isNaN || b.isNaN) ? double.nan : math.min(a, b);
double _jsMax(double a, double b) =>
    (a.isNaN || b.isNaN) ? double.nan : math.max(a, b);

/// Sampled fine enough that a segment is shorter than a frame at 120Hz.
String sampleEasing(EasingFn curve, double duration) {
  final points = math.min(120, math.max(32, jsRound(duration / 8).toInt()));
  final values = <String>[];
  for (var i = 0; i < points; i += 1) {
    final t = i / (points - 1);
    final value = i == points - 1 ? 1.0 : curve(t);
    values.add(jsNumberToString(jsRound(value * 10000) / 10000));
  }
  return 'linear(${values.join(', ')})';
}
