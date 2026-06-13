/// Scanner that enumerates saved JSON match records in the export directory.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/match_record.dart';

/// Scans [exportDirectory] for JSON export files and parses lightweight
/// summaries for the data management list view.
class MatchRecordScanner {
  /// Creates a [MatchRecordScanner].
  MatchRecordScanner({required this.exportDirectory});

  /// Directory to scan for `*.json` files.
  final String exportDirectory;

  /// Returns parsed [MatchRecord]s sorted by match time (newest first).
  Future<List<MatchRecord>> scan() async {
    if (exportDirectory.isEmpty) return [];

    final dir = Directory(exportDirectory);
    if (!await dir.exists()) return [];

    final records = <MatchRecord>[];
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.toLowerCase().endsWith('.json')) continue;

      final record = await _parseFile(entity);
      if (record != null) records.add(record);
    }

    records.sort((a, b) => b.matchTime.compareTo(a.matchTime));
    return records;
  }

  Future<MatchRecord?> _parseFile(File file) async {
    try {
      final text = await file.readAsString();
      final size = await file.length();
      // Parse JSON off the UI thread; long matches can be several MB.
      final summary = await compute(
        parseMatchSummary,
        ScanInput(text: text, path: file.path, sizeBytes: size),
      );
      return summary;
    } on Exception {
      return null;
    }
  }
}

/// Input bundle for the isolate-friendly [parseMatchSummary].
class ScanInput {
  /// Creates a [ScanInput].
  const ScanInput({
    required this.text,
    required this.path,
    required this.sizeBytes,
  });

  /// Raw JSON file contents.
  final String text;

  /// Absolute file path.
  final String path;

  /// File size in bytes.
  final int sizeBytes;
}

/// Parses a single export file's JSON [text] into a [MatchRecord] summary.
///
/// Top-level and isolate-safe (no instance state) so it can run via
/// [compute]. Returns null on any structural error.
MatchRecord? parseMatchSummary(ScanInput input) {
  try {
    final json = jsonDecode(input.text) as Map<String, dynamic>;
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final messages = json['messages'] as List<dynamic>? ?? [];

    final isMerged = metadata?['merged'] == true;

    // Merged files carry robot_id 0 (no single owner). Derive a representative
    // side from the `side` metadata so the team filter classifies them.
    var robotId = (metadata?['robot_id'] as num?)?.toInt() ?? 0;
    if (isMerged && robotId == 0) {
      robotId = metadata?['side'] == 'blue' ? 100 : 1;
    }

    final messageCount = (metadata?['message_count'] as num?)?.toInt() ??
        messages.length;

    final matchStartStr = metadata?['match_start_time'] as String?;
    final matchTime = matchStartStr != null
        ? DateTime.tryParse(matchStartStr) ?? DateTime.now()
        : _firstMessageTime(messages);

    final durationSec = (metadata?['duration_seconds'] as num?)?.toInt();

    final scores = _extractScores(messages);
    final typeCounts = _countTypes(messages);
    final isComplete = _reachedSettlement(messages);

    return MatchRecord(
      filePath: input.path,
      fileName: input.path.split(Platform.pathSeparator).last,
      matchTime: matchTime,
      robotId: robotId,
      messageCount: messageCount,
      redScore: scores.$1,
      blueScore: scores.$2,
      duration: durationSec != null ? Duration(seconds: durationSec) : null,
      isComplete: isComplete,
      isMerged: isMerged,
      fileSizeBytes: input.sizeBytes,
      eventCount: typeCounts['Event'] ?? 0,
      typeCounts: typeCounts,
    );
  } on Object {
    return null;
  }
}

DateTime _firstMessageTime(List<dynamic> messages) {
  for (final msg in messages) {
    if (msg is! Map<String, dynamic>) continue;
    final ts = msg['timestamp'] as String?;
    final parsed = ts != null ? DateTime.tryParse(ts) : null;
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

(int?, int?) _extractScores(List<dynamic> messages) {
  int? redScore;
  int? blueScore;

  for (final msg in messages.reversed) {
    if (msg is! Map<String, dynamic>) continue;
    if (msg['type'] != 'GameStatus') continue;

    final payload = msg['payload'] as Map<String, dynamic>?;
    if (payload == null) continue;

    redScore ??= (payload['redScore'] as num?)?.toInt();
    blueScore ??= (payload['blueScore'] as num?)?.toInt();
    if (redScore != null && blueScore != null) break;
  }

  return (redScore, blueScore);
}

Map<String, int> _countTypes(List<dynamic> messages) {
  final counts = <String, int>{};
  for (final msg in messages) {
    if (msg is! Map<String, dynamic>) continue;
    final type = msg['type'] as String?;
    if (type == null) continue;
    counts[type] = (counts[type] ?? 0) + 1;
  }
  return counts;
}

/// Whether any GameStatus message reached the settlement stage (5).
bool _reachedSettlement(List<dynamic> messages) {
  for (final msg in messages.reversed) {
    if (msg is! Map<String, dynamic>) continue;
    if (msg['type'] != 'GameStatus') continue;
    final payload = msg['payload'] as Map<String, dynamic>?;
    final stage = (payload?['currentStage'] as num?)?.toInt();
    if (stage == 5) return true;
  }
  return false;
}
