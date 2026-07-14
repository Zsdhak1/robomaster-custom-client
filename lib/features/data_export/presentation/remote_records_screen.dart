/// 列出共享远程仓库中的比赛记录，并允许操作手下载到本地导出目录。
///
/// 远程文件名会被解析为日期、阵营和机器人 ID，使列表与记录管理页的筛选方式保持一致。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/sync/remote_sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../connection/domain/robot_identity.dart';
import '../../settings/logic/github_sync_provider.dart';
import '../domain/remote_record_meta.dart';
import '../logic/data_export_providers.dart';
import '../logic/remote_records_provider.dart';

/// 用于浏览远程记录的页面。
class RemoteRecordsScreen extends ConsumerStatefulWidget {
  /// 创建 [RemoteRecordsScreen]。
  const RemoteRecordsScreen({super.key});

  @override
  ConsumerState<RemoteRecordsScreen> createState() =>
      _RemoteRecordsScreenState();
}

class _RemoteRecordsScreenState extends ConsumerState<RemoteRecordsScreen> {
  DateTime? _filterDate;
  _RemoteSideFilter _sideFilter = _RemoteSideFilter.all;
  int? _robotFilter;

  @override
  Widget build(BuildContext context) {
    final syncConfig = ref.watch(gitHubSyncConfigProvider);
    final remoteState = ref.watch(remoteRecordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('远程记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: remoteState.isLoading
                ? null
                : () => ref.read(remoteRecordsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RepoHeader(config: syncConfig),
          _FilterBar(
            date: _filterDate,
            side: _sideFilter,
            robotId: _robotFilter,
            records: remoteState.records,
            onDateChanged: (d) => setState(() => _filterDate = d),
            onSideChanged: (s) => setState(() => _sideFilter = s),
            onRobotChanged: (id) => setState(() => _robotFilter = id),
          ),
          if (remoteState.error.isNotEmpty)
            _ErrorBanner(message: remoteState.error),
          Expanded(
            child: remoteState.isLoading && remoteState.records.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _RemoteRecordList(
                    records: remoteState.records,
                    filterDate: _filterDate,
                    sideFilter: _sideFilter,
                    robotFilter: _robotFilter,
                  ),
          ),
        ],
      ),
    );
  }
}

enum _RemoteSideFilter { all, red, blue }

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.date,
    required this.side,
    required this.robotId,
    required this.records,
    required this.onDateChanged,
    required this.onSideChanged,
    required this.onRobotChanged,
  });

  final DateTime? date;
  final _RemoteSideFilter side;
  final int? robotId;
  final List<RemoteRecordRef> records;
  final ValueChanged<DateTime?> onDateChanged;
  final ValueChanged<_RemoteSideFilter> onSideChanged;
  final ValueChanged<int?> onRobotChanged;

  @override
  Widget build(BuildContext context) {
    final robotIds = records
        .map((r) => RemoteRecordMeta.parse(r.fileName).robotId)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DateFilterChip(
            date: date,
            onChanged: onDateChanged,
          ),
          _SideFilterChip(
            value: side,
            onChanged: onSideChanged,
          ),
          _RobotFilterChip(
            robotIds: robotIds,
            selected: robotId,
            onChanged: onRobotChanged,
          ),
        ],
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({required this.date, required this.onChanged});

  final DateTime? date;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = date == null
        ? '全部日期'
        : '${date!.year}-${_two(date!.month)}-${_two(date!.day)}';
    return InputChip(
      avatar: const Icon(Icons.calendar_today, size: 18),
      label: Text(label),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2025),
          lastDate: DateTime.now().add(const Duration(days: 1)),
        );
        onChanged(picked);
      },
      deleteIcon: date == null ? null : const Icon(Icons.clear, size: 18),
      onDeleted: date == null ? null : () => onChanged(null),
    );
  }

  static String _two(int n) => n >= 10 ? '$n' : '0$n';
}

class _SideFilterChip extends StatelessWidget {
  const _SideFilterChip({required this.value, required this.onChanged});

  final _RemoteSideFilter value;
  final ValueChanged<_RemoteSideFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<_RemoteSideFilter>(
      initialSelection: value,
      label: const Text('阵营'),
      onSelected: (v) {
        if (v != null) onChanged(v);
      },
      dropdownMenuEntries: const [
        DropdownMenuEntry(value: _RemoteSideFilter.all, label: '全部阵营'),
        DropdownMenuEntry(value: _RemoteSideFilter.red, label: '红方'),
        DropdownMenuEntry(value: _RemoteSideFilter.blue, label: '蓝方'),
      ],
    );
  }
}

class _RobotFilterChip extends StatelessWidget {
  const _RobotFilterChip({
    required this.robotIds,
    required this.selected,
    required this.onChanged,
  });

  final List<int> robotIds;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<int?>(
      initialSelection: selected,
      label: const Text('机器人'),
      onSelected: onChanged,
      dropdownMenuEntries: [
        const DropdownMenuEntry<int?>(value: null, label: '全部机器人'),
        for (final id in robotIds)
          DropdownMenuEntry<int?>(
            value: id,
            label: robotDisplayName(id),
          ),
      ],
    );
  }
}

class _RepoHeader extends StatelessWidget {
  const _RepoHeader({required this.config});

  final RemoteSyncConfig config;

  @override
  Widget build(BuildContext context) {
    final canPull = config.canPull;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.cloud,
              color: canPull
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canPull ? config.repository : '未配置远程仓库',
                    style: context.textTheme.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    canPull
                        ? '分支 ${config.branch} · 目录 ${config.recordsDir}'
                        : '请在「数据记录配置」中配置 GitHub 同步',
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
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: MaterialBanner(
        content: Text(message),
        leading: const Icon(Icons.error_outline, color: Colors.red),
        backgroundColor: Colors.red.shade50,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _RemoteRecordList extends ConsumerWidget {
  const _RemoteRecordList({
    required this.records,
    required this.filterDate,
    required this.sideFilter,
    required this.robotFilter,
  });

  final List<RemoteRecordRef> records;
  final DateTime? filterDate;
  final _RemoteSideFilter sideFilter;
  final int? robotFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = records.where((record) {
      final info = RemoteRecordMeta.parse(record.fileName);
      if (filterDate != null && info.date != null) {
        final d = info.date!;
        if (d.year != filterDate!.year ||
            d.month != filterDate!.month ||
            d.day != filterDate!.day) {
          return false;
        }
      }
      if (sideFilter != _RemoteSideFilter.all &&
          info.side != RecordSide.unknown) {
        final isBlue = info.side == RecordSide.blue;
        if (sideFilter == _RemoteSideFilter.blue && !isBlue) return false;
        if (sideFilter == _RemoteSideFilter.red && isBlue) return false;
      }
      if (robotFilter != null && info.robotId != robotFilter) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('暂无匹配记录', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        return _RemoteRecordTile(record: filtered[index]);
      },
    );
  }
}

class _RemoteRecordTile extends ConsumerWidget {
  const _RemoteRecordTile({required this.record});

  final RemoteRecordRef record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = RemoteRecordMeta.parse(record.fileName);
    final remoteState = ref.watch(remoteRecordsProvider);
    final isDownloading = remoteState.isLoading;
    final sideColor =
        info.side == RecordSide.blue ? rmBlueTeamColor : rmRedTeamColor;

    return Card(
      child: ListTile(
        leading: Icon(
          info.kind == RecordKind.merged ? Icons.merge_type : Icons.shield,
          color: info.side == RecordSide.unknown ? Colors.grey : sideColor,
        ),
        title: Text(_title(info)),
        subtitle: Text(
          '${_dateLabel(info)} · ${_sideLabel(info)} · ${_robotLabel(info)} · '
          '${_formatSize(record.sizeBytes)}\n${record.fileName}',
          style: context.textTheme.bodySmall!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
        isThreeLine: true,
        trailing: isDownloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                icon: const Icon(Icons.download),
                tooltip: '下载到本地',
                onPressed: () => _download(context, ref),
              ),
      ),
    );
  }

  String _title(RemoteRecordMeta info) {
    if (info.kind == RecordKind.merged) return '合并记录';
    if (info.robotId != null) return robotDisplayName(info.robotId!);
    return info.fileName;
  }

  String _dateLabel(RemoteRecordMeta info) {
    final d = info.date;
    if (d == null) return '—';
    return '${d.year}-${_two(d.month)}-${_two(d.day)} ${d.hour}:${_two(d.minute)}';
  }

  String _sideLabel(RemoteRecordMeta info) => switch (info.side) {
        RecordSide.red => '红方',
        RecordSide.blue => '蓝方',
        RecordSide.unknown => '未知阵营',
      };

  String _robotLabel(RemoteRecordMeta info) {
    if (info.kind == RecordKind.merged) return '多机合并';
    if (info.robotId != null) return 'ID ${info.robotId}';
    return '未知编号';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(remoteRecordsProvider.notifier);
    final path = await notifier.download(record);
    if (!context.mounted) return;

    if (path != null) {
      ref.invalidate(matchRecordsProvider);
      context.showSuccessSnack('已下载: $path');
    } else {
      context.showErrorSnack('下载失败');
    }
  }

  static String _two(int n) => n >= 10 ? '$n' : '0$n';
}
