/// JSON 数据导入器使用的 Riverpod Provider。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../data/json_importer.dart';

/// 提供已经配置好的 [JsonImporter] 实例。
///
/// 导入器与 [ProtobufParser] 共享同一套 topic 到 Protobuf 的映射，
/// 让导出文件往返导入时仍能恢复为相同消息类型。
final jsonImporterProvider = Provider<JsonImporter>(
  (ref) => JsonImporter(messageFactories: ProtobufParser.messageFactories),
);
