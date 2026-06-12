/// JSON importer for recorded MQTT messages.
///
/// Reads an export file, validates the schema version, and reconstructs
/// [ProtobufEnvelope]s from the stored JSON payloads.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../../core/protobuf/protobuf_parser.dart';

/// Expected schema version for import compatibility.
const String _schemaVersion = '2.0';

/// Key used to detect raw-byte fallback payloads in exported JSON.
const String _rawBase64Key = 'raw_base64';

/// Imports recorded MQTT data from a JSON export file.
class JsonImporter {
  /// Creates a [JsonImporter] with the topic-to-factory [messageFactories]
  /// used to reconstruct Protobuf messages.
  JsonImporter({required this.messageFactories});

  /// Topic name to Protobuf message factory mapping.
  final Map<String, GeneratedMessage Function()> messageFactories;

  /// Reads [filePath] and returns a list of reconstructed envelopes.
  ///
  /// Throws [FormatException] if the schema version is unsupported.
  /// Unrecognized or malformed message entries are skipped.
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
