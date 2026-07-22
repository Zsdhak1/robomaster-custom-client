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
        events.add(_allyRespawnEvent(sample, index));
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
      if (current == 0) _trackEnemyBaseHealth(index, sample, config);
      if (before == 0 && current > 0 && config.enabled) {
        events.add(_classifyEnemyRespawn(index, sample, config));
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
    final bounds = expectedFreeRespawnBounds(
      config: config,
      remainingMatchSeconds: sample.remainingMatchSeconds,
      priorBuybackCount: buybacks,
    );
    _enemyDeaths[index] = _DeathRecord(
      at: sample.timestamp,
      normalDuration: bounds?.normal,
      fastestDuration: bounds?.fastest,
      baseLowDuringDeath: _isEnemyBaseLow(sample, config),
    );
  }

  void _trackEnemyBaseHealth(
    int index,
    UnitHealthSample sample,
    RespawnRuleConfig config,
  ) {
    final death = _enemyDeaths[index];
    if (death == null || death.baseLowDuringDeath) return;
    if (!_isEnemyBaseLow(sample, config)) return;
    _enemyDeaths[index] = death.copyWith(baseLowDuringDeath: true);
  }

  bool _isEnemyBaseLow(UnitHealthSample sample, RespawnRuleConfig config) {
    final baseHealth = sample.enemyBaseHealth;
    return baseHealth != null && baseHealth <= config.lowBaseHealthThreshold;
  }

  RuleNotificationEvent _classifyEnemyRespawn(
    int index,
    UnitHealthSample sample,
    RespawnRuleConfig config,
  ) {
    final death = _enemyDeaths.remove(index);
    if (death == null) return _enemyRespawnEvent(sample, index, null, null);
    final elapsed = sample.timestamp.difference(death.at);
    final tolerance = Duration(milliseconds: config.toleranceMilliseconds);
    final method = _respawnMethod(death, elapsed, tolerance);
    final disabledPaidDetection =
        method == _EnemyRespawnMethod.paid && !config.buybackDetectionEnabled;
    if (method == null || disabledPaidDetection) {
      return _enemyRespawnEvent(sample, index, elapsed, null);
    }
    if (method == _EnemyRespawnMethod.paid) {
      _enemyBuybackCounts[index] = (_enemyBuybackCounts[index] ?? 0) + 1;
    }
    return _enemyRespawnEvent(sample, index, elapsed, method, death);
  }

  _EnemyRespawnMethod? _respawnMethod(
    _DeathRecord death,
    Duration elapsed,
    Duration tolerance,
  ) {
    final fastest = death.fastestDuration;
    final normal = death.normalDuration;
    if (fastest == null || normal == null) return null;
    final toleratedElapsed = elapsed + tolerance;
    if (toleratedElapsed < fastest) return _EnemyRespawnMethod.paid;
    if (toleratedElapsed < normal) return _EnemyRespawnMethod.accelerated;
    return _EnemyRespawnMethod.normal;
  }

  RuleNotificationEvent _allyRespawnEvent(
    UnitHealthSample sample,
    int index,
  ) {
    final name = notificationRobotName(
      index,
      sample.selectedRobotId,
      enemy: false,
    );
    return RuleNotificationEvent(
      type: NotificationEventType.allyRespawned,
      headline: '$name已复活',
      detail: '己方机器人血量恢复',
      dedupKey: 'ally-respawn-$index',
      occurredAt: sample.timestamp,
    );
  }

  RuleNotificationEvent _enemyRespawnEvent(
    UnitHealthSample sample,
    int index,
    Duration? elapsed,
    _EnemyRespawnMethod? method, [
    _DeathRecord? death,
  ]) {
    final paid = method == _EnemyRespawnMethod.paid;
    final detail = _enemyRespawnDetail(elapsed, method, death);
    final robotId = notificationRobotBaseIds[index];
    return RuleNotificationEvent(
      type: paid
          ? NotificationEventType.enemyBoughtRespawn
          : NotificationEventType.enemyRespawned,
      headline: '敌方 $robotId 号机器人复活',
      detail: detail,
      dedupKey: paid ? 'enemy-buyback-$index' : 'enemy-respawn-$index',
      occurredAt: sample.timestamp,
    );
  }

  String _enemyRespawnDetail(
    Duration? elapsed,
    _EnemyRespawnMethod? method,
    _DeathRecord? death,
  ) {
    final seconds = elapsed?.inSeconds;
    if (seconds == null || method == null) {
      final elapsedText = seconds == null ? '用时未知' : '用时 $seconds 秒';
      return '敌方复活$elapsedText，复活方式不确定';
    }
    final inference = switch (method) {
      _EnemyRespawnMethod.paid => '付费复活',
      _EnemyRespawnMethod.normal => '普通免费复活',
      _EnemyRespawnMethod.accelerated => death?.baseLowDuringDeath == true
          ? '基地低血量加速免费复活'
          : '补给区加速免费复活',
    };
    return '敌方复活用时 $seconds 秒，推断为$inference';
  }
}

/// 按普通和加速规则分别计算从战亡到免费复活的预计时长。
RespawnDurationBounds? expectedFreeRespawnBounds({
  required RespawnRuleConfig config,
  required int? remainingMatchSeconds,
  required int priorBuybackCount,
}) {
  if (remainingMatchSeconds == null) return null;
  final elapsedMatch = (config.matchDurationSeconds - remainingMatchSeconds)
      .clamp(0, config.matchDurationSeconds);
  final timeProgress = elapsedMatch ~/ config.timeDivisor;
  final buybackPenalty = priorBuybackCount * config.progressPenaltyPerBuyback;
  final requiredProgress = config.baseProgress + timeProgress + buybackPenalty;
  final fastestRate = math.max(
    config.normalProgressPerSecond,
    config.acceleratedProgressPerSecond,
  );
  return RespawnDurationBounds(
    normal: _respawnDuration(requiredProgress, config.normalProgressPerSecond),
    fastest: _respawnDuration(requiredProgress, fastestRate),
  );
}

Duration _respawnDuration(int requiredProgress, int progressPerSecond) {
  final milliseconds = (requiredProgress * 1000 / progressPerSecond).ceil();
  return Duration(milliseconds: milliseconds);
}

/// 按规则档案计算从战亡到免费复活的预计时长。
Duration? expectedFreeRespawnDuration({
  required RespawnRuleConfig config,
  required int? remainingMatchSeconds,
  required int? enemyBaseHealth,
  required int priorBuybackCount,
}) {
  return expectedFreeRespawnBounds(
    config: config,
    remainingMatchSeconds: remainingMatchSeconds,
    priorBuybackCount: priorBuybackCount,
  )?.normal;
}

class _DeathRecord {
  const _DeathRecord({
    required this.at,
    required this.normalDuration,
    required this.fastestDuration,
    required this.baseLowDuringDeath,
  });

  final DateTime at;
  final Duration? normalDuration;
  final Duration? fastestDuration;
  final bool baseLowDuringDeath;

  _DeathRecord copyWith({required bool baseLowDuringDeath}) {
    return _DeathRecord(
      at: at,
      normalDuration: normalDuration,
      fastestDuration: fastestDuration,
      baseLowDuringDeath: baseLowDuringDeath,
    );
  }
}

enum _EnemyRespawnMethod { paid, accelerated, normal }
