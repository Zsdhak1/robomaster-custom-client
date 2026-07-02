/// MD3 window size classes for adaptive layout.
///
/// Maps the current window width to one of three breakpoints defined by the
/// Material 3 specification. Use [context.windowSizeClass] (from
/// [ResponsiveContext]) to switch navigation layout, content density, etc.
library;

/// Width breakpoints for MD3 adaptive layout.
///
/// | Class | Width range | Typical device |
/// |-------|-------------|----------------|
/// | compact | < 600 dp | Phone, narrow window |
/// | medium | 600 – 839 dp | Tablet, small desktop |
/// | expanded | ≥ 840 dp | Large desktop |
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// Returns the [WindowSizeClass] for a given [widthDp].
  static WindowSizeClass fromWidth(double widthDp) {
    if (widthDp < 600) return WindowSizeClass.compact;
    if (widthDp < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  /// Whether this class is [WindowSizeClass.compact].
  bool get isCompact => this == WindowSizeClass.compact;

  /// Whether this class is [WindowSizeClass.medium].
  bool get isMedium => this == WindowSizeClass.medium;

  /// Whether this class is [WindowSizeClass.expanded].
  bool get isExpanded => this == WindowSizeClass.expanded;
}
