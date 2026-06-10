/// Riverpod providers for MQTT and UDP data streams.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../../core/video/video_frame.dart';
import '../../../services/ffplay_decoder.dart';
import '../../../services/mqtt_service.dart';
import '../../../services/video_stream_service.dart';
import 'game_state.dart';
import 'game_state_notifier.dart';

// ============================================================
// Service instances (kept alive as long as the app runs)
// ============================================================

/// Provides the singleton [MqttService] instance.
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService(clientId: 'robomaster_monitor');
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the singleton [VideoStreamService] instance.
final videoStreamServiceProvider = Provider<VideoStreamService>((ref) {
  final service = VideoStreamService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provides the singleton [FfplayDecoder] (Windows verification backend).
final ffplayDecoderProvider = Provider<FfplayDecoder>((ref) {
  final decoder = FfplayDecoder();
  ref.onDispose(decoder.dispose);
  return decoder;
});

/// Provides the [ProtobufParser] instance.
final protobufParserProvider = Provider<ProtobufParser>((ref) {
  return ProtobufParser(
    logger: (message) => debugPrint('[ProtobufParser] $message'),
  );
});

// ============================================================
// Stream providers
// ============================================================

/// Stream of parsed Protobuf envelopes from MQTT.
///
/// Listens to [MqttService.messageStream] and parses each payload.
final mqttMessageProvider = StreamProvider<ProtobufEnvelope>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  final parser = ref.watch(protobufParserProvider);

  return mqtt.messageStream.map(
    (msg) => parser.parse(msg.topic, msg.payload),
  );
});

/// Stream of reassembled HEVC video frames from UDP 3334.
final videoFrameProvider = StreamProvider<VideoFrame>((ref) {
  final video = ref.watch(videoStreamServiceProvider);
  return video.frameStream;
});

/// Connection state stream from MQTT service.
final mqttConnectionStateProvider = StreamProvider<MqttConnectionState>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  return mqtt.stateStream;
});

/// Current MQTT connection state.
///
/// Uses [AsyncValue] so that consumers rebuild on state changes.
final mqttConnectionStateSyncProvider = Provider<MqttConnectionState>((ref) {
  final asyncValue = ref.watch(mqttConnectionStateProvider);
  return asyncValue.when(
    data: (s) => s,
    loading: () => MqttConnectionState.disconnected,
    error: (_, _) => MqttConnectionState.error,
  );
});

/// Whether UDP video stream is currently listening.
final udpListeningProvider = Provider<bool>((ref) {
  final video = ref.watch(videoStreamServiceProvider);
  return video.isListening;
});

/// Reactive controller for starting/stopping the UDP video stream.
///
/// [VideoStreamService.isListening] is not reactive on its own, so this
/// notifier mirrors the listening state and drives UI rebuilds on toggle.
class VideoStreamController extends StateNotifier<bool> {
  /// Creates a [VideoStreamController] bound to [_service].
  VideoStreamController(this._service) : super(_service.isListening);

  final VideoStreamService _service;

  /// Starts the UDP listener and reflects the new state.
  Future<void> start() async {
    await _service.start();
    state = _service.isListening;
  }

  /// Stops the UDP listener and reflects the new state.
  void stop() {
    _service.stop();
    state = _service.isListening;
  }

  /// Toggles the listener on/off.
  Future<void> toggle() => state ? Future.sync(stop) : start();
}

/// Exposes the reactive video-stream listening state and controls.
final videoStreamControllerProvider =
    StateNotifierProvider<VideoStreamController, bool>((ref) {
  final service = ref.watch(videoStreamServiceProvider);
  return VideoStreamController(service);
});

// ============================================================
// Aggregated game state
// ============================================================

/// Aggregated game state from all MQTT status messages.
///
/// Updated incrementally as new Protobuf envelopes arrive.
final gameStateProvider =
    StateNotifierProvider<GameStateNotifier, GameState>((ref) {
  final notifier = GameStateNotifier();

  ref
    ..listen(mqttConnectionStateProvider, (_, next) {
      next.whenData(
        (s) => notifier.setConnected(
          connected: s == MqttConnectionState.connected,
        ),
      );
    })
    ..listen(mqttMessageProvider, (_, next) {
      next.whenData(notifier.handleEnvelope);
    });

  return notifier;
});
