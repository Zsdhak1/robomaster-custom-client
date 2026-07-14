/// 共享的 MQTT 登录状态徽标。
///
/// 与仪表盘顶部栏的登录指示器保持一致（登录身份、己方红/蓝胶囊和连接圆点），
/// 让视频页面也能在右上角展示同一套实时比赛和连接状态。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connection/domain/robot_identity.dart';
import '../../features/dashboard/logic/stream_providers.dart';
import '../responsive/responsive_ext.dart';
import '../state/session_providers.dart';
import '../theme/app_theme.dart';

/// 显示 MQTT 登录身份和连接状态的紧凑横向徽标。
///
/// 设计为放置在视频页面右上角的半透明覆盖层中；[onDark] 为 true 时使用浅色文字和图标。
class MqttLoginBadge extends ConsumerWidget {
  /// 创建 [MqttLoginBadge]。
  const MqttLoginBadge({this.onDark = true, super.key});

  /// 为 true 时按深色或半透明背景渲染，前景使用浅色。
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(gameStateProvider).isConnected;
    final selectedId = ref.watch(selectedRobotIdProvider);
    final ownIsBlue = isBlueSide(selectedId);
    final fg = onDark ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: onDark
            ? Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: Padding(
        padding: context.insetSym(h: 10, v: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.fastOutSlowIn,
              switchOutCurve: Curves.fastOutSlowIn,
              child: Icon(
                isConnected ? Icons.cloud_done : Icons.cloud_off,
                key: ValueKey<bool>(isConnected),
                size: context.iconSize(16),
                color: isConnected ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
            context.sizedBox(w: 6),
            Text(
              isConnected
                  ? '${robotDisplayName(selectedId)}（ID：$selectedId）'
                  : '未连接（离线）',
              style: context.textTheme.bodySmall!.copyWith(
                color: fg,
                fontWeight: FontWeight.w500,
              ),
            ),
            context.sizedBox(w: 8),
            _SideBadge(ownIsBlue: ownIsBlue),
          ],
        ),
      ),
    );
  }
}

/// 显示己方红/蓝阵营的实心胶囊徽标。
class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.ownIsBlue});

  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    final color = ownIsBlue ? rmBlueTeamColor : rmRedTeamColor;
    return Container(
      padding: context.insetSym(h: 8, v: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(context.sp(10)),
      ),
      child: Text(
        ownIsBlue ? '己方·蓝' : '己方·红',
        style: context.textTheme.labelSmall!.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
