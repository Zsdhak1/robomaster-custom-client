/// Debug message log for tracking all MQTT topic messages.
///
/// Maintains a rolling buffer of recent ProtobufEnvelope records,
/// with a max capacity to avoid unbounded memory growth.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protobuf/protobuf.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import 'stream_providers.dart';

/// A single parsed Protobuf field (name → formatted value).
class DebugField {
  /// Creates a [DebugField].
  const DebugField({required this.name, required this.value});

  /// Field name from the Protobuf definition.
  final String name;

  /// Human-readable formatted field value.
  final String value;
}

/// Single debug log entry for an MQTT message.
class DebugLogEntry {
  /// Creates a [DebugLogEntry].
  DebugLogEntry({
    required this.topic,
    required this.messageType,
    required this.rawBytes,
    required this.timestamp,
    this.isRecognized = false,
    this.fields = const [],
    this.parseError,
  });

  /// MQTT topic name.
  final String topic;

  /// Protobuf message type identifier.
  final String messageType;

  /// Raw Protobuf bytes.
  final Uint8List rawBytes;

  /// Reception timestamp.
  final DateTime timestamp;

  /// Whether the envelope type was recognized.
  final bool isRecognized;

  /// Parsed Protobuf fields (empty when unrecognized or parse failed).
  final List<DebugField> fields;

  /// Parse error message if deserialization failed.
  final String? parseError;

  /// Formatted hex string of [rawBytes].
  String get hexSummary {
    const max = 32;
    final slice = rawBytes.length > max
        ? rawBytes.sublist(0, max)
        : rawBytes;
    final hex = slice
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return rawBytes.length > max
        ? '$hex... (${rawBytes.length} bytes)'
        : hex;
  }
}

/// Maximum raw bytes to store per entry for display.
const int _maxRawBytes = 128;

/// Total maximum entries across all topics.
const int _maxTotalEntries = 500;

/// State holder for debug message logs.
class DebugMessageLog {
  /// Creates an empty [DebugMessageLog].
  const DebugMessageLog({
    this.entries = const [],
    this.topicSet = const {},
  });

  /// All log entries in chronological order.
  final List<DebugLogEntry> entries;

  /// Set of all topics that have been seen.
  final Set<String> topicSet;

  /// Returns entries filtered by [topic].
  List<DebugLogEntry> forTopic(String topic) =>
      entries.where((e) => e.topic == topic).toList();

  /// Creates a copy with a new [entry] appended.
  DebugMessageLog withEntry(DebugLogEntry entry) {
    var newEntries = [...entries, entry];
    if (newEntries.length > _maxTotalEntries) {
      newEntries = newEntries.sublist(
        newEntries.length - _maxTotalEntries,
      );
    }
    final newTopics = {...topicSet, entry.topic};
    return DebugMessageLog(
      entries: newEntries,
      topicSet: newTopics,
    );
  }

  /// Creates an empty log.
  DebugMessageLog clear() => const DebugMessageLog();
}

/// Notifier that accumulates MQTT debug messages.
class DebugMessageLogNotifier extends StateNotifier<DebugMessageLog> {
  /// Creates a [DebugMessageLogNotifier].
  DebugMessageLogNotifier() : super(const DebugMessageLog());

  /// Adds a [ProtobufEnvelope] to the log.
  void add(ProtobufEnvelope envelope) {
    final entry = DebugLogEntry(
      topic: envelope.topic,
      messageType: envelope.messageType,
      rawBytes: envelope.rawBytes.length > _maxRawBytes
          ? envelope.rawBytes.sublist(0, _maxRawBytes)
          : envelope.rawBytes,
      timestamp: envelope.timestamp,
      isRecognized: envelope.isRecognized,
      fields: _extractFields(envelope.protobufMessage),
    );
    state = state.withEntry(entry);
  }

  /// Extracts parsed fields from [message] into a flat field list.
  static List<DebugField> _extractFields(GeneratedMessage? message) {
    if (message == null) return const [];
    try {
      final json = message.toProto3Json();
      if (json is! Map) {
        return [DebugField(name: 'value', value: '$json')];
      }
      return json.entries
          .map((e) => DebugField(
                name: '${e.key}',
                value: _formatValue(e.value),
              ))
          .toList();
    } on Exception {
      return const [];
    }
  }

  /// Formats a Protobuf JSON value for compact display.
  static String _formatValue(Object? value) {
    if (value == null) return 'null';
    if (value is List) {
      if (value.isEmpty) return '[]';
      return '[${value.join(', ')}]';
    }
    if (value is Map) {
      return value.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(', ');
    }
    return '$value';
  }

  /// Clears all log entries.
  void clear() {
    state = state.clear();
  }
}

/// Provider for the debug message log notifier.
final debugMessageLogProvider =
    StateNotifierProvider<DebugMessageLogNotifier, DebugMessageLog>((ref) {
  final notifier = DebugMessageLogNotifier();

  ref.listen(mqttMessageProvider, (_, next) {
    next.whenData(notifier.add);
  });

  return notifier;
});
