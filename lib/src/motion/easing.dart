import 'dart:math' as math;

/// Evaluating a CSS easing in Dart, so an interrupted animation can be asked
/// how fast it was travelling at the moment it was replaced. Only the forms the
/// library can hand out are understood; anything else returns null, and the
/// caller falls back to starting the next animation from rest.
typedef EasingFn = double Function(double t);

const Map<String, List<double>> _keywords = {
  'linear': [0, 0, 1, 1],
  'ease': [0.25, 0.1, 0.25, 1],
  'ease-in': [0.42, 0, 1, 1],
  'ease-out': [0, 0, 0.58, 1],
  'ease-in-out': [0.42, 0, 0.58, 1],
};

double _axis(double p1, double p2, double t) {
  final u = 1 - t;
  return 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t;
}

EasingFn cubicBezier(double x1, double y1, double x2, double y2) {
  return (t) {
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 24; i += 1) {
      final mid = (lo + hi) / 2;
      if (_axis(x1, x2, mid) < t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _axis(y1, y2, (lo + hi) / 2);
  };
}

/// Positions left out are spread evenly between the nearest given ones.
List<double> _fillStops(List<double?> stops) {
  final filled = List<double?>.of(stops);
  filled[0] ??= 0;
  filled[filled.length - 1] ??= 1;

  for (var i = 1; i < filled.length; i += 1) {
    if (filled[i] != null) continue;
    var next = i;
    while (filled[next] == null) {
      next += 1;
    }
    final start = filled[i - 1]!;
    final step = (filled[next]! - start) / (next - i + 1);
    for (var j = i; j < next; j += 1) {
      filled[j] = start + step * (j - i + 1);
    }
  }

  // Monotonic, so a segment can never span backwards.
  final out = <double>[];
  for (var i = 0; i < filled.length; i++) {
    final stop = filled[i]!;
    out.add(i == 0 ? stop : math.max(stop, out[i - 1]));
  }
  return out;
}

EasingFn? _linearEasing(String body) {
  final values = <double>[];
  final stops = <double?>[];

  for (final part in body.split(',')) {
    final tokens = part.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final value = jsNumber(tokens.isEmpty ? '' : tokens[0]);
    if (!value.isFinite) return null;

    final percents = tokens.sublist(tokens.isEmpty ? 0 : 1);
    if (percents.length > 2) return null;
    if (percents.isEmpty) {
      values.add(value);
      stops.add(null);
      continue;
    }
    // Two stops hold the value across the span between them.
    for (final percent in percents) {
      if (!percent.endsWith('%')) return null;
      final stop = jsNumber(percent.substring(0, percent.length - 1));
      if (!stop.isFinite) return null;
      values.add(value);
      stops.add(stop / 100);
    }
  }

  if (values.length < 2) return null;
  final positions = _fillStops(stops);

  return (t) {
    if (t <= positions[0]) return values[0];
    final last = positions.length - 1;
    if (t >= positions[last]) return values[last];

    var i = 0;
    while (i < last && positions[i + 1] < t) {
      i += 1;
    }
    final span = positions[i + 1] - positions[i];
    if (span == 0) return values[i + 1];
    return values[i] + ((values[i + 1] - values[i]) * (t - positions[i])) / span;
  };
}

final RegExp _bezierRe = RegExp(r'^cubic-bezier\(([^)]*)\)$');
final RegExp _linearRe = RegExp(r'^linear\(([^)]*)\)$');

EasingFn? parseEasing(String ease) {
  final value = ease.trim().toLowerCase();

  final keyword = _keywords[value];
  if (keyword != null) {
    return cubicBezier(keyword[0], keyword[1], keyword[2], keyword[3]);
  }

  final bezier = _bezierRe.firstMatch(value);
  if (bezier != null) {
    final n = bezier.group(1)!.split(',').map((part) => jsNumber(part.trim())).toList();
    if (n.length != 4 || n.any((v) => !v.isFinite)) return null;
    return cubicBezier(n[0], n[1], n[2], n[3]);
  }

  final linear = _linearRe.firstMatch(value);
  if (linear != null) return _linearEasing(linear.group(1)!);

  return null;
}

const double _h = 1e-4;

/// Progress per unit of normalised time. Forward, so a knot reports the
/// segment ahead.
double slopeAt(EasingFn easing, double t) {
  final a = math.min(math.max(t, 0.0), 1 - _h);
  return (easing(a + _h) - easing(a)) / _h;
}

/// JavaScript `Number(string)` for the forms a CSS easing can carry.
double jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  final lower = t.toLowerCase();
  if (lower.startsWith('0x') || lower.startsWith('0b') || lower.startsWith('0o')) {
    final radix = lower[1] == 'x' ? 16 : (lower[1] == 'b' ? 2 : 8);
    final v = int.tryParse(t.substring(2), radix: radix);
    return v == null ? double.nan : v.toDouble();
  }
  if (t == 'Infinity' || t == '+Infinity') return double.infinity;
  if (t == '-Infinity') return double.negativeInfinity;
  if (lower == 'infinity' || lower == 'nan') return double.nan;
  return double.tryParse(t) ?? double.nan;
}

/// JavaScript `Math.round`: halves round towards +∞.
double jsRound(double x) {
  final f = x.floorToDouble();
  return (x - f >= 0.5) ? f + 1 : f;
}

/// JavaScript number → string for the values a sampled easing carries.
String jsNumberToString(double v) {
  if (v == 0) return '0';
  if (v.isNaN) return 'NaN';
  if (v.isInfinite) return v > 0 ? 'Infinity' : '-Infinity';
  if (v == v.truncateToDouble() && v.abs() < 1e21) {
    return v.toInt().toString();
  }
  return v.toString();
}
