/// Application theme constants for WOD Client.
///
/// The app supports light and dark themes. Brand/team/status colors are fixed
/// across both modes (they carry protocol meaning — red/blue side, health,
/// connection state), while surface/text/divider colors are resolved from the
/// active [ThemeData] so every page adapts to the chosen [ThemeMode].
library;

import 'package:flutter/material.dart';

import 'text_theme.dart';

/// MD3 emphasized curve: cubic-bezier(0.2, 0, 0, 1).
///
/// This is the Material 3 "emphasized" easing curve used for page transitions
/// and large-screen navigation. It accelerates quickly then decelerates smoothly.
const Curve m3EmphasizedCurve = Cubic(0.2, 0, 0, 1);

/// MD3 standard curve for medium-duration transitions (300ms).
const Curve m3StandardCurve = Cubic(0.4, 0, 0.2, 1);

/// M3 page transition builder using [m3EmphasizedCurve] with 500ms duration.
class M3PageTransitionsBuilder extends PageTransitionsBuilder {
  /// Creates an [M3PageTransitionsBuilder].
  const M3PageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.15, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: m3EmphasizedCurve)),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: m3EmphasizedCurve)),
        child: child,
      ),
    );
  }
}

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

/// Health bar gradient colors — protocol semantics, fixed across themes.
const Color rmHealthLowColor = Color(0xFFEF4444); // red
const Color rmHealthMidColor = Color(0xFFF59E0B); // orange-amber
const Color rmHealthHighColor = Color(0xFF22C55E); // green

/// Feedback/snackbar colors — protocol semantics, fixed across themes.
const Color rmSuccessColor = Color(0xFF2E7D32);

/// Crosshair overlay colors for the custom video line.
const Color rmCrosshairColor = Color(0xFFE6BEEA); // lavender
const Color rmCrosshairCenterColor = Color(0xFFAAFFAA); // light-green

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
Color rmSurface(BuildContext context) => Theme.of(context).colorScheme.surface;

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
ThemeData buildAppTheme() =>
    _buildThemeWithAccent(rmPrimaryBlue, Brightness.light);

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
    // Use the responsive MD3 type scale. Widgets resolve text through
    // Theme.of(context).textTheme; the ResponsiveContext extension also exposes
    // context.textTheme scaled by the window size factor.
    textTheme: scaledTextThemeByFactor(1.0),
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
    // M3 page transitions: emphasized curve + 500ms slide+fade.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        for (final platform in TargetPlatform.values)
          platform: const M3PageTransitionsBuilder(),
      },
    ),
  );
}
