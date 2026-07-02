/// Full-screen page hosting the custom H.264/H.265 video stream (0x0310).
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/widgets/stream_connection_fab.dart';
import '../../../core/widgets/video_stream_page_scaffold.dart';
import '../../settings/logic/settings_providers.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('自定义图传启动失败: $e')));
      }
    }
  }

  /// Switches the decode codec (H.264 / H.265) and persists it.
  ///
  /// The codec is captured by [CustomVideoController.start] and frozen into the
  /// service (gate / NAL scanner / demuxer format all branch on it), so a live
  /// switch only takes effect after a restart — mirroring the [_setTsWrap]
  /// pattern in the settings screen. When the stream is running we stop & start
  /// so the new codec applies immediately.
  Future<void> _setCodec(CustomVideoCodec codec) async {
    if (codec == ref.read(customVideoCodecProvider)) return;
    await ref.read(customVideoCodecProvider.notifier).set(codec);

    final wasRunning = ref.read(customVideoControllerProvider);
    final ctrl = ref.read(customVideoControllerProvider.notifier);
    try {
      if (wasRunning) {
        ctrl.stop();
        await ctrl.start();
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('切换 ${codec.label} 后重启失败: $e')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasRunning ? '已切换到 ${codec.label} 并重启接收' : '已切换到 ${codec.label}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
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
      //    CustomVideoStreamService and produces a .h264/.hevc file in app docs.
      final tempPath = await ctrl.startDump();

      // 3. Determine the correct extension from the active codec.
      final codec = ref.read(customVideoCodecProvider);
      final ext = codec == CustomVideoCodec.h265 ? 'hevc' : 'h264';
      final extLabel = codec == CustomVideoCodec.h265
          ? 'HEVC Annex-B'
          : 'H.264 Annex-B';

      // 4. Open platform save dialog
      final saveLocation = await getSaveLocation(
        suggestedName:
            'custom_video_dump_'
            '${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}'
            '.$ext',
        acceptedTypeGroups: [
          XTypeGroup(label: extLabel, extensions: [ext]),
        ],
      );

      if (saveLocation == null) {
        // User cancelled the dialog — temp file remains as fallback.
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已取消保存，临时文件保留在:\n$tempPath')));
        }
        return;
      }

      // 4. Copy temp file to user-selected location
      final src = File(tempPath);
      final dst = File(saveLocation.path);
      await src.copy(dst.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('视频流已保存到:\n${dst.path}')));
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('录制/保存失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDumping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRunning = ref.watch(customVideoControllerProvider);
    final codec = ref.watch(customVideoCodecProvider);

    return VideoStreamPageScaffold(
      title: '自定义图传 · 0x0310',
      body: const CustomVideoPanel(),
      isRunning: isRunning,
      onToggle: _toggleStream,
      appBarActions: [
        _CodecSelector(selected: codec, onChanged: _setCodec),
        SizedBox(width: context.sp(8)),
      ],
      secondaryActions: isRunning
          ? [
              StreamFabAction(
                icon: Icons.save_alt,
                label: _isDumping ? '正在录制 20s…' : '保存前 20 秒',
                enabled: !_isDumping,
                onPressed: _dumpAndSave,
              ),
            ]
          : const [],
    );
  }
}

/// AppBar control letting the user manually pick the decode codec.
///
/// Reflects [customVideoCodecProvider] (the desired/persisted codec); the side
/// panel's "编码格式" row reflects the actually-running codec read back from the
/// service, so a brief mismatch during a restart confirms the switch landed.
class _CodecSelector extends StatelessWidget {
  const _CodecSelector({required this.selected, required this.onChanged});

  /// Currently-selected codec.
  final CustomVideoCodec selected;

  /// Invoked with the newly-chosen codec.
  final ValueChanged<CustomVideoCodec> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetSym(v: 8),
      child: SegmentedButton<CustomVideoCodec>(
        segments: const [
          ButtonSegment(value: CustomVideoCodec.h264, label: Text('H.264')),
          ButtonSegment(value: CustomVideoCodec.h265, label: Text('H.265')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: WidgetStatePropertyAll(context.textTheme.labelMedium),
        ),
      ),
    );
  }
}
