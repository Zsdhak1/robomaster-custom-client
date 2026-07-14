/// 数据导出页面使用的 Riverpod Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/robomaster_custom_client.pb.dart';
import '../../dashboard/logic/game_state.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/match_record_scanner.dart';
import '../domain/match_record.dart';
import 'data_import_provider.dart';

/// 扫描已配置的导出目录，并返回保存的 [MatchRecord] 列表。
///
/// 导出、导入或删除后刷新此 Provider，即可更新列表。
final matchRecordsProvider = FutureProvider<List<MatchRecord>>((ref) async {
  final directory = ref.watch(exportDirectoryProvider);
  final scanner = MatchRecordScanner(exportDirectory: directory);
  return scanner.scan();
});

/// 右侧预览面板当前选中记录的路径。
final selectedRecordProvider = StateProvider<String?>((ref) => null);

/// 从当前选中记录中提取的事件。
final selectedRecordEventsProvider = FutureProvider<List<TimedEvent>>((ref) async {
  final path = ref.watch(selectedRecordProvider);
  if (path == null) return [];

  final importer = ref.watch(jsonImporterProvider);
  final envelopes = await importer.import(path);

  final events = <TimedEvent>[];
  for (final envelope in envelopes) {
    final msg = envelope.protobufMessage;
    if (msg is Event) {
      events.add(TimedEvent(event: msg, timestamp: envelope.timestamp));
    }
  }

  events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return events;
});

/// 当前选中记录的摘要。
final selectedRecordSummaryProvider = Provider<AsyncValue<MatchRecord?>>((ref) {
  final path = ref.watch(selectedRecordProvider);
  final recordsAsync = ref.watch(matchRecordsProvider);
  return recordsAsync.whenData(
    (records) => records.where((r) => r.filePath == path).firstOrNull,
  );
});
