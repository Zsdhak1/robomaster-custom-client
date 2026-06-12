/// Settings screen for dashboard display preferences.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/topic_registry.dart';
import '../../../core/state/session_providers.dart';
import '../../connection/domain/robot_identity.dart';
import '../logic/record_config_provider.dart';
import '../logic/settings_providers.dart';
import 'hwdec_screen.dart';
import 'record_config_screen.dart';

/// Lets the user pick how the dashboard presents the two teams.
class SettingsScreen extends ConsumerWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(dashboardDisplayModeProvider);
    final ownIsBlue = isBlueSide(ref.watch(selectedRobotIdProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('当前阵营'),
          _SideBanner(ownIsBlue: ownIsBlue),
          const SizedBox(height: 24),
          _buildSectionTitle('机器人列表显示模式'),
          for (final option in DashboardDisplayMode.values)
            _ModeTile(
              mode: option,
              selected: option == mode,
              onTap: () => ref
                  .read(dashboardDisplayModeProvider.notifier)
                  .state = option,
            ),
          const SizedBox(height: 24),
          ..._buildVideoDecoderSection(ref),
          const SizedBox(height: 24),
          ..._buildExportSection(ref),
          const SizedBox(height: 24),
          ..._buildDeveloperSection(ref),
        ],
      ),
    );
  }

  List<Widget> _buildVideoDecoderSection(WidgetRef ref) {
    return [
      _buildSectionTitle('视频解码器'),
      const SizedBox(height: 4),
      Text(
        '切换底层解码库以适配不同平台，默认 media_kit。',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 8),
      for (final option in VideoDecoderBackend.values)
        // ffplay is a Windows-only verification backend (subprocess).
        if (option != VideoDecoderBackend.ffplay || Platform.isWindows)
          _DecoderTile(
            backend: option,
            selected: option == ref.watch(videoDecoderBackendProvider),
            onTap: () =>
                ref.read(videoDecoderBackendProvider.notifier).set(option),
          ),
      const SizedBox(height: 12),
      _HwdecEntry(
        mediaKitSelected: ref.watch(videoDecoderBackendProvider) ==
            VideoDecoderBackend.mediaKit,
        current: ref.watch(hwdecModeProvider),
      ),
    ];
  }

  List<Widget> _buildExportSection(WidgetRef ref) {
    final directory = ref.watch(exportDirectoryProvider);
    final isUserChosen =
        ref.watch(exportDirectoryProvider.notifier).isUserChosen;
    return [
      _buildSectionTitle('数据导出'),
      const SizedBox(height: 4),
      Text(
        '比赛结算时自动整场保存；中途断线会等到比赛结束时刻再兜底保存，'
        '保证一场比赛为一个完整文件。',
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('导出目录'),
              subtitle: Text(
                directory.isEmpty
                    ? '未设置（导出时选择）'
                    : '${isUserChosen ? '自定义' : '默认'}：$directory',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () async {
                  final path = await getDirectoryPath();
                  if (path != null && path.isNotEmpty) {
                    await ref
                        .read(exportDirectoryProvider.notifier)
                        .set(path);
                  }
                },
                child: const Text('选择'),
              ),
            ),
            if (isUserChosen)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: TextButton.icon(
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('恢复默认目录'),
                    onPressed: () => ref
                        .read(exportDirectoryProvider.notifier)
                        .resetToDefault(),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const _RecordConfigEntry(),
    ];
  }

  List<Widget> _buildDeveloperSection(WidgetRef ref) {
    return [
      _buildSectionTitle('开发者'),
      Card(
        child: SwitchListTile(
          title: const Text('开发者模式'),
          subtitle: const Text('显示视频/仪表盘的 Debug 面板与状态浮层等调试组件'),
          value: ref.watch(developerModeProvider),
          onChanged: (v) =>
              ref.read(developerModeProvider.notifier).set(enabled: v),
        ),
      ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Banner showing which side the client logged in as.
class _SideBanner extends StatelessWidget {
  const _SideBanner({required this.ownIsBlue});

  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        leading: Icon(Icons.shield, color: color),
        title: Text(ownIsBlue ? '己方：蓝方' : '己方：红方'),
        subtitle: const Text('阵营由登录页选择的机器人身份决定'),
      ),
    );
  }
}

/// Entry row that opens the hardware-decoder picker (second-level page).
///
/// Only meaningful for the media_kit backend; disabled otherwise.
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

/// Entry to the data-record topic configuration sub-screen.
class _RecordConfigEntry extends ConsumerWidget {
  const _RecordConfigEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(recordConfigProvider);
    final total = TopicRegistry.recordableTopicNames.length;
    final enabled = config.enabledTopics.length;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.checklist),
        title: const Text('数据记录配置'),
        subtitle: Text('选择要订阅并记录的 topic（已启用 $enabled/$total）'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RecordConfigScreen(),
          ),
        ),
      ),
    );
  }
}

/// A selectable video decoder backend option card.
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      backend.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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

/// A selectable display-mode option card.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final DashboardDisplayMode mode;
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
                      mode.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
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
