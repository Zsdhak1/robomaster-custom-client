/// 用于追踪所有 MQTT 主题消息的调试日志。
///
/// 维护最近 ProtobufEnvelope 记录的滚动缓冲区，并设置容量上限以避免内存无界增长。
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:protobuf/protobuf.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import 'stream_providers.dart';

/// 单个已解析 Protobuf 字段，包含名称和格式化后的值。
class DebugField {
  /// 创建 [DebugField]。
  const DebugField({required this.name, required this.value});

  /// 来自 Protobuf 定义的字段名称。
  final String name;

  /// 格式化后的可读字段值。
  final String value;
}

/// 单条 MQTT 消息对应的调试日志条目。
class DebugLogEntry {
  /// 创建 [DebugLogEntry]。
  DebugLogEntry({
    required this.topic,
    required this.messageType,
    required this.rawBytes,
    required this.timestamp,
    this.isRecognized = false,
    this.fields = const [],
    this.parseError,
  });

  /// MQTT 主题名称。
  final String topic;

  /// Protobuf 消息类型标识符。
  final String messageType;

  /// 原始 Protobuf 字节。
  final Uint8List rawBytes;

  /// 接收时间戳。
  final DateTime timestamp;

  /// 信封类型是否已识别。
  final bool isRecognized;

  /// 已解析的 Protobuf 字段；未识别或解析失败时为空。
  final List<DebugField> fields;

  /// 反序列化失败时的解析错误消息。
  final String? parseError;

  /// [rawBytes] 的格式化十六进制字符串。
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

/// 每条记录最多保存用于显示的原始字节数。
const int _maxRawBytes = 128;

/// 所有主题合计最多保存的条目数。
const int _maxTotalEntries = 500;

/// 调试消息日志的状态持有者。
class DebugMessageLog {
  /// 创建空的 [DebugMessageLog]。
  const DebugMessageLog({
    this.entries = const [],
    this.topicSet = const {},
  });

  /// 按时间顺序排列的所有日志条目。
  final List<DebugLogEntry> entries;

  /// 已见过的所有主题集合。
  final Set<String> topicSet;

  /// 返回按 [topic] 过滤后的条目。
  List<DebugLogEntry> forTopic(String topic) =>
      entries.where((e) => e.topic == topic).toList();

  /// 创建追加 [entry] 后的副本。
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

  /// 创建空日志。
  DebugMessageLog clear() => const DebugMessageLog();
}

/// 累积 MQTT 调试消息的通知器。
class DebugMessageLogNotifier extends StateNotifier<DebugMessageLog> {
  /// 创建 [DebugMessageLogNotifier]。
  DebugMessageLogNotifier() : super(const DebugMessageLog());

  /// 将 [ProtobufEnvelope] 添加到日志。
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

  /// 从 [message] 提取已解析字段，并展平为字段列表。
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

  /// 将 Protobuf JSON 值格式化为紧凑显示文本。
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

  /// 清空所有日志条目。
  void clear() {
    state = state.clear();
  }
}

/// 调试消息日志通知器使用的 Provider。
final debugMessageLogProvider =
    StateNotifierProvider<DebugMessageLogNotifier, DebugMessageLog>((ref) {
  final notifier = DebugMessageLogNotifier();

  ref.listen(mqttMessageProvider, (_, next) {
    next.whenData(notifier.add);
  });

  return notifier;
});
