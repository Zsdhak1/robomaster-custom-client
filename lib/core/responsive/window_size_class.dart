/// MD3 自适应布局使用的窗口大小类别。
///
/// 按 Material 3 规范定义的三个断点，将当前窗口宽度映射为紧凑、中等或展开。
/// 可通过 [ResponsiveContext.windowSizeClass] 切换导航布局、内容密度等。
library;

/// MD3 自适应布局使用的宽度断点。
///
/// | 类别 | 宽度范围 | 典型设备 |
/// |-------|-------------|----------------|
/// | 紧凑 | < 600 dp | 手机、窄窗口 |
/// | 中等 | 600 – 839 dp | 平板、小桌面窗口 |
/// | 展开 | ≥ 840 dp | 大桌面窗口 |
enum WindowSizeClass {
  compact,
  medium,
  expanded;

  /// 返回 [widthDp] 对应的 [WindowSizeClass]。
  static WindowSizeClass fromWidth(double widthDp) {
    if (widthDp < 600) return WindowSizeClass.compact;
    if (widthDp < 840) return WindowSizeClass.medium;
    return WindowSizeClass.expanded;
  }

  /// 当前类别是否为 [WindowSizeClass.compact]。
  bool get isCompact => this == WindowSizeClass.compact;

  /// 当前类别是否为 [WindowSizeClass.medium]。
  bool get isMedium => this == WindowSizeClass.medium;

  /// 当前类别是否为 [WindowSizeClass.expanded]。
  bool get isExpanded => this == WindowSizeClass.expanded;
}
