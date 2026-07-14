/// MQTT 数据记录器使用的 Riverpod Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../../services/mqtt_service.dart';
import '../../dashboard/logic/stream_providers.dart';
import '../../settings/logic/record_config_provider.dart';
import '../domain/data_recorder.dart';

/// 将 MQTT [ProtobufEnvelope] 记录到按类型分桶的内存历史中。
///
/// 消息按时间顺序保留，并按消息类型分组。
/// 当总数超过 [DataRecorderState.maxMessages] 时，最早的消息会被淘汰。
class DataRecorderNotifier extends StateNotifier<DataRecorderState> {
  /// 创建带可选 [maxMessages] 上限的 [DataRecorderNotifier]。
  DataRecorderNotifier({int maxMessages = defaultMaxRecordedMessages})
      : super(DataRecorderState(maxMessages: maxMessages));

  final List<RecordedMessage> _timeline = [];
  final Map<String, List<RecordedMessage>> _buckets = {};

  /// 开始记录传入的信封。
  void startRecording() {
    if (state.isRecording) return;
    state = state.copyWith(
      isRecording: true,
      startTime: DateTime.now(),
    );
  }

  /// 停止记录传入的信封。
  void stopRecording() {
    if (!state.isRecording) return;
    state = state.copyWith(isRecording: false, stopTime: DateTime.now());
  }

  /// 如果当前处于记录状态，则保存 [envelope]。
///
  /// 超过上限时自动淘汰最早的消息。
  void recordEnvelope(ProtobufEnvelope envelope) {
    if (!state.isRecording) return;

    final message = RecordedMessage.fromEnvelope(envelope);
    _timeline.add(message);
    _buckets.putIfAbsent(message.messageType, () => []).add(message);

    if (_timeline.length > state.maxMessages) {
      _evictOldest();
    }

    state = state.copyWith(
      buckets: Map.unmodifiable(
        Map<String, List<RecordedMessage>>.from(_buckets),
      ),
      totalCount: _timeline.length,
    );
  }

  /// 清空所有已记录消息，并重置计时信息。
  void clear() {
    _timeline.clear();
    _buckets.clear();
    state = DataRecorderState(maxMessages: state.maxMessages);
  }

  void _evictOldest() {
    final oldest = _timeline.removeAt(0);
    final bucket = _buckets[oldest.messageType];
    if (bucket == null) return;
    bucket.removeAt(0);
    if (bucket.isEmpty) {
      _buckets.remove(oldest.messageType);
    }
  }
}

/// 提供 [DataRecorderNotifier] 的全局 Provider。
///
/// - MQTT 连接后自动开始记录。
/// - MQTT 断开后自动停止记录。
/// - [DataRecorderState.isRecording] 为 true 时追加每个已解析信封。
final dataRecorderProvider =
    StateNotifierProvider<DataRecorderNotifier, DataRecorderState>((ref) {
  final notifier = DataRecorderNotifier();

  ref
    ..listen<AsyncValue<ProtobufEnvelope>>(
      mqttMessageProvider,
      (_, next) {
        next.whenData((envelope) {
          // 订阅层已经按记录配置过滤；这里再做一次防护，作为“什么会被存储”的单一判断点。
          // 这样配置在会话中变更时，不需要重新订阅也能立即生效。
          if (ref.read(recordConfigProvider).isEnabled(envelope.topic)) {
            notifier.recordEnvelope(envelope);
          }
        });
      },
    )
    ..listen<AsyncValue<MqttConnectionState>>(
      mqttConnectionStateProvider,
      (_, next) {
        next.whenData((connectionState) {
          if (connectionState == MqttConnectionState.connected) {
            notifier.startRecording();
          } else {
            notifier.stopRecording();
          }
        });
      },
    );

  return notifier;
});
