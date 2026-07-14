/// 数据管理页面展示已保存比赛记录时使用的模型。
library;

/// 从导出目录中解析出的已保存 JSON 比赛记录。
class MatchRecord {
  /// 创建 [MatchRecord]。
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
    this.isMerged = false,
    this.fileSizeBytes = 0,
    this.eventCount = 0,
    this.typeCounts = const {},
  });

  /// JSON 文件的绝对路径。
  final String filePath;

  /// JSON 文件基础名称。
  final String fileName;

  /// 从元数据或第一条消息推导出的比赛开始时间。
  final DateTime matchTime;

  /// 记录该文件的机器人身份。
  final int robotId;

  /// 文件中的消息总数。
  final int messageCount;

  /// 红方最终得分；不可用时为 null。
  final int? redScore;

  /// 蓝方最终得分；不可用时为 null。
  final int? blueScore;

  /// 已记录比赛持续时间；不可用时为 null。
  final Duration? duration;

  /// 记录是否到达结算阶段，即是否为完整比赛。
  final bool isComplete;

  /// 该记录是否由多个客户端文件合并产生（`metadata.merged == true`）。
  final bool isMerged;

  /// 文件大小，单位为字节。
  final int fileSizeBytes;

  /// 文件中 [event] 消息的数量。
  final int eventCount;

  /// 各消息类型的消息数量，例如 `{'GameStatus': 1200, ...}`。
  final Map<String, int> typeCounts;

  /// 记录是否携带最终得分。
  bool get hasScore => redScore != null && blueScore != null;

  /// 客户端以蓝方机器人登录时为 true（ID >= 100）。
  bool get isBlue => robotId >= 100;

  /// 左侧面板列表项使用的单行标签。
  String get title {
    final date = '${matchTime.year}-${_twoDigits(matchTime.month)}-'
        '${_twoDigits(matchTime.day)}';
    final side = isBlue ? '蓝方' : '红方';
    final score = hasScore ? '$blueScore:$redScore' : '';
    return score.isEmpty ? '$date $side' : '$date $side $score';
  }

  /// 比赛时间的 `HH:mm` 时钟标签。
  String get timeLabel =>
      '${_twoDigits(matchTime.hour)}:${_twoDigits(matchTime.minute)}';

  /// 可读持续时间，例如 `7:30`；未知时为 `—`。
  String get durationLabel {
    final d = duration;
    if (d == null) return '—';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${_twoDigits(s)}';
  }

  /// 可读文件大小，例如 `1.2 MB` / `840 KB`。
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
