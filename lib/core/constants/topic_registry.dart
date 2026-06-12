/// Central registry of every MQTT topic in the RoboMaster custom-client
/// protocol (V1.3.1), with the metadata needed to decide what to record and
/// how to merge multi-client recordings.
///
/// The "发送方/接收方" column in the protocol overview table is identical for
/// every server→client topic and therefore cannot tell private from broadcast
/// data. The real criterion is each topic's data semantics, captured here as
/// [TopicScope]. See the project memory `topic-receive-scope` for the audit.
library;

import '../constants/protocol_constants.dart';

/// Direction of a topic's data flow relative to the custom client.
enum TopicDirection {
  /// Server → custom client (telemetry the client receives and can record).
  serverToClient,

  /// Custom client → server / robot (commands the client sends).
  clientToServer,
}

/// Reception scope — who receives a given server→client topic, which decides
/// how multi-client recordings merge.
enum TopicScope {
  /// Every same-side client receives identical content. On merge: take the
  /// union and de-duplicate by (topic, timestamp); keep one copy.
  teamShared,

  /// Only the client bound to that robot id receives its own robot's data.
  /// On merge: key by robot id to reconstruct the full-field per-robot detail.
  robotPrivate,

  /// A command the client sends; not part of the telemetry recording set.
  command,
}

/// Human-readable label for a [TopicScope].
extension TopicScopeLabel on TopicScope {
  /// Short Chinese label used as a section header in the config screen.
  String get label => switch (this) {
        TopicScope.teamShared => '全队共享',
        TopicScope.robotPrivate => '机器人私有',
        TopicScope.command => '客户端指令',
      };

  /// One-line description of how this scope behaves on merge.
  String get description => switch (this) {
        TopicScope.teamShared => '同阵营任意客户端收到的内容一致，合并时取一份。',
        TopicScope.robotPrivate => '仅对应 id 客户端能收到自己那台机器人的数据，合并后拼出全场。',
        TopicScope.command => '客户端发往服务器/机器人的指令，非接收数据。',
      };
}

/// Immutable metadata describing one protocol topic.
class TopicInfo {
  /// Creates a [TopicInfo].
  const TopicInfo({
    required this.topic,
    required this.displayName,
    required this.purpose,
    required this.direction,
    required this.scope,
    required this.frequency,
  });

  /// MQTT topic name (matches the protobuf message / topic constant).
  final String topic;

  /// Chinese display name shown in the UI (same as [topic] for now).
  final String displayName;

  /// Short purpose description from the protocol document.
  final String purpose;

  /// Data-flow direction relative to the client.
  final TopicDirection direction;

  /// Reception scope governing merge behavior.
  final TopicScope scope;

  /// Nominal send frequency / trigger description.
  final String frequency;

  /// Whether this topic is telemetry the client can record (server→client).
  bool get isRecordable => direction == TopicDirection.serverToClient;
}

/// The full protocol topic registry, keyed by topic name.
///
/// Source of truth for: which topics to subscribe/record, how the config
/// screen groups them, and how the merger treats each topic.
class TopicRegistry {
  TopicRegistry._();

  /// All topics in declaration order.
  static const List<TopicInfo> all = [
    // ---- Commands (client → server/robot) ----
    TopicInfo(
      topic: topicKeyboardMouseControl,
      displayName: topicKeyboardMouseControl,
      purpose: '传输鼠标键盘输入',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '75Hz',
    ),
    TopicInfo(
      topic: topicCustomControl,
      displayName: topicCustomControl,
      purpose: '最大30字节的自定义数据',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '75Hz',
    ),
    // ---- Team-shared telemetry (server → client) ----
    TopicInfo(
      topic: topicGameStatus,
      displayName: topicGameStatus,
      purpose: '同步比赛全局状态信息',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '5Hz',
    ),
    TopicInfo(
      topic: topicGlobalUnitStatus,
      displayName: topicGlobalUnitStatus,
      purpose: '同步基地、前哨站和所有机器人状态',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicGlobalLogisticsStatus,
      displayName: topicGlobalLogisticsStatus,
      purpose: '同步全局后勤信息',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicGlobalSpecialMechanism,
      displayName: topicGlobalSpecialMechanism,
      purpose: '同步正在生效的全局特殊机制',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicEvent,
      displayName: topicEvent,
      purpose: '全局事件通知',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicPenaltyInfo,
      displayName: topicPenaltyInfo,
      purpose: '判罚信息同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicRadarInfoToClient,
      displayName: topicRadarInfoToClient,
      purpose: '雷达发送的机器人位置信息',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicTechCoreMotionStateSync,
      displayName: topicTechCoreMotionStateSync,
      purpose: '科技核心运动状态同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicDeployModeStatusSync,
      displayName: topicDeployModeStatusSync,
      purpose: '英雄部署模式状态同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicRuneStatusSync,
      displayName: topicRuneStatusSync,
      purpose: '能量机关状态同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicDartSelectTargetStatusSync,
      displayName: topicDartSelectTargetStatusSync,
      purpose: '飞镖目标选择状态同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicAirSupportStatusSync,
      displayName: topicAirSupportStatusSync,
      purpose: '空中支援状态反馈',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '1Hz',
    ),
    // ---- Robot-private telemetry (server → client, per robot id) ----
    TopicInfo(
      topic: topicRobotInjuryStat,
      displayName: topicRobotInjuryStat,
      purpose: '机器人一次存活期间累计受伤统计',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicRobotRespawnStatus,
      displayName: topicRobotRespawnStatus,
      purpose: '机器人复活状态同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicRobotStaticStatus,
      displayName: topicRobotStaticStatus,
      purpose: '机器人固定属性和配置',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicRobotDynamicStatus,
      displayName: topicRobotDynamicStatus,
      purpose: '机器人实时数据',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '10Hz',
    ),
    TopicInfo(
      topic: topicRobotModuleStatus,
      displayName: topicRobotModuleStatus,
      purpose: '机器人各模块运行状态',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicRobotPosition,
      displayName: topicRobotPosition,
      purpose: '机器人空间坐标和朝向（仅云台手客户端生效）',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicBuff,
      displayName: topicBuff,
      purpose: 'Buff 效果信息',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '获得增益触发，此后1Hz',
    ),
    TopicInfo(
      topic: topicRobotPathPlanInfo,
      displayName: topicRobotPathPlanInfo,
      purpose: '哨兵轨迹规划信息',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicRobotPerformanceSelectionSync,
      displayName: topicRobotPerformanceSelectionSync,
      purpose: '步兵/英雄性能体系状态同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicSentryStatusSync,
      displayName: topicSentryStatusSync,
      purpose: '哨兵姿态相关信息同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '1Hz',
    ),
    TopicInfo(
      topic: topicSentryCtrlResult,
      displayName: topicSentryCtrlResult,
      purpose: '哨兵控制指令结果反馈',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicCustomByteBlock,
      displayName: topicCustomByteBlock,
      purpose: '机器人自定义上传数据流（对应0x0310，原始字节）',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.robotPrivate,
      frequency: '50Hz',
    ),
    // ---- Map click info (server → client, team-shared notification) ----
    TopicInfo(
      topic: topicMapClickInfo,
      displayName: topicMapClickInfo,
      purpose: '地图点击标记信息同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '触发式发送',
    ),
    // ---- Remaining commands (client → server) ----
    TopicInfo(
      topic: topicMapClickCmd,
      displayName: topicMapClickCmd,
      purpose: '地图点击标记指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicAssemblyCommand,
      displayName: topicAssemblyCommand,
      purpose: '工程装配指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicRobotPerformanceSelectionCommand,
      displayName: topicRobotPerformanceSelectionCommand,
      purpose: '地面机器人选择性能体系或控制方式',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicCommonCommand,
      displayName: topicCommonCommand,
      purpose: '机器人多种常用指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicHeroDeployModeEventCommand,
      displayName: topicHeroDeployModeEventCommand,
      purpose: '英雄部署模式指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicRuneActivateCommand,
      displayName: topicRuneActivateCommand,
      purpose: '能量机关激活指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicDartCommand,
      displayName: topicDartCommand,
      purpose: '飞镖控制指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicSentryCtrlCommand,
      displayName: topicSentryCtrlCommand,
      purpose: '哨兵控制指令请求',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
    TopicInfo(
      topic: topicAirSupportCommand,
      displayName: topicAirSupportCommand,
      purpose: '空中支援指令',
      direction: TopicDirection.clientToServer,
      scope: TopicScope.command,
      frequency: '触发式发送',
    ),
  ];

  /// Lookup table by topic name.
  static final Map<String, TopicInfo> byName = {
    for (final info in all) info.topic: info,
  };

  /// All server→client topics that can be recorded.
  static final List<TopicInfo> recordable =
      all.where((t) => t.isRecordable).toList();

  /// Recordable topics grouped by [TopicScope] (teamShared, robotPrivate).
  static final Map<TopicScope, List<TopicInfo>> recordableByScope = {
    for (final scope in [TopicScope.teamShared, TopicScope.robotPrivate])
      scope: recordable.where((t) => t.scope == scope).toList(),
  };

  /// The set of recordable topic names — the default record/subscribe set.
  static final Set<String> recordableTopicNames =
      recordable.map((t) => t.topic).toSet();
}
