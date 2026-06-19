/// Riverpod providers for the custom H.264 video stream (0x0310 / CustomByteBlock).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/logic/stream_providers.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/custom_byte_block_source.dart';
import 'custom_video_stream_service.dart';

export 'custom_video_stream_service.dart';

/// Immutable snapshot of the custom-video pipeline health.
///
/// Each field pinpoints a different stage, so a glance tells you exactly where
/// the pipeline is stuck:
/// - [chunksReceived] == 0 → no MQTT data (not connected / not subscribed).
/// - [chunksReceived] > 0 but [gateOpen] false → SPS/PPS never recognized.
/// - [gateOpen] true but [decoderClients] == 0 → player not attached to bridge.
/// - all > 0 but no picture → decoder/demuxer issue.
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
  });

  /// Reads a live snapshot from [service].
  factory CustomVideoStats.from(CustomVideoStreamService service) {
    return CustomVideoStats(
      running: service.isRunning,
      chunksReceived: service.chunksReceived,
      bytesReceived: service.bytesReceived,
      gateOpen: service.gateOpen,
      framesForwarded: service.framesForwarded,
      bytesForwarded: service.bytesForwarded,
      decoderClients: service.decoderClients,
      streamUrl: service.streamUrl,
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
}

/// Provides the singleton [CustomByteBlockSource] instance.
final customByteBlockSourceProvider = Provider<CustomByteBlockSource>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  final parser = ref.watch(protobufParserProvider);
  final source = CustomByteBlockSource(mqttService: mqtt, parser: parser);
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
/// giving widgets a value that actually changes.
final customVideoStatsProvider = StreamProvider<CustomVideoStats>((ref) {
  final service = ref.watch(customVideoStreamServiceProvider);
  return Stream<CustomVideoStats>.periodic(
    const Duration(seconds: 1),
    (_) => CustomVideoStats.from(service),
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
    state = false;
  }

  /// Toggles the bridge on/off.
  Future<void> toggle() => state ? Future.sync(stop) : start();
}

/// Exposes the reactive custom-video running state and controls.
final customVideoControllerProvider =
    StateNotifierProvider<CustomVideoController, bool>((ref) {
  final source = ref.watch(customByteBlockSourceProvider);
  final service = ref.watch(customVideoStreamServiceProvider);
  return CustomVideoController(source, service, ref);
});
