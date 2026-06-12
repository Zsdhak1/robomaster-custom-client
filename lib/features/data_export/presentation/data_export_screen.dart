/// Data export management screen.
///
/// Left side lists saved JSON match records; right side previews the selected
/// record's event timeline.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigation_drawer.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../connection/domain/robot_identity.dart';
import '../../dashboard/logic/game_state.dart';
import '../../dashboard/logic/stream_providers.dart';
import '../../dashboard/presentation/app_navigation.dart';
import '../../dashboard/presentation/widgets/event_timeline_panel.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/json_exporter.dart';
import '../domain/match_record.dart';
import '../logic/data_export_providers.dart';
import '../logic/data_import_provider.dart';
import '../logic/data_recorder_provider.dart';
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
      drawer: AppNavigationDrawer(
        current: AppDestination.data,
        onSelect: (dest) => navigateToDestination(context, dest),
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: '菜单',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('记录管理'),
        actions: [
          _RecordingIndicator(isRecording: recorder.isRecording),
          const _ExportButton(),
          IconButton(
            icon: const Icon(Icons.cloud_sync_outlined),
            tooltip: '同步',
            onPressed: () => ref.invalidate(matchRecordsProvider),
          ),
          const _ImportButton(),
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
            style: TextStyle(
              fontSize: 13,
              color: isRecording ? Colors.red : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _ExportButton extends ConsumerWidget {
  const _ExportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.upload_file),
      tooltip: '导出当前记录',
      onPressed: () => _export(context, ref),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
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
}

class _ImportButton extends ConsumerWidget {
  const _ImportButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.download),
      tooltip: '导入 JSON',
      onPressed: () => _import(context, ref),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final file = await openFile(acceptedTypeGroups: const [_jsonTypeGroup]);
    if (file == null) return;

    final importer = ref.read(jsonImporterProvider);
    try {
      final envelopes = await importer.import(file.path);
      ref.read(gameStateProvider.notifier).replayEnvelopes(envelopes);
      if (context.mounted) {
        _showSnackBar(context, '已导入 ${envelopes.length} 条消息');
      }
    } on Exception catch (e) {
      if (context.mounted) {
        _showSnackBar(context, '导入失败: $e');
      }
    }
  }
}

/// Sort options for the record list.
enum _RecordSort { timeDesc, timeAsc, durationDesc }

/// Side filter for the record list.
enum _SideFilter { all, blue, red }

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
      itemBuilder: (context, index) => _RecordTile(record: records[index]),
    );
  }
}

class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRecordProvider) == record.filePath;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: selected ? colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => ref.read(selectedRecordProvider.notifier).state =
            record.filePath,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                isBlueSide(record.robotId)
                    ? Icons.shield_moon
                    : Icons.shield,
                color: teamAccentColor(record.robotId),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.folder_open, size: 20),
                tooltip: '在文件管理器中显示',
                onPressed: () => _reveal(context),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: '删除',
                onPressed: () => _delete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reveal(BuildContext context) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,${record.filePath}']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', record.filePath]);
      } else if (Platform.isLinux) {
        // Most Linux file managers cannot select a file; open the directory.
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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
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

class _PreviewPanel extends ConsumerWidget {
  const _PreviewPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(selectedRecordEventsProvider);
    final summaryAsync = ref.watch(selectedRecordSummaryProvider);
    final record = summaryAsync.valueOrNull;

    if (record == null) {
      return const Center(
        child: Text('选择左侧记录查看关键数据', style: TextStyle(color: Colors.grey)),
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
        const Text(
          '事件时间轴',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

/// Key-data summary card identifying which match this record is, plus a button
/// to open the full replay screen.
class _MatchSummaryCard extends StatelessWidget {
  const _MatchSummaryCard({required this.record});

  final MatchRecord record;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr = '${record.matchTime.year}-'
        '${_two(record.matchTime.month)}-${_two(record.matchTime.day)} '
        '${record.timeLabel}';

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
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _CompletenessChip(isComplete: record.isComplete),
              ],
            ),
            const SizedBox(height: 12),
            // Final score, large.
            if (record.hasScore)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${record.blueScore}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: rmBlueTeamColor,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(':', style: TextStyle(fontSize: 28)),
                  ),
                  Text(
                    '${record.redScore}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: rmRedTeamColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '蓝 : 红',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              )
            else
              Text('无终局比分', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            // Stat chips.
            Wrap(
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
            ),
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
            style: TextStyle(
              fontSize: 12,
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
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
