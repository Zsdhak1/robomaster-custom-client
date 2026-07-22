/// MQTT Protobuf 消息解析器和分发器。
///
/// 根据 MQTT 主题名选择对应的 Protobuf 消息类型，反序列化传入载荷；
/// 未识别的主题会降级为原始字节日志，避免中断数据流。
library;

import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../generated/robomaster_custom_client.pb.dart';
import '../constants/protocol_constants.dart';

/// 未识别主题使用的降级消息类型。
const String _unknownMessageType = 'unknown';

/// 十六进制摘要最多展示的字节数。
const int _maxHexBytes = 32;

/// 已解析或未解析 MQTT Protobuf 消息的统一信封。
class ProtobufEnvelope {
  /// 创建 [ProtobufEnvelope]。
  ProtobufEnvelope({
    required this.topic,
    required this.messageType,
    required this.rawBytes,
    required this.timestamp,
    this.connectionGeneration = 0,
    this.protobufMessage,
  });

  /// MQTT 主题名称。
  final String topic;

  /// Protobuf 消息类型标识符。
  final String messageType;

  /// 原始 Protobuf 字节，用于调试和降级记录。
  final Uint8List rawBytes;

  /// 接收时间戳。
  final DateTime timestamp;

  /// 产生该消息的 MQTT 连接代次；非实时 MQTT 数据使用 0。
  final int connectionGeneration;

  /// 已解析的 Protobuf 消息实例；类型未识别时为 null。
  final GeneratedMessage? protobufMessage;

  /// 此信封是否包含已识别的消息类型。
  bool get isRecognized => protobufMessage != null;

  @override
  String toString() =>
      'ProtobufEnvelope(topic: $topic, type: $messageType, '
      'generation: $connectionGeneration, recognized: $isRecognized, '
      'bytes: ${rawBytes.length})';
}

/// 按主题名解析 MQTT 载荷。
class ProtobufParser {
  /// 创建 [ProtobufParser]，可选传入 [logger] 记录降级信息。
  ProtobufParser({this.logger});

  /// 用于记录未识别消息和解析错误的可选日志回调。
  final void Function(String)? logger;

  /// 主题名到 Protobuf 消息工厂的映射。
  static final Map<String, GeneratedMessage Function()> messageFactories = {
    topicKeyboardMouseControl: KeyboardMouseControl.new,
    topicCustomControl: CustomControl.new,
    topicGameStatus: GameStatus.new,
    topicGlobalUnitStatus: GlobalUnitStatus.new,
    topicGlobalLogisticsStatus: GlobalLogisticsStatus.new,
    topicGlobalSpecialMechanism: GlobalSpecialMechanism.new,
    topicEvent: Event.new,
    topicRobotInjuryStat: RobotInjuryStat.new,
    topicRobotRespawnStatus: RobotRespawnStatus.new,
    topicRobotStaticStatus: RobotStaticStatus.new,
    topicRobotDynamicStatus: RobotDynamicStatus.new,
    topicRobotModuleStatus: RobotModuleStatus.new,
    topicRobotPosition: RobotPosition.new,
    topicBuff: Buff.new,
    topicPenaltyInfo: PenaltyInfo.new,
    topicRobotPathPlanInfo: RobotPathPlanInfo.new,
    topicMapClickInfo: MapClickInfo.new,
    topicMapClickCmd: MapClickCmd.new,
    topicRadarInfoToClient: RadarInfoToClient.new,
    topicCustomByteBlock: CustomByteBlock.new,
    topicAssemblyCommand: AssemblyCommand.new,
    topicTechCoreMotionStateSync: TechCoreMotionStateSync.new,
    topicRobotPerformanceSelectionCommand: RobotPerformanceSelectionCommand.new,
    topicRobotPerformanceSelectionSync: RobotPerformanceSelectionSync.new,
    topicCommonCommand: CommonCommand.new,
    topicHeroDeployModeEventCommand: HeroDeployModeEventCommand.new,
    topicDeployModeStatusSync: DeployModeStatusSync.new,
    topicRuneActivateCommand: RuneActivateCommand.new,
    topicRuneStatusSync: RuneStatusSync.new,
    topicSentryStatusSync: SentryStatusSync.new,
    topicDartCommand: DartCommand.new,
    topicDartSelectTargetStatusSync: DartSelectTargetStatusSync.new,
    topicSentryCtrlCommand: SentryCtrlCommand.new,
    topicSentryCtrlResult: SentryCtrlResult.new,
    topicAirSupportCommand: AirSupportCommand.new,
    topicAirSupportStatusSync: AirSupportStatusSync.new,
  };

  /// 将在 [topic] 上收到的 [payload] 解析为 [ProtobufEnvelope]。
  ///
  /// 如果 [topic] 未识别，则返回 [ProtobufEnvelope.protobufMessage] 为 null
  /// 的信封，并记录原始字节摘要。
  ProtobufEnvelope parse(
    String topic,
    Uint8List payload, {
    DateTime? receivedAt,
    int connectionGeneration = 0,
  }) {
    final factory = messageFactories[topic];
    final timestamp = receivedAt ?? DateTime.now();

    if (factory == null) {
      logger?.call(
        'Unrecognized topic: $topic, bytes: ${_hexSummary(payload)}',
      );
      return ProtobufEnvelope(
        topic: topic,
        messageType: _unknownMessageType,
        rawBytes: payload,
        timestamp: timestamp,
        connectionGeneration: connectionGeneration,
      );
    }

    try {
      final message = factory()..mergeFromBuffer(payload);
      return ProtobufEnvelope(
        topic: topic,
        messageType: topic,
        protobufMessage: message,
        rawBytes: payload,
        timestamp: timestamp,
        connectionGeneration: connectionGeneration,
      );
    } on Exception catch (e, stackTrace) {
      logger?.call(
        'Parse error on $topic: $e\n$stackTrace, '
        'bytes: ${_hexSummary(payload)}',
      );
      return ProtobufEnvelope(
        topic: topic,
        messageType: topic,
        rawBytes: payload,
        timestamp: timestamp,
        connectionGeneration: connectionGeneration,
      );
    }
  }

  /// 返回 [data] 前 [_maxHexBytes] 字节的十六进制摘要。
  static String _hexSummary(Uint8List data) {
    final slice = data.length > _maxHexBytes
        ? data.sublist(0, _maxHexBytes)
        : data;
    final hex = slice.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    return data.length > _maxHexBytes ? '$hex... (${data.length} bytes)' : hex;
  }
}
