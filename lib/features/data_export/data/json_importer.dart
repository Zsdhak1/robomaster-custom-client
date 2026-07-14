/// 已记录 MQTT 消息的 JSON 导入器。
///
/// 读取导出文件、校验 Schema 版本，并从已存储 JSON 载荷重建 [ProtobufEnvelope]。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../../core/protobuf/protobuf_parser.dart';

/// 导入兼容性要求的 Schema 版本。
const String _schemaVersion = '2.0';

/// 用于检测导出 JSON 中原始字节降级载荷的键。
const String _rawBase64Key = 'raw_base64';

/// 从 JSON 导出文件导入已记录 MQTT 数据。
class JsonImporter {
  /// 创建带主题到工厂映射 [messageFactories] 的 [JsonImporter]，用于重建 Protobuf 消息。
  JsonImporter({required this.messageFactories});

  /// 主题名到 Protobuf 消息工厂的映射。
  final Map<String, GeneratedMessage Function()> messageFactories;

  /// 读取 [filePath]，并返回重建后的信封列表。
  ///
  /// Schema 版本不支持时抛出 [FormatException]。
  /// 未识别或格式错误的消息条目会被跳过。
  Future<List<ProtobufEnvelope>> import(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final json = jsonDecode(jsonString) as Map<String, dynamic>;

    _validateSchema(json);

    final messagesJson = json['messages'] as List<dynamic>?;
    if (messagesJson == null) return [];

    return messagesJson
        .map(_parseMessage)
        .whereType<ProtobufEnvelope>()
        .toList();
  }

  void _validateSchema(Map<String, dynamic> json) {
    final version = json['schema_version'];
    if (version != _schemaVersion) {
      throw FormatException(
        '不支持的 schema 版本: $version（期望 $_schemaVersion）',
      );
    }
  }

  ProtobufEnvelope? _parseMessage(dynamic msgJson) {
    if (msgJson is! Map<String, dynamic>) return null;

    final type = msgJson['type'] as String?;
    final topic = msgJson['topic'] as String?;
    final timestampStr = msgJson['timestamp'] as String?;
    final payload = msgJson['payload'];

    if (type == null || topic == null || timestampStr == null) return null;

    final timestamp = DateTime.tryParse(timestampStr) ?? DateTime.now();
    final rawBytes = _extractRawBytes(payload);

    final factory = messageFactories[type];
    if (factory == null) {
      return ProtobufEnvelope(
        topic: topic,
        messageType: type,
        rawBytes: rawBytes ?? Uint8List(0),
        timestamp: timestamp,
      );
    }

    try {
      final message = factory()..mergeFromProto3Json(payload);
      return ProtobufEnvelope(
        topic: topic,
        messageType: type,
        protobufMessage: message,
        rawBytes: rawBytes ?? Uint8List(0),
        timestamp: timestamp,
      );
    } on Exception {
      return null;
    }
  }

  Uint8List? _extractRawBytes(Object? payload) {
    if (payload is! Map<String, dynamic>) return null;
    final rawBase64 = payload[_rawBase64Key] as String?;
    if (rawBase64 == null) return null;
    try {
      return base64Decode(rawBase64);
    } on FormatException {
      return null;
    }
  }
}
