/// 敌方斩杀线的状态跟踪和通知生成。
library;

import '../../settings/domain/combat_notification_rules.dart';
import '../../settings/domain/kill_estimate_config.dart';
import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';
import 'notification_rule_models.dart';

const int _heroRobotId = 1;
const int _engineerRobotId = 2;
const int _collisionBaseDamage = 2;
const Set<int> _smallProjectileRobotIds = {3, 4, 6, 7};

/// 执行斩杀线冷却、再武装和三种阈值判定。
class KillLineNotificationTracker {
  final Map<int, bool> _armed = {};
  final Map<int, DateTime> _lastNotifiedAt = {};

  /// 处理一次敌方血量快照。
  List<RuleNotificationEvent> handle(
    UnitHealthSample sample,
    KillLineRuleConfig config,
    KillEstimateConfig estimate,
  ) {
    if (!config.enabled) return const [];
    final events = <RuleNotificationEvent>[];
    for (var index = 0; index < sample.enemyHealth.length; index++) {
      final health = sample.enemyHealth[index];
      final evaluation = _evaluate(sample, index, health, config, estimate);
      if (evaluation == null) continue;
      if (!evaluation.inside) {
        if (evaluation.rearmed) _armed[index] = true;
        continue;
      }
      if (_armed[index] == false ||
          _coolingDown(index, sample.timestamp, config)) {
        continue;
      }
      _armed[index] = false;
      _lastNotifiedAt[index] = sample.timestamp;
      events.add(_event(sample, index, health, evaluation.description));
    }
    return events;
  }

  /// 新比赛开始时清空冷却和再武装状态。
  void reset() {
    _armed.clear();
    _lastNotifiedAt.clear();
  }

  bool _coolingDown(int index, DateTime now, KillLineRuleConfig config) {
    final last = _lastNotifiedAt[index];
    return last != null &&
        now.difference(last) < Duration(seconds: config.cooldownSeconds);
  }

  _KillLineEvaluation? _evaluate(
    UnitHealthSample sample,
    int index,
    int health,
    KillLineRuleConfig config,
    KillEstimateConfig estimate,
  ) {
    if (health <= 0 || index >= notificationRobotCount) return null;
    final role = KillEstimateRobotRole.values[index];
    final metric = switch (config.mode) {
      KillLineMode.expectedProjectiles => _damageMetric(
        sample,
        index,
        health,
        config,
        estimate,
      ),
      KillLineMode.healthPercent => _healthPercentMetric(
        role,
        health,
        config,
        estimate,
      ),
      KillLineMode.fixedHealth => (
        health.toDouble(),
        config.fixedHealthThreshold.toDouble(),
        '当前 $health HP',
      ),
    };
    if (metric == null) return null;
    final (value, threshold, description) = metric;
    return _KillLineEvaluation(
      inside: value <= threshold,
      rearmed: value > threshold + config.rearmDelta,
      description: description,
    );
  }

  (double, double, String)? _damageMetric(
    UnitHealthSample sample,
    int index,
    int health,
    KillLineRuleConfig config,
    KillEstimateConfig estimate,
  ) {
    final damage = _damageFor(sample, index, estimate);
    if (damage == null) return null;
    if (damage <= 0) return (double.maxFinite, 0, '');
    if (sample.selectedRobotId % 100 == _engineerRobotId) {
      return (health.toDouble(), damage.toDouble(), '一次撞击扣血可清空当前血量');
    }
    final projectiles =
        estimate.expectedProjectilesForDamage(
          currentHealth: health,
          projectileDamage: damage.toDouble(),
        ) ??
        double.maxFinite.toInt();
    final threshold = _thresholdFor(index, config);
    return (
      projectiles.toDouble(),
      threshold.toDouble(),
      '预计还需 $projectiles 发弹丸',
    );
  }

  int? _damageFor(
    UnitHealthSample sample,
    int index,
    KillEstimateConfig estimate,
  ) {
    final selectedBaseId = sample.selectedRobotId % 100;
    final defense = _targetDefenseFraction(sample, index);
    if (selectedBaseId == _engineerRobotId) {
      return (_collisionBaseDamage * (1 - defense)).round();
    }
    final baseDamage = switch (selectedBaseId) {
      _heroRobotId => estimate.largeProjectileDamage,
      _ when _smallProjectileRobotIds.contains(selectedBaseId) =>
        estimate.smallProjectileDamage,
      _ => null,
    };
    if (baseDamage == null) return null;
    final attack =
        (sample.combatBuffs.attackLevelFor(sample.selectedRobotId) ?? 100) /
        100;
    return (baseDamage * attack * (1 - defense)).round();
  }

  double _targetDefenseFraction(UnitHealthSample sample, int index) {
    final ownBlue = sample.selectedRobotId >= 100;
    final targetRobotId = notificationRobotBaseIds[index] + (ownBlue ? 0 : 100);
    return (sample.combatBuffs.defenseLevelFor(targetRobotId) ?? 0) / 100;
  }

  int _thresholdFor(int index, KillLineRuleConfig config) => switch (index) {
    0 => config.heroThreshold,
    4 => config.sentryThreshold,
    _ => config.infantryThreshold,
  };

  (double, double, String) _healthPercentMetric(
    KillEstimateRobotRole role,
    int health,
    KillLineRuleConfig config,
    KillEstimateConfig estimate,
  ) {
    final maxHealth = estimate.maxHealth(role);
    final percent = maxHealth <= 0 ? 100.0 : health * 100 / maxHealth;
    return (
      percent,
      config.healthPercentThreshold.toDouble(),
      '当前血量 ${percent.toStringAsFixed(1)}%',
    );
  }

  RuleNotificationEvent _event(
    UnitHealthSample sample,
    int index,
    int health,
    String description,
  ) {
    final robotId = notificationRobotBaseIds[index];
    return RuleNotificationEvent(
      type: NotificationEventType.enemyKillLine,
      headline: '敌方 $robotId 号机器人进入斩杀线',
      detail: '$description · $health HP',
      dedupKey: 'enemy-kill-line-$index',
      occurredAt: sample.timestamp,
    );
  }
}

class _KillLineEvaluation {
  const _KillLineEvaluation({
    required this.inside,
    required this.rearmed,
    required this.description,
  });

  final bool inside;
  final bool rearmed;
  final String description;
}
