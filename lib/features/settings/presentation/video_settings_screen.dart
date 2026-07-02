/// 图传 — 官方图传解码器 + 自定义图传参数
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/settings_providers.dart';
import 'hwdec_screen.dart';

/// Sub-screen for all video transmission settings.
class VideoSettingsScreen extends ConsumerWidget {
  /// Creates a [VideoSettingsScreen].
  const VideoSettingsScreen({super.key, this.embedded = false});

  /// When true, renders only the body without its own Scaffold/AppBar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _buildBody(context, ref);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('图传')),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._buildOfficialSection(context, ref),
        const SizedBox(height: 24),
        ..._buildCustomSection(context, ref),
      ],
    );
  }

  // ================================================================
  // 官方图传 (UDP 3334)
  // ================================================================

  List<Widget> _buildOfficialSection(BuildContext context, WidgetRef ref) {
    return [
      _buildSubSectionTitle(context, '官方图传 (UDP 3334)'),
      const SizedBox(height: 4),
      Text(
        '切换底层解码库以适配不同平台，默认 media_kit。',
        style: context.textTheme.bodySmall!.copyWith(
          color: rmTextSecondary(context),
        ),
      ),
      const SizedBox(height: 8),
      for (final option in VideoDecoderBackend.values)
        if (option != VideoDecoderBackend.ffplay || Platform.isWindows)
          _DecoderTile(
            backend: option,
            selected: option == ref.watch(videoDecoderBackendProvider),
            onTap: () =>
                ref.read(videoDecoderBackendProvider.notifier).set(option),
          ),
      const SizedBox(height: 12),
      _HwdecEntry(
        mediaKitSelected:
            ref.watch(videoDecoderBackendProvider) ==
            VideoDecoderBackend.mediaKit,
        current: ref.watch(hwdecModeProvider),
      ),
    ];
  }

  // ================================================================
  // 自定义图传 (0x0310)
  // ================================================================

  List<Widget> _buildCustomSection(BuildContext context, WidgetRef ref) {
    return [
      _buildSubSectionTitle(context, '自定义图传 (0x0310 / 裸 H.264)'),
      const SizedBox(height: 4),
      Text(
        '仅作用于自定义图传 (CustomByteBlock)，与官方图传独立。'
        '默认 fvp；media_kit 多数平台不含裸 H.264 解封装；ffplay 仅验证用',
        style: context.textTheme.bodySmall!.copyWith(
          color: rmTextSecondary(context),
        ),
      ),
      const SizedBox(height: 8),
      for (final option in VideoDecoderBackend.values)
        if (option != VideoDecoderBackend.ffplay || Platform.isWindows)
          _DecoderTile(
            backend: option,
            selected: option == ref.watch(customVideoBackendProvider),
            onTap: () =>
                ref.read(customVideoBackendProvider.notifier).set(option),
          ),
      const SizedBox(height: 8),
      _buildTsWrapCard(ref),
      const SizedBox(height: 8),
      Card(
        child: SwitchListTile(
          title: const Text('8 字节序列号包头'),
          subtitle: const Text(
            '每包前 8 字节为 uint64(LE) 递增序列号，用于统计丢包率；'
            '开启后会解析并在调试面板显示，并在拼包前剥离这 8 字节。',
          ),
          value: ref.watch(customVideoSeqHeaderProvider),
          onChanged: (v) =>
              ref.read(customVideoSeqHeaderProvider.notifier).set(enabled: v),
        ),
      ),
      const SizedBox(height: 8),
      _buildSliceModeCard(context, ref),
      if (ref.watch(customVideoSliceModeProvider) ==
          CustomVideoSliceMode.fixed) ...[
        const SizedBox(height: 8),
        _PayloadBytesTile(
          bytes: ref.watch(customVideoPayloadBytesProvider),
          onChanged: (v) =>
              ref.read(customVideoPayloadBytesProvider.notifier).set(v),
        ),
      ],
    ];
  }

  Widget _buildSliceModeCard(BuildContext context, WidgetRef ref) {
    final current = ref.watch(customVideoSliceModeProvider);
    return Card(
      child: RadioGroup<CustomVideoSliceMode>(
        groupValue: current,
        onChanged: (value) {
          if (value != null) {
            ref.read(customVideoSliceModeProvider.notifier).set(value);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                '拼包方式（实时生效）',
                style: context.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final mode in CustomVideoSliceMode.values)
              RadioListTile<CustomVideoSliceMode>(
                value: mode,
                title: Text(mode.label),
                subtitle: Text(mode.description),
                dense: true,
              ),
          ],
        ),
      ),
    );
  }

  /// MPEG-TS wrap toggle. media_kit forces TS on (its libmpv lacks the raw
  /// H.264 demuxer), so the switch is locked on and explained for that backend
  /// instead of silently overriding a switch the user left off.
  Widget _buildTsWrapCard(WidgetRef ref) {
    final forced =
        ref.watch(customVideoBackendProvider) == VideoDecoderBackend.mediaKit;
    final effective = ref.watch(customVideoEffectiveTsWrapProvider);
    return Card(
      child: SwitchListTile(
        title: const Text('封装为 MPEG-TS（推荐开启）'),
        subtitle: Text(
          forced
              ? 'media_kit 不含裸 H.264 解封装，已强制封装为 MPEG-TS。切换会自动重启接收。'
              : '把裸 H.264 包成 MPEG-TS，切换会自动重启接收。',
        ),
        value: effective,
        onChanged: forced ? null : (v) => _setTsWrap(ref, enabled: v),
      ),
    );
  }

  Future<void> _setTsWrap(WidgetRef ref, {required bool enabled}) async {
    // Persist only. If this changes the effective TS value while streaming,
    // customVideoControllerProvider's listener restarts the bridge — keeping
    // restart logic in one place and avoiding a double restart.
    await ref.read(customVideoTsWrapProvider.notifier).set(enabled: enabled);
  }

  Widget _buildSubSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: context.textTheme.bodySmall!.copyWith(
          fontWeight: FontWeight.w600,
          color: rmTextSecondary(context),
        ),
      ),
    );
  }
}

// ======================================================================
// 图传子组件
// ======================================================================

class _HwdecEntry extends StatelessWidget {
  const _HwdecEntry({required this.mediaKitSelected, required this.current});

  final bool mediaKitSelected;
  final HwdecMode current;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.memory),
        title: const Text('硬件解码器'),
        subtitle: Text(
          mediaKitSelected ? current.label : '仅 media_kit 后端可用',
        ),
        trailing: const Icon(Icons.chevron_right),
        enabled: mediaKitSelected,
        onTap: mediaKitSelected
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HwdecScreen(),
                  ),
                )
            : null,
      ),
    );
  }
}

class _DecoderTile extends StatelessWidget {
  const _DecoderTile({
    required this.backend,
    required this.selected,
    required this.onTap,
  });

  final VideoDecoderBackend backend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? color : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      backend.label,
                      style: context.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      backend.description,
                      style: context.textTheme.bodySmall!.copyWith(
                        color: rmTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayloadBytesTile extends StatelessWidget {
  const _PayloadBytesTile({required this.bytes, required this.onChanged});

  final int bytes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '单包图传数据字节数',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: bytes > customVideoMinPayloadBytes
                      ? () => onChanged(bytes - 1)
                      : null,
                ),
                Text(
                  '$bytes',
                  style: context.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: bytes < customVideoMaxPayloadBytes
                      ? () => onChanged(bytes + 1)
                      : null,
                ),
              ],
            ),
            Slider(
              value: bytes.toDouble(),
              min: customVideoMinPayloadBytes.toDouble(),
              max: customVideoMaxPayloadBytes.toDouble(),
              divisions:
                  customVideoMaxPayloadBytes - customVideoMinPayloadBytes,
              label: '$bytes',
              onChanged: (v) => onChanged(v.round()),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                '每个 CustomByteBlock 取 ${customVideoHeaderBytes}B 包头 + '
                '$bytes B 视频数据拼接（默认 $customVideoDefaultPayloadBytes）。'
                '修改即时生效，无需重启接收。',
                style: context.textTheme.bodySmall!.copyWith(
                  color: rmTextSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
