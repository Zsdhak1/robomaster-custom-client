/// Windows/Linux 固定设计画布的整体等比缩放容器。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design_constants.dart';
import 'desktop_design_scope.dart';

/// 在桌面端把固定 1280×720 布局整体 contain 到当前窗口。
class DesktopDesignCanvas extends StatelessWidget {
  /// 创建固定设计画布。
  const DesktopDesignCanvas({required this.child, super.key});

  /// 固定画布内显示的应用外壳。
  final Widget child;

  /// 当前平台是否使用桌面固定画布。
  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// 根据可用窗口比例生成高度固定为 720、宽度在 1080～1280 间变化的设计画布。
  static Size designSizeFor(Size availableSize) {
    if (availableSize.width <= 0 || availableSize.height <= 0) {
      return const Size(refWidth, refHeight);
    }
    final aspectRatio = availableSize.width / availableSize.height;
    final slightlyWiderThanLimit =
        aspectRatio > maxDesktopAspectRatio &&
        aspectRatio <=
            maxDesktopAspectRatio + desktopWorkAreaAspectTolerance;
    final designAspectRatio = slightlyWiderThanLimit
        ? aspectRatio
        : aspectRatio.clamp(minDesktopAspectRatio, maxDesktopAspectRatio);
    return Size(refHeight * designAspectRatio, refHeight);
  }

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return child;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => _buildCanvas(
        context,
        constraints.biggest,
        scheme.surfaceContainerLowest,
      ),
    );
  }

  Widget _buildCanvas(BuildContext context, Size availableSize, Color color) {
    final media = MediaQuery.of(context);
    final designSize = designSizeFor(availableSize);
    return ColoredBox(
      color: color,
      child: SizedBox.expand(
        child: FittedBox(
          child: SizedBox.fromSize(
            size: designSize,
            child: DesktopDesignScope(
              componentScale: designSize.height / refHeight,
              child: MediaQuery(
                data: media.copyWith(size: designSize),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
