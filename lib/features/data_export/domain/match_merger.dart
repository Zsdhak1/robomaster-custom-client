/// 将多个客户端比赛记录合并为一份完整比赛数据集的领域模型和算法。
///
/// 合并遵循 [TopicScope]：
/// - [TopicScope.teamShared] 主题会广播给同阵营所有客户端；合并时取并集，并按
///   （主题，时间戳，载荷）去重。
/// - [TopicScope.robotPrivate] 主题只会被绑定到对应机器人 ID 的客户端接收；合并时按
///   机器人 ID 重组逐机器人流。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/constants/topic_registry.dart';

/// 一次合并尝试的结果。
sealed class MergeResult {
  /// 创建 [MergeResult]。
  const MergeResult();
}

/// 合并成功；[record] 描述生成的文件。
final class MergeSuccess extends MergeResult {
  /// 创建 [MergeSuccess]。
  const MergeSuccess({required this.record});

  /// 已写入磁盘的合并记录摘要。
  final MergedMatchRecord record;
}

/// 合并失败，通常因为所选文件无法代表同一场比赛。
final class MergeFailure extends MergeResult {
  /// 创建 [MergeFailure]。
  const MergeFailure({required this.reason});

  /// 合并被拒绝的可读原因。
  final String reason;
}

/// 合并记录文件的轻量摘要。
class MergedMatchRecord {
  /// 创建 [MergedMatchRecord]。
  const MergedMatchRecord({
    required this.filePath,
    required this.matchTime,
    required this.robotIds,
    required this.messageCount,
  });

  /// 已合并 JSON 文件的绝对路径。
  final String filePath;

  /// 从源文件推导出的比赛开始时间（UTC）。
  final DateTime matchTime;

  /// 贡献私有遥测的机器人 ID。
  final List<int> robotIds;

  /// 去重和重组后的消息总数。
  final int messageCount;
}

/// 将多份已导出的 JSON 比赛记录合并为一份完整记录。
///
/// 文件必须描述同一场比赛。判定启发式要求：
/// - 比赛开始时间差在 [maxTimeDelta] 内
/// - 如果存在比分，蓝方和红方比分必须一致
/// - 所有机器人必须属于同一阵营（全蓝方或全红方）
class MatchMerger {
  /// 创建 [MatchMerger]。
  const MatchMerger({
    this.maxTimeDelta = const Duration(seconds: 30),
  });

  /// 源文件比赛开始时间之间允许的最大差值。
  final Duration maxTimeDelta;

  /// 校验 [filePaths] 是否可合并，并执行合并。
  ///
  /// 合并后的 JSON 会写入 [exportDirectory]，命名约定为
  /// `rm_merged_{side}_{yyyyMMdd_HHmmss}.json`。
  Future<MergeResult> merge({
    required List<String> filePaths,
    required String exportDirectory,
  }) async {
    if (filePaths.length < 2) {
      return const MergeFailure(reason: '请至少选择 2 个记录进行合并');
    }

    final sources = <_SourceRecord>[];
    for (final path in filePaths) {
      final source = await _loadSource(path);
      if (source == null) {
        return MergeFailure(reason: '无法解析文件: $path');
      }
      sources.add(source);
    }

    final validation = _validateSameMatch(sources);
    if (validation != null) return validation;

    final merged = _mergeMessages(sources);
    final filePath = await _writeMergedFile(
      exportDirectory: exportDirectory,
      sources: sources,
      mergedMessages: merged,
    );

    return MergeSuccess(
      record: MergedMatchRecord(
        filePath: filePath,
        matchTime: sources.first.matchTime.toUtc(),
        robotIds: sources.map((s) => s.robotId).toSet().toList()..sort(),
        messageCount: merged.length,
      ),
    );
  }

  Future<_SourceRecord?> _loadSource(String path) async {
    try {
      final file = File(path);
      final text = await file.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      final metadata = json['metadata'] as Map<String, dynamic>?;
      final robotId = (metadata?['robot_id'] as num?)?.toInt() ?? 0;
      final matchStartStr = metadata?['match_start_time'] as String?;
      final matchTime = matchStartStr != null
          ? DateTime.tryParse(matchStartStr) ?? DateTime.now()
          : DateTime.now();
      final messages = (json['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final scores = _extractScores(messages);
      return _SourceRecord(
        filePath: path,
        robotId: robotId,
        matchTime: matchTime,
        messages: messages,
        blueScore: scores.$1,
        redScore: scores.$2,
      );
    } on Exception {
      return null;
    }
  }

  MergeFailure? _validateSameMatch(List<_SourceRecord> sources) {
    final first = sources.first;

    // 所有机器人必须属于同一阵营。
    final sides = sources.map((s) => _sideOf(s.robotId)).toSet();
    if (sides.length != 1) {
      return const MergeFailure(reason: '只能合并同一阵营的记录（红方或蓝方）');
    }

    // 比赛开始时间必须足够接近。
    for (final source in sources.skip(1)) {
      final delta = source.matchTime.difference(first.matchTime).abs();
      if (delta > maxTimeDelta) {
        return const MergeFailure(
          reason: '比赛开始时间相差过大，请确认是同一场比赛',
        );
      }
    }

    // 存在比分时必须一致。
    int? consensusBlue;
    int? consensusRed;
    for (final source in sources) {
      if (source.blueScore != null) {
        if (consensusBlue == null) {
          consensusBlue = source.blueScore;
        } else if (consensusBlue != source.blueScore) {
          return const MergeFailure(reason: '蓝方比分不一致，无法合并');
        }
      }
      if (source.redScore != null) {
        if (consensusRed == null) {
          consensusRed = source.redScore;
        } else if (consensusRed != source.redScore) {
          return const MergeFailure(reason: '红方比分不一致，无法合并');
        }
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _mergeMessages(List<_SourceRecord> sources) {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    for (final source in sources) {
      for (final msg in source.messages) {
        final topic = msg['topic'] as String?;
        if (topic == null) continue;

        final scope = TopicRegistry.byName[topic]?.scope;
        if (scope == TopicScope.command) continue;

        final robotId = _messageRobotId(msg) ?? source.robotId;
        final key = _dedupKey(topic: topic, msg: msg, robotId: robotId);

        if (seen.add(key)) {
          merged.add(msg);
        }
      }
    }

    merged.sort(
      (a, b) {
        final ta = _parseTimestamp(a['timestamp'] as String?);
        final tb = _parseTimestamp(b['timestamp'] as String?);
        return ta.compareTo(tb);
      },
    );
    return merged;
  }

  String _dedupKey({
    required String topic,
    required Map<String, dynamic> msg,
    required int robotId,
  }) {
    final timestamp = msg['timestamp'] as String? ?? '';
    final payload = msg['payload'];
    final payloadKey = _stablePayloadKey(payload);

    final scope = TopicRegistry.byName[topic]?.scope;
    if (scope == TopicScope.robotPrivate) {
      return '$topic|$timestamp|$robotId|$payloadKey';
    }
    return '$topic|$timestamp|$payloadKey';
  }

  /// 为载荷构建稳定字符串键，同时不修改原始对象。
  ///
  /// 载荷不是 JSON 对象时，回退到原始字符串表示。
  String _stablePayloadKey(Object? payload) {
    if (payload is Map<String, dynamic>) {
      // 复制后再移除 raw-byte 降级字段，避免影响将写入合并输出的原消息。
      final copy = Map<String, dynamic>.of(payload)..remove('raw_base64');
      return const JsonEncoder().convert(copy);
    }
    if (payload is List<dynamic>) {
      return const JsonEncoder().convert(payload);
    }
    return payload.toString();
  }

  int? _messageRobotId(Map<String, dynamic> msg) {
    final payload = msg['payload'];
    if (payload is! Map<String, dynamic>) return null;

    // Protobuf JSON 对 Dart proto 字段使用 lowerCamelCase。
    final id = payload['robotId'] ?? payload['senderId'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    return null;
  }

  DateTime _parseTimestamp(String? value) {
    return value != null ? DateTime.tryParse(value) ?? DateTime(0) : DateTime(0);
  }

  Future<String> _writeMergedFile({
    required String exportDirectory,
    required List<_SourceRecord> sources,
    required List<Map<String, dynamic>> mergedMessages,
  }) async {
    final side = _sideOf(sources.first.robotId) == _Side.blue ? 'blue' : 'red';
    final timeStr = _formatDateTime(sources.first.matchTime.toLocal());
    final fileName = 'rm_merged_${side}_$timeStr.json';
    final filePath = p.join(exportDirectory, fileName);

    final scores = _consensusScores(sources);
    final durations = sources
        .map((s) => _extractDuration(s.messages))
        .whereType<int>()
        .toList();
    final maxDuration = durations.isEmpty ? null : durations.reduce((a, b) => a > b ? a : b);

    final jsonData = {
      'schema_version': '2.0',
      'export_time': DateTime.now().toUtc().toIso8601String(),
      'metadata': {
        'robot_id': 0,
        'match_start_time': sources.first.matchTime.toUtc().toIso8601String(),
        'duration_seconds': maxDuration,
        'message_count': mergedMessages.length,
        'merged_from': sources.map((s) => p.basename(s.filePath)).toList(),
        'source_robot_ids': sources.map((s) => s.robotId).toList(),
        'merged': true,
        'side': side,
        if (scores.$1 != null) 'blue_score': scores.$1,
        if (scores.$2 != null) 'red_score': scores.$2,
      },
      'messages': mergedMessages,
    };

    await File(filePath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(jsonData),
    );
    return filePath;
  }

  (int?, int?) _consensusScores(List<_SourceRecord> sources) {
    int? blue;
    int? red;
    for (final source in sources) {
      if (blue == null && source.blueScore != null) blue = source.blueScore;
      if (red == null && source.redScore != null) red = source.redScore;
    }
    return (blue, red);
  }

  int? _extractDuration(List<Map<String, dynamic>> messages) {
    for (final msg in messages.reversed) {
      if (msg['type'] != 'GameStatus') continue;
      final payload = msg['payload'] as Map<String, dynamic>?;
      final elapsed = (payload?['stageElapsedSec'] as num?)?.toInt();
      if (elapsed != null && elapsed > 0) return elapsed;
    }
    return null;
  }

  (int?, int?) _extractScores(List<Map<String, dynamic>> messages) {
    int? red;
    int? blue;
    for (final msg in messages.reversed) {
      if (msg['type'] != 'GameStatus') continue;
      final payload = msg['payload'] as Map<String, dynamic>?;
      red ??= (payload?['redScore'] as num?)?.toInt();
      blue ??= (payload?['blueScore'] as num?)?.toInt();
      if (red != null && blue != null) break;
    }
    return (blue, red);
  }

  _Side _sideOf(int robotId) =>
      robotId >= 100 ? _Side.blue : _Side.red;

  String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final sb = StringBuffer()
      ..write(d.year)
      ..write(_two(d.month))
      ..write(_two(d.day))
      ..write('_')
      ..write(_two(d.hour))
      ..write(_two(d.minute))
      ..write(_two(d.second));
    return sb.toString();
  }

  static String _two(int n) => n >= 10 ? '$n' : '0$n';
}

enum _Side { blue, red }

class _SourceRecord {
  const _SourceRecord({
    required this.filePath,
    required this.robotId,
    required this.matchTime,
    required this.messages,
    this.blueScore,
    this.redScore,
  });

  final String filePath;
  final int robotId;
  final DateTime matchTime;
  final List<Map<String, dynamic>> messages;
  final int? blueScore;
  final int? redScore;
}
