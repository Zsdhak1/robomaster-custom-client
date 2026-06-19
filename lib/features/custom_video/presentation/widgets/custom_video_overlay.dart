/// Debug overlay for the custom H.264 video line.
///
/// Shows live statistics: received chunks, decoder state, bridge throughput,
/// and the last decoder error. Only visible when developer mode is on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/custom_video_providers.dart';

/// Compact debug overlay positioned over the custom video panel.
class CustomVideoOverlay extends ConsumerWidget {
  /// Creates a [CustomVideoOverlay].
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
          style: const TextStyle(color: Colors.white, fontSize: 10),
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
