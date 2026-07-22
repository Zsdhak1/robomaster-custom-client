/// MQTT 和 UDP 数据流使用的 Riverpod Provider。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../../core/video/video_frame.dart';
import '../../../services/ffplay_decoder.dart';
import '../../../services/mqtt_service.dart';
import '../../../services/video_stream_service.dart';
import '../../settings/logic/settings_providers.dart';
import 'dashboard_notification_models.dart';
import 'game_state.dart';
import 'game_state_notifier.dart';

// ============================================================
// 服务实例（随应用生命周期保持存活）
// ============================================================

/// 提供单例 [MqttService] 实例。
final mqttServiceProvider = Provider<MqttService>((ref) {
  final service = MqttService(clientId: 'robomaster_monitor');
  ref.onDispose(service.dispose);
  return service;
});

/// 提供单例 [VideoStreamService] 实例。
final videoStreamServiceProvider = Provider<VideoStreamService>((ref) {
  final service = VideoStreamService();
  ref.onDispose(service.dispose);
  return service;
});

/// 提供单例 [FfplayDecoder]，用于 Windows 验证后端。
final ffplayDecoderProvider = Provider<FfplayDecoder>((ref) {
  final decoder = FfplayDecoder();
  ref.onDispose(decoder.dispose);
  return decoder;
});

/// 提供 [ProtobufParser] 实例。
final protobufParserProvider = Provider<ProtobufParser>((ref) {
  return ProtobufParser(
    logger: (message) => debugPrint('[ProtobufParser] $message'),
  );
});

// ============================================================
// 流 Provider
// ============================================================

/// 来自 MQTT 的已解析 Protobuf 信封流。
///
/// 每次调用都会独立监听 [MqttService.messageStream]，并完整重放其缓存。
final mqttEnvelopeStreamFactoryProvider =
    Provider<Stream<ProtobufEnvelope> Function()>((ref) {
      final mqtt = ref.watch(mqttServiceProvider);
      final parser = ref.watch(protobufParserProvider);

      return () => mqtt.messageStream.map(
        (msg) => parser.parse(
          msg.topic,
          msg.payload,
          receivedAt: msg.receivedAt,
          connectionGeneration: msg.connectionGeneration,
        ),
      );
    });

/// 供比赛状态、记录和调试功能共享的 MQTT Protobuf 信封流。
final mqttMessageProvider = StreamProvider<ProtobufEnvelope>((ref) {
  return ref.watch(mqttEnvelopeStreamFactoryProvider)();
});

/// 来自 UDP 3334 的已重组 HEVC 视频帧流。
final videoFrameProvider = StreamProvider<VideoFrame>((ref) {
  final video = ref.watch(videoStreamServiceProvider);
  return video.frameStream;
});

/// 来自 MQTT 服务的连接状态流。
final mqttConnectionStateProvider = StreamProvider<MqttConnectionState>((ref) {
  final mqtt = ref.watch(mqttServiceProvider);
  return mqtt.stateStream;
});

/// 当前 MQTT 连接状态。
///
/// 使用 [AsyncValue]，让消费者在状态变化时重建。
final mqttConnectionStateSyncProvider = Provider<MqttConnectionState>((ref) {
  final asyncValue = ref.watch(mqttConnectionStateProvider);
  return asyncValue.when(
    data: (s) => s,
    loading: () => MqttConnectionState.disconnected,
    error: (_, _) => MqttConnectionState.error,
  );
});

/// UDP 视频流当前是否正在监听。
final udpListeningProvider = Provider<bool>((ref) {
  final video = ref.watch(videoStreamServiceProvider);
  return video.isListening;
});

/// 用于启动和停止 UDP 视频流的响应式控制器。
///
/// [VideoStreamService.isListening] 本身不是响应式状态，因此该通知器负责同步监听状态，
/// 并在切换时驱动 UI 重建。
class VideoStreamController extends StateNotifier<bool> {
  /// 创建绑定到 [_service] 的 [VideoStreamController]。
  VideoStreamController(this._service) : super(_service.isListening);

  final VideoStreamService _service;

  /// 启动 UDP 监听器并同步最新状态。
  Future<void> start() async {
    await _service.start();
    state = _service.isListening;
  }

  /// 停止 UDP 监听器并同步最新状态。
  void stop() {
    _service.stop();
    state = _service.isListening;
  }

  /// 切换监听器开关状态。
  Future<void> toggle() => state ? Future.sync(stop) : start();
}

/// 暴露响应式视频流监听状态和控制器。
final videoStreamControllerProvider =
    StateNotifierProvider<VideoStreamController, bool>((ref) {
      final service = ref.watch(videoStreamServiceProvider);
      return VideoStreamController(service);
    });

// ============================================================
// 聚合比赛状态。
// ============================================================

/// 从所有 MQTT 状态消息聚合比赛状态。
///
/// 新的 Protobuf 信封到达时增量更新。
final gameStateProvider = StateNotifierProvider<GameStateNotifier, GameState>((
  ref,
) {
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

/// 当前已持久化的通知样式选择。
final dashboardNotificationStyleSyncProvider =
    Provider<DashboardNotificationStyle>(
      (ref) => ref.watch(dashboardNotificationStyleProvider),
    );
