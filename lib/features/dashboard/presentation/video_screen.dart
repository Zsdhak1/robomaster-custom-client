/// UDP 3334 video-stream monitoring screen.
///
/// Controls the [VideoStreamService] (start/stop the UDP listener) and shows
/// live stream health: latest reassembled frame metadata, reassembly stats and
/// a real decoder (media_kit / fvp). Includes a debug panel for telemetry.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigation_drawer.dart';
import '../../settings/logic/settings_providers.dart';
import '../logic/stream_providers.dart';
import 'app_navigation.dart';
import 'widgets/debug_fab.dart';
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

  @override
  Widget build(BuildContext context) {
    final isListening = ref.watch(videoStreamControllerProvider);
    final devMode = ref.watch(developerModeProvider);

    return Scaffold(
      drawer: AppNavigationDrawer(
        current: AppDestination.video,
        onSelect: (dest) => navigateToDestination(context, dest),
      ),
      appBar: AppBar(
        title: const Text('视频流 · UDP 3334'),
        actions: [
          IconButton(
            icon: Icon(isListening ? Icons.stop : Icons.play_arrow),
            tooltip: isListening ? '停止接收' : '开始接收',
            onPressed: () =>
                ref.read(videoStreamControllerProvider.notifier).toggle(),
          ),
        ],
      ),
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
      floatingActionButton: devMode
          ? DebugFab(
              isOpen: _isDebugOpen,
              onToggle: () => setState(() => _isDebugOpen = !_isDebugOpen),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}
