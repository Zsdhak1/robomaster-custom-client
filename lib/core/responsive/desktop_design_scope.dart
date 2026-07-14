import 'package:flutter/widgets.dart';

/// 向固定高度的桌面设计画布内部提供组件尺寸缩放因子。
class DesktopDesignScope extends InheritedWidget {
  /// 创建桌面设计画布范围。
  const DesktopDesignScope({
    required this.componentScale,
    required super.child,
    super.key,
  });

  /// 画布内部组件相对于 720 设计高度的缩放因子。
  final double componentScale;

  /// 获取最近的桌面设计画布范围。
  static DesktopDesignScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopDesignScope>();

  @override
  bool updateShouldNotify(DesktopDesignScope oldWidget) =>
      componentScale != oldWidget.componentScale;
}
