/// Application theme constants for RoboMaster Monitor.
library;

import 'package:flutter/material.dart';

/// Primary brand color — matches the blue top bar in the design.
const Color rmPrimaryBlue = Color(0xFF2196F3);

/// Card background color.
const Color rmCardBackground = Colors.white;

/// Card border color.
const Color rmCardBorder = Color(0xFFE0E0E0);

/// Label pill background (light blue tint).
Color get rmLabelBackground =>
    rmPrimaryBlue.withValues(alpha: 0.15);

/// Standard card border radius.
const double rmCardRadius = 12.0;

/// Standard padding inside cards.
const EdgeInsets rmCardPadding = EdgeInsets.all(12);

/// Progress bar colors.
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

/// Creates the light theme for the application.
ThemeData buildAppTheme() => _buildThemeWithAccent(rmPrimaryBlue);

/// Creates a theme variant tinted by [accent], used for red/blue team
/// switching on the login screen. Buttons, focused fields and the color
/// scheme all derive from [accent].
ThemeData buildTeamTheme(Color accent) => _buildThemeWithAccent(accent);

ThemeData _buildThemeWithAccent(Color accent) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      // Pin primary to the exact brand accent so every surface that reads
      // colorScheme.primary (dashboard top bar, drawer, charts) matches the
      // AppBar, which uses `accent` directly. Without this, the M3 seed
      // algorithm tone-maps primary to a slightly different shade and the
      // dashboard top bar looks like a different blue than the AppBars.
      primary: accent,
    ),
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
        side: const BorderSide(color: rmCardBorder),
      ),
      color: rmCardBackground,
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
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
