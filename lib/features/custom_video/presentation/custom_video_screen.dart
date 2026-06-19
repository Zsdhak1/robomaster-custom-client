/// Full-screen page hosting the custom H.264 video stream (0x0310).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/page_fab_menu.dart';
import '../logic/custom_video_providers.dart';
import 'widgets/custom_video_panel.dart';

/// Custom video-stream page: controls the independent H.264 bridge and shows
/// the decoded feed with crosshair overlay.
class CustomVideoScreen extends ConsumerStatefulWidget {
  /// Creates a [CustomVideoScreen].
  const CustomVideoScreen({super.key});

  @override
  ConsumerState<CustomVideoScreen> createState() => _CustomVideoScreenState();
}

class _CustomVideoScreenState extends ConsumerState<CustomVideoScreen> {
  Future<void> _toggleStream() async {
    try {
      await ref.read(customVideoControllerProvider.notifier).toggle();
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('自定义图传启动失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(customVideoControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('自定义图传 · CustomByteBlock')),
      body: const CustomVideoPanel(),
      floatingActionButton: PageFabMenu(
        actions: [
          FabAction(
            icon: isRunning ? Icons.stop : Icons.play_arrow,
            label: isRunning ? '停止接收' : '开始接收',
            onSelected: _toggleStream,
          ),
        ],
      ),
    );
  }
}
