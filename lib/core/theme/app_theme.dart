/// WOD 客户端使用的应用主题常量。
///
/// 应用支持浅色和深色主题。品牌、队伍、状态颜色在两种模式中保持固定，
/// 因为它们承载协议语义（红/蓝方、血量、连接状态）；表面、文本和分隔线颜色
/// 则从当前 [ThemeData] 解析，使页面能适配所选 [ThemeMode]。
library;

import 'package:flutter/material.dart';

import 'text_theme.dart';

/// MD3 强调缓动曲线：cubic-bezier(0.2, 0, 0, 1)。
///
/// Material 3 的 emphasized 缓动曲线，用于页面过渡和大屏导航；
/// 先快速加速，再平滑减速。
const Curve m3EmphasizedCurve = Cubic(0.2, 0, 0, 1);

/// MD3 中等时长过渡（300ms）使用的标准缓动曲线。
const Curve m3StandardCurve = Cubic(0.4, 0, 0.2, 1);

/// 使用 [m3EmphasizedCurve] 和 500ms 时长的 M3 页面过渡构建器。
class M3PageTransitionsBuilder extends PageTransitionsBuilder {
  /// 创建 [M3PageTransitionsBuilder]。
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

/// 主品牌色，匹配设计中的蓝方顶部栏。
const Color rmPrimaryBlue = Color(0xFF2196F3);

/// 浅色主题下的卡片边框颜色。
const Color rmCardBorder = Color(0xFFE0E0E0);

/// 深色主题下的卡片边框颜色。
const Color rmCardBorderDark = Color(0xFF3A3A3A);

/// 标签胶囊背景色，使用浅蓝色调。
Color get rmLabelBackground => rmPrimaryBlue.withValues(alpha: 0.15);

/// 标准卡片边框半径。
const double rmCardRadius = 12.0;

/// 卡片内部标准内边距。
const EdgeInsets rmCardPadding = EdgeInsets.all(12);

/// 进度条颜色，跨主题固定以保留协议语义。
const Color rmHealthBarColor = Color(0xFF2196F3);
const Color rmAmmoBarColor = Color(0xFF4CAF50);
const Color rmCounterBarColor = Color(0xFFFF9800); // 反制进度条 — 橙色

/// 登录页红/蓝方主题切换使用的队伍强调色。
const Color rmBlueTeamColor = Color(0xFF2563EB);
const Color rmRedTeamColor = Color(0xFFDC2626);

/// 血量栏渐变颜色，承载协议语义并跨主题固定。
const Color rmHealthLowColor = Color(0xFFEF4444); // 红方
const Color rmHealthMidColor = Color(0xFFF59E0B); // 橙黄色
const Color rmHealthHighColor = Color(0xFF22C55E); // 绿色

/// 反馈和 snackbar 颜色，跨主题固定以保留协议语义。
const Color rmSuccessColor = Color(0xFF2E7D32);

/// 自定义图传链路使用的准星覆盖层颜色。
const Color rmCrosshairColor = Color(0xFFE6BEEA); // 淡紫色
const Color rmCrosshairCenterColor = Color(0xFFAAFFAA); // 浅绿色

/// 顶部状态栏高度。
const double rmTopBarHeight = 48;

/// 状态指示器圆点大小。
const double rmStatusDotSize = 10;

/// 状态行中的机器人图标大小。
const double rmRobotIconSize = 48;

// ============================================================
// 感知主题的语义颜色辅助函数
//
// 组件应调用这些函数，而不是硬编码白色或灰阶。这样同一组件能在浅色和深色模式下
// 正确渲染，并基于当前 ColorScheme 而不是平台 brightness 直接取色。
// ============================================================

/// 卡片和抬升表面使用的背景色。
Color rmSurface(BuildContext context) => Theme.of(context).colorScheme.surface;

/// 卡片使用的边框/分隔线颜色，会适配亮暗模式。
Color rmBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? rmCardBorderDark
    : rmCardBorder;

/// 从当前配色方案解析出的主文本颜色。
Color rmTextPrimary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface;

/// 次级/弱化文本颜色，用于说明、提示和单位。
Color rmTextSecondary(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// 进度条轨道和非活跃 chip 使用的弱填充色。
Color rmTrackFill(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);

// ============================================================
// 主题构建器
// ============================================================

/// 创建应用浅色主题。
ThemeData buildAppTheme() =>
    _buildThemeWithAccent(rmPrimaryBlue, Brightness.light);

/// 创建使用 [accent] 着色的主题变体，用于登录页红/蓝方切换。
/// 按钮、聚焦输入框以及配色方案都会从 [accent] 派生。
ThemeData buildTeamTheme(Color accent) =>
    _buildThemeWithAccent(accent, Brightness.light);

/// 创建使用 [accent] 着色的深色主题变体。
ThemeData buildTeamThemeDark(Color accent) =>
    _buildThemeWithAccent(accent, Brightness.dark);

ThemeData _buildThemeWithAccent(Color accent, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    // 将 primary 固定为精确品牌强调色，使所有读取 colorScheme.primary 的表面
    // （仪表盘顶部栏、抽屉、图表）与直接使用 accent 的 AppBar 保持一致。
    // 否则 M3 seed 算法会把 primary 映射成略有差异的色阶。
    primary: accent,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    fontFamily: appFontFamily,
    // 使用响应式 MD3 字体层级。组件可通过 Theme.of(context).textTheme 读取主题文本；
    // ResponsiveContext 扩展也提供按窗口大小缩放后的 context.textTheme。
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
    // M3 页面过渡：强调曲线 + 500ms slide+fade。
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        for (final platform in TargetPlatform.values)
          platform: const M3PageTransitionsBuilder(),
      },
    ),
  );
}
