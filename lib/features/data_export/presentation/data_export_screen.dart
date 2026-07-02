/// Data export management screen.
///
/// Left side lists saved JSON match records; right side previews the selected
/// record's event timeline.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/navigation/page_fab_menu.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../connection/domain/robot_identity.dart';
import '../../dashboard/logic/game_state.dart';
import '../../dashboard/logic/stream_providers.dart';
import '../../dashboard/presentation/widgets/event_timeline_panel.dart';
import '../../settings/logic/github_sync_provider.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/json_exporter.dart';
import '../domain/match_merger.dart';
import '../domain/match_record.dart';
import '../logic/data_export_providers.dart';
import '../logic/data_recorder_provider.dart';
import 'remote_records_screen.dart';
import 'replay_screen.dart';

const _jsonTypeGroup = XTypeGroup(
  label: 'JSON',
  extensions: ['json'],
);

/// Screen for managing saved match records and previewing their events.
class DataExportScreen extends ConsumerWidget {
  /// Creates a [DataExportScreen].
  const DataExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportDir = ref.watch(exportDirectoryProvider);
    final recorder = ref.watch(dataRecorderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录管理'),
        actions: [
          _RecordingIndicator(isRecording: recorder.isRecording),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: _RecordList(exportDirectory: exportDir),
          ),
          const VerticalDivider(width: 1),
          const Expanded(
            flex: 3,
            child: _PreviewPanel(),
          ),
        ],
      ),
      floatingActionButton: PageFabMenu(
        actions: [
          FabAction(
            icon: Icons.upload_file,
            label: '导出当前记录',
            onSelected: () => _DataActions.export(context, ref),
          ),
          FabAction(
            icon: Icons.download,
            label: '导入记录文件',
            onSelected: () => _DataActions.import(context, ref),
          ),
          FabAction(
            icon: Icons.cloud_sync_outlined,
            label: '刷新列表',
            onSelected: () => ref.invalidate(matchRecordsProvider),
          ),
          FabAction(
            icon: Icons.cloud_outlined,
            label: '远程记录',
            onSelected: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RemoteRecordsScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingIndicator extends StatelessWidget {
  const _RecordingIndicator({required this.isRecording});

  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: [
          Icon(
            Icons.fiber_manual_record,
            size: 14,
            color: isRecording ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isRecording ? '录制中' : '未录制',
            style: context.textTheme.bodySmall!.copyWith(
              color: isRecording ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Export / import operations invoked from the page FAB menu.
///
/// Kept as static helpers (rather than buttons) so the FAB can call them
/// directly with the ambient [BuildContext] and [WidgetRef].
abstract final class _DataActions {
  static Future<void> export(BuildContext context, WidgetRef ref) async {
    final directory = ref.read(exportDirectoryProvider);
    if (directory.isEmpty) {
      _showSnackBar(context, '请先前往设置页选择导出目录');
      return;
    }

    final robotId = ref.read(selectedRobotIdProvider);
    final matchStartTime = ref.read(gameStateProvider).matchStartTime;
    final recorder = ref.read(dataRecorderProvider);

    final exporter = JsonExporter(
      robotId: robotId,
      exportDirectory: directory,
      matchStartTime: matchStartTime,
    );

    try {
      final path = await exporter.export(recorder);
      ref.invalidate(matchRecordsProvider);
      if (context.mounted) {
        _showSnackBar(context, '已导出: $path');
      }
    } on Exception catch (e) {
      if (context.mounted) {
        _showSnackBar(context, '导出失败: $e');
      }
    }
  }

  /// Copies one or more external JSON record files into the export directory so
  /// they show up in the record list and can be selected for merging.
  static Future<void> import(BuildContext context, WidgetRef ref) async {
    final directory = ref.read(exportDirectoryProvider);
    if (directory.isEmpty) {
      _showSnackBar(context, '请先前往设置页选择导出目录');
      return;
    }

    final files = await openFiles(acceptedTypeGroups: const [_jsonTypeGroup]);
    if (files.isEmpty) return;

    var copied = 0;
    final failures = <String>[];
    for (final file in files) {
      try {
        await _copyIntoDirectory(file.path, directory);
        copied++;
      } on Exception catch (e) {
        failures.add('${file.name}: $e');
      }
    }

    ref.invalidate(matchRecordsProvider);
    if (!context.mounted) return;

    if (failures.isEmpty) {
      _showSnackBar(context, '已导入 $copied 个记录文件');
    } else {
      _showSnackBar(
        context,
        '导入 $copied 个，失败 ${failures.length} 个: ${failures.first}',
      );
    }
  }

  /// Copies [sourcePath] into [directory], skipping when it already lives there
  /// and de-duplicating the file name on collision.
  static Future<void> _copyIntoDirectory(
    String sourcePath,
    String directory,
  ) async {
    final source = File(sourcePath);
    final name = source.uri.pathSegments.last;
    var target = File('$directory${Platform.pathSeparator}$name');

    // Already inside the export directory: nothing to copy.
    if (source.absolute.path == target.absolute.path) return;

    // Avoid clobbering an existing record with the same name.
    if (target.existsSync()) {
      final stem = name.endsWith('.json')
          ? name.substring(0, name.length - 5)
          : name;
      var suffix = 1;
      while (target.existsSync()) {
        target = File(
          '$directory${Platform.pathSeparator}${stem}_import$suffix.json',
        );
        suffix++;
      }
    }

    await source.copy(target.path);
  }
}

/// Sort options for the record list.
enum _RecordSort { timeDesc, timeAsc, durationDesc }

/// Side filter for the record list.
enum _SideFilter { all, blue, red, merged }

class _RecordList extends ConsumerStatefulWidget {
  const _RecordList({required this.exportDirectory});

  final String exportDirectory;

  @override
  ConsumerState<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends ConsumerState<_RecordList> {
  String _query = '';
  _RecordSort _sort = _RecordSort.timeDesc;
  _SideFilter _side = _SideFilter.all;
  bool _isSelecting = false;
  final Set<String> _selectedPaths = {};

  void startSelecting() {
    setState(() {
      _isSelecting = true;
      _selectedPaths.clear();
    });
  }

  void cancelSelecting() {
    setState(() {
      _isSelecting = false;
      _selectedPaths.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exportDirectory.isEmpty) {
      return const Center(child: Text('请先前往设置页选择导出目录'));
    }

    final recordsAsync = ref.watch(matchRecordsProvider);

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: recordsAsync.when(
            data: (records) => _buildList(context, _applyFilters(records)),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败: $e')),
          ),
        ),
        if (_isSelecting) _buildSelectionBar(),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索文件名 / 日期',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_SideFilter>(
                  segments: const [
                    ButtonSegment(value: _SideFilter.all, label: Text('全部')),
                    ButtonSegment(value: _SideFilter.blue, label: Text('蓝方')),
                    ButtonSegment(value: _SideFilter.red, label: Text('红方')),
                    ButtonSegment(
                      value: _SideFilter.merged,
                      label: Text('已合并'),
                    ),
                  ],
                  selected: {_side},
                  onSelectionChanged: (s) => setState(() => _side = s.first),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_RecordSort>(
                icon: const Icon(Icons.sort),
                tooltip: '排序',
                initialValue: _sort,
                onSelected: (s) => setState(() => _sort = s),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _RecordSort.timeDesc,
                    child: Text('时间（新→旧）'),
                  ),
                  PopupMenuItem(
                    value: _RecordSort.timeAsc,
                    child: Text('时间（旧→新）'),
                  ),
                  PopupMenuItem(
                    value: _RecordSort.durationDesc,
                    child: Text('时长（长→短）'),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(_isSelecting ? Icons.close : Icons.check_circle_outline),
                tooltip: _isSelecting ? '取消多选' : '多选合并',
                onPressed: () => _isSelecting ? cancelSelecting() : startSelecting(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<MatchRecord> _applyFilters(List<MatchRecord> records) {
    final list = records.where((r) {
      if (_side == _SideFilter.blue && !r.isBlue) return false;
      if (_side == _SideFilter.red && r.isBlue) return false;
      if (_side == _SideFilter.merged && !r.isMerged) return false;
      if (_query.isNotEmpty) {
        final haystack = '${r.fileName} ${r.title}'.toLowerCase();
        if (!haystack.contains(_query.toLowerCase())) return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case _RecordSort.timeDesc:
        list.sort((a, b) => b.matchTime.compareTo(a.matchTime));
      case _RecordSort.timeAsc:
        list.sort((a, b) => a.matchTime.compareTo(b.matchTime));
      case _RecordSort.durationDesc:
        list.sort(
          (a, b) => (b.duration ?? Duration.zero)
              .compareTo(a.duration ?? Duration.zero),
        );
    }
    return list;
  }

  Widget _buildList(BuildContext context, List<MatchRecord> records) {
    if (records.isEmpty) {
      return const Center(child: Text('暂无匹配记录'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: records.length,
      itemBuilder: (context, index) => _RecordTile(
        record: records[index],
        isSelecting: _isSelecting,
        isSelected: _selectedPaths.contains(records[index].filePath),
        onToggleSelected: () => setState(() {
          final path = records[index].filePath;
          if (_selectedPaths.contains(path)) {
            _selectedPaths.remove(path);
          } else {
            _selectedPaths.add(path);
          }
        }),
      ),
    );
  }

  Widget _buildSelectionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Text(
              '已选 ${_selectedPaths.length} 项',
              style: context.textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: cancelSelecting,
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.cloud_upload, size: 18),
              label: const Text('上传'),
              onPressed: _selectedPaths.isNotEmpty
                  ? () => _uploadSelected(context)
                  : null,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              icon: const Icon(Icons.merge_type, size: 18),
              label: const Text('合并'),
              onPressed: _selectedPaths.length >= 2
                  ? () => _runMerge(context)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMerge(BuildContext context) async {
    final directory = ref.read(exportDirectoryProvider);
    if (directory.isEmpty) {
      _showSnackBar(context, '请先前往设置页选择导出目录');
      return;
    }

    const merger = MatchMerger();
    final result = await merger.merge(
      filePaths: _selectedPaths.toList(),
      exportDirectory: directory,
    );

    if (!context.mounted) return;

    switch (result) {
      case MergeSuccess(:final record):
        cancelSelecting();
        ref.invalidate(matchRecordsProvider);
        _showSnackBar(context, '已合并: ${record.messageCount} 条消息');
      case MergeFailure(:final reason):
        _showSnackBar(context, '合并失败: $reason');
    }
  }

  Future<void> _uploadSelected(BuildContext context) async {
    final records = ref.read(matchRecordsProvider).valueOrNull ?? [];
    final selected = records
        .where((r) => _selectedPaths.contains(r.filePath))
        .toList();
    if (selected.isEmpty) return;

    final remote = ref.read(gitHubBackedSyncServiceProvider);
    var ok = 0;
    final failures = <String>[];
    for (final record in selected) {
      final result = await remote.uploadRecord(record);
      if (result.ok) {
        ok++;
      } else {
        failures.add('${record.fileName}: ${result.message}');
      }
    }

    if (!context.mounted) return;
    if (failures.isEmpty) {
      cancelSelecting();
      _showSnackBar(context, '已上传 $ok 个记录');
    } else {
      _showSnackBar(
        context,
        '上传 $ok 个，失败 ${failures.length} 个: ${failures.first}',
      );
    }
  }
}

class _RecordTile extends ConsumerWidget {
  const _RecordTile({
    required this.record,
    this.isSelecting = false,
    this.isSelected = false,
    this.onToggleSelected,
  });

  final MatchRecord record;
  final bool isSelecting;
  final bool isSelected;
  final VoidCallback? onToggleSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRecordProvider) == record.filePath;
    final colorScheme = Theme.of(context).colorScheme;

    return ProviderScope(
      overrides: [
        _currentRecordProvider.overrideWithValue(record),
      ],
      child: Card(
        color: selected ? colorScheme.primaryContainer : null,
        child: InkWell(
          onTap: isSelecting
              ? onToggleSelected
              : () => ref.read(selectedRecordProvider.notifier).state =
                  record.filePath,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _LeadingIcon(isSelecting: isSelecting, isSelected: isSelected),
                const SizedBox(width: 12),
                Expanded(child: _RecordInfo(record: record)),
                if (!isSelecting) const _RecordActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _currentRecordProvider = Provider<MatchRecord>((ref) {
  throw UnimplementedError('must be overridden via ProviderScope');
});

class _PreviewPanel extends ConsumerWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(selectedRecordEventsProvider);
    final summaryAsync = ref.watch(selectedRecordSummaryProvider);
    final record = summaryAsync.valueOrNull;

    if (record == null) {
      return Center(
        child: Text(
          '选择左侧记录查看关键数据',
          style: context.textTheme.bodyMedium!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MatchSummaryCard(record: record),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEventHeader(context, eventsAsync),
                    const Divider(),
                    Expanded(
                      child: eventsAsync.when(
                        data: (events) => EventTimelineView(
                          events: events,
                          matchStart: record.matchTime,
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text('预览失败: $e')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventHeader(
    BuildContext context,
    AsyncValue<List<TimedEvent>> eventsAsync,
  ) {
    final count = eventsAsync.valueOrNull?.length ?? 0;
    return Row(
      children: [
        Icon(
          Icons.timeline,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          '事件时间轴',
          style: context.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: context.textTheme.bodySmall!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

/// Key-data summary card identifying which match this record is, plus a button
/// to open the full replay screen.
class _MatchSummaryCard extends ConsumerWidget {
  const _MatchSummaryCard({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr = '${record.matchTime.year}-'
        '${_two(record.matchTime.month)}-${_two(record.matchTime.day)} '
        '${record.timeLabel}';
    final selectedRobotId = ref.watch(selectedRobotIdProvider);
    final identity = allRobotIdentities
        .where((r) => r.id == selectedRobotId)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style: context.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CompletenessChip(isComplete: record.isComplete),
              ],
            ),
            const SizedBox(height: 8),
            _IdentityChip(identity: identity, robotId: selectedRobotId),
            const SizedBox(height: 12),
            _ScoreRow(record: record),
            const SizedBox(height: 12),
            _StatChips(record: record),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('进入回放'),
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReplayScreen(record: record),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _two(int n) => n >= 10 ? '$n' : '0$n';
}

class _CompletenessChip extends StatelessWidget {
  const _CompletenessChip({required this.isComplete});

  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isComplete ? '完整' : '未录到结算',
            style: context.textTheme.bodySmall!.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.identity, required this.robotId});

  final RobotIdentity? identity;
  final int robotId;

  @override
  Widget build(BuildContext context) {
    final color = identity?.sideColor ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBlueSide(robotId) ? Icons.shield_moon : Icons.shield,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            identity?.displayName ?? '未知身份 ($robotId)',
            style: context.textTheme.bodySmall!.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    if (!record.hasScore) {
      return Text(
        '无终局比分',
        style: context.textTheme.bodyMedium!.copyWith(
          color: rmTextSecondary(context),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${record.blueScore}',
          style: context.textTheme.displaySmall!.copyWith(
            fontWeight: FontWeight.bold,
            color: rmBlueTeamColor,
          ),
        ),
        Padding(
          padding: context.insetSym(h: 8),
          child: Text(
            ':',
            style: context.textTheme.headlineMedium,
          ),
        ),
        Text(
          '${record.redScore}',
          style: context.textTheme.displaySmall!.copyWith(
            fontWeight: FontWeight.bold,
            color: rmRedTeamColor,
          ),
        ),
        context.sizedBox(w: 12),
        Padding(
          padding: context.insetOnly(b: 6),
          child: Text(
            '蓝 : 红',
            style: context.textTheme.bodySmall!.copyWith(
              color: rmTextSecondary(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChips extends StatelessWidget {
  const _StatChips({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.timer_outlined,
          label: '时长 ${record.durationLabel}',
        ),
        _StatChip(
          icon: record.isBlue ? Icons.shield_moon : Icons.shield,
          label: '录制方 ${record.isBlue ? '蓝方' : '红方'}',
        ),
        _StatChip(
          icon: Icons.bolt,
          label: '事件 ${record.eventCount}',
        ),
        _StatChip(
          icon: Icons.dataset_outlined,
          label: '消息 ${record.messageCount}',
        ),
        _StatChip(
          icon: Icons.sd_storage_outlined,
          label: record.fileSizeLabel,
        ),
      ],
    );
  }
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.isSelecting, required this.isSelected});

  final bool isSelecting;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isSelecting) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Icon(
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isSelected ? colorScheme.primary : Colors.grey,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _RecordInfo extends StatelessWidget {
  const _RecordInfo({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                record.title,
                style: context.textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (record.isMerged) ...[
              const _MergedBadge(),
              const SizedBox(width: 6),
            ],
            if (!record.isComplete)
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: Colors.orange.shade700,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${record.timeLabel} · ${record.durationLabel} · '
          '事件 ${record.eventCount} · ${record.fileSizeLabel}',
          style: context.textTheme.bodySmall!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
      ],
    );
  }
}

class _RecordActions extends ConsumerWidget {
  const _RecordActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(_currentRecordProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.folder_open, size: 20),
          tooltip: '在文件管理器中显示',
          onPressed: () => _reveal(context, record),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: '删除',
          onPressed: () => _delete(context, ref, record),
        ),
      ],
    );
  }

  Future<void> _reveal(BuildContext context, MatchRecord record) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,${record.filePath}']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', record.filePath]);
      } else if (Platform.isLinux) {
        final dir = record.filePath.substring(
          0,
          record.filePath.lastIndexOf(Platform.pathSeparator),
        );
        await Process.run('xdg-open', [dir]);
      } else if (context.mounted) {
        _showSnackBar(context, record.filePath);
      }
    } on Exception catch (e) {
      if (context.mounted) _showSnackBar(context, '无法打开文件管理器: $e');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MatchRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确认删除 ${record.fileName} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await File(record.filePath).delete();
      ref.invalidate(matchRecordsProvider);
      if (ref.read(selectedRecordProvider) == record.filePath) {
        ref.read(selectedRecordProvider.notifier).state = null;
      }
      if (context.mounted) {
        _showSnackBar(context, '已删除 ${record.fileName}');
      }
    } on Exception catch (e) {
      if (context.mounted) {
        _showSnackBar(context, '删除失败: $e');
      }
    }
  }
}

/// A compact "已合并" badge shown on merged record tiles.
class _MergedBadge extends StatelessWidget {
  const _MergedBadge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.merge_type, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '已合并',
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

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: rmTrackFill(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: rmTextSecondary(context)),
          const SizedBox(width: 5),
          Text(label, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  // Route through the unified messenger; failure phrasing gets the error style.
  const errorMarkers = ['失败', '无法', '错误'];
  if (errorMarkers.any(message.contains)) {
    context.showErrorSnack(message);
  } else {
    context.showInfoSnack(message);
  }
}
