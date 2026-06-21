/// Full-screen page hosting the custom H.264 video stream (0x0310).
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
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
  /// Tracks in-progress dump so the FAB can disable the save button.
  bool _isDumping = false;

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

  /// Dumps 20 seconds of stream, then opens the platform save dialog for the
  /// user to choose where to write the `.h264` file.  Cancelling the save
  /// dialog is harmless — the temp file in app docs is left as a fallback.
  Future<void> _dumpAndSave() async {
    final ctrl = ref.read(customVideoControllerProvider.notifier);
    setState(() => _isDumping = true);

    try {
      // 1. Show progress
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在录制 20 秒视频流…'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 2. Start 20-second dump — the dump captures chunks inside
      //    CustomVideoStreamService and produces a .h264 file in app docs.
      final tempPath = await ctrl.startDump();

      // 3. Open platform save dialog
      final saveLocation = await getSaveLocation(
        suggestedName: 'custom_video_dump_'
            '${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}'
            '.h264',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'H.264 Annex-B',
            extensions: ['h264'],
          ),
        ],
      );

      if (saveLocation == null) {
        // User cancelled the dialog — temp file remains as fallback.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已取消保存，临时文件保留在:\n$tempPath'),
            ),
          );
        }
        return;
      }

      // 4. Copy temp file to user-selected location
      final src = File(tempPath);
      final dst = File(saveLocation.path);
      await src.copy(dst.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('视频流已保存到:\n${dst.path}'),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录制/保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDumping = false);
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
          FabAction(
            icon: Icons.save_alt,
            label: isRunning ? (_isDumping ? '正在录制 20s…' : '保存前 20 秒') : '保存前 20 秒',
            enabled: isRunning && !_isDumping,
            onSelected: _dumpAndSave,
          ),
        ],
      ),
    );
  }
}
