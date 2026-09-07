import 'package:flutter/widgets.dart';

/// Whether the platform asks for reduced motion right now.
///
/// Upstream reads `matchMedia("(prefers-reduced-motion: reduce)")` live, so
/// this is read at every update rather than captured. Both Flutter surfaces are
/// consulted: the inherited [MediaQueryData.disableAnimations] (which tests and
/// `MediaQuery` overrides can set) and the platform's own accessibility
/// features, which is what the OS setting reaches.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

/// The effective disabled state: the explicit option, or reduced motion when it
/// is respected (upstream `isDisabled()`).
bool isMorphDisabled(
  BuildContext context, {
  required bool disabled,
  required bool respectReducedMotion,
}) =>
    disabled || (respectReducedMotion && prefersReducedMotion(context));
