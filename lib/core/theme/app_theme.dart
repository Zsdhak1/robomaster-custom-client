/// Application theme constants for RoboMaster Monitor.
///
/// The app supports light and dark themes. Brand/team/status colors are fixed
/// across both modes (they carry protocol meaning — red/blue side, health,
/// connection state), while surface/text/divider colors are resolved from the
/// active [ThemeData] so every page adapts to the chosen [ThemeMode].
library;

import 'package:flutter/material.dart';

/// Primary brand color — matches the blue top bar in the design.
const Color rmPrimaryBlue = Color(0xFF2196F3);

/// Card border color (light theme).
const Color rmCardBorder = Color(0xFFE0E0E0);

/// Card border color (dark theme).
const Color rmCardBorderDark = Color(0xFF3A3A3A);

/// Label pill background (light blue tint).
Color get rmLabelBackground => rmPrimaryBlue.withValues(alpha: 0.15);

/// Standard card border radius.
const double rmCardRadius = 12.0;

/// Standard padding inside cards.
const EdgeInsets rmCardPadding = EdgeInsets.all(12);

/// Progress bar colors — fixed across themes (carry protocol meaning).
const Color rmHealthBarColor = Color(0xFF2196F3);
const Color rmAmmoBarColor = Color(0xFF4CAF50);
const Color rmCounterBarColor = Color(0xFFFF9800); // 反制进度条 — 橙色

/// Team accent colors used for red/blue theme switching on the login screen.
const Color rmBlueTeamColor = Color(0xFF2563EB);
const Color rmRedTeamColor = Color(0xFFDC2626);

/// Top status bar height.
const double rmTopBarHeight = 48;

/// Status indicator dot size.
const double rmStatusDotSize = 10;

/// Robot icon size in status rows.
const double rmRobotIconSize = 48;

// ============================================================
// Theme-aware semantic color helpers
//
// Widgets call these instead of hardcoding Colors.white / grey shades so the
// same widget renders correctly in both light and dark mode. They resolve
// against the active ColorScheme rather than the platform brightness directly.
// ============================================================

/// Background color for cards and elevated surfaces.
Color rmSurface(BuildContext context) =>
    Theme.of(context).colorScheme.surface;

/// Border/divider color for cards, adapting to brightness.
Color rmBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? rmCardBorderDark
        : rmCardBorder;

/// Primary text color resolved from the color scheme.
Color rmTextPrimary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// Secondary/muted text color (captions, hints, units).
Color rmTextSecondary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// Faint fill used for progress-bar tracks and inert chips.
Color rmTrackFill(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

// ============================================================
// Theme builders
// ============================================================

/// Creates the light theme for the application.
ThemeData buildAppTheme() => _buildThemeWithAccent(rmPrimaryBlue, Brightness.light);

/// Creates a theme variant tinted by [accent], used for red/blue team
/// switching on the login screen. Buttons, focused fields and the color
/// scheme all derive from [accent].
ThemeData buildTeamTheme(Color accent) =>
    _buildThemeWithAccent(accent, Brightness.light);

/// Creates the dark theme variant tinted by [accent].
ThemeData buildTeamThemeDark(Color accent) =>
    _buildThemeWithAccent(accent, Brightness.dark);

ThemeData _buildThemeWithAccent(Color accent, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    // Pin primary to the exact brand accent so every surface that reads
    // colorScheme.primary (dashboard top bar, drawer, charts) matches the
    // AppBar, which uses `accent` directly. Without this, the M3 seed
    // algorithm tone-maps primary to a slightly different shade and the
    // dashboard top bar looks like a different blue than the AppBars.
    primary: accent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    appBarTheme: AppBarTheme(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(rmCardRadius),
        side: BorderSide(color: isDark ? rmCardBorderDark : rmCardBorder),
      ),
      color: colorScheme.surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rmCardRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(rmCardRadius),
      ),
      filled: true,
      fillColor: isDark
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
