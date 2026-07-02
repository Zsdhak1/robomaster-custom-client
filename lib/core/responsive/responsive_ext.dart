/// Extension methods on [BuildContext] for proportional scaling.
///
/// Usage:
/// ```dart
/// final s = context.scale;            // unified scale factor
/// final fontSize = context.fontSize(16);
/// final padding  = context.inset(12);
/// final iconSz   = context.iconSize(24);
/// ```
library;

import 'package:flutter/material.dart';

import '../theme/text_theme.dart';
import 'design_constants.dart';
import 'window_size_class.dart';

extension ResponsiveContext on BuildContext {
  /// Unified scale factor: minimum of horizontal and vertical ratios,
  /// clamped to [minScale]..[maxScale].
  ///
  /// Using `min` preserves aspect-ratio fidelity — when the window is
  /// wider than 16:9 the content does not grow taller, and when narrower
  /// it does not get crushed horizontally.
  double get scale {
    final size = MediaQuery.sizeOf(this);
    final sx = size.width / refWidth;
    final sy = size.height / refHeight;
    return (sx < sy ? sx : sy).clamp(minScale, maxScale);
  }

  // ---- convenience helpers ----

  /// Scale a base font size.
  double fontSize(double base) => base * scale;

  /// Scale a base pixel dimension (spacing, height, width, radius…).
  double sp(double base) => base * scale;

  /// Scale an icon dimension.
  double iconSize(double base) => base * scale;

  /// All-[value] edge insets scaled.
  EdgeInsets insetAll(double value) => EdgeInsets.all(sp(value));

  /// Symmetric horizontal + vertical insets scaled.
  EdgeInsets insetSym({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: sp(h), vertical: sp(v));

  /// Only‑side insets scaled.
  EdgeInsets insetOnly({
    double l = 0,
    double t = 0,
    double r = 0,
    double b = 0,
  }) =>
      EdgeInsets.only(
        left: sp(l),
        top: sp(t),
        right: sp(r),
        bottom: sp(b),
      );

  /// Fixed-size box with scaled width / height.
  Widget sizedBox({double? w, double? h}) =>
      SizedBox(width: w != null ? sp(w) : null, height: h != null ? sp(h) : null);

  // ---- theme-aware convenience getters ----
  // These map the raw constants from [app_theme] to their scaled equivalents
  // so callers can write `context.rmTopBarHeight` instead of
  // `context.sp(rmTopBarHeight)`.

  /// Scaled top status bar height (base: 48).
  double get rmTopBarHeight => sp(48);

  /// Scaled status indicator dot size (base: 10).
  double get rmStatusDotSize => sp(10);

  /// Scaled robot icon size (base: 48).
  double get rmRobotIconSize => sp(48);

  /// Scaled card border radius (base: 12).
  double get rmCardRadius => sp(12);

  /// MD3 [TextTheme] scaled by the current window size.
  ///
  /// Prefer this over raw `TextStyle(fontSize: ...)` calls. Use type-scale
  /// roles (`displaySmall`, `headlineMedium`, `titleMedium`, `bodyMedium`,
  /// `labelSmall`, etc.) and apply `.copyWith()` only for local overrides
  /// such as `fontWeight` or `color`. This keeps typography responsive and
  /// consistent across the app.
  ///
  /// Example:
  /// ```dart
  /// Text('Hello', style: context.textTheme.titleMedium)
  /// ```
  TextTheme get textTheme => scaledTextThemeByFactor(scale);

  /// MD3 window size class for the current viewport width.
  ///
  /// Use this to switch navigation layout, content density or column count:
  /// - compact (<600) → bottom NavigationBar
  /// - medium (600–839) → collapsed NavigationRail
  /// - expanded (≥840) → expanded NavigationRail with labels
  WindowSizeClass get windowSizeClass =>
      WindowSizeClass.fromWidth(MediaQuery.sizeOf(this).width);
}
