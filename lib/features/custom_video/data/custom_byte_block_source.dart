/// Data source that subscribes to the MQTT `CustomByteBlock` topic and emits
/// raw H.264 Annex-B byte chunks carried inside each message.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/protobuf/protobuf_parser.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import '../../../services/mqtt_service.dart';

/// Maximum allowed payload size for a [CustomByteBlock] message.
///
/// The protocol limits the 0x0310 custom data stream to 2.4 kbit (300 bytes)
/// at 50 Hz. Anything larger is malformed or from a different source.
const int _maxCustomByteBlockBytes = 300;

/// Emits H.264 Annex-B byte chunks received via MQTT `CustomByteBlock`.
class CustomByteBlockSource {
  /// Creates a source bound to [mqttService] and [parser].
  CustomByteBlockSource({
    required this._mqttService,
    required this._parser,
  });

  final MqttService _mqttService;
  final ProtobufParser _parser;

  /// Subscription forwarding parsed chunks into [_chunkController].
  StreamSubscription<({String topic, Uint8List payload})>? _mqttSub;

  /// Broadcast controller exposing the Annex-B chunk stream.
  final _chunkController = StreamController<Uint8List>.broadcast();

  /// Whether the source is currently subscribed.
  bool get isSubscribed => _mqttSub != null;

  /// Stream of H.264 Annex-B chunks extracted from `CustomByteBlock` messages.
  Stream<Uint8List> get chunkStream => _chunkController.stream;

  /// Starts listening to [topicCustomByteBlock].
  ///
  /// Idempotent: calling start() multiple times has no effect beyond the first.
  void start() {
    if (_mqttSub != null) return;

    _mqttService.subscribe(topicCustomByteBlock);
    _mqttSub = _mqttService.messageStream.listen(_onMqttMessage);
  }

  /// Stops listening and unsubscribes from the topic.
  void stop() {
    _mqttSub?.cancel();
    _mqttSub = null;
    _mqttService.unsubscribe(topicCustomByteBlock);
  }

  /// Releases all resources, including the broadcast [chunkStream].
  void dispose() {
    stop();
    _chunkController.close();
  }

  void _onMqttMessage(({String topic, Uint8List payload}) msg) {
    if (msg.topic != topicCustomByteBlock) return;

    final envelope = _parser.parse(msg.topic, msg.payload);
    final message = envelope.protobufMessage;
    if (message is! CustomByteBlock) {
      return;
    }

    final data = message.data;
    if (data.isEmpty) {
      return;
    }
    if (data.length > _maxCustomByteBlockBytes) {
      return;
    }

    _chunkController.add(Uint8List.fromList(data));
  }
}
