/// 扫描导出目录中已保存的 JSON 比赛记录。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/match_record.dart';

/// 扫描 [exportDirectory] 下的 JSON 导出文件，并解析数据管理列表需要的轻量摘要。
class MatchRecordScanner {
  /// 创建 [MatchRecordScanner]。
  MatchRecordScanner({required this.exportDirectory});

  /// 用于扫描 `*.json` 文件的目录。
  final String exportDirectory;

  /// 返回按比赛时间倒序排列的 [MatchRecord] 列表。
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
      // 在后台 isolate 解析 JSON，避免数 MB 级比赛记录阻塞 UI 线程。
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

/// 传给 isolate 友好的 [parseMatchSummary] 的输入数据包。
class ScanInput {
  /// 创建 [ScanInput]。
  const ScanInput({
    required this.text,
    required this.path,
    required this.sizeBytes,
  });

  /// 原始 JSON 文件内容。
  final String text;

  /// 绝对文件路径。
  final String path;

  /// 文件大小，单位为字节。
  final int sizeBytes;
}

/// 将单个导出文件的 JSON [text] 解析为 [MatchRecord] 摘要。
///
/// 该函数是顶层纯函数，不依赖实例状态，因此可以通过 [compute] 放入 isolate 执行。
/// 任意结构错误都会返回 null。
MatchRecord? parseMatchSummary(ScanInput input) {
  try {
    final json = jsonDecode(input.text) as Map<String, dynamic>;
    final metadata = json['metadata'] as Map<String, dynamic>?;
    final messages = json['messages'] as List<dynamic>? ?? [];

    final isMerged = metadata?['merged'] == true;

    // 合并记录会携带 robot_id 0，表示没有单一来源机器人。
    // 这里根据 side 元数据派生一个代表性 ID，让阵营筛选仍能正确分类。
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

/// 是否有任意 GameStatus 消息进入结算阶段（5）。
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
