/// Data-record topic configuration sub-screen.
///
/// Lists every recordable (server→client) topic grouped by reception scope
/// (team-shared vs robot-private), letting the operator choose which topics to
/// subscribe to and record. Includes a remote-sync action that pulls a shared
/// config (no-op until the GitHub backend lands).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/topic_registry.dart';
import '../../../core/sync/remote_sync_service.dart';
import '../logic/record_config_provider.dart';

/// Screen for choosing which protocol topics to record.
class RecordConfigScreen extends ConsumerWidget {
  /// Creates a [RecordConfigScreen].
  const RecordConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(recordConfigProvider);
    final notifier = ref.read(recordConfigProvider.notifier);
    final total = TopicRegistry.recordableTopicNames.length;
    final enabled = config.enabledTopics.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('数据记录配置'),
        actions: [
          TextButton(
            onPressed: () => notifier.setAll(enabled: true),
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: () => notifier.setAll(enabled: false),
            child: const Text('全不选'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SummaryBanner(enabled: enabled, total: total),
          const SizedBox(height: 8),
          for (final entry in TopicRegistry.recordableByScope.entries)
            _ScopeSection(
              scope: entry.key,
              topics: entry.value,
              config: config,
              onToggle: notifier.setTopic,
            ),
          const SizedBox(height: 8),
          _RemoteSyncCard(notifier: notifier),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.enabled, required this.total});

  final int enabled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '当前记录 $enabled/$total 个 topic。仅订阅并记录这里勾选的项；'
                '指令类 topic（客户端→服务器）不在记录范围内。',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One scope group (team-shared or robot-private) with a header and a switch
/// per topic.
class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.scope,
    required this.topics,
    required this.config,
    required this.onToggle,
  });

  final TopicScope scope;
  final List<TopicInfo> topics;
  final RecordConfig config;
  final void Function(String topic, {required bool enabled}) onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scope.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scope.description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final info in topics)
            SwitchListTile(
              dense: true,
              title: Text(info.displayName),
              subtitle: Text(
                '${info.purpose} · ${info.frequency}',
                style: const TextStyle(fontSize: 12),
              ),
              value: config.isEnabled(info.topic),
              onChanged: (v) => onToggle(info.topic, enabled: v),
            ),
        ],
      ),
    );
  }
}

/// Remote-sync actions for the shared record config. Functional once the
/// GitHub backend is wired; today it surfaces a "not configured" message.
class _RemoteSyncCard extends StatelessWidget {
  const _RemoteSyncCard({required this.notifier});

  final RecordConfigNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '远程配置同步',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '从统一仓库拉取/上传全队记录配置（GitHub 同步将在后续版本提供）。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('从远程拉取'),
                  onPressed: () => _runSync(context, notifier.pullFromRemote),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('上传到远程'),
                  onPressed: () => _runSync(context, notifier.pushToRemote),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runSync(
    BuildContext context,
    Future<SyncResult> Function() action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action();
    messenger.showSnackBar(
      SnackBar(content: Text(result.message.isEmpty ? '完成' : result.message)),
    );
  }
}
