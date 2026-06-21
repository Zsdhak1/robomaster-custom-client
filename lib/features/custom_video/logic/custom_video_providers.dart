/// Riverpod providers for the custom H.264 video stream (0x0310 / CustomByteBlock).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/logic/stream_providers.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/custom_byte_block_source.dart';
import 'custom_video_decoder_info.dart';
import 'custom_video_stream_service.dart';

export 'custom_video_decoder_info.dart';
export 'custom_video_stream_service.dart';

/// Immutable snapshot of the custom-video pipeline health.
///
/// Each field pinpoints a different stage, so a glance tells you exactly where
/// the pipeline is stuck:
/// - [chunksReceived] == 0 → no MQTT data (not connected / not subscribed).
/// - [chunksReceived] > 0 but [gateOpen] false → SPS/PPS never recognized.
/// - [gateOpen] true but [decoderClients] == 0 → player not attached to bridge.
/// - all > 0 but no picture → decoder/demuxer issue.
///
/// The `*PerSec` fields are computed by [customVideoStatsProvider] from the
/// delta between successive 1-second ticks, giving live throughput rather than
/// cumulative totals.
class CustomVideoStats {
  /// Creates a [CustomVideoStats] snapshot.
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
    this.nonIdrSeen = 0,
    this.millisSinceLastKeyframe,
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

  /// Reads a live snapshot from [service] and [source] (rates default to 0;
  /// the provider fills them in from inter-tick deltas).
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
      nonIdrSeen: service.nalCounts[1] ?? 0,
      millisSinceLastKeyframe: service.millisSinceLastKeyframe,
      hasSequence: source.hasSequence,
      lastSequence: source.lastSequence,
      seqPacketsSeen: source.seqPacketsSeen,
      packetsLost: source.packetsLost,
      seqRegressions: source.seqRegressions,
      lossRate: source.lossRate,
    );
  }

  /// Whether the bridge is active.
  final bool running;

  /// MQTT chunks received (pre-gate upstream count).
  final int chunksReceived;

  /// MQTT bytes received (pre-gate upstream count).
  final int bytesReceived;

  /// Whether the H.264 keyframe gate has opened.
  final bool gateOpen;

  /// Frames forwarded to decoder clients.
  final int framesForwarded;

  /// Bytes forwarded to decoder clients.
  final int bytesForwarded;

  /// Connected decoder clients.
  final int decoderClients;

  /// TCP bridge URL, or null when stopped.
  final String? streamUrl;

  /// Whether the served stream is MPEG-TS wrapped.
  final bool tsWrap;

  /// Bytes held in the pre-keyframe gate buffer (0 once the gate opens).
  final int gateBufferBytes;

  /// Frames buffered by the bridge while waiting for the first keyframe.
  final int pendingFrames;

  /// Milliseconds since the last MQTT chunk arrived, or null if none yet.
  final int? millisSinceLastChunk;

  /// IDR keyframe NAL units (type 5) seen over the post-slice stream.
  final int keyframesSeen;

  /// SPS parameter-set NAL units (type 7) seen over the post-slice stream.
  final int spsSeen;

  /// Non-IDR slice NAL units (type 1) seen over the post-slice stream.
  final int nonIdrSeen;

  /// Milliseconds since the last keyframe/parameter-set NAL, or null if none.
  final int? millisSinceLastKeyframe;

  /// Whether a packet sequence number has been observed yet.
  final bool hasSequence;

  /// Most recent packet sequence number (uint64 LE leading 8 bytes).
  final int lastSequence;

  /// Packets observed via their sequence number since start.
  final int seqPacketsSeen;

  /// Packets inferred lost from sequence-number gaps since start.
  final int packetsLost;

  /// Out-of-order / duplicate sequence numbers seen since start.
  final int seqRegressions;

  /// Packet-loss rate in [0, 1] derived from the sequence span.
  final double lossRate;

  /// Chunks received per second over the last tick.
  final double chunksPerSec;

  /// Upstream bytes received per second over the last tick.
  final double bytesInPerSec;

  /// Frames forwarded to clients per second over the last tick.
  final double framesPerSec;

  /// Bytes forwarded to clients per second over the last tick.
  final double bytesOutPerSec;

  /// Returns a copy with the computed throughput rates filled in.
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
      nonIdrSeen: nonIdrSeen,
      millisSinceLastKeyframe: millisSinceLastKeyframe,
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

/// Provides the singleton [CustomByteBlockSource] instance.
///
/// The slice mode and fixed-mode byte counts are supplied as live callbacks
/// reading the settings providers, so adjusting them retunes the per-packet
/// slice immediately without rebuilding the source or restarting the stream.
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

/// Provides the singleton [CustomVideoStreamService] (independent TCP bridge).
final customVideoStreamServiceProvider =
    Provider<CustomVideoStreamService>((ref) {
  final service = CustomVideoStreamService();
  ref.onDispose(service.dispose);
  return service;
});

/// Polls the service once per second so the UI reflects live counters.
///
/// The service is a singleton (stable reference), so `ref.watch` of it never
/// rebuilds on counter changes. This stream emits a fresh snapshot each tick,
/// giving widgets a value that actually changes. Each tick also derives live
/// throughput rates (chunks/s, frames/s, in/out KB/s) from the delta against
/// the previous tick's cumulative totals.
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
      // Guard against a zero/!running interval producing inf/NaN rates.
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

/// Reactive controller starting/stopping the custom H.264 video bridge.
///
/// Mirrors the official line's [VideoStreamController] pattern: wires the MQTT
/// [CustomByteBlockSource] chunk stream into the independent bridge and drives
/// UI rebuilds on toggle.
class CustomVideoController extends StateNotifier<bool> {
  /// Creates a controller bound to [_source], [_service] and [_ref].
  CustomVideoController(this._source, this._service, this._ref) : super(false);

  final CustomByteBlockSource _source;
  final CustomVideoStreamService _service;
  final Ref _ref;

  /// Starts MQTT subscription and the bridge.
  Future<void> start() async {
    // Clear stale decoder diagnostics from a previous session so the debug
    // panel reflects only the run that's starting now.
    _ref.read(customVideoDecoderInfoProvider.notifier).reset();
    _source.start();
    await _service.start(
      _source.chunkStream,
      tsWrap: _ref.read(customVideoTsWrapProvider),
    );
    state = true;
  }

  /// Stops the bridge and unsubscribes.
  void stop() {
    _service.stop();
    _source.stop();
    _ref.read(customVideoDecoderInfoProvider.notifier).reset();
    state = false;
  }

  /// Toggles the bridge on/off.
  Future<void> toggle() => state ? Future.sync(stop) : start();

  // ---------------------------------------------------------------
  // 20-second stream dump helpers
  // ---------------------------------------------------------------

  /// Starts a 20-second dump of the raw H.264 stream.
  ///
  /// Returns a future that completes with the `.h264` file path.
  Future<String> startDump() => _service.startDump();

  /// Cancels an in-progress dump.
  void stopDump() => _service.stopDump();

  /// Whether a dump is currently running.
  bool get isDumping => _service.isDumping;

  /// The underlying service (for direct access to dump API).
  CustomVideoStreamService get service => _service;
}

/// Exposes the reactive custom-video running state and controls.
final customVideoControllerProvider =
    StateNotifierProvider<CustomVideoController, bool>((ref) {
  final source = ref.watch(customByteBlockSourceProvider);
  final service = ref.watch(customVideoStreamServiceProvider);
  return CustomVideoController(source, service, ref);
});
