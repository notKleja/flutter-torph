import 'package:flutter/widgets.dart';

/// Read live at every update, as upstream reads its media query. Both flags
/// are distinct: MediaQuery carries Android's setting, `reduceMotion` iOS's.
bool prefersReducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .reduceMotion;

/// The effective disabled state: the explicit option, or reduced motion when it
/// is respected (upstream `isDisabled()`).
bool isMorphDisabled(
  BuildContext context, {
  required bool disabled,
  required bool respectReducedMotion,
}) => disabled || (respectReducedMotion && prefersReducedMotion(context));
