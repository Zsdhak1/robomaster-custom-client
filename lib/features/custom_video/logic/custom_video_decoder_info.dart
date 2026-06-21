/// Decoder-reported diagnostics for the custom H.264 line (0x0310).
///
/// The TCP-bridge counters in [CustomVideoStats] tell you what the pipeline
/// PRODUCED; this model tells you what the in-app decoder actually MADE OF it -
/// the negotiated resolution, codec, frame rate, buffering and any error the
/// player surfaced. Together they pinpoint whether a black screen is an
/// upstream (no bytes / no keyframe) or a downstream (demux / decode) problem.
///
/// Players (fvp / media_kit) push updates here via
/// [CustomVideoDecoderInfoNotifier]; the debug panel reads the snapshot.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Severity of a [DecoderLogEntry], driving its colour in the debug log.
enum DecoderLogLevel {
  /// Routine lifecycle event (open, state change, resolution known).
  info,

  /// Recoverable hiccup (buffering, reconnect).
  warn,

  /// Decode/demux failure surfaced by the player.
  error,
}

/// One timestamped line in the rolling decoder log.
class DecoderLogEntry {
  /// Creates an entry stamped [time] with [level] and [message].
  const DecoderLogEntry({
    required this.time,
    required this.level,
    required this.message,
  });

  /// When the event was recorded.
  final DateTime time;

  /// Severity bucket.
  final DecoderLogLevel level;

  /// Human-readable description.
  final String message;
}

/// Immutable snapshot of what the active decoder reports about the stream.
class CustomVideoDecoderInfo {
  /// Creates a decoder-info snapshot.
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

  /// The decoder backend label (fvp / media_kit / ffplay).
  final String? backend;

  /// Whether the decoder reports it is actively playing frames.
  final bool playing;

  /// Whether the decoder is currently (re)buffering.
  final bool buffering;

  /// Buffering progress 0-100 (media_kit reports this; null if unknown).
  final double? bufferingPercent;

  /// Negotiated picture width in pixels, or null before the SPS is parsed.
  final int? width;

  /// Negotiated picture height in pixels, or null before the SPS is parsed.
  final int? height;

  /// Codec string the decoder locked onto (e.g. `h264`).
  final String? codec;

  /// Pixel format name (e.g. `yuv420p`), when the decoder exposes it.
  final String? pixelFormat;

  /// Frame rate the decoder parsed from the stream, or null if unknown.
  final double? decoderFps;

  /// Stream bit rate in bits/s, when the decoder exposes it.
  final int? bitRate;

  /// H.264 profile id, when the decoder exposes it.
  final int? profile;

  /// How many times the player has (re)opened the stream this session.
  final int attempt;

  /// The most recent error the player surfaced, or null.
  final String? lastError;

  /// Rolling log of the most recent decoder events (newest last).
  final List<DecoderLogEntry> logs;

  /// Whether the decoder has resolved a picture size yet.
  bool get hasResolution => (width ?? 0) > 0 && (height ?? 0) > 0;

  /// Returns a copy with the supplied fields overridden.
  ///
  /// [clearError] forces [lastError] back to null (since a null argument is
  /// indistinguishable from "leave unchanged" in the normal copy pattern).
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

/// Maximum decoder-log lines retained (bounds memory; oldest dropped first).
const int _maxDecoderLogs = 60;

/// Mutable holder the active player pushes its diagnostics into.
///
/// All update methods append a matching [DecoderLogEntry] where useful, so the
/// debug panel shows both the current snapshot and a scrollback of how it got
/// there (e.g. "resolution 1280x720", "decode error: ...").
class CustomVideoDecoderInfoNotifier
    extends StateNotifier<CustomVideoDecoderInfo> {
  /// Creates the notifier in the empty (no-decoder) state.
  CustomVideoDecoderInfoNotifier() : super(const CustomVideoDecoderInfo());

  /// Clears all decoder diagnostics (call on stream start/stop).
  void reset() => state = const CustomVideoDecoderInfo();

  /// Records which backend is decoding and bumps the open attempt counter.
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

  /// Updates the play/pause state.
  void setPlaying({required bool playing}) {
    if (state.playing == playing) return;
    state = state.copyWith(playing: playing);
    _log(DecoderLogLevel.info, playing ? '开始播放' : '暂停/停止');
  }

  /// Updates the buffering state and optional progress percentage.
  void setBuffering({required bool buffering, double? percent}) {
    state = state.copyWith(buffering: buffering, bufferingPercent: percent);
  }

  /// Records the decoder-negotiated picture size.
  void setResolution(int? width, int? height) {
    if (width == null || height == null || width <= 0 || height <= 0) return;
    if (state.width == width && state.height == height) return;
    state = state.copyWith(width: width, height: height);
    _log(DecoderLogLevel.info, '分辨率 ${width}x$height');
  }

  /// Records codec details parsed from the stream.
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

  /// Records the most recent decoder error.
  void setError(String message) {
    state = state.copyWith(lastError: message, playing: false);
    _log(DecoderLogLevel.error, message);
  }

  /// Appends a free-form diagnostic line at [level].
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

/// Live decoder diagnostics for the custom video line.
///
/// A singleton the active player writes to and the debug panel reads.
final customVideoDecoderInfoProvider = StateNotifierProvider<
    CustomVideoDecoderInfoNotifier, CustomVideoDecoderInfo>(
  (ref) => CustomVideoDecoderInfoNotifier(),
);
