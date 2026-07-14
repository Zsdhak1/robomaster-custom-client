/// 自定义 H.264 视频链路使用的调试覆盖层。
///
/// 显示实时统计：已接收块、解码器状态、桥接吞吐量和最近的解码器错误。
/// 仅在开发者模式开启时可见。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../logic/custom_video_providers.dart';

/// 由自定义图传面板定位的紧凑调试覆盖层。
class CustomVideoOverlay extends ConsumerWidget {
  /// 创建 [CustomVideoOverlay]。
  const CustomVideoOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(customVideoStatsProvider).valueOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: DefaultTextStyle(
          style: context.textTheme.labelSmall!.copyWith(color: Colors.white),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('收到 chunk: ${stats?.chunksReceived ?? 0}'),
              Text('收到字节: ${_formatBytes(stats?.bytesReceived ?? 0)}'),
              Text('门控: ${(stats?.gateOpen ?? false) ? "已开" : "等待"}'),
              Text('桥转发: ${stats?.framesForwarded ?? 0} 帧'),
              Text('桥字节: ${_formatBytes(stats?.bytesForwarded ?? 0)}'),
              Text('解码器连接: ${stats?.decoderClients ?? 0}'),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }
}
