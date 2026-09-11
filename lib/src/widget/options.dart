import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/foundation.dart';

import '../motion/easing.dart';
import '../motion/morph_engine.dart';
import '../motion/spring.dart';

/// Upstream `DEFAULT_TEXT_MORPH_OPTIONS.ease`.
const String defaultEase = 'cubic-bezier(0.19, 1, 0.22, 1)';

/// Upstream `DEFAULT_TEXT_MORPH_OPTIONS.duration`, in milliseconds.
const Duration defaultDuration = Duration(milliseconds: 400);

/// Upstream `DEFAULT_TEXT_MORPH_OPTIONS.locale`.
const String defaultLocaleTag = 'en';

/// Blur sigma, in logical pixels, that entering items start from and exiting
/// items fade into. Zero disables it.
const double defaultBlur = 1.5;

/// Validates an `ease` option the way the engine will, but at widget
/// construction time so the error names the caller.
Object validateEase(Object ease) {
  if (ease is SpringParams) return ease;
  if (ease is Curve) return ease;
  if (ease is String) {
    if (parseEasing(ease) == null) {
      throw ArgumentError.value(ease, 'ease', 'unsupported CSS easing');
    }
    return ease;
  }
  throw ArgumentError.value(
    ease,
    'ease',
    'must be a CSS easing String, a Curve, or SpringParams',
  );
}

double validateBlur(double blur) {
  if (!blur.isFinite || blur < 0) {
    throw ArgumentError.value(
      blur,
      'blur',
      'must be a finite, non-negative number',
    );
  }
  return blur;
}

ResolvedEase resolveWidgetEase(Object ease, Duration duration) =>
    resolveEase(validateEase(ease), duration.inMilliseconds);

/// Upstream `MorphController.serializeConfig`: the options whose change
/// recreates the instance (`LIFECYCLE-001`). Callbacks are deliberately absent,
/// so changing one never tears a morph down.
/// Keyed on the resolved easing, since a non-const `Curve` has no `==`.
@immutable
class MorphConfigKey {
  const MorphConfigKey({
    required this.resolvedEase,
    required this.resolvedDuration,
    required this.locale,
    required this.scale,
    required this.numbers,
    required this.decimals,
    required this.blur,
    required this.debug,
    required this.disabled,
    required this.respectReducedMotion,
  });

  final String resolvedEase;
  final Duration resolvedDuration;
  final String locale;
  final bool scale;
  final bool numbers;
  final int? decimals;
  final double blur;
  final bool debug;
  final bool disabled;
  final bool respectReducedMotion;

  @override
  bool operator ==(Object other) =>
      other is MorphConfigKey &&
      other.resolvedEase == resolvedEase &&
      other.resolvedDuration == resolvedDuration &&
      other.locale == locale &&
      other.scale == scale &&
      other.numbers == numbers &&
      other.decimals == decimals &&
      other.blur == blur &&
      other.debug == debug &&
      other.disabled == disabled &&
      other.respectReducedMotion == respectReducedMotion;

  @override
  int get hashCode => Object.hash(
    resolvedEase,
    resolvedDuration,
    locale,
    scale,
    numbers,
    decimals,
    blur,
    debug,
    disabled,
    respectReducedMotion,
  );

  @override
  String toString() =>
      'MorphConfigKey(resolvedEase: $resolvedEase, '
      'resolvedDuration: $resolvedDuration, '
      'locale: $locale, scale: $scale, numbers: $numbers, decimals: $decimals, '
      'blur: $blur, debug: $debug, disabled: $disabled, '
      'respectReducedMotion: $respectReducedMotion)';
}

/// Builds the engine's resolved config (upstream `resolveEase`).
MorphConfig buildMorphConfig({
  required ResolvedEase resolvedEase,
  required String locale,
  required bool scale,
  required bool numbers,
  required int? decimals,
  required bool debug,
  double blur = defaultBlur,
  VoidCallback? onAnimationStart,
  VoidCallback? onAnimationComplete,
  VoidCallback? onAnimationCancel,
}) {
  return MorphConfig(
    locale: locale,
    duration: resolvedEase.duration.toDouble(),
    ease: resolvedEase.ease,
    scale: scale,
    numbers: numbers,
    decimals: decimals,
    blur: validateBlur(blur),
    debug: debug,
    onAnimationStart: onAnimationStart,
    onAnimationComplete: onAnimationComplete,
    onAnimationCancel: onAnimationCancel,
  );
}
