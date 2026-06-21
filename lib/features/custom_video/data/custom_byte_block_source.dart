/// Data source that subscribes to the MQTT `CustomByteBlock` topic and emits
/// the H.264 Annex-B byte chunks carried inside each message.
///
/// Wire format (per the current robot firmware): each packet's
/// `CustomByteBlock.data` starts with an 8-byte uint64 little-endian sequence
/// number (incrementing by 1 per packet, used here for packet-loss detection),
/// followed by the H.264 payload. The payload itself may carry an additional
/// protobuf-style length prefix (`0x0A <varint> <payload> [padding]`), so the
/// slicing of the post-sequence body is configurable (see
/// [CustomVideoSliceMode]) and read **live** per packet — a settings change
/// applies on the next packet without a restart.
///
/// The `is_frame_start` marker is intentionally NOT used for framing here — in
/// practice the robot does not set it reliably, so gating emission on it
/// strands the stream (no chunk is ever forwarded).
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/protobuf/protobuf_parser.dart';
import '../../../features/settings/logic/settings_providers.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import '../../../services/mqtt_service.dart';
import 'custom_packet_slicer.dart';
import 'packet_sequence_tracker.dart';

/// Emits H.264 Annex-B byte chunks received via MQTT `CustomByteBlock`.
class CustomByteBlockSource {
  /// Creates a source bound to [mqttService] and [parser].
  ///
  /// The slicing behavior is supplied as live callbacks so a settings change
  /// applies on the next packet:
  /// - `sliceMode` returns the active [CustomVideoSliceMode].
  /// - `headerBytes` / `payloadBytes` feed [CustomVideoSliceMode.fixed].
  /// - `seqHeaderEnabled` toggles parsing/stripping the leading uint64 LE
  ///   sequence number used for packet-loss detection.
  CustomByteBlockSource({
    required this._mqttService,
    required this._parser,
    required this._sliceMode,
    required this._headerBytes,
    required this._payloadBytes,
    required this._seqHeaderEnabled,
  });

  final MqttService _mqttService;
  final ProtobufParser _parser;
  final CustomVideoSliceMode Function() _sliceMode;
  final int Function() _headerBytes;
  final int Function() _payloadBytes;
  final bool Function() _seqHeaderEnabled;

  StreamSubscription<({String topic, Uint8List payload})>? _mqttSub;
  final _chunkController = StreamController<Uint8List>.broadcast();

  /// Tracks the leading sequence number for packet-loss reporting.
  final _seqTracker = PacketSequenceTracker();

  // ---- Diagnostics (read by the debug panel) -----------------------------

  /// Total packets received on the topic.
  int packetsReceived = 0;

  /// Packets where a `0x0A <varint>` prefix was detected (stripPrefix mode).
  int packetsWithPrefix = 0;

  /// Packets where the declared length exceeded the bytes that arrived
  /// (truncated packet — a sign of a link/MTU problem upstream).
  int packetsTruncated = 0;

  /// The most recent packet's raw length (pre-slice).
  int lastRawLength = 0;

  /// The most recent packet's declared payload length (-1 if no prefix).
  int lastDeclaredLength = -1;

  /// The most recent packet's sequence number (uint64 LE leading 8 bytes).
  int get lastSequence => _seqTracker.lastSeq;

  /// Whether at least one sequence number has been observed.
  bool get hasSequence => _seqTracker.hasData;

  /// Packets observed via their sequence number since [start].
  int get seqPacketsSeen => _seqTracker.packetsSeen;

  /// Packets inferred lost from sequence-number gaps since [start].
  int get packetsLost => _seqTracker.packetsLost;

  /// Out-of-order / duplicate sequence numbers seen since [start].
  int get seqRegressions => _seqTracker.regressions;

  /// Packet-loss rate in [0, 1] derived from the sequence span.
  double get lossRate => _seqTracker.lossRate;

  /// Whether the source is currently subscribed.
  bool get isSubscribed => _mqttSub != null;

  /// Stream of H.264 Annex-B chunks extracted from `CustomByteBlock` messages.
  Stream<Uint8List> get chunkStream => _chunkController.stream;

  /// Starts listening to [topicCustomByteBlock]. Idempotent.
  void start() {
    if (_mqttSub != null) return;
    packetsReceived = 0;
    packetsWithPrefix = 0;
    packetsTruncated = 0;
    _seqTracker.reset();
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
    if (message is! CustomByteBlock) return;

    final rawData = message.data;
    if (rawData.isEmpty) return;

    final data = Uint8List.fromList(rawData);
    packetsReceived++;
    lastRawLength = data.length;

    // The robot prepends an 8-byte uint64 LE sequence number for loss
    // detection. Observe it for the loss counters, then strip it so the slicer
    // sees only the H.264 payload (whatever framing it carries).
    var body = data;
    if (_seqHeaderEnabled() && data.length >= customVideoSeqHeaderBytes) {
      _seqTracker.observe(data);
      body = Uint8List.sublistView(data, customVideoSeqHeaderBytes);
    }
    if (body.isEmpty) return;

    final SliceResult result;
    switch (_sliceMode()) {
      case CustomVideoSliceMode.verbatim:
        result = SliceResult(
          bytes: body,
          prefixBytes: 0,
          declaredLength: -1,
          prefixDetected: false,
        );
      case CustomVideoSliceMode.stripPrefix:
        result = stripVarintPrefix(body);
      case CustomVideoSliceMode.fixed:
        result = sliceFixed(body, _headerBytes(), _payloadBytes());
    }

    lastDeclaredLength = result.declaredLength;
    if (result.prefixDetected) packetsWithPrefix++;
    if (result.declaredLength > 0 &&
        result.declaredLength > body.length - result.prefixBytes) {
      packetsTruncated++;
    }

    if (result.bytes.isNotEmpty) {
      _chunkController.add(Uint8List.fromList(result.bytes));
    }
  }
}
