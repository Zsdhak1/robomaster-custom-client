/// 自定义 H.264 链路（0x0310）的解码器诊断信息。
///
/// [CustomVideoStats] 的 TCP 桥接计数器用于判断流水线产出了什么；
/// 该模型用于判断应用内解码器实际解析出了什么，包括协商分辨率、编解码器、
/// 帧率、缓冲状态以及播放器暴露的错误。两者结合可以快速定位黑屏来自上游
/// （无字节或无关键帧）还是下游（解复用或解码）问题。
///
/// 播放器（fvp / media_kit）通过 [CustomVideoDecoderInfoNotifier] 写入更新，
/// 调试面板读取该快照。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [DecoderLogEntry] 的严重级别，用于驱动调试日志颜色。
enum DecoderLogLevel {
  /// 常规生命周期事件，例如打开、状态变化、分辨率已知。
  info,

  /// 可恢复的小故障，例如缓冲或重连。
  warn,

  /// 播放器暴露的解码或解复用失败。
  error,
}

/// 带时间戳的滚动解码器日志条目。
class DecoderLogEntry {
  /// 使用 [time]、[level] 和 [message] 创建日志条目。
  const DecoderLogEntry({
    required this.time,
    required this.level,
    required this.message,
  });

  /// 事件被记录的时间。
  final DateTime time;

  /// 严重级别。
  final DecoderLogLevel level;

  /// 可读描述。
  final String message;
}

/// 当前解码器对视频流报告信息的不可变快照。
class CustomVideoDecoderInfo {
  /// 创建解码器信息快照。
  const CustomVideoDecoderInfo({
    this.backend,
    this.playing = false,
    this.buffering = false,
    this.bufferingPercent,
    this.width,
    this.height,
    this.codec,
    this.pixelFormat,
    this.decoderFps,
    this.bitRate,
    this.profile,
    this.attempt = 0,
    this.lastError,
    this.logs = const [],
  });

  /// 解码器后端标签（fvp / media_kit / ffplay）。
  final String? backend;

  /// 解码器是否报告正在主动播放帧。
  final bool playing;

  /// 解码器当前是否正在缓冲或重新缓冲。
  final bool buffering;

  /// 缓冲进度 0-100；media_kit 会报告该值，未知时为 null。
  final double? bufferingPercent;

  /// 解码器协商出的图像宽度，单位像素；SPS 解析前为 null。
  final int? width;

  /// 解码器协商出的图像高度，单位像素；SPS 解析前为 null。
  final int? height;

  /// 解码器锁定的编解码器字符串，例如 `h264`。
  final String? codec;

  /// 解码器暴露的像素格式名称，例如 `yuv420p`。
  final String? pixelFormat;

  /// 解码器从流中解析出的帧率；未知时为 null。
  final double? decoderFps;

  /// 解码器暴露的流码率，单位 bit/s。
  final int? bitRate;

  /// 解码器暴露的 H.264 profile ID。
  final int? profile;

  /// 本次会话中播放器打开或重新打开该流的次数。
  final int attempt;

  /// 播放器最近暴露的错误；没有时为 null。
  final String? lastError;

  /// 最近的解码器滚动日志，最新条目在末尾。
  final List<DecoderLogEntry> logs;

  /// 解码器是否已经解析出图像尺寸。
  bool get hasResolution => (width ?? 0) > 0 && (height ?? 0) > 0;

  /// 返回覆盖指定字段后的副本。
  ///
  /// [clearError] 会强制 [lastError] 置为 null；普通 copyWith 模式无法区分
  /// “传入 null” 与“保持不变”。
  CustomVideoDecoderInfo copyWith({
    String? backend,
    bool? playing,
    bool? buffering,
    double? bufferingPercent,
    int? width,
    int? height,
    String? codec,
    String? pixelFormat,
    double? decoderFps,
    int? bitRate,
    int? profile,
    int? attempt,
    String? lastError,
    bool clearError = false,
    List<DecoderLogEntry>? logs,
  }) {
    return CustomVideoDecoderInfo(
      backend: backend ?? this.backend,
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      bufferingPercent: bufferingPercent ?? this.bufferingPercent,
      width: width ?? this.width,
      height: height ?? this.height,
      codec: codec ?? this.codec,
      pixelFormat: pixelFormat ?? this.pixelFormat,
      decoderFps: decoderFps ?? this.decoderFps,
      bitRate: bitRate ?? this.bitRate,
      profile: profile ?? this.profile,
      attempt: attempt ?? this.attempt,
      lastError: clearError ? null : (lastError ?? this.lastError),
      logs: logs ?? this.logs,
    );
  }
}

/// 最多保留的解码器日志条数，用于限制内存；超出时先丢弃最早条目。
const int _maxDecoderLogs = 60;

/// 当前播放器写入诊断信息的可变持有者。
///
/// 各更新方法会在有价值时追加对应的 [DecoderLogEntry]，让调试面板既能显示当前快照，
/// 也能回看状态是如何变化到当前结果的，例如“分辨率 1280x720”或“解码错误: ...”。
class CustomVideoDecoderInfoNotifier
    extends StateNotifier<CustomVideoDecoderInfo> {
  /// 以空解码器状态创建通知器。
  CustomVideoDecoderInfoNotifier() : super(const CustomVideoDecoderInfo());

  /// 清空所有解码器诊断，通常在流启动或停止时调用。
  void reset() => state = const CustomVideoDecoderInfo();

  /// 记录当前解码后端，并更新打开尝试次数。
  void beginSession(String backend, {required int attempt}) {
    state = state.copyWith(
      backend: backend,
      attempt: attempt,
      playing: false,
      buffering: false,
      clearError: true,
    );
    _log(DecoderLogLevel.info, '打开流 ($backend, 第 $attempt 次)');
  }

  /// 更新播放或暂停状态。
  void setPlaying({required bool playing}) {
    if (state.playing == playing) return;
    state = state.copyWith(playing: playing);
    _log(DecoderLogLevel.info, playing ? '开始播放' : '暂停/停止');
  }

  /// 更新缓冲状态和可选进度百分比。
  void setBuffering({required bool buffering, double? percent}) {
    state = state.copyWith(buffering: buffering, bufferingPercent: percent);
  }

  /// 记录解码器协商出的图像尺寸。
  void setResolution(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) return;
    if (state.width == width && state.height == height) return;
    state = state.copyWith(width: width, height: height);
    _log(DecoderLogLevel.info, '分辨率 ${width}x$height');
  }

  /// 记录从流中解析出的编解码器详情。
  void setCodec({
    String? codec,
    String? pixelFormat,
    double? fps,
    int? bitRate,
    int? profile,
  }) {
    state = state.copyWith(
      codec: codec,
      pixelFormat: pixelFormat,
      decoderFps: fps,
      bitRate: bitRate,
      profile: profile,
    );
    if (codec != null) {
      _log(
        DecoderLogLevel.info,
        '编解码 $codec${fps != null ? ' @ ${fps.toStringAsFixed(1)}fps' : ''}',
      );
    }
  }

  /// 记录最近的解码器错误。
  void setError(String message) {
    state = state.copyWith(lastError: message, playing: false);
    _log(DecoderLogLevel.error, message);
  }

  /// 追加一条 [level] 级别的自由格式诊断日志。
  void log(DecoderLogLevel level, String message) => _log(level, message);

  void _log(DecoderLogLevel level, String message) {
    final entry = DecoderLogEntry(
      time: DateTime.now(),
      level: level,
      message: message,
    );
    final next = [...state.logs, entry];
    if (next.length > _maxDecoderLogs) {
      next.removeRange(0, next.length - _maxDecoderLogs);
    }
    state = state.copyWith(logs: next);
  }
}

/// 自定义图传链路的实时解码器诊断。
///
/// 当前播放器写入该单例，调试面板从中读取。
final customVideoDecoderInfoProvider = StateNotifierProvider<
    CustomVideoDecoderInfoNotifier, CustomVideoDecoderInfo>(
  (ref) => CustomVideoDecoderInfoNotifier(),
);
