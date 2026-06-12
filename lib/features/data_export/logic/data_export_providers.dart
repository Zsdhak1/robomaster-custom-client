/// Riverpod providers for the data export screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/robomaster_custom_client.pb.dart';
import '../../dashboard/logic/game_state.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/match_record_scanner.dart';
import '../domain/match_record.dart';
import 'data_import_provider.dart';

/// Scans the configured export directory and returns saved [MatchRecord]s.
///
/// Refresh this provider after export/import/delete to update the list.
final matchRecordsProvider = FutureProvider<List<MatchRecord>>((ref) async {
  final directory = ref.watch(exportDirectoryProvider);
  final scanner = MatchRecordScanner(exportDirectory: directory);
  return scanner.scan();
});

/// Path of the currently selected record for the right-side preview.
final selectedRecordProvider = StateProvider<String?>((ref) => null);

/// Events extracted from the currently selected record.
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

/// Summary of the currently selected record.
final selectedRecordSummaryProvider = Provider<AsyncValue<MatchRecord?>>((ref) {
  final path = ref.watch(selectedRecordProvider);
  final recordsAsync = ref.watch(matchRecordsProvider);
  return recordsAsync.whenData(
    (records) => records.where((r) => r.filePath == path).firstOrNull,
  );
});
