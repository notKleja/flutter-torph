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

/// The option defaults, exactly upstream's `DEFAULT_TEXT_MORPH_OPTIONS`
/// (`BASE_DEFAULTS` plus `debug`, `scale`, `numbers`).
@immutable
class TextMorphOptions {
  const TextMorphOptions({
    this.locale = defaultLocaleTag,
    this.duration = defaultDuration,
    this.ease = defaultEase,
    this.disabled = false,
    this.respectReducedMotion = true,
    this.debug = false,
    this.scale = true,
    this.numbers = true,
    this.decimals,
    this.blur = defaultBlur,
    this.bidi = true,
  });

  final String locale;
  final Duration duration;

  /// A CSS easing `String` or a [SpringParams].
  final Object ease;
  final bool disabled;
  final bool respectReducedMotion;
  final bool debug;
  final bool scale;
  final bool numbers;
  final int? decimals;
  final double blur;

  /// Place each segment where the Unicode Bidirectional Algorithm puts it.
  final bool bidi;

  @override
  bool operator ==(Object other) =>
      other is TextMorphOptions &&
      other.locale == locale &&
      other.duration == duration &&
      other.ease == ease &&
      other.disabled == disabled &&
      other.respectReducedMotion == respectReducedMotion &&
      other.debug == debug &&
      other.scale == scale &&
      other.numbers == numbers &&
      other.decimals == decimals &&
      other.blur == blur &&
      other.bidi == bidi;

  @override
  int get hashCode => Object.hash(locale, duration, ease, disabled,
      respectReducedMotion, debug, scale, numbers, decimals, blur, bidi);
}

/// Upstream `DEFAULT_TEXT_MORPH_OPTIONS`.
const TextMorphOptions defaultTextMorphOptions = TextMorphOptions();

/// Validates an `ease` option the way the engine will, but at widget
/// construction time so the error names the caller.
///
/// Throws [ArgumentError] for anything that is neither a [SpringParams] nor a
/// CSS easing string the engine can parse.
Object validateEase(Object ease) {
  if (ease is SpringParams) return ease;
  if (ease is String) {
    if (parseEasing(ease) == null) {
      throw ArgumentError.value(ease, 'ease', 'unsupported CSS easing');
    }
    return ease;
  }
  throw ArgumentError.value(ease, 'ease', 'must be a CSS easing String or SpringParams');
}

double validateBlur(double blur) {
  if (!blur.isFinite || blur < 0) {
    throw ArgumentError.value(blur, 'blur', 'must be a finite, non-negative number');
  }
  return blur;
}

/// Upstream `MorphController.serializeConfig`: the options whose change
/// recreates the instance (`LIFECYCLE-001`). Callbacks are deliberately absent,
/// so changing one never tears a morph down.
@immutable
class MorphConfigKey {
  const MorphConfigKey({
    required this.ease,
    required this.duration,
    required this.locale,
    required this.scale,
    required this.numbers,
    required this.decimals,
    required this.blur,
    required this.debug,
    required this.disabled,
    required this.respectReducedMotion,
  });

  final Object ease;
  final Duration duration;
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
      other.ease == ease &&
      other.duration == duration &&
      other.locale == locale &&
      other.scale == scale &&
      other.numbers == numbers &&
      other.decimals == decimals &&
      other.blur == blur &&
      other.debug == debug &&
      other.disabled == disabled &&
      other.respectReducedMotion == respectReducedMotion;

  @override
  int get hashCode => Object.hash(ease, duration, locale, scale, numbers,
      decimals, blur, debug, disabled, respectReducedMotion);

  @override
  String toString() => 'MorphConfigKey(ease: $ease, duration: $duration, '
      'locale: $locale, scale: $scale, numbers: $numbers, decimals: $decimals, '
      'blur: $blur, debug: $debug, disabled: $disabled, '
      'respectReducedMotion: $respectReducedMotion)';
}

/// Builds the engine's resolved config. A spring settles on its own physics, so
/// it replaces `duration` (upstream `resolveEase`).
MorphConfig buildMorphConfig({
  required Object ease,
  required Duration duration,
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
  final resolved = resolveEase(validateEase(ease), duration.inMilliseconds);
  return MorphConfig(
    locale: locale,
    duration: resolved.duration.toDouble(),
    ease: resolved.ease,
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
