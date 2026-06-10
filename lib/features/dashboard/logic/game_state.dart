/// Aggregated game state from all MQTT status messages.
///
/// Updated incrementally as new Protobuf envelopes arrive.
library;

import '../../../generated/robomaster_custom_client.pb.dart';

/// Snapshot of a single status update with timestamp.
class StatusSnapshot {
  /// Creates a [StatusSnapshot].
  StatusSnapshot({required this.status, required this.timestamp});

  /// The [GlobalUnitStatus] at this point in time.
  final GlobalUnitStatus status;

  /// When this snapshot was recorded.
  final DateTime timestamp;
}

/// An [Event] paired with its reception time for relative-time display.
class TimedEvent {
  /// Creates a [TimedEvent].
  TimedEvent({required this.event, required this.timestamp});

  /// The decoded protobuf event.
  final Event event;

  /// When this event was received.
  final DateTime timestamp;
}

/// Complete aggregated game state.
class GameState {
  /// Creates an empty [GameState].
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

  /// Latest game status (round, score, stage, countdown).
  final GameStatus? gameStatus;

  /// Latest unit status (health, outpost, robot health, bullets).
  final GlobalUnitStatus? globalUnitStatus;

  /// Latest logistics status (economy, tech level, encryption).
  final GlobalLogisticsStatus? globalLogisticsStatus;

  /// Latest special mechanism status.
  final GlobalSpecialMechanism? globalSpecialMechanism;

  /// Latest air support status (drone counter-progress).
  final AirSupportStatusSync? airSupportStatusSync;

  /// Recent events with timestamps (max history, newest first).
  final List<TimedEvent> eventList;

  /// History of [GlobalUnitStatus] for charting (last 120 seconds).
  final List<StatusSnapshot> statusHistory;

  /// Wall-clock time when the match entered the "比赛中" stage (stage 4).
  ///
  /// Used to render event times relative to match start. Null until the
  /// match begins.
  final DateTime? matchStartTime;

  /// Whether MQTT is currently connected.
  final bool isConnected;

  /// Creates a copy with selected fields updated.
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

  /// Ally robots occupy indices 0-4 of the robot_health / robot_bullets
  /// arrays, ordered 英雄/工程/步兵3/步兵4/哨兵 (protocol ids 1/2/3/4/7).
  static const int allyRobotCount = 5;

  /// Total accumulated allowed ammo across all ally robots.
  ///
  /// Sums `robot_bullets` (字段12: 己方机器人剩余累计发弹量). Returns null
  /// when no unit status has been received yet.
  int? get allyTotalBullets {
    final list = globalUnitStatus?.robotBullets;
    if (list == null || list.isEmpty) return null;
    var sum = 0;
    for (var i = 0; i < list.length && i < allyRobotCount; i++) {
      sum += list[i];
    }
    return sum;
  }

  /// Total health of ally robots (indices 0-4 of robot_health).
  int? get allyTotalHealth {
    final list = globalUnitStatus?.robotHealth;
    if (list == null || list.isEmpty) return null;
    var sum = 0;
    for (var i = 0; i < list.length && i < allyRobotCount; i++) {
      sum += list[i];
    }
    return sum;
  }

  /// Total health of enemy robots (indices 5+ of robot_health).
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
