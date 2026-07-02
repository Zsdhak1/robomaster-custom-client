/// UDP 3334 video-stream monitoring screen.
///
/// Controls the [VideoStreamService] (start/stop the UDP listener) and shows
/// live stream health: latest reassembled frame metadata, reassembly stats and
/// a real decoder (media_kit / fvp). The right-side panel mirrors the custom
/// video page: basic info, a developer-only debug section and 敌方血量 bars.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/widgets/video_stream_page_scaffold.dart';
import '../logic/stream_providers.dart';
import 'widgets/video_panel.dart';

/// Full-screen page hosting the UDP video-stream monitor.
class VideoScreen extends ConsumerStatefulWidget {
  /// Creates a [VideoScreen].
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  /// Toggles the UDP listener, surfacing bind failures (e.g. port in use).
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
