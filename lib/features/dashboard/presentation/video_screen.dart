/// UDP 3334 video-stream monitoring screen.
///
/// Controls the [VideoStreamService] (start/stop the UDP listener) and shows
/// live stream health: latest reassembled frame metadata, reassembly stats and
/// a real decoder (media_kit / fvp). Includes a debug panel for telemetry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/navigation/page_fab_menu.dart';
import '../../settings/logic/settings_providers.dart';
import '../logic/stream_providers.dart';
import 'widgets/video_debug_panel.dart';
import 'widgets/video_panel.dart';

/// Full-screen page hosting the UDP video-stream monitor.
class VideoScreen extends ConsumerStatefulWidget {
  /// Creates a [VideoScreen].
  const VideoScreen({super.key});

  @override
  ConsumerState<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends ConsumerState<VideoScreen> {
  bool _isDebugOpen = false;

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
    final devMode = ref.watch(developerModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('视频流 · UDP 3334')),
      body: Stack(
        children: [
          const VideoPanel(),
          if (devMode && _isDebugOpen)
            const Positioned(
              right: 16,
              bottom: 80,
              child: VideoDebugPanel(),
            ),
        ],
      ),
      floatingActionButton: PageFabMenu(
        actions: [
          FabAction(
            icon: isListening ? Icons.stop : Icons.play_arrow,
            label: isListening ? '停止接收' : '开始接收',
            onSelected: _toggleStream,
          ),
          if (devMode)
            FabAction(
              icon: _isDebugOpen ? Icons.bug_report : Icons.bug_report_outlined,
              label: _isDebugOpen ? '隐藏调试面板' : '显示调试面板',
              onSelected: () => setState(() => _isDebugOpen = !_isDebugOpen),
            ),
        ],
      ),
    );
  }
}
