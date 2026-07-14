/// 将远程记录文件名解析为可展示的元数据。
///
/// 远程文件遵循导出和合并记录的命名约定：
/// - `rm_export_{robotId}_{yyyyMMdd_HHmmss}.json`
/// - `rm_merged_{red|blue}_{yyyyMMdd_HHmmss}.json`
///
/// 只解析文件名而不下载每个文件，使远程列表保持轻量，同时让 UI 能展示日期、
/// 阵营、机器人 ID，并按这些字段筛选。
library;

import '../../connection/domain/robot_identity.dart';

/// 记录所属阵营。
enum RecordSide {
  /// 红方阵营（协议机器人 ID < 100）。
  red,

  /// 蓝方阵营（协议机器人 ID >= 100）。
  blue,

  /// 无法从文件名判断阵营。
  unknown,
}

/// 文件对应的记录类型。
enum RecordKind {
  /// 单机器人导出记录（`rm_export_...`）。
  export,

  /// 多来源合并记录（`rm_merged_...`）。
  merged,

  /// 文件名不匹配任何已知模式。
  unknown,
}

/// 从远程记录文件名解码出的元数据。
class RemoteRecordMeta {
  /// 创建 [RemoteRecordMeta]。
  const RemoteRecordMeta({
    required this.fileName,
    this.date,
    this.side = RecordSide.unknown,
    this.robotId,
    this.kind = RecordKind.unknown,
  });

  /// 原始文件名，用于下载请求和降级展示标签。
  final String fileName;

  /// 从文件名解码出的本地采集时间；无法解析时为 null。
  final DateTime? date;

  /// 从机器人 ID 或合并记录阵营标记推断出的阵营。
  final RecordSide side;

  /// 导出记录对应的机器人 ID；合并记录或未知记录为 null。
  final int? robotId;

  /// 记录类型。
  final RecordKind kind;

  static final RegExp _exportPattern =
      RegExp(r'^rm_export_(\d+)_(\d{8})_(\d{6})$');
  static final RegExp _mergedPattern =
      RegExp(r'^rm_merged_(red|blue)_(\d{8})_(\d{6})$');

  /// 将 [fileName] 解码为 [RemoteRecordMeta]。
  factory RemoteRecordMeta.parse(String fileName) {
    final base = fileName.endsWith('.json')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;

    final export = _exportPattern.firstMatch(base);
    if (export != null) {
      final robotId = int.tryParse(export.group(1)!);
      return RemoteRecordMeta(
        fileName: fileName,
        date: _parseDateTime(export.group(2)!, export.group(3)!),
        side: robotId != null && isBlueSide(robotId)
            ? RecordSide.blue
            : RecordSide.red,
        robotId: robotId,
        kind: RecordKind.export,
      );
    }

    final merged = _mergedPattern.firstMatch(base);
    if (merged != null) {
      return RemoteRecordMeta(
        fileName: fileName,
        date: _parseDateTime(merged.group(2)!, merged.group(3)!),
        side: merged.group(1) == 'blue' ? RecordSide.blue : RecordSide.red,
        kind: RecordKind.merged,
      );
    }

    return RemoteRecordMeta(fileName: fileName);
  }

  static DateTime? _parseDateTime(String dateStr, String timeStr) {
    try {
      return DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
        int.parse(timeStr.substring(0, 2)),
        int.parse(timeStr.substring(2, 4)),
        int.parse(timeStr.substring(4, 6)),
      );
    } on FormatException {
      return null;
    }
  }
}
