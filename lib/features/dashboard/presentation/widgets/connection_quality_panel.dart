/// 连接质量面板，显示实时 MQTT 和 UDP 视频流连接参数。
///
/// ## M3 合规性
/// - 全面使用 `titleSmall`/`bodyMedium`/`labelLarge` 文本角色。
/// - 区段标题使用色调表面背景（`surfaceContainerHigher`）。
/// - 保留协议语义颜色，例如健康绿色和红方状态色。
/// - 交互元素保持足够的 48sp 触控目标。
/// - 所有数字值使用 `FontFeature.tabularFigures`。
/// - 状态指示器提供语义标签。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/mqtt_service.dart';
import '../../logic/stream_providers.dart';

/// 显示 MQTT 和 UDP 视频流连接质量指标。
class ConnectionQualityPanel extends StatefulWidget {
  /// 创建 [ConnectionQualityPanel]。
  const ConnectionQualityPanel({super.key});

  @override
  State<ConnectionQualityPanel> createState() => _ConnectionQualityPanelState();
}

class _ConnectionQualityPanelState extends State<ConnectionQualityPanel> {
  late final Timer _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const _PanelBody();
}

class _PanelBody extends ConsumerWidget {
  const _PanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mqttState = ref.watch(mqttConnectionStateSyncProvider);
    final isMqttConnected = mqttState == MqttConnectionState.connected;
    final videoService = ref.watch(videoStreamServiceProvider);
    final isVideoListening = ref.watch(udpListeningProvider);

    return Card(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(context.sp(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 头部 ---
            Row(
              children: [
                Icon(
                  Icons.signal_cellular_alt_rounded,
                  size: context.iconSize(20),
                  color: scheme.primary,
                ),
                SizedBox(width: context.sp(8)),
                Text(
                  '连接质量',
                  style: context.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(10)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ConnectionSummaryRow(
                    label: 'MQTT 3333',
                    value: isMqttConnected ? '已连接' : '未连接',
                    active: isMqttConnected,
                  ),
                  _ConnectionSummaryRow(
                    label: 'UDP 3334',
                    value: isVideoListening ? '监听中' : '已停止',
                    active: isVideoListening,
                  ),
                  _ConnectionSummaryRow(
                    label: '视频帧',
                    value:
                        '完成 ${videoService.framesCompleted} · 丢弃 ${videoService.framesDropped}',
                    active: videoService.framesDropped == 0,
                  ),
                  _ConnectionSummaryRow(
                    label: '解码桥',
                    value: videoService.bridgeStarted
                        ? '已启动 · ${videoService.decoderClients} 客户端'
                        : '等待中 · ${videoService.decoderClients} 客户端',
                    active: videoService.bridgeStarted,
                    waiting: !videoService.bridgeStarted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionSummaryRow extends StatelessWidget {
  const _ConnectionSummaryRow({
    required this.label,
    required this.value,
    required this.active,
    this.waiting = false,
  });

  final String label;
  final String value;
  final bool active;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = waiting
        ? rmHealthMidColor
        : active
        ? rmHealthHighColor
        : rmHealthLowColor;
    return Container(
      padding: context.insetSym(h: 8, v: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: Row(
        children: [
          _SummaryDot(color: statusColor, label: '$label：$value'),
          context.sizedBox(w: 7),
          Text(label, style: context.textTheme.labelMedium),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: context.textTheme.labelMedium!.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDot extends StatelessWidget {
  const _SummaryDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: Container(
        width: context.sp(9),
        height: context.sp(9),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
