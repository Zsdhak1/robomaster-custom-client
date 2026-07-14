/// 自定义 H.264/H.265 视频流（0x0310 / CustomByteBlock）的 Riverpod Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/logic/stream_providers.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/custom_byte_block_source.dart';
import 'custom_video_decoder_info.dart';
import 'custom_video_stream_service.dart';

export 'custom_video_decoder_info.dart';
export 'custom_video_stream_service.dart';

/// 自定义图传流水线状态的不可变快照。
///
/// 每个字段对应流水线的一个阶段，便于快速判断卡点：
/// - [chunksReceived] == 0 → 没有 MQTT 数据（未连接或未订阅）。
/// - [chunksReceived] > 0 但 [gateOpen] 为 false → 尚未识别 SPS/PPS。
/// - [gateOpen] 为 true 但 [decoderClients] == 0 → 播放器尚未连接到桥接。
/// - 上述阶段均正常但无画面 → 解码器或解复用器配置问题。
///
/// `*PerSec` 字段由 [customVideoStatsProvider] 根据连续 1 秒 tick 的增量计算，
/// 表示实时吞吐量，而不是累计总量。
class CustomVideoStats {
  /// 创建 [CustomVideoStats] 快照。
  const CustomVideoStats({
    required this.running,
    required this.chunksReceived,
    required this.bytesReceived,
    required this.gateOpen,
    required this.framesForwarded,
    required this.bytesForwarded,
    required this.decoderClients,
    required this.streamUrl,
    required this.tsWrap,
    required this.gateBufferBytes,
    required this.pendingFrames,
    required this.millisSinceLastChunk,
    this.keyframesSeen = 0,
    this.spsSeen = 0,
    this.vpsSeen = 0,
    this.nonIdrSeen = 0,
    this.millisSinceLastKeyframe,
    this.codec = CustomVideoCodec.h264,
    this.hasSequence = false,
    this.lastSequence = 0,
    this.seqPacketsSeen = 0,
    this.packetsLost = 0,
    this.seqRegressions = 0,
    this.lossRate = 0,
    this.chunksPerSec = 0,
    this.bytesInPerSec = 0,
    this.framesPerSec = 0,
    this.bytesOutPerSec = 0,
  });

  /// 从 [service] 和 [source] 读取实时快照。
  ///
  /// 速率字段默认为 0，Provider 会根据 tick 间增量补齐。
  factory CustomVideoStats.from(
    CustomVideoStreamService service,
    CustomByteBlockSource source,
  ) {
    return CustomVideoStats(
      running: service.isRunning,
      chunksReceived: service.chunksReceived,
      bytesReceived: service.bytesReceived,
      gateOpen: service.gateOpen,
      framesForwarded: service.framesForwarded,
      bytesForwarded: service.bytesForwarded,
      decoderClients: service.decoderClients,
      streamUrl: service.streamUrl,
      tsWrap: service.tsWrap,
      gateBufferBytes: service.gateBufferBytes,
      pendingFrames: service.pendingFrames,
      millisSinceLastChunk: service.millisSinceLastChunk,
      keyframesSeen: service.keyframesSeen,
      spsSeen: service.spsSeen,
      vpsSeen: service.vpsSeen,
      nonIdrSeen: service.nonIdrSeen,
      millisSinceLastKeyframe: service.millisSinceLastKeyframe,
      codec: service.codec,
      hasSequence: source.hasSequence,
      lastSequence: source.lastSequence,
      seqPacketsSeen: source.seqPacketsSeen,
      packetsLost: source.packetsLost,
      seqRegressions: source.seqRegressions,
      lossRate: source.lossRate,
    );
  }

  /// 桥接当前是否正在运行。
  final bool running;

  /// 已接收的 MQTT 块数，统计闸门前上游数量。
  final int chunksReceived;

  /// 已接收的 MQTT 字节数，统计闸门前上游数量。
  final int bytesReceived;

  /// H.264/H.265 关键帧闸门是否已经打开。
  final bool gateOpen;

  /// 已转发给解码器客户端的帧数。
  final int framesForwarded;

  /// 已转发给解码器客户端的字节数。
  final int bytesForwarded;

  /// 已连接的解码器客户端数量。
  final int decoderClients;

  /// TCP 桥接 URL；停止时为 null。
  final String? streamUrl;

  /// 服务输出流是否已封装为 MPEG-TS。
  final bool tsWrap;

  /// 关键帧闸门打开前缓冲区中的字节数；闸门打开后为 0。
  final int gateBufferBytes;

  /// 等待首个关键帧时桥接缓冲的帧数。
  final int pendingFrames;

  /// 距离最近一个 MQTT 块到达的毫秒数；尚未收到时为 null。
  final int? millisSinceLastChunk;

  /// 切片后流中观察到的 IDR 关键帧 NAL 单元数量。
  ///
  /// H.264：类型 5（IDR）。H.265/HEVC：类型 19 + 20（IDR_W_RADL / IDR_N_LP）。
  final int keyframesSeen;

  /// 切片后流中观察到的 SPS 参数集 NAL 单元数量。
  ///
  /// H.264：类型 7。H.265/HEVC：类型 33。
  final int spsSeen;

  /// 切片后流中观察到的 VPS 参数集 NAL 单元数量。
  ///
  /// H.264 没有 VPS，因此始终为 0。H.265/HEVC：类型 32。
  final int vpsSeen;

  /// 切片后流中观察到的非 IDR 切片 NAL 单元数量。
  ///
  /// H.264：类型 1。H.265/HEVC：类型 1（TRAIL_R）及类似类型。
  final int nonIdrSeen;

  /// 距离最近一个关键帧/参数集 NAL 的毫秒数；尚未观察到时为 null。
  final int? millisSinceLastKeyframe;

  /// 当前会话配置的视频编码格式。
  final CustomVideoCodec codec;

  /// 是否已经观察到包序列号。
  final bool hasSequence;

  /// 最近一个包的序列号（前置 8 字节 uint64 LE）。
  final int lastSequence;

  /// 启动后通过序列号观察到的包数。
  final int seqPacketsSeen;

  /// 启动后从序列号间隔推断出的丢包数。
  final int packetsLost;

  /// 启动后观察到的乱序或重复序列号次数。
  final int seqRegressions;

  /// 根据序列号范围推导出的丢包率，取值范围为 `[0, 1]`。
  final double lossRate;

  /// 最近一个 tick 内每秒接收的块数。
  final double chunksPerSec;

  /// 最近一个 tick 内每秒接收的上游字节数。
  final double bytesInPerSec;

  /// 最近一个 tick 内每秒转发给客户端的帧数。
  final double framesPerSec;

  /// 最近一个 tick 内每秒转发给客户端的字节数。
  final double bytesOutPerSec;

  /// 返回填充吞吐量速率后的副本。
  CustomVideoStats withRates({
    required double chunksPerSec,
    required double bytesInPerSec,
    required double framesPerSec,
    required double bytesOutPerSec,
  }) {
    return CustomVideoStats(
      running: running,
      chunksReceived: chunksReceived,
      bytesReceived: bytesReceived,
      gateOpen: gateOpen,
      framesForwarded: framesForwarded,
      bytesForwarded: bytesForwarded,
      decoderClients: decoderClients,
      streamUrl: streamUrl,
      tsWrap: tsWrap,
      gateBufferBytes: gateBufferBytes,
      pendingFrames: pendingFrames,
      millisSinceLastChunk: millisSinceLastChunk,
      keyframesSeen: keyframesSeen,
      spsSeen: spsSeen,
      vpsSeen: vpsSeen,
      nonIdrSeen: nonIdrSeen,
      millisSinceLastKeyframe: millisSinceLastKeyframe,
      codec: codec,
      hasSequence: hasSequence,
      lastSequence: lastSequence,
      seqPacketsSeen: seqPacketsSeen,
      packetsLost: packetsLost,
      seqRegressions: seqRegressions,
      lossRate: lossRate,
      chunksPerSec: chunksPerSec,
      bytesInPerSec: bytesInPerSec,
      framesPerSec: framesPerSec,
      bytesOutPerSec: bytesOutPerSec,
    );
  }
}

/// 提供单例 [CustomByteBlockSource] 实例。
///
/// 切片模式和固定模式字节数通过实时回调读取设置 Provider，因此调整这些设置会
/// 立即改变后续包的切片方式，无需重建数据源或重启流。
final customByteBlockSourceProvider = Provider<CustomByteBlockSource>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  final parser = ref.watch(protobufParserProvider);
  final source = CustomByteBlockSource(
    mqttService: mqtt,
    parser: parser,
    sliceMode: () => ref.read(customVideoSliceModeProvider),
    headerBytes: () => customVideoHeaderBytes,
    payloadBytes: () => ref.read(customVideoPayloadBytesProvider),
    seqHeaderEnabled: () => ref.read(customVideoSeqHeaderProvider),
  );
  ref.onDispose(source.dispose);
  return source;
});

/// 提供单例 [CustomVideoStreamService]，即独立 TCP 桥接服务。
final customVideoStreamServiceProvider =
    Provider<CustomVideoStreamService>((ref) {
  final service = CustomVideoStreamService();
  ref.onDispose(service.dispose);
  return service;
});

/// 每秒轮询一次服务，让 UI 能反映实时计数器。
///
/// 服务是单例且引用稳定，直接 `ref.watch` 不会因计数器变化而重建。该流每个 tick
/// 发出新快照，使组件获得真实变化的值；同时根据与上一个 tick 累计值的差量计算
/// 实时吞吐量（块/s、帧/s、输入/输出 KB/s）。
final customVideoStatsProvider = StreamProvider<CustomVideoStats>((ref) {
  final service = ref.watch(customVideoStreamServiceProvider);
  final source = ref.watch(customByteBlockSourceProvider);

  var prevChunks = 0;
  var prevBytesIn = 0;
  var prevFrames = 0;
  var prevBytesOut = 0;
  var prevAt = DateTime.now();

  return Stream<CustomVideoStats>.periodic(
    const Duration(seconds: 1),
    (_) {
      final snap = CustomVideoStats.from(service, source);
      final now = DateTime.now();
      final dtSec = now.difference(prevAt).inMilliseconds / 1000.0;
      // 避免 0 间隔或异常间隔产生 inf/NaN 速率。
      final divisor = dtSec <= 0 ? 1.0 : dtSec;

      final withRates = snap.withRates(
        chunksPerSec: (snap.chunksReceived - prevChunks) / divisor,
        bytesInPerSec: (snap.bytesReceived - prevBytesIn) / divisor,
        framesPerSec: (snap.framesForwarded - prevFrames) / divisor,
        bytesOutPerSec: (snap.bytesForwarded - prevBytesOut) / divisor,
      );

      prevChunks = snap.chunksReceived;
      prevBytesIn = snap.bytesReceived;
      prevFrames = snap.framesForwarded;
      prevBytesOut = snap.bytesForwarded;
      prevAt = now;
      return withRates;
    },
  );
});

/// 控制自定义 H.264/H.265 视频桥接启动和停止的响应式控制器。
///
/// 与官方链路的 [VideoStreamController] 模式保持一致：把 MQTT
/// [CustomByteBlockSource] 块流接入独立桥接，并在切换时驱动 UI 重建。
class CustomVideoController extends StateNotifier<bool> {
  /// 创建绑定到 [_source]、[_service] 和 [_ref] 的控制器。
  CustomVideoController(this._source, this._service, this._ref) : super(false);

  final CustomByteBlockSource _source;
  final CustomVideoStreamService _service;
  final Ref _ref;

  /// 启动 MQTT 订阅和桥接。
  Future<void> start() async {
    // 清空上一次会话遗留的解码器诊断，让调试面板只反映当前运行。
    _ref.read(customVideoDecoderInfoProvider.notifier).reset();
    _source.start();
    try {
      await _service.start(
        _source.chunkStream,
        tsWrap: _ref.read(customVideoEffectiveTsWrapProvider),
        codec: _ref.read(customVideoCodecProvider),
      );
      state = true;
    } on Object {
      _source.stop();
      state = false;
      rethrow;
    }
  }

  /// 停止桥接并取消订阅。
  void stop() {
    _service.stop();
    _source.stop();
    _ref.read(customVideoDecoderInfoProvider.notifier).reset();
    state = false;
  }

  /// 切换桥接开关状态。
  Future<void> toggle() => state ? Future.sync(stop) : start();

  /// 停止并重启桥接，让已变化的服务格式立即生效。
  ///
  /// 例如实时切换后端时改变 TS wrap 状态；未运行时为空操作。
  Future<void> restart() async {
    if (!state) return;
    stop();
    await start();
  }

  // ---------------------------------------------------------------
  // 20 秒流转储辅助函数
  // ---------------------------------------------------------------

  /// 启动一次 20 秒原始视频流转储。
  ///
  /// 返回完成后生成的 `.h264` 或 `.hevc` 文件路径。
  Future<String> startDump() => _service.startDump();

  /// 取消正在进行的转储。
  void stopDump() => _service.stopDump();

  /// 当前是否正在转储。
  bool get isDumping => _service.isDumping;

  /// 底层服务，用于直接访问转储 API。
  CustomVideoStreamService get service => _service;
}

/// 暴露自定义图传的运行状态和控制器。
final customVideoControllerProvider =
    StateNotifierProvider<CustomVideoController, bool>((ref) {
  final source = ref.watch(customByteBlockSourceProvider);
  final service = ref.watch(customVideoStreamServiceProvider);
  final controller = CustomVideoController(source, service, ref);
  // 流式传输期间如果有效 TS wrap 值变化（例如用户中途切换 media_kit 后端），
  // 桥接输出字节就不再匹配播放器强制使用的解复用器。重启桥接以重新对齐服务格式。
  ref.listen<bool>(customVideoEffectiveTsWrapProvider, (prev, next) {
    if (prev != null && prev != next) {
      controller.restart();
    }
  });
  return controller;
});
