/// Riverpod provider for the MQTT data recorder.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../../services/mqtt_service.dart';
import '../../dashboard/logic/stream_providers.dart';
import '../../settings/logic/record_config_provider.dart';
import '../domain/data_recorder.dart';

/// Records MQTT [ProtobufEnvelope]s into memory-bucketed history.
///
/// Messages are kept in chronological order and grouped by message type.
/// When the total count exceeds [DataRecorderState.maxMessages] the oldest
/// message is evicted.
class DataRecorderNotifier extends StateNotifier<DataRecorderState> {
  /// Creates a [DataRecorderNotifier] with an optional [maxMessages] cap.
  DataRecorderNotifier({int maxMessages = defaultMaxRecordedMessages})
      : super(DataRecorderState(maxMessages: maxMessages));

  final List<RecordedMessage> _timeline = [];
  final Map<String, List<RecordedMessage>> _buckets = {};

  /// Starts recording incoming envelopes.
  void startRecording() {
    if (state.isRecording) return;
    state = state.copyWith(
      isRecording: true,
      startTime: DateTime.now(),
    );
  }

  /// Stops recording incoming envelopes.
  void stopRecording() {
    if (!state.isRecording) return;
    state = state.copyWith(isRecording: false, stopTime: DateTime.now());
  }

  /// Records [envelope] if currently recording.
  ///
  /// Automatically evicts the oldest message when the cap is exceeded.
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

  /// Clears all recorded messages and resets timing.
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

/// Global provider for the [DataRecorderNotifier].
///
/// - Starts recording automatically when MQTT connects.
/// - Stops recording when MQTT disconnects.
/// - Appends every parsed envelope while [DataRecorderState.isRecording] is true.
final dataRecorderProvider =
    StateNotifierProvider<DataRecorderNotifier, DataRecorderState>((ref) {
  final notifier = DataRecorderNotifier();

  ref
    ..listen<AsyncValue<ProtobufEnvelope>>(
      mqttMessageProvider,
      (_, next) {
        next.whenData((envelope) {
          // Subscription is already filtered by the record config, but guard
          // here too: this is the single source of truth for what gets stored,
          // so config changes mid-session take effect without re-subscribing.
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
