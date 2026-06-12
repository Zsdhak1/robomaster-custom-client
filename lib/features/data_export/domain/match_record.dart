/// Models for saved match records shown in the data management screen.
library;

/// A saved JSON match record parsed from the export directory.
class MatchRecord {
  /// Creates a [MatchRecord].
  MatchRecord({
    required this.filePath,
    required this.fileName,
    required this.matchTime,
    required this.robotId,
    required this.messageCount,
    this.redScore,
    this.blueScore,
    this.duration,
    this.isComplete = false,
    this.fileSizeBytes = 0,
    this.eventCount = 0,
    this.typeCounts = const {},
  });

  /// Absolute path to the JSON file.
  final String filePath;

  /// Base name of the JSON file.
  final String fileName;

  /// Match start time derived from metadata or first message.
  final DateTime matchTime;

  /// Robot identity that recorded this file.
  final int robotId;

  /// Total number of messages in the file.
  final int messageCount;

  /// Final red team score, null if unavailable.
  final int? redScore;

  /// Final blue team score, null if unavailable.
  final int? blueScore;

  /// Recorded match duration, null if unavailable.
  final Duration? duration;

  /// Whether the recording reached the settlement stage (a complete match).
  final bool isComplete;

  /// File size in bytes.
  final int fileSizeBytes;

  /// Number of [Event] messages in the file.
  final int eventCount;

  /// Count of messages per message type (e.g. `{'GameStatus': 1200, ...}`).
  final Map<String, int> typeCounts;

  /// Whether the record carries a final score.
  bool get hasScore => redScore != null && blueScore != null;

  /// True when this client logged in as a blue-side robot (ids >= 100).
  bool get isBlue => robotId >= 100;

  /// One-line label for the left panel list tile.
  String get title {
    final date = '${matchTime.year}-${_twoDigits(matchTime.month)}-'
        '${_twoDigits(matchTime.day)}';
    final side = isBlue ? '蓝方' : '红方';
    final score = hasScore ? '$blueScore:$redScore' : '';
    return score.isEmpty ? '$date $side' : '$date $side $score';
  }

  /// `HH:mm` clock label of the match time.
  String get timeLabel =>
      '${_twoDigits(matchTime.hour)}:${_twoDigits(matchTime.minute)}';

  /// Human-readable duration like `7:30`, or `—` when unknown.
  String get durationLabel {
    final d = duration;
    if (d == null) return '—';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${_twoDigits(s)}';
  }

  /// Human-readable file size like `1.2 MB` / `840 KB`.
  String get fileSizeLabel {
    if (fileSizeBytes <= 0) return '—';
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    final kb = fileSizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  static String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
