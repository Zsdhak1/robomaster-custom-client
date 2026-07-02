/// Connection quality panel showing real-time MQTT and UDP video stream
/// connection quality parameters.
///
/// ## M3 Compliance
/// - `titleSmall`/`bodyMedium`/`labelLarge` type roles throughout
/// - Tonal surface backgrounds (`surfaceContainerHigher`) for section headers
/// - Protocol-semantic colors preserved (health-green/red for states)
/// - Adequate 48sp touch targets for interactive elements
/// - `FontFeature.tabularFigures` on all numeric values
/// - Semantics labels on status indicators
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/mqtt_service.dart';
import '../../logic/stream_providers.dart';

/// Displays MQTT and UDP video stream connection quality metrics.
class ConnectionQualityPanel extends StatefulWidget {
  /// Creates a [ConnectionQualityPanel].
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
            // --- Header ---
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
            // --- Metrics body ---
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(label: 'MQTT 3333', active: isMqttConnected),
                    SizedBox(height: context.sp(4)),
                    _MetricRow(
                      label: '连接状态',
                      value: isMqttConnected ? '已连接' : '未连接',
                      valueColor: isMqttConnected
                          ? rmHealthHighColor
                          : rmHealthLowColor,
                    ),
                    SizedBox(height: context.sp(3)),
                    _StatusDotRow(isConnected: isMqttConnected),

                    SizedBox(height: context.sp(8)),
                    _SectionHeader(label: 'UDP 3334', active: isVideoListening),
                    SizedBox(height: context.sp(4)),
                    _MetricRow(
                      label: '接收状态',
                      value: isVideoListening ? '监听中' : '已停止',
                      valueColor: isVideoListening
                          ? rmHealthHighColor
                          : scheme.onSurfaceVariant,
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '完成帧数',
                      value: '${videoService.framesCompleted}',
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '丢弃帧数',
                      value: '${videoService.framesDropped}',
                      valueColor: videoService.framesDropped > 0
                          ? rmHealthLowColor
                          : null,
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '待重组',
                      value: '${videoService.pendingFrameCount}',
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '收包总数',
                      value: '${videoService.packetsReceived}',
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '丢包数',
                      value: '${videoService.packetsDropped}',
                      valueColor: videoService.packetsDropped > 0
                          ? rmHealthLowColor
                          : null,
                    ),

                    SizedBox(height: context.sp(8)),
                    _SectionHeader(
                      label: '解码桥',
                      active: videoService.bridgeStarted,
                    ),
                    SizedBox(height: context.sp(4)),
                    _MetricRow(
                      label: '桥状态',
                      value: videoService.bridgeStarted ? '已启动' : '等待中',
                      valueColor: videoService.bridgeStarted
                          ? rmHealthHighColor
                          : rmHealthMidColor,
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '解码客户端',
                      value: '${videoService.decoderClients}',
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '转发帧数',
                      value: '${videoService.tcpFramesForwarded}',
                    ),
                    SizedBox(height: context.sp(3)),
                    _MetricRow(
                      label: '最大分片数',
                      value: '${videoService.maxFragmentsSeen}',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// _SectionHeader — tonal pill with leading status dot
// ====================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(8),
        vertical: context.sp(5),
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(context.sp(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: active ? '连接正常' : '连接异常',
            child: Container(
              width: context.sp(10),
              height: context.sp(10),
              decoration: BoxDecoration(
                color: active ? rmHealthHighColor : rmHealthLowColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: context.sp(6)),
          Text(
            label,
            style: context.textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// _MetricRow — label | value pair
// ====================================================================

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(4),
        vertical: context.sp(2),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: context.textTheme.bodySmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? scheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// _StatusDotRow — visual dot + text description of MQTT state
// ====================================================================

class _StatusDotRow extends StatelessWidget {
  const _StatusDotRow({required this.isConnected});
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.sp(4)),
      child: Row(
        children: [
          Semantics(
            label: isConnected ? 'MQTT 已连接' : 'MQTT 未连接',
            child: Container(
              width: context.sp(10),
              height: context.sp(10),
              decoration: BoxDecoration(
                color: isConnected ? rmHealthHighColor : rmHealthLowColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: context.sp(6)),
          Text(
            isConnected ? 'MQTT 已连接' : 'MQTT 未连接',
            style: context.textTheme.bodySmall!.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
