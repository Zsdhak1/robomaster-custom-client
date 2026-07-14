/// 承载自定义 H.264/H.265 视频流（0x0310）的全屏页面。
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/widgets/stream_connection_fab.dart';
import '../../../core/widgets/video_stream_page_scaffold.dart';
import '../../settings/logic/settings_providers.dart';
import '../logic/custom_video_providers.dart';
import 'widgets/custom_video_panel.dart';

/// 自定义图传页面：控制独立 H.264/H.265 桥接，并显示带准星覆盖层的已解码流。
class CustomVideoScreen extends ConsumerStatefulWidget {
  /// 创建 [CustomVideoScreen]。
  const CustomVideoScreen({super.key});

  @override
  ConsumerState<CustomVideoScreen> createState() => _CustomVideoScreenState();
}

class _CustomVideoScreenState extends ConsumerState<CustomVideoScreen> {
  /// 跟踪正在进行的转储，以便 FAB 禁用保存按钮。
  bool _isDumping = false;

  Future<void> _toggleStream() async {
    try {
      await ref.read(customVideoControllerProvider.notifier).toggle();
    } on Object catch (e) {
      if (mounted) {
        context.showErrorSnack('自定义图传启动失败: $e');
      }
    }
  }

  /// 切换并持久化解码编码格式（H.264 / H.265）。
  ///
  /// 编码格式会在 [CustomVideoController.start] 时写入服务（关键帧闸门、NAL 扫描器、
  /// 解复用格式都依赖它），因此运行中切换需要重启才会生效；这与设置页的
  /// [_setTsWrap] 模式一致。若流正在运行，则先停止再启动，使新编码格式立即应用。
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
        context.showErrorSnack('切换 ${codec.label} 后重启失败: $e');
      }
      return;
    }

    if (mounted) {
      context.showSuccessSnack(
        wasRunning ? '已切换到 ${codec.label} 并重启接收' : '已切换到 ${codec.label}',
      );
    }
  }

  /// 转储 20 秒视频流，然后打开平台保存对话框，让用户选择 `.h264` 或 `.hevc` 文件路径。
  ///
  /// 取消保存对话框不会造成问题，临时文件会保留在应用文档目录作为降级结果。
  Future<void> _dumpAndSave() async {
    final ctrl = ref.read(customVideoControllerProvider.notifier);
    setState(() => _isDumping = true);

    try {
      // 1. 显示进度。
      if (mounted) {
        context.showInfoSnack('正在录制 20 秒视频流…');
      }

      // 2. 启动 20 秒转储，由 CustomVideoStreamService 产出临时 .h264/.hevc 文件。
      final tempPath = await ctrl.startDump();

      // 3. 根据当前编码格式确定正确扩展名。
      final codec = ref.read(customVideoCodecProvider);
      final ext = codec == CustomVideoCodec.h265 ? 'hevc' : 'h264';
      final extLabel = codec == CustomVideoCodec.h265
          ? 'HEVC Annex-B'
          : 'H.264 Annex-B';

      // 4. 打开平台保存对话框。
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
        // 用户取消保存对话框，临时文件保留作为降级结果。
        if (mounted) {
          context.showInfoSnack('已取消保存，临时文件保留在:\n$tempPath');
        }
        return;
      }

      // 5. 将临时文件复制到用户选择的位置。
      final src = File(tempPath);
      final dst = File(saveLocation.path);
      await src.copy(dst.path);

      if (mounted) {
        context.showSuccessSnack('视频流已保存到:\n${dst.path}');
      }
    } on Object catch (e) {
      if (mounted) {
        context.showErrorSnack('录制/保存失败: $e');
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

/// AppBar 控件，用于让用户手动选择解码编码格式。
///
/// 这里反映 [customVideoCodecProvider] 中期望且已持久化的编码格式；侧边面板的
/// “编码格式”行则读取服务中实际运行的编码格式。重启期间短暂不一致可确认切换已触发。
class _CodecSelector extends StatelessWidget {
  const _CodecSelector({required this.selected, required this.onChanged});

  /// 当前选中的编码格式。
  final CustomVideoCodec selected;

  /// 用户选择新编码格式时调用。
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
