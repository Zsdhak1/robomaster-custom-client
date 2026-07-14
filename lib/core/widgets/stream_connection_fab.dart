/// 视频页面共用的流连接扩展 FAB。
///
/// 右下角的 [FloatingActionButton.extended] 会根据实时流状态切换标签、图标和操作：
/// 停止时显示连接，运行时显示断开连接。两条视频链路共享该组件，使连接控件视觉一致。
/// 可选 [secondaryActions] 用于暴露页面特定操作，例如自定义图传的录制保存。
library;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 显示在主连接 FAB 上方的页面特定次级操作。
class StreamFabAction {
  /// 创建 [StreamFabAction]。
  const StreamFabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  /// mini 操作按钮使用的前导图标。
  final IconData icon;

  /// 描述该操作的工具提示和标签。
  final String label;

  /// 点击时调用；[enabled] 为 false 时按钮禁用。
  final VoidCallback onPressed;

  /// 该操作是否可选择。
  final bool enabled;
}

/// 用于连接或断开视频流的扩展 FAB。
class StreamConnectionFab extends ConsumerWidget {
  /// 创建 [StreamConnectionFab]。
  const StreamConnectionFab({
    required this.isRunning,
    required this.onToggle,
    this.connectLabel = '连接',
    this.disconnectLabel = '断开连接',
    this.secondaryActions = const [],
    super.key,
  });

  /// 流当前是否正在运行。
  final bool isRunning;

  /// 切换流的开关状态。
  final Future<void> Function() onToggle;

  /// 流停止时显示的标签。
  final String connectLabel;

  /// 流运行时显示的标签。
  final String disconnectLabel;

  /// 显示在主 FAB 上方的页面特定 mini FAB 操作。
  final List<StreamFabAction> secondaryActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final action in secondaryActions) ...[
          FloatingActionButton.small(
            heroTag: null,
            tooltip: action.label,
            onPressed: action.enabled ? action.onPressed : null,
            backgroundColor: action.enabled
                ? null
                : scheme.surfaceContainerHighest,
            child: Icon(action.icon),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton.extended(
          heroTag: null,
          onPressed: onToggle,
          backgroundColor: isRunning ? scheme.errorContainer : null,
          foregroundColor: isRunning ? scheme.onErrorContainer : null,
          icon: Icon(isRunning ? Icons.link_off : Icons.link),
          label: Text(isRunning ? disconnectLabel : connectLabel),
        ),
      ],
    );
  }
}
