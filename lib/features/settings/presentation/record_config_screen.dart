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
import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/sync/remote_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/github_sync_provider.dart';
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
          const _RemoteSyncCard(),
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
                  style: context.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scope.description,
                  style: context.textTheme.bodySmall!.copyWith(
                    color: rmTextSecondary(context),
                  ),
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
                style: context.textTheme.bodySmall,
              ),
              value: config.isEnabled(info.topic),
              onChanged: (v) => onToggle(info.topic, enabled: v),
            ),
        ],
      ),
    );
  }
}

/// Remote-sync actions for the shared record config, backed by GitHub.
///
/// Shows the current connection target, lets the operator open the GitHub
/// configuration dialog, and pull/push the shared `record_config.json`.
class _RemoteSyncCard extends ConsumerWidget {
  const _RemoteSyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncConfig = ref.watch(gitHubSyncConfigProvider);
    final notifier = ref.read(recordConfigProvider.notifier);
    final canPull = syncConfig.canPull;
    final canPush = syncConfig.canPush;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '远程配置同步',
                    style: context.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _SyncStatusPill(canPull: canPull, canPush: canPush),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              canPull
                  ? '仓库 ${syncConfig.repository} · 分支 ${syncConfig.branch}'
                      '${canPush ? '' : ' · 仅可拉取（填写令牌后可上传）'}'
                  : '配置 GitHub 仓库后，可在全队之间拉取/上传统一的记录配置。',
              style: context.textTheme.bodySmall!.copyWith(
                color: rmTextSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('配置 GitHub'),
                  onPressed: () => _openConfigDialog(context, ref),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_download, size: 18),
                  label: const Text('从远程拉取'),
                  onPressed: canPull
                      ? () => _runSync(context, notifier.pullFromRemote)
                      : null,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_upload, size: 18),
                  label: const Text('上传到远程'),
                  onPressed: canPush
                      ? () => _runSync(context, notifier.pushToRemote)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openConfigDialog(BuildContext context, WidgetRef ref) async {
    final current = ref.read(gitHubSyncConfigProvider);
    final result = await showDialog<RemoteSyncConfig>(
      context: context,
      builder: (_) => _GitHubConfigDialog(initial: current),
    );
    if (result != null) {
      await ref.read(gitHubSyncConfigProvider.notifier).update(result);
    }
  }

  Future<void> _runSync(
    BuildContext context,
    Future<SyncResult> Function() action,
  ) async {
    context.showInfoSnack('同步中…');
    final result = await action();
    if (!context.mounted) return;
    if (result.ok) {
      context.showSuccessSnack(result.message.isEmpty ? '完成' : result.message);
    } else {
      context.showErrorSnack(result.message.isEmpty ? '同步失败' : result.message);
    }
  }
}

/// A small pill showing whether remote sync is configured.
class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill({required this.canPull, required this.canPush});

  final bool canPull;
  final bool canPush;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch ((canPull, canPush)) {
      (true, true) => (Colors.green, Icons.check_circle, '可读写'),
      (true, false) => (Colors.blue, Icons.cloud_done, '仅可拉取'),
      _ => (Colors.grey, Icons.cloud_off, '未配置'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall!.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for entering the GitHub repository, branch, token, and in-repo paths.
class _GitHubConfigDialog extends StatefulWidget {
  const _GitHubConfigDialog({required this.initial});

  final RemoteSyncConfig initial;

  @override
  State<_GitHubConfigDialog> createState() => _GitHubConfigDialogState();
}

class _GitHubConfigDialogState extends State<_GitHubConfigDialog> {
  late final TextEditingController _repo;
  late final TextEditingController _branch;
  late final TextEditingController _token;
  late final TextEditingController _configPath;
  late final TextEditingController _recordsDir;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _repo = TextEditingController(text: widget.initial.repository);
    _branch = TextEditingController(text: widget.initial.branch);
    _token = TextEditingController(text: widget.initial.token);
    _configPath = TextEditingController(text: widget.initial.configPath);
    _recordsDir = TextEditingController(text: widget.initial.recordsDir);
  }

  @override
  void dispose() {
    _repo.dispose();
    _branch.dispose();
    _token.dispose();
    _configPath.dispose();
    _recordsDir.dispose();
    super.dispose();
  }

  void _save() {
    final config = widget.initial.copyWith(
      repository: _repo.text.trim(),
      branch: _branch.text.trim().isEmpty ? 'main' : _branch.text.trim(),
      token: _token.text.trim(),
      configPath: _configPath.text.trim().isEmpty
          ? 'record_config.json'
          : _configPath.text.trim(),
      recordsDir: _recordsDir.text.trim().isEmpty
          ? 'records'
          : _recordsDir.text.trim(),
    );
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('GitHub 同步配置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_repo, '仓库 (owner/repo)', 'your-team/rm-config'),
              _field(_branch, '分支', 'main'),
              _tokenField(),
              _field(_configPath, '配置文件路径', 'record_config.json'),
              _field(_recordsDir, '记录目录', 'records'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: rmTrackFill(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.key,
                            size: 14, color: rmTextSecondary(context)),
                        const SizedBox(width: 4),
                        Text(
                          '令牌使用细粒度 PAT（单仓库授权）',
                          style: context.textTheme.labelSmall!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: rmTextPrimary(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GitHub → Settings → Developer settings → '
                      'Fine-grained personal access tokens：\n'
                      '· Repository access：仅选本仓库\n'
                      '· Permissions → Repository → Contents：\n'
                      '   只读拉取选 Read，需上传则选 Read and write\n'
                      '令牌仅保存在本机，不写入共享配置文件。',
                      style: context.textTheme.labelSmall!.copyWith(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _tokenField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: _token,
        obscureText: _obscureToken,
        decoration: InputDecoration(
          isDense: true,
          labelText: '访问令牌 (Fine-grained PAT)',
          hintText: 'github_pat_...',
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureToken ? Icons.visibility : Icons.visibility_off,
              size: 18,
            ),
            tooltip: _obscureToken ? '显示' : '隐藏',
            onPressed: () => setState(() => _obscureToken = !_obscureToken),
          ),
        ),
      ),
    );
  }
}
