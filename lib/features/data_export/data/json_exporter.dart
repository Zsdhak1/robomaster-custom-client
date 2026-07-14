/// 已记录 MQTT 消息的 JSON 导出器。
///
/// 生成包含 Schema 版本、元数据和 Protobuf 消息扁平数组的 JSON 文件。
/// Protobuf 消息通过 [GeneratedMessage.toProto3Json] 编码。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protobuf/protobuf.dart';

import '../domain/data_recorder.dart';

/// 当前导出 Schema 版本。
const String _schemaVersion = '2.0';

/// 写入每个导出文件的应用版本。
const String _appVersion = '0.1.0+1';

/// 将 [DataRecorderState] 导出到 [exportDirectory] 中的 JSON 文件。
///
/// 文件名遵循约定：
/// `rm_export_{robotId}_{yyyyMMdd_HHmmss}.json`
/// 其中时间戳来自 [matchStartTime]，没有时使用当前时间。
class JsonExporter {
  /// 创建 [JsonExporter]。
  JsonExporter({
    required this.robotId,
    required this.exportDirectory,
    this.matchStartTime,
  });

  /// 记录该数据的机器人身份（协议 ID）。
  final int robotId;

  /// 目标目录路径，必须可写。
  final String exportDirectory;

  /// 用于文件命名的比赛开始时间；没有时回退到当前时间。
  final DateTime? matchStartTime;

  /// 写入导出文件，并返回其绝对路径。
  ///
  /// [exportDirectory] 为空时抛出 [StateError]。
  /// 写入失败时抛出 [FileSystemException]。
  Future<String> export(DataRecorderState state) async {
    if (exportDirectory.isEmpty) {
      throw StateError('导出目录未设置');
    }

    final fileName = _buildFileName();
    final filePath = p.join(exportDirectory, fileName);
    final file = File(filePath);

    final jsonData = _buildExportMap(state);
    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonData);

    await file.writeAsString(jsonString);
    return filePath;
  }

  String _buildFileName() {
    final time = matchStartTime ?? DateTime.now();
    final timeStr = _formatDateTime(time);
    return 'rm_export_${robotId}_$timeStr.json';
  }

  Map<String, dynamic> _buildExportMap(DataRecorderState state) {
    return {
      'schema_version': _schemaVersion,
      'export_time': DateTime.now().toUtc().toIso8601String(),
      'app_version': _appVersion,
      'metadata': {
        'robot_id': robotId,
        'match_start_time': matchStartTime?.toUtc().toIso8601String(),
        'duration_seconds': state.duration?.inSeconds,
        'message_count': state.totalCount,
        'bucket_count': state.buckets.length,
      },
      'messages': _flattenMessages(state),
    };
  }

  List<Map<String, dynamic>> _flattenMessages(DataRecorderState state) {
    final all = <RecordedMessage>[];
    for (final bucket in state.buckets.values) {
      all.addAll(bucket);
    }
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return all.map(_messageToJson).toList();
  }

  Map<String, dynamic> _messageToJson(RecordedMessage msg) {
    final Object payload = msg.protobufMessage?.toProto3Json() ?? {
      'raw_base64': base64Encode(msg.rawBytes),
    };
    return {
      'timestamp': msg.timestamp.toUtc().toIso8601String(),
      'topic': msg.topic,
      'type': msg.messageType,
      'payload': payload,
    };
  }

  static String _formatDateTime(DateTime dt) {
    final d = dt.toLocal();
    final sb = StringBuffer()
      ..write(d.year)
      ..write(_twoDigits(d.month))
      ..write(_twoDigits(d.day))
      ..write('_')
      ..write(_twoDigits(d.hour))
      ..write(_twoDigits(d.minute))
      ..write(_twoDigits(d.second));
    return sb.toString();
  }

  static String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
