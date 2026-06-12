/// JSON exporter for recorded MQTT messages.
///
/// Produces a JSON file with schema version, metadata and a flat array of
/// Protobuf messages encoded via [GeneratedMessage.toProto3Json].
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:protobuf/protobuf.dart';

import '../domain/data_recorder.dart';

/// Current export schema version.
const String _schemaVersion = '2.0';

/// Application version written into every export file.
const String _appVersion = '0.1.0+1';

/// Exports [DataRecorderState] to a JSON file under [exportDirectory].
///
/// The file name follows the convention:
/// `rm_export_{robotId}_{yyyyMMdd_HHmmss}.json`
/// where the timestamp is derived from [matchStartTime] or the current time.
class JsonExporter {
  /// Creates a [JsonExporter].
  JsonExporter({
    required this.robotId,
    required this.exportDirectory,
    this.matchStartTime,
  });

  /// Robot identity that recorded this data (protocol id).
  final int robotId;

  /// Target directory path (must be writable).
  final String exportDirectory;

  /// Match start time used for file naming; falls back to now.
  final DateTime? matchStartTime;

  /// Writes the export file and returns the absolute path.
  ///
  /// Throws [StateError] if [exportDirectory] is empty.
  /// Throws [FileSystemException] if writing fails.
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
