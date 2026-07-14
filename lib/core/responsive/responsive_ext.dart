/// [BuildContext] 上用于等比缩放的扩展方法。
///
/// 用法：
/// ```dart
/// final s = context.scale;          // 统一缩放因子
/// final fontSize = context.fontSize(16);
/// final padding = context.insetAll(12);
/// final iconSize = context.iconSize(24);
/// ```
library;

import 'package:flutter/material.dart';

import '../theme/text_theme.dart';
import 'design_constants.dart';
import 'desktop_design_scope.dart';
import 'window_size_class.dart';

/// 在 [BuildContext] 上提供响应式尺寸、边距、文字主题和窗口类别辅助方法。
extension ResponsiveContext on BuildContext {
  /// 统一缩放因子：水平和垂直比例中的较小值，并钳制到 [minScale]..[maxScale]。
  ///
  /// 使用较小值可保持宽高比例：窗口宽于 16:9 时内容不会继续变高，窗口更窄时也不会被
  /// 水平方向压扁。
  double get scale {
    final desktopScale = DesktopDesignScope.maybeOf(this)?.componentScale;
    if (desktopScale != null) {
      return desktopScale.clamp(minScale, maxScale);
    }
    final size = MediaQuery.sizeOf(this);
    final sx = size.width / refWidth;
    final sy = size.height / refHeight;
    return (sx < sy ? sx : sy).clamp(minScale, maxScale);
  }

  // ---- 便捷辅助函数 ----

  /// 缩放一个基准字号。
  double fontSize(double base) => base * scale;

  /// 缩放一个基准像素尺寸，例如间距、高度、宽度或圆角。
  double sp(double base) => base * scale;

  /// 缩放一个图标尺寸。
  double iconSize(double base) => base * scale;

  /// 创建四边都为 [value] 的缩放后边距。
  EdgeInsets insetAll(double value) => EdgeInsets.all(sp(value));

  /// 创建缩放后的水平/垂直对称边距。
  EdgeInsets insetSym({double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(horizontal: sp(h), vertical: sp(v));

  /// 创建缩放后的单侧边距。
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

  /// 创建带缩放后宽度/高度的固定尺寸盒子。
  Widget sizedBox({double? w, double? h}) =>
      SizedBox(width: w != null ? sp(w) : null, height: h != null ? sp(h) : null);

  // ---- 感知主题的便捷读取器 ----
  // 这些 getter 将 app_theme 中的原始常量映射为缩放后的值，
  // 因此调用方可以写 `context.rmTopBarHeight`，而不是
  // `context.sp(rmTopBarHeight)`.

  /// 缩放后的顶部状态栏高度（基准值 48）。
  double get rmTopBarHeight => sp(48);

  /// 缩放后的状态指示器圆点大小（基准值 10）。
  double get rmStatusDotSize => sp(10);

  /// 缩放后的机器人图标大小（基准值 48）。
  double get rmRobotIconSize => sp(48);

  /// 缩放后的卡片圆角半径（基准值 12）。
  double get rmCardRadius => sp(12);

  /// 按当前窗口大小缩放后的 MD3 [TextTheme]。
  ///
  /// 优先使用该 getter，而不是直接写 `TextStyle(fontSize: ...)`。建议使用字体层级角色
  /// （如 `displaySmall`、`headlineMedium`、`titleMedium`、`bodyMedium`、
  /// `labelSmall` 等），并仅用 `.copyWith()` 覆盖 `fontWeight` 或颜色等局部属性。
  /// 这样可以保持全应用字体响应式且一致。
  ///
  /// 示例：
  /// ```dart
  /// Text('Hello', style: context.textTheme.titleMedium)
  /// ```
  TextTheme get textTheme => scaledTextThemeByFactor(scale);

  /// 当前视口宽度对应的 MD3 窗口大小类别。
  ///
  /// 可用它切换导航布局、内容密度或列数：
  /// - 紧凑 (<600) → 底部 NavigationBar
  /// - 中等 (600–839) → 收起的 NavigationRail
  /// - 展开 (≥840) → 带标签的展开 NavigationRail
  WindowSizeClass get windowSizeClass =>
      WindowSizeClass.fromWidth(MediaQuery.sizeOf(this).width);
}
