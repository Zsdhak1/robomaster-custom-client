/// MD3 字体层级定义与响应式缩放辅助函数。
///
/// 该文件刻意不依赖 Riverpod 或自定义扩展，方便 [app_theme.dart] 与
/// [responsive_ext.dart] 同时导入，避免形成循环依赖。
library;

import 'package:flutter/material.dart';

/// 应用全局使用的 MiSans 字体族名称。
const String appFontFamily = 'MiSans';

// ============================================================
// MD3 字体层级常量
// ============================================================

/// 标准 MD3 字体层级大小，未经过响应式缩放。
///
/// 这些数值匹配 Material 3 规范。使用 [scaledTextTheme] 或
/// [scaledTextThemeByFactor] 可获得按当前窗口响应式因子缩放后的版本。
const _TextScaleEntry _tsDisplay = _TextScaleEntry(57, 36, 45);
const _TextScaleEntry _tsHeadline = _TextScaleEntry(32, 24, 28);
const _TextScaleEntry _tsTitle = _TextScaleEntry(22, 16, 14);
const _TextScaleEntry _tsBody = _TextScaleEntry(16, 14, 12);
const _TextScaleEntry _tsLabel = _TextScaleEntry(14, 12, 11);

/// 保存一个字体层级中 large、small、medium 三个粒度的内部辅助类型。
class _TextScaleEntry {
  const _TextScaleEntry(this.large, this.small, this.medium);
  final double large, small, medium;
}

// ============================================================
// 公开 API
// ============================================================

/// 构建所有字号都乘以 [factor] 的 MD3 [TextTheme]。
///
/// 当 [factor] == 1.0 时，结果匹配标准 MD3 规范。传入响应式缩放因子
/// （例如来自 [ResponsiveContext.scale]）可让主题跟随窗口大小变化。
TextTheme scaledTextThemeByFactor(double factor) {
  return TextTheme(
    // 显示
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
    // 标题
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
    // 标题
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
    // 主体
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
    // 标签
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
  ).apply(fontFamily: appFontFamily);
}

/// 返回按系统无障碍文本缩放因子处理后的 MD3 [TextTheme]。
///
/// **注意：** 这里使用系统级文本缩放因子，不使用窗口响应式缩放。窗口响应式缩放请使用
/// `scaledTextThemeByFactor(context.scale)` 或来自 [ResponsiveContext] 的
/// `context.textTheme`。
TextTheme scaledTextTheme(BuildContext context) =>
    scaledTextThemeByFactor(MediaQuery.textScalerOf(context).scale(1.0));
