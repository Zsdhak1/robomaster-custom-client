/// 回放 — 数据导出目录、记录配置
library;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/topic_registry.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/record_config_provider.dart';
import '../logic/settings_providers.dart';
import 'record_config_screen.dart';

/// Sub-screen for playback / data-recording settings.
class PlaybackSettingsScreen extends ConsumerWidget {
  /// Creates a [PlaybackSettingsScreen].
  const PlaybackSettingsScreen({super.key, this.embedded = false});

  /// When true, renders only the body without its own Scaffold/AppBar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = _buildBody(context, ref);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('回放')),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ..._buildExportSection(context, ref),
      ],
    );
  }

  List<Widget> _buildExportSection(BuildContext context, WidgetRef ref) {
    final directory = ref.watch(exportDirectoryProvider);
    final isUserChosen =
        ref.watch(exportDirectoryProvider.notifier).isUserChosen;
    return [
      const SizedBox(height: 4),
      Text(
        '比赛结算时自动整场保存；中途断线会等到比赛结束时刻再兜底保存，'
        '保证一场比赛为一个完整文件。',
        style: context.textTheme.bodySmall!.copyWith(
          color: rmTextSecondary(context),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            _DirectoryPickerTile(
              directory: directory,
              isUserChosen: isUserChosen,
              onPick: (path) =>
                  ref.read(exportDirectoryProvider.notifier).set(path),
            ),
            if (isUserChosen)
              _ResetDirectoryButton(
                onReset: () =>
                    ref.read(exportDirectoryProvider.notifier).resetToDefault(),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      const _RecordConfigEntry(),
    ];
  }
}

class _DirectoryPickerTile extends StatelessWidget {
  const _DirectoryPickerTile({
    required this.directory,
    required this.isUserChosen,
    required this.onPick,
  });

  final String directory;
  final bool isUserChosen;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListTile(
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
            onPick(path);
          }
        },
        child: const Text('选择'),
      ),
    );
  }
}

class _ResetDirectoryButton extends StatelessWidget {
  const _ResetDirectoryButton({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, bottom: 8),
        child: TextButton.icon(
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('恢复默认目录'),
          onPressed: onReset,
        ),
      ),
    );
  }
}

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
