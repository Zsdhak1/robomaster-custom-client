// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_models.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_rule_engine.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/kill_estimate_config.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';

void main() {
  group('NotificationRuleEngine kill line', _registerKillLineTests);
  group('NotificationRuleEngine respawn', _registerRespawnTests);
  test('maps protocol, deploy and module transitions', _testTransitions);
}

void _registerKillLineTests() {
  test('detects projectile threshold and requires rearm', _testProjectileRearm);
  test('supports health percent and fixed modes', _testOtherKillLineModes);
}

void _registerRespawnTests() {
  test('classifies buyback and free respawn', _testRespawnClassification);
  test('detects ally respawn', _testAllyRespawn);
  test('calculates configurable free respawn duration', _testRespawnFormula);
}

void _testProjectileRearm() {
  final engine = NotificationRuleEngine();
  const config = KillLineRuleConfig(
    heroThreshold: 3,
    cooldownSeconds: 0,
    rearmDelta: 1,
  );
  final start = DateTime(2026, 7, 13, 12);
  _handleKillLine(engine, start, 500, config);
  final first = _handleKillLine(
    engine,
    start.add(const Duration(seconds: 1)),
    100,
    config,
  );
  expect(first.single.type, NotificationEventType.enemyKillLine);
  final duplicate = _handleKillLine(
    engine,
    start.add(const Duration(seconds: 2)),
    90,
    config,
  );
  expect(duplicate, isEmpty);
  _handleKillLine(engine, start.add(const Duration(seconds: 3)), 300, config);
  final rearmed = _handleKillLine(
    engine,
    start.add(const Duration(seconds: 4)),
    100,
    config,
  );
  expect(rearmed, hasLength(1));
}

void _testOtherKillLineModes() {
  final now = DateTime(2026, 7, 13, 12);
  for (final config in const [
    KillLineRuleConfig(
      mode: KillLineMode.healthPercent,
      healthPercentThreshold: 20,
    ),
    KillLineRuleConfig(
      mode: KillLineMode.fixedHealth,
      fixedHealthThreshold: 100,
    ),
  ]) {
    final events = _handleKillLine(NotificationRuleEngine(), now, 90, config);
    expect(
      events.any((event) => event.type == NotificationEventType.enemyKillLine),
      isTrue,
    );
  }
}

void _testRespawnClassification() {
  final engine = NotificationRuleEngine();
  const respawn = RespawnRuleConfig(toleranceMilliseconds: 0);
  final start = DateTime(2026, 7, 13, 12);
  _handle(engine, _sample(start), respawn);
  _handle(
    engine,
    _sample(
      start.add(const Duration(seconds: 1)),
      enemy: [0, 0, 300, 300, 600],
    ),
    respawn,
  );
  final early = _handle(
    engine,
    _sample(
      start.add(const Duration(seconds: 6)),
      enemy: [500, 0, 300, 300, 600],
    ),
    respawn,
  );
  expect(early.single.type, NotificationEventType.enemyBoughtRespawn);
  final normal = _handle(
    engine,
    _sample(start.add(const Duration(seconds: 12))),
    respawn,
  );
  expect(normal.single.type, NotificationEventType.enemyRespawned);
}

void _testAllyRespawn() {
  final engine = NotificationRuleEngine();
  final start = DateTime(2026, 7, 13, 12);
  _handle(
    engine,
    _sample(start, ally: [0, 300, 300, 300, 600]),
    const RespawnRuleConfig(),
  );
  final ally = _handle(
    engine,
    _sample(start.add(const Duration(seconds: 1))),
    const RespawnRuleConfig(),
  );
  expect(ally.single.type, NotificationEventType.allyRespawned);
}

void _testRespawnFormula() {
  const config = RespawnRuleConfig();
  final duration = expectedFreeRespawnDuration(
    config: config,
    remainingMatchSeconds: 320,
    enemyBaseHealth: 1500,
    priorBuybackCount: 1,
  );
  expect(duration, const Duration(seconds: 10));
}

void _testTransitions() {
  final engine = NotificationRuleEngine();
  final now = DateTime(2026, 7, 13, 12);
  expect(engine.observeDeployStatus(1), isFalse);
  expect(engine.observeDeployStatus(0), isFalse);
  expect(engine.observeDeployStatus(1), isTrue);
  expect(
    engine.handleProtocolEvent(eventId: 14, param: '', timestamp: now)?.type,
    NotificationEventType.enemyRequestedLevelFour,
  );
  expect(
    engine.handleProtocolEvent(eventId: 15, param: '0', timestamp: now)?.type,
    NotificationEventType.allyAssemblyCompleted,
  );
  expect(engine.handleModuleStatus(List.filled(11, 1), now), isEmpty);
  final offline = List<int>.filled(11, 1)..[7] = 0;
  expect(
    engine.handleModuleStatus(offline, now).single.type,
    NotificationEventType.moduleDisconnected,
  );
  expect(
    engine.handleModuleStatus(List.filled(11, 1), now).single.type,
    NotificationEventType.moduleRecovered,
  );
}

List<RuleNotificationEvent> _handleKillLine(
  NotificationRuleEngine engine,
  DateTime timestamp,
  int heroHealth,
  KillLineRuleConfig config,
) {
  return engine.handleUnitHealth(
    _sample(timestamp, enemy: [heroHealth, 300, 300, 300, 600]),
    killLine: config,
    respawn: const RespawnRuleConfig(enabled: false),
    estimate: const KillEstimateConfig(),
  );
}

UnitHealthSample _sample(
  DateTime timestamp, {
  List<int> ally = const [500, 300, 300, 300, 600],
  List<int> enemy = const [500, 300, 300, 300, 600],
}) {
  return UnitHealthSample(
    allyHealth: ally,
    enemyHealth: enemy,
    selectedRobotId: 1,
    timestamp: timestamp,
    remainingMatchSeconds: 420,
    enemyBaseHealth: 5000,
  );
}

List<RuleNotificationEvent> _handle(
  NotificationRuleEngine engine,
  UnitHealthSample sample,
  RespawnRuleConfig respawn,
) {
  return engine.handleUnitHealth(
    sample,
    killLine: const KillLineRuleConfig(enabled: false),
    respawn: respawn,
    estimate: const KillEstimateConfig(),
  );
}
