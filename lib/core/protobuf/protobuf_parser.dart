/// MQTT Protobuf message parser and dispatcher.
///
/// Maps MQTT topic names to their corresponding Protobuf message types,
/// deserializes incoming payloads, and falls back to raw bytes logging
/// for unrecognized topics.
library;

import 'dart:typed_data';

import 'package:protobuf/protobuf.dart';

import '../../generated/robomaster_custom_client.pb.dart';
import '../constants/protocol_constants.dart';

/// Fallback message type for unrecognized topics.
const String _unknownMessageType = 'unknown';

/// Maximum bytes to display in hex summary.
const int _maxHexBytes = 32;

/// Envelope wrapping a parsed (or unparsed) MQTT Protobuf message.
class ProtobufEnvelope {
  /// Creates a [ProtobufEnvelope].
  ProtobufEnvelope({
    required this.topic,
    required this.messageType,
    required this.rawBytes,
    required this.timestamp,
    this.protobufMessage,
  });

  /// MQTT topic name.
  final String topic;

  /// Protobuf message type identifier.
  final String messageType;

  /// Raw Protobuf bytes (for debugging and fallback).
  final Uint8List rawBytes;

  /// Reception timestamp.
  final DateTime timestamp;

  /// Parsed Protobuf message instance (null if type unrecognized).
  final GeneratedMessage? protobufMessage;

  /// Whether this envelope contains a recognized message type.
  bool get isRecognized => protobufMessage != null;

  @override
  String toString() =>
      'ProtobufEnvelope(topic: $topic, type: $messageType, '
      'recognized: $isRecognized, bytes: ${rawBytes.length})';
}

/// Parses MQTT payloads based on topic name.
class ProtobufParser {
  /// Creates a [ProtobufParser] with optional [logger].
  ProtobufParser({this.logger});

  /// Optional logger for unrecognized messages and parse errors.
  final void Function(String)? logger;

  /// Topic name to Protobuf message factory mapping.
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
    topicRobotPerformanceSelectionCommand:
        RobotPerformanceSelectionCommand.new,
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

  /// Parses [payload] received on [topic] into a [ProtobufEnvelope].
  ///
  /// If [topic] is unrecognized, returns an envelope with
  /// [ProtobufEnvelope.protobufMessage] set to null and logs the raw bytes.
  ProtobufEnvelope parse(String topic, Uint8List payload) {
    final factory = messageFactories[topic];

    if (factory == null) {
      logger?.call(
        'Unrecognized topic: $topic, bytes: ${_hexSummary(payload)}',
      );
      return ProtobufEnvelope(
        topic: topic,
        messageType: _unknownMessageType,
        rawBytes: payload,
        timestamp: DateTime.now(),
      );
    }

    try {
      final message = factory()..mergeFromBuffer(payload);
      return ProtobufEnvelope(
        topic: topic,
        messageType: topic,
        protobufMessage: message,
        rawBytes: payload,
        timestamp: DateTime.now(),
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
        timestamp: DateTime.now(),
      );
    }
  }

  /// Returns a hex string summary of [data] (first [_maxHexBytes] bytes).
  static String _hexSummary(Uint8List data) {
    final slice =
        data.length > _maxHexBytes ? data.sublist(0, _maxHexBytes) : data;
    final hex = slice
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return data.length > _maxHexBytes
        ? '$hex... (${data.length} bytes)'
        : hex;
  }
}
