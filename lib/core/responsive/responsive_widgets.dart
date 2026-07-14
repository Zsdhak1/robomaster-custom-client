/// 随窗口大小缩放的开箱即用组件。
///
/// 这些轻量封装会在内部读取 [ResponsiveContext.scale]，调用方无需重复书写缩放公式。
library;

import 'package:flutter/material.dart';

import 'responsive_ext.dart';

// ---------------------------------------------------------------------------
// ScaledSizedBox 缩放尺寸盒
// ---------------------------------------------------------------------------

/// [width] 与 [height] 会乘以当前 [ResponsiveContext.scale] 的 [SizedBox]。
class ScaledSizedBox extends StatelessWidget {
  /// 创建 [ScaledSizedBox]。
  const ScaledSizedBox({super.key, this.width, this.height});

  /// 基准宽度，会自动缩放。
  final double? width;

  /// 基准高度，会自动缩放。
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width != null ? context.sp(width!) : null,
      height: height != null ? context.sp(height!) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// ScaledPadding 缩放内边距
// ---------------------------------------------------------------------------

/// 会对内边距数值进行响应式缩放的 [Padding] 组件。
class ScaledPadding extends StatelessWidget {
  /// 创建使用等距内边距的 [ScaledPadding]。
  const ScaledPadding.all({
    required this.child,
    required double value,
    super.key,
  }) : insets = null,
       _all = value,
       _h = 0,
       _v = 0;

  /// 创建使用水平/垂直对称内边距的 [ScaledPadding]。
  const ScaledPadding.symmetric({
    required this.child,
    super.key,
    double horizontal = 0,
    double vertical = 0,
  }) : insets = null,
       _all = null,
       _h = horizontal,
       _v = vertical;

  /// 创建使用预先计算好的 [EdgeInsets] 的 [ScaledPadding]。
  ///
  /// 当调用方已经通过 [ResponsiveContext] 辅助函数算好边距时使用。
  const ScaledPadding.fromInsets({
    required this.child,
    required this.insets,
    super.key,
  }) : _all = null,
       _h = 0,
       _v = 0;

  final EdgeInsets? insets;
  final double? _all;
  final double _h;
  final double _v;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final value = insets;
    if (value != null) return Padding(padding: value, child: child);
    return Padding(
      padding: _all != null
          ? context.insetAll(_all)
          : context.insetSym(h: _h, v: _v),
      child: child,
    );
  }
}
