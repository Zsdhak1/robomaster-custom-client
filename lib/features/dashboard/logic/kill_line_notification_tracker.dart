/// 敌方斩杀线的状态跟踪和通知生成。
library;

import '../../settings/domain/combat_notification_rules.dart';
import '../../settings/domain/kill_estimate_config.dart';
import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';
import 'notification_rule_models.dart';

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
      final evaluation = _evaluate(index, health, config, estimate);
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
    int index,
    int health,
    KillLineRuleConfig config,
    KillEstimateConfig estimate,
  ) {
    if (health <= 0 || index >= notificationRobotCount) return null;
    final role = KillEstimateRobotRole.values[index];
    final (value, threshold, description) = switch (config.mode) {
      KillLineMode.expectedProjectiles => _projectileMetric(
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
    return _KillLineEvaluation(
      inside: value <= threshold,
      rearmed: value > threshold + config.rearmDelta,
      description: description,
    );
  }

  (double, double, String) _projectileMetric(
    int index,
    int health,
    KillLineRuleConfig config,
    KillEstimateConfig estimate,
  ) {
    final projectiles =
        estimate.expectedProjectiles(
          currentHealth: health,
          useLargeProjectile: index == 0,
        ) ??
        double.maxFinite.toInt();
    final threshold = switch (index) {
      0 => config.heroThreshold,
      4 => config.sentryThreshold,
      _ => config.infantryThreshold,
    };
    return (
      projectiles.toDouble(),
      threshold.toDouble(),
      '预计 $projectiles 发可击杀',
    );
  }

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
    final name = notificationRobotName(
      index,
      sample.selectedRobotId,
      enemy: true,
    );
    return RuleNotificationEvent(
      type: NotificationEventType.enemyKillLine,
      headline: '$name进入斩杀线',
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
