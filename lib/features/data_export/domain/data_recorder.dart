/// 内存中的 MQTT 消息记录器模型。
library;

import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../../core/protobuf/protobuf_parser.dart';

/// 内存中默认保留的最大已记录消息数。
const int defaultMaxRecordedMessages = 10000;

/// 单条已记录 MQTT 消息，包含导出所需元数据。
class RecordedMessage {
  /// 创建 [RecordedMessage]。
  const RecordedMessage({
    required this.topic,
    required this.messageType,
    required this.timestamp,
    required this.rawBytes,
    this.protobufMessage,
  });

  /// 从已解析的 [ProtobufEnvelope] 创建 [RecordedMessage]。
  factory RecordedMessage.fromEnvelope(ProtobufEnvelope envelope) {
    return RecordedMessage(
      topic: envelope.topic,
      messageType: envelope.messageType,
      timestamp: envelope.timestamp,
      rawBytes: envelope.rawBytes,
      protobufMessage: envelope.protobufMessage,
    );
  }

  /// 接收该消息的 MQTT 主题。
  final String topic;

  /// Protobuf 消息类型标识；已识别类型使用主题名。
  final String messageType;

  /// 接收时间戳。
  final DateTime timestamp;

  /// 原始 Protobuf 字节。
  final Uint8List rawBytes;

  /// 已解析 Protobuf 消息；类型未识别时为 null。
  final GeneratedMessage? protobufMessage;
}

/// 记录器当前状态的不可变快照。
class DataRecorderState {
  /// 创建 [DataRecorderState]。
  const DataRecorderState({
    this.isRecording = false,
    this.maxMessages = defaultMaxRecordedMessages,
    this.buckets = const {},
    this.totalCount = 0,
    this.startTime,
    this.stopTime,
  });

  /// 当前是否正在记录新的信封。
  final bool isRecording;

  /// 滚动淘汰前最多保留的消息数量。
  final int maxMessages;

  /// 按 [RecordedMessage.messageType] 分组的已记录消息。
  final Map<String, List<RecordedMessage>> buckets;

  /// 所有 bucket 中的已记录消息总数。
  final int totalCount;

  /// 记录启动时间；从未启动时为 null。
  final DateTime? startTime;

  /// 最近一次停止记录的时间；尚未停止时为 null。
  final DateTime? stopTime;

  /// [startTime] 与 [stopTime] 之间的持续时间；仍在记录时计算到当前时间。
  Duration? get duration {
    final start = startTime;
    if (start == null) return null;
    final end = stopTime ?? DateTime.now();
    return end.difference(start);
  }

  /// 创建更新部分字段后的副本。
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
