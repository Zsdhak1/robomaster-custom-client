/// 从所有 MQTT 状态消息聚合出的比赛状态。
///
/// 新的 Protobuf 信封到达时增量更新。
library;

import '../../../generated/robomaster_custom_client.pb.dart';

/// 带时间戳的单次状态更新快照。
class StatusSnapshot {
  /// 创建 [StatusSnapshot]。
  StatusSnapshot({required this.status, required this.timestamp});

  /// 该时间点的 [GlobalUnitStatus]。
  final GlobalUnitStatus status;

  /// 快照记录时间。
  final DateTime timestamp;
}

/// 与接收时间配对的 [event]，用于相对时间显示。
class TimedEvent {
  /// 创建 [TimedEvent]。
  TimedEvent({required this.event, required this.timestamp});

  /// 已解码的 protobuf 事件。
  final Event event;

  /// 事件接收时间。
  final DateTime timestamp;
}

/// 完整的聚合比赛状态。
class GameState {
  /// 创建空的 [GameState]。
  const GameState({
    this.gameStatus,
    this.globalUnitStatus,
    this.globalLogisticsStatus,
    this.globalSpecialMechanism,
    this.airSupportStatusSync,
    this.eventList = const [],
    this.statusHistory = const [],
    this.matchStartTime,
    this.isConnected = false,
  });

  /// 最新比赛状态（局数、得分、阶段、倒计时）。
  final GameStatus? gameStatus;

  /// 最新单位状态（血量、前哨站、机器人血量、子弹）。
  final GlobalUnitStatus? globalUnitStatus;

  /// 最新后勤状态（经济、科技等级、加密信息）。
  final GlobalLogisticsStatus? globalLogisticsStatus;

  /// 最新特殊机制状态。
  final GlobalSpecialMechanism? globalSpecialMechanism;

  /// 最新空中支援状态（无人机反制进度）。
  final AirSupportStatusSync? airSupportStatusSync;

  /// 带时间戳的最近事件，最新在前并受历史上限限制。
  final List<TimedEvent> eventList;

  /// 用于图表展示的 [GlobalUnitStatus] 历史（最近 120 秒）。
  final List<StatusSnapshot> statusHistory;

  /// 比赛进入“比赛中”阶段（阶段 4）时的墙钟时间。
  ///
  /// 用于渲染相对于比赛开始的事件时间；比赛开始前为 null。
  final DateTime? matchStartTime;

  /// MQTT 当前是否已连接。
  final bool isConnected;

  /// 创建更新指定字段后的副本。
  GameState copyWith({
    GameStatus? gameStatus,
    GlobalUnitStatus? globalUnitStatus,
    GlobalLogisticsStatus? globalLogisticsStatus,
    GlobalSpecialMechanism? globalSpecialMechanism,
    AirSupportStatusSync? airSupportStatusSync,
    List<TimedEvent>? eventList,
    List<StatusSnapshot>? statusHistory,
    DateTime? matchStartTime,
    bool? isConnected,
  }) {
    return GameState(
      gameStatus: gameStatus ?? this.gameStatus,
      globalUnitStatus: globalUnitStatus ?? this.globalUnitStatus,
      globalLogisticsStatus:
          globalLogisticsStatus ?? this.globalLogisticsStatus,
      globalSpecialMechanism:
          globalSpecialMechanism ?? this.globalSpecialMechanism,
      airSupportStatusSync: airSupportStatusSync ?? this.airSupportStatusSync,
      eventList: eventList ?? this.eventList,
      statusHistory: statusHistory ?? this.statusHistory,
      matchStartTime: matchStartTime ?? this.matchStartTime,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  /// 己方机器人占用 `robot_health` / `robot_bullets` 数组的索引 0-4，
  /// 顺序为英雄/工程/步兵3/步兵4/哨兵（协议 ID 1/2/3/4/7）。
  static const int allyRobotCount = 5;

  /// 所有己方机器人的累计剩余弹药总量。
  ///
  /// 汇总 `robot_bullets`（字段 12：己方机器人剩余累计发弹量）。
  /// 尚未收到单位状态时返回 null。
  int? get allyTotalBullets {
    final list = globalUnitStatus?.robotBullets;
    if (list == null || list.isEmpty) return null;
    var sum = 0;
    for (var i = 0; i < list.length && i < allyRobotCount; i++) {
      sum += list[i];
    }
    return sum;
  }

  /// 己方机器人总血量（`robot_health` 索引 0-4）。
  int? get allyTotalHealth {
    final list = globalUnitStatus?.robotHealth;
    if (list == null || list.isEmpty) return null;
    var sum = 0;
    for (var i = 0; i < list.length && i < allyRobotCount; i++) {
      sum += list[i];
    }
    return sum;
  }

  /// 敌方机器人总血量（`robot_health` 索引 5+）。
  int? get enemyTotalHealth {
    final list = globalUnitStatus?.robotHealth;
    if (list == null || list.length <= allyRobotCount) return null;
    var sum = 0;
    for (var i = allyRobotCount; i < list.length; i++) {
      sum += list[i];
    }
    return sum;
  }
}
