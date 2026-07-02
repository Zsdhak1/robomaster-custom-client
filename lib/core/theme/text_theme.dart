/// MD3 type scale definitions and responsive scaling helpers.
///
/// This file is intentionally dependency-free (no Riverpod, no custom
/// extensions) so both [app_theme.dart] and [responsive_ext.dart] can
/// import it without creating circular dependencies.
library;

import 'package:flutter/material.dart';

// ============================================================
// MD3 Type Scale constants
// ============================================================

/// Standard MD3 type scale sizes (unscaled).
///
/// These match the Material 3 specification. Use [scaledTextTheme] or
/// [scaledTextThemeByFactor] to obtain a version scaled by the current
/// window's responsive factor.
const _TextScaleEntry _tsDisplay = _TextScaleEntry(57, 36, 45);
const _TextScaleEntry _tsHeadline = _TextScaleEntry(32, 24, 28);
const _TextScaleEntry _tsTitle = _TextScaleEntry(22, 16, 14);
const _TextScaleEntry _tsBody = _TextScaleEntry(16, 14, 12);
const _TextScaleEntry _tsLabel = _TextScaleEntry(14, 12, 11);

/// Internal helper to hold the three granularities of a type scale tier.
class _TextScaleEntry {
  const _TextScaleEntry(this.large, this.small, this.medium);
  final double large, small, medium;
}

// ============================================================
// Public API
// ============================================================

/// Builds an MD3 [TextTheme] with every size multiplied by [factor].
///
/// When [factor] == 1.0 the result matches the standard MD3 specification.
/// Pass a responsive scale factor (e.g. from [ResponsiveContext.scale]) to
/// make the theme follow the window size.
TextTheme scaledTextThemeByFactor(double factor) {
  return TextTheme(
    // Display
    displayLarge: TextStyle(
      fontSize: _tsDisplay.large * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontSize: _tsDisplay.medium * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    displaySmall: TextStyle(
      fontSize: _tsDisplay.small * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    // Headline
    headlineLarge: TextStyle(
      fontSize: _tsHeadline.large * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontSize: _tsHeadline.medium * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    headlineSmall: TextStyle(
      fontSize: _tsHeadline.small * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    ),
    // Title
    titleLarge: TextStyle(
      fontSize: _tsTitle.large * factor,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontSize: _tsTitle.medium * factor,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontSize: _tsTitle.small * factor,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    // Body
    bodyLarge: TextStyle(
      fontSize: _tsBody.large * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.5,
    ),
    bodyMedium: TextStyle(
      fontSize: _tsBody.medium * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: _tsBody.small * factor,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.4,
    ),
    // Label
    labelLarge: TextStyle(
      fontSize: _tsLabel.large * factor,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: _tsLabel.medium * factor,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontSize: _tsLabel.small * factor,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    ),
  );
}

/// Returns the MD3 [TextTheme] scaled by the user's accessibility text scale.
///
/// **Note:** This uses the OS-level text scaling factor, not the window
/// responsive scale. For responsive window scaling, use
/// `scaledTextThemeByFactor(context.scale)` or `context.textTheme` (from
/// [ResponsiveContext]).
TextTheme scaledTextTheme(BuildContext context) =>
    scaledTextThemeByFactor(
      MediaQuery.textScalerOf(context).scale(1.0),
    );