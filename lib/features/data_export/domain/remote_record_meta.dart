/// Parses remote recording file names into displayable metadata.
///
/// Remote files follow the export/merge naming conventions:
/// - `rm_export_{robotId}_{yyyyMMdd_HHmmss}.json`
/// - `rm_merged_{red|blue}_{yyyyMMdd_HHmmss}.json`
///
/// Parsing the name (rather than downloading each file) keeps the remote list
/// lightweight while still letting the UI show date / side / robot id and
/// filter on them.
library;

import '../../connection/domain/robot_identity.dart';

/// Which side a recording belongs to.
enum RecordSide {
  /// Red side (protocol robot id < 100).
  red,

  /// Blue side (protocol robot id >= 100).
  blue,

  /// Side could not be determined from the file name.
  unknown,
}

/// What kind of recording a file represents.
enum RecordKind {
  /// A single-robot export (`rm_export_...`).
  export,

  /// A multi-source merged record (`rm_merged_...`).
  merged,

  /// File name did not match a known pattern.
  unknown,
}

/// Metadata decoded from a remote recording file name.
class RemoteRecordMeta {
  /// Creates a [RemoteRecordMeta].
  const RemoteRecordMeta({
    required this.fileName,
    this.date,
    this.side = RecordSide.unknown,
    this.robotId,
    this.kind = RecordKind.unknown,
  });

  /// Original file name (kept for download + as a fallback label).
  final String fileName;

  /// Local capture time decoded from the name, null when unparseable.
  final DateTime? date;

  /// Side inferred from the robot id or merged side token.
  final RecordSide side;

  /// Robot id for export records, null for merged/unknown.
  final int? robotId;

  /// Recording kind.
  final RecordKind kind;

  static final RegExp _exportPattern =
      RegExp(r'^rm_export_(\d+)_(\d{8})_(\d{6})$');
  static final RegExp _mergedPattern =
      RegExp(r'^rm_merged_(red|blue)_(\d{8})_(\d{6})$');

  /// Decodes [fileName] into [RemoteRecordMeta].
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
