/// RoboMaster 自定义客户端协议（V1.3.1）的 MQTT 主题集中注册表。
///
/// 这里记录每个主题的方向、接收范围、频率和合并策略。协议总览表里的
/// “发送方/接收方”列对所有服务器到客户端主题都相同，不能据此判断数据是
/// 机器人私有还是全队广播；真正依据是每个主题的数据语义，并由 [TopicScope]
/// 明确表达。历史审计见项目记忆 `topic-receive-scope`。
library;

import '../constants/protocol_constants.dart';

/// 主题数据流相对于自定义客户端的方向。
enum TopicDirection {
  /// 服务器 → 自定义客户端（客户端接收且可记录的遥测数据）。
  serverToClient,

  /// 自定义客户端 → 服务器 / 机器人（客户端发送的控制指令）。
  clientToServer,
}

/// 服务器到客户端主题的接收范围，用于决定多客户端记录如何合并。
enum TopicScope {
  /// 同阵营客户端收到相同内容。合并时按（主题，时间戳）去重后保留一份。
  teamShared,

  /// 仅绑定到对应机器人 ID 的客户端能收到该机器人自己的数据。
  /// 合并时按机器人 ID 分组，重建全场的逐机器人明细。
  robotPrivate,

  /// 客户端发送的指令，不属于遥测记录集合。
  command,
}

/// [TopicScope] 的可读标签与说明。
extension TopicScopeLabel on TopicScope {
  /// 设置页分组标题使用的短中文标签。
  String get label => switch (this) {
        TopicScope.teamShared => '全队共享',
        TopicScope.robotPrivate => '机器人私有',
        TopicScope.command => '客户端指令',
      };

  /// 描述该接收范围在合并时的处理方式。
  String get description => switch (this) {
        TopicScope.teamShared => '同阵营任意客户端收到的内容一致，合并时取一份。',
        TopicScope.robotPrivate => '仅对应 id 客户端能收到自己那台机器人的数据，合并后拼出全场。',
        TopicScope.command => '客户端发往服务器/机器人的指令，非接收数据。',
      };
}

/// 协议主题的不可变元数据。
class TopicInfo {
  /// 创建 [TopicInfo]。
  const TopicInfo({
    required this.topic,
    required this.displayName,
    required this.purpose,
    required this.direction,
    required this.scope,
    required this.frequency,
  });

  /// MQTT 主题名，与 Protobuf 消息名和主题常量匹配。
  final String topic;

  /// UI 中显示的中文名称；当前暂与 [topic] 保持一致。
  final String displayName;

  /// 来自协议文档的简短用途说明。
  final String purpose;

  /// 相对于客户端的数据流方向。
  final TopicDirection direction;

  /// 决定合并行为的接收范围。
  final TopicScope scope;

  /// 标称发送频率或触发方式说明。
  final String frequency;

  /// 该主题是否为客户端可记录的服务器到客户端遥测数据。
  bool get isRecordable => direction == TopicDirection.serverToClient;
}

/// 完整协议主题注册表，按主题名索引。
///
/// 这是订阅/记录主题、配置页分组以及记录合并策略的唯一来源。
class TopicRegistry {
  TopicRegistry._();

  /// 按声明顺序排列的全部主题。
  static const List<TopicInfo> all = [
    // ---- 命令 (客户端 → 服务器/机器人) ----
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
    // ---- 全队共享遥测（服务器 → 客户端）----
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
    // ---- 机器人私有遥测（服务器 → 客户端，按机器人 ID 区分）----
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
    // ---- 地图点击信息（服务器 → 客户端，全队共享通知）----
    TopicInfo(
      topic: topicMapClickInfo,
      displayName: topicMapClickInfo,
      purpose: '地图点击标记信息同步',
      direction: TopicDirection.serverToClient,
      scope: TopicScope.teamShared,
      frequency: '触发式发送',
    ),
    // ---- 其余指令（客户端 → 服务器）----
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

  /// 按主题名查找 [TopicInfo]。
  static final Map<String, TopicInfo> byName = {
    for (final info in all) info.topic: info,
  };

  /// 所有可记录的服务器到客户端主题。
  static final List<TopicInfo> recordable =
      all.where((t) => t.isRecordable).toList();

  /// 按 [TopicScope] 分组的可记录主题。
  static final Map<TopicScope, List<TopicInfo>> recordableByScope = {
    for (final scope in [TopicScope.teamShared, TopicScope.robotPrivate])
      scope: recordable.where((t) => t.scope == scope).toList(),
  };

  /// 可记录主题名集合，也是默认记录/订阅集合。
  static final Set<String> recordableTopicNames =
      recordable.map((t) => t.topic).toSet();
}
