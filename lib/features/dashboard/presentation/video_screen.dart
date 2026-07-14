/// UDP 3334 视频流监控页面。
///
/// 控制 [VideoStreamService]（启动/停止 UDP 监听器），并显示实时流状态：
/// 最新重组帧元数据、重组统计和真实解码器（media_kit / fvp）。右侧面板与自定义视频页
/// 对齐，包含基础信息、仅开发者可见的调试区段和敌方血量栏。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/widgets/video_stream_page_scaffold.dart';
import '../logic/stream_providers.dart';
import 'widgets/video_panel.dart';

/// 承载 UDP 视频流监控的全屏页面。
class VideoScreen extends ConsumerStatefulWidget {
  /// 创建 [VideoScreen]。
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  /// 切换 UDP 监听器，并向用户暴露端口占用等绑定失败。
  Future<void> _toggleStream() async {
    try {
      await ref.read(videoStreamControllerProvider.notifier).toggle();
    } on Object catch (e) {
      if (mounted) {
        context.showErrorSnack('视频流启动失败（UDP $defaultUdpVideoPort 端口绑定失败）: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(videoStreamControllerProvider);

    return VideoStreamPageScaffold(
      title: 'UDP 图传 · 3334',
      body: const VideoPanel(),
      isRunning: isListening,
      onToggle: _toggleStream,
    );
  }
}
