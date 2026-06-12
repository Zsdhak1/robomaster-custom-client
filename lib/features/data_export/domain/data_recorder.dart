/// In-memory MQTT message recorder models.
library;

import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../../core/protobuf/protobuf_parser.dart';

/// Default maximum number of recorded messages kept in memory.
const int defaultMaxRecordedMessages = 10000;

/// A single recorded MQTT message with metadata needed for export.
class RecordedMessage {
  /// Creates a [RecordedMessage].
  const RecordedMessage({
    required this.topic,
    required this.messageType,
    required this.timestamp,
    required this.rawBytes,
    this.protobufMessage,
  });

  /// Creates a [RecordedMessage] from a parsed [ProtobufEnvelope].
  factory RecordedMessage.fromEnvelope(ProtobufEnvelope envelope) {
    return RecordedMessage(
      topic: envelope.topic,
      messageType: envelope.messageType,
      timestamp: envelope.timestamp,
      rawBytes: envelope.rawBytes,
      protobufMessage: envelope.protobufMessage,
    );
  }

  /// MQTT topic on which the message was received.
  final String topic;

  /// Protobuf message type identifier (topic name for recognized types).
  final String messageType;

  /// Reception timestamp.
  final DateTime timestamp;

  /// Raw Protobuf bytes.
  final Uint8List rawBytes;

  /// Parsed Protobuf message, null when the type is unrecognized.
  final GeneratedMessage? protobufMessage;
}

/// Immutable snapshot of the recorder's current state.
class DataRecorderState {
  /// Creates a [DataRecorderState].
  const DataRecorderState({
    this.isRecording = false,
    this.maxMessages = defaultMaxRecordedMessages,
    this.buckets = const {},
    this.totalCount = 0,
    this.startTime,
    this.stopTime,
  });

  /// Whether new envelopes are currently being recorded.
  final bool isRecording;

  /// Maximum number of messages to keep before rolling eviction.
  final int maxMessages;

  /// Recorded messages grouped by [RecordedMessage.messageType].
  final Map<String, List<RecordedMessage>> buckets;

  /// Total number of recorded messages across all buckets.
  final int totalCount;

  /// Time when recording started, null if never started.
  final DateTime? startTime;

  /// Time when recording was last stopped, null if not stopped.
  final DateTime? stopTime;

  /// Duration between [startTime] and [stopTime] (or now if still recording).
  Duration? get duration {
    final start = startTime;
    if (start == null) return null;
    final end = stopTime ?? DateTime.now();
    return end.difference(start);
  }

  /// Creates a copy with selected fields updated.
  DataRecorderState copyWith({
    bool? isRecording,
    int? maxMessages,
    Map<String, List<RecordedMessage>>? buckets,
    int? totalCount,
    DateTime? startTime,
    DateTime? stopTime,
  }) {
    return DataRecorderState(
      isRecording: isRecording ?? this.isRecording,
      maxMessages: maxMessages ?? this.maxMessages,
      buckets: buckets ?? this.buckets,
      totalCount: totalCount ?? this.totalCount,
      startTime: startTime ?? this.startTime,
      stopTime: stopTime ?? this.stopTime,
    );
  }
}
