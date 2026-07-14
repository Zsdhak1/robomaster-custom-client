/// 通知功能使用的有状态比赛规则引擎。
library;

import 'dart:math' as math;

import '../../settings/domain/combat_notification_rules.dart';
import '../../settings/domain/kill_estimate_config.dart';
import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';
import 'kill_line_notification_tracker.dart';
import 'notification_protocol_tracker.dart';
import 'notification_rule_models.dart';

export 'notification_rule_models.dart';

/// 处理血量、比赛事件、部署状态和模块状态的规则引擎。
class NotificationRuleEngine {
  List<int>? _previousAllyHealth;
  List<int>? _previousEnemyHealth;
  final NotificationProtocolTracker _protocol = NotificationProtocolTracker();
  final KillLineNotificationTracker _killLines = KillLineNotificationTracker();
  final Map<int, _DeathRecord> _enemyDeaths = {};
  final Map<int, int> _enemyBuybackCounts = {};

  /// 处理单位血量快照并返回新产生的通知事件。
  List<RuleNotificationEvent> handleUnitHealth(
    UnitHealthSample sample, {
    required KillLineRuleConfig killLine,
    required RespawnRuleConfig respawn,
    required KillEstimateConfig estimate,
  }) {
    final events = <RuleNotificationEvent>[
      ..._detectAllyRespawns(sample),
      ..._detectEnemyDeathsAndRespawns(sample, respawn),
      ..._killLines.handle(sample, killLine, estimate),
    ];
    _previousAllyHealth = List<int>.from(sample.allyHealth);
    _previousEnemyHealth = List<int>.from(sample.enemyHealth);
    return events;
  }

  /// 处理协议全局事件，只返回通知计划中需要的事件。
  RuleNotificationEvent? handleProtocolEvent({
    required int eventId,
    required String param,
    required DateTime timestamp,
  }) {
    return _protocol.handleEvent(
      eventId: eventId,
      param: param,
      timestamp: timestamp,
    );
  }

  /// 观察英雄部署状态；仅 0→1 返回 true。
  bool observeDeployStatus(int status) {
    return _protocol.observeDeployStatus(status);
  }

  /// 检测本机各模块在线状态变化。
  List<RuleNotificationEvent> handleModuleStatus(
    List<int> statuses,
    DateTime timestamp,
  ) {
    return _protocol.handleModuleStatus(statuses, timestamp);
  }

  /// 清理跨比赛状态，避免上一场的死亡和冷却泄漏。
  void resetMatch() {
    _previousAllyHealth = null;
    _previousEnemyHealth = null;
    _protocol.resetMatch();
    _killLines.reset();
    _enemyDeaths.clear();
    _enemyBuybackCounts.clear();
  }

  List<RuleNotificationEvent> _detectAllyRespawns(UnitHealthSample sample) {
    final previous = _previousAllyHealth;
    if (previous == null) return const [];
    final events = <RuleNotificationEvent>[];
    final count = math.min(sample.allyHealth.length, previous.length);
    for (var index = 0; index < count; index++) {
      if (previous[index] == 0 && sample.allyHealth[index] > 0) {
        events.add(_respawnEvent(sample, index, enemy: false));
      }
    }
    return events;
  }

  List<RuleNotificationEvent> _detectEnemyDeathsAndRespawns(
    UnitHealthSample sample,
    RespawnRuleConfig config,
  ) {
    final previous = _previousEnemyHealth;
    if (previous == null) return const [];
    final events = <RuleNotificationEvent>[];
    final count = math.min(sample.enemyHealth.length, previous.length);
    for (var index = 0; index < count; index++) {
      final before = previous[index];
      final current = sample.enemyHealth[index];
      if (before > 0 && current == 0) _recordEnemyDeath(index, sample, config);
      if (before == 0 && current > 0 && config.enabled) {
        final event = _classifyEnemyRespawn(index, sample, config);
        if (event != null) events.add(event);
      }
    }
    return events;
  }

  void _recordEnemyDeath(
    int index,
    UnitHealthSample sample,
    RespawnRuleConfig config,
  ) {
    final buybacks = _enemyBuybackCounts[index] ?? 0;
    final expected = expectedFreeRespawnDuration(
      config: config,
      remainingMatchSeconds: sample.remainingMatchSeconds,
      enemyBaseHealth: sample.enemyBaseHealth,
      priorBuybackCount: buybacks,
    );
    _enemyDeaths[index] = _DeathRecord(
      at: sample.timestamp,
      expectedDuration: expected,
    );
  }

  RuleNotificationEvent? _classifyEnemyRespawn(
    int index,
    UnitHealthSample sample,
    RespawnRuleConfig config,
  ) {
    final death = _enemyDeaths.remove(index);
    if (death == null) return _respawnEvent(sample, index, enemy: true);
    final elapsed = sample.timestamp.difference(death.at);
    final expected = death.expectedDuration;
    if (expected == null) return _uncertainRespawn(index, sample, config);
    final tolerance = Duration(milliseconds: config.toleranceMilliseconds);
    final boughtBack = elapsed + tolerance < expected;
    if (!boughtBack || !config.buybackDetectionEnabled) {
      return _respawnEvent(sample, index, enemy: true, elapsed: elapsed);
    }
    _enemyBuybackCounts[index] = (_enemyBuybackCounts[index] ?? 0) + 1;
    return _buybackEvent(sample, index, elapsed, expected);
  }

  RuleNotificationEvent? _uncertainRespawn(
    int index,
    UnitHealthSample sample,
    RespawnRuleConfig config,
  ) {
    if (!config.buybackDetectionEnabled ||
        config.uncertainBehavior == UncertainBuybackBehavior.suppress) {
      return _respawnEvent(sample, index, enemy: true);
    }
    return RuleNotificationEvent(
      type: NotificationEventType.enemyBoughtRespawn,
      headline:
          '${notificationRobotName(index, sample.selectedRobotId, enemy: true)}疑似买活',
      detail: '缺少完整比赛时间，无法确认是否早于免费复活时刻',
      dedupKey: 'enemy-buyback-$index',
      occurredAt: sample.timestamp,
    );
  }

  RuleNotificationEvent _respawnEvent(
    UnitHealthSample sample,
    int index, {
    required bool enemy,
    Duration? elapsed,
  }) {
    final name = notificationRobotName(
      index,
      sample.selectedRobotId,
      enemy: enemy,
    );
    final prefix = enemy ? '敌方' : '己方';
    final elapsedText = elapsed == null ? '' : '，读秒 ${elapsed.inSeconds} 秒';
    return RuleNotificationEvent(
      type: enemy
          ? NotificationEventType.enemyRespawned
          : NotificationEventType.allyRespawned,
      headline: '$name已复活',
      detail: '$prefix机器人血量恢复$elapsedText',
      dedupKey: '${enemy ? 'enemy' : 'ally'}-respawn-$index',
      occurredAt: sample.timestamp,
    );
  }

  RuleNotificationEvent _buybackEvent(
    UnitHealthSample sample,
    int index,
    Duration elapsed,
    Duration expected,
  ) {
    final name = notificationRobotName(
      index,
      sample.selectedRobotId,
      enemy: true,
    );
    return RuleNotificationEvent(
      type: NotificationEventType.enemyBoughtRespawn,
      headline: '$name买活',
      detail: '战亡 ${elapsed.inSeconds} 秒恢复，免费复活预计需 ${expected.inSeconds} 秒',
      dedupKey: 'enemy-buyback-$index',
      occurredAt: sample.timestamp,
    );
  }
}

/// 按规则档案计算从战亡到免费复活的预计时长。
Duration? expectedFreeRespawnDuration({
  required RespawnRuleConfig config,
  required int? remainingMatchSeconds,
  required int? enemyBaseHealth,
  required int priorBuybackCount,
}) {
  if (remainingMatchSeconds == null) return null;
  final elapsedMatch = (config.matchDurationSeconds - remainingMatchSeconds)
      .clamp(0, config.matchDurationSeconds);
  final timeProgress = elapsedMatch ~/ config.timeDivisor;
  final buybackPenalty = priorBuybackCount * config.progressPenaltyPerBuyback;
  final requiredProgress = config.baseProgress + timeProgress + buybackPenalty;
  final accelerated =
      enemyBaseHealth != null &&
      enemyBaseHealth <= config.lowBaseHealthThreshold;
  final rate = accelerated
      ? config.acceleratedProgressPerSecond
      : config.normalProgressPerSecond;
  final milliseconds = (requiredProgress * 1000 / rate).ceil();
  return Duration(milliseconds: milliseconds);
}

class _DeathRecord {
  const _DeathRecord({required this.at, required this.expectedDuration});

  final DateTime at;
  final Duration? expectedDuration;
}
