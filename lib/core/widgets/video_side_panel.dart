/// 视频页面共用的右侧面板。
///
/// 自上而下布局：
/// 1. 基础连接信息（[basicInfo]），始终显示。
/// 2. 调试区段（[debugSection]），仅开发者模式开启时显示。
/// 3. 仪表盘敌方血量列表，占据剩余约 3/5 高度。这里复用 enemy-focus 模式下的
///    [RobotStatusList]，只缩小尺寸以适配更窄的视频页侧边面板，不改变内容。
///
/// UDP 3334 链路和自定义 0x0310 链路都使用该组件，确保两个侧边面板视觉和行为一致。
library;

import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/widgets/robot_status_list.dart';
import '../responsive/desktop_design_canvas.dart';
import '../responsive/desktop_design_scope.dart';
import '../responsive/responsive_ext.dart';
import '../state/session_providers.dart';

/// 位于视频流右侧的信息和血量面板。
class VideoSidePanel extends StatelessWidget {
  /// 创建 [VideoSidePanel]。
  const VideoSidePanel({
    required this.title,
    required this.basicInfo,
    required this.developerMode,
    this.debugSection,
    super.key,
  });

  /// 面板标题，例如“视频流状态”。
  final String title;

  /// 始终可见的基础连接信息组件。
  final Widget basicInfo;

  /// 开发者模式是否已启用，用于控制 [debugSection] 可见性。
  final bool developerMode;

  /// 完整调试内容，仅在 [developerMode] 为 true 时显示。
  final Widget? debugSection;

  @override
  Widget build(BuildContext context) {
    final showDebug = developerMode && debugSection != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 顶部：基础信息 + 开发者调试，放在同一卡片内。
        Expanded(
          flex: showDebug ? 2 : 1,
          child: Card(
            child: Padding(
              padding: context.insetAll(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  context.sizedBox(h: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          basicInfo,
                          if (showDebug) ...[
                            const Divider(height: 24),
                            VideoDebugSection(child: debugSection!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 底部约 3/5：缩小后的仪表盘敌方血量列表。
        const Expanded(flex: 3, child: _ScaledEnemyHealth()),
      ],
    );
  }
}

/// 视频侧边面板共用的装饰化调试区段。
class VideoDebugSection extends StatelessWidget {
  /// 创建装饰化调试区段。
  const VideoDebugSection({required this.child, super.key});

  /// 调试内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: context.insetAll(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: child,
    );
  }
}

/// 视频侧边面板共用的状态行。
class VideoStatusRow extends StatelessWidget {
  /// 创建带彩色圆点的状态行。
  const VideoStatusRow({
    required this.isRunning,
    required this.runningLabel,
    this.stoppedLabel = '已停止',
    super.key,
  });

  /// 视频流是否正在运行。
  final bool isRunning;

  /// 运行中状态显示的标签。
  final String runningLabel;

  /// 已停止状态显示的标签。
  final String stoppedLabel;

  @override
  Widget build(BuildContext context) {
    final color = isRunning
        ? Colors.green
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Container(
          width: context.rmStatusDotSize,
          height: context.rmStatusDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        context.sizedBox(w: 8),
        Text(
          isRunning ? runningLabel : stoppedLabel,
          style: context.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// 视频侧边面板共用的标签/值行。
class VideoInfoRow extends StatelessWidget {
  /// 创建信息行。
  const VideoInfoRow({required this.label, required this.value, super.key});

  /// 左侧标签。
  final String label;

  /// 右侧值。
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetSym(v: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 将 enemy-focus 模式下的仪表盘 [RobotStatusList] 缩小到适合较窄侧边面板的尺寸。
///
/// 该列表会通过 `context.scale` 按窗口大小计算尺寸；视频页只给它约 1/3 宽度，
/// 因此这里缩小传入的 [MediaQuery] 尺寸。这样字体、图标、条形和内边距会统一缩放，
/// 保留仪表盘中的全部信息（图标、标签胶囊、血量条、数值和头部）。
class _ScaledEnemyHealth extends StatelessWidget {
  const _ScaledEnemyHealth();

  /// 报告给内嵌列表的真实窗口大小比例，用于获得适合侧边面板的较小缩放。
  static const double _scaleFraction = 0.62;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final healthList = MediaQuery(
      data: media.copyWith(size: media.size * _scaleFraction),
      child: const RobotStatusList(
        modeOverride: DashboardDisplayMode.enemyFocus,
      ),
    );
    if (!DesktopDesignCanvas.isSupported) return healthList;
    return DesktopDesignScope(
      componentScale: context.scale * _scaleFraction,
      child: healthList,
    );
  }
}
