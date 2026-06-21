/// Shared MQTT login-status badge.
///
/// Mirrors the dashboard top bar's login indicator (登录身份 + 己方红/蓝 pill +
/// connection dot) so the video pages can show the same status in their
/// top-right corner. Reads the live game/connection providers directly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connection/domain/robot_identity.dart';
import '../../features/dashboard/logic/stream_providers.dart';
import '../responsive/responsive_ext.dart';
import '../state/session_providers.dart';
import '../theme/app_theme.dart';

/// A compact horizontal badge showing MQTT login identity and connection state.
///
/// Designed to sit on a translucent overlay in the top-right of the video
/// pages; pass [onDark] true to render text/icons in light colors.
class MqttLoginBadge extends ConsumerWidget {
  /// Creates a [MqttLoginBadge].
  const MqttLoginBadge({this.onDark = true, super.key});

  /// When true, renders for a dark/translucent background (white foreground).
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
            ? Colors.black.withValues(alpha: 0.55)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: Padding(
        padding: context.insetSym(h: 10, v: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              size: context.iconSize(16),
              color: isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
            context.sizedBox(w: 6),
            Text(
              isConnected
                  ? '${robotDisplayName(selectedId)}（ID：$selectedId）'
                  : '未连接（离线）',
              style: TextStyle(
                color: fg,
                fontSize: context.fontSize(13),
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

/// Solid pill badge showing the own side (己方 红/蓝).
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
        style: TextStyle(
          color: Colors.white,
          fontSize: context.fontSize(12),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
