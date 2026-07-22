// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/combat_buff_tracker.dart';
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
  test(
    'uses logged-in weapon and combat buffs for kill line',
    _testOperatorWeaponAndBuffs,
  );
  test(
    'maps enemy defense buffs for both alliances',
    _testEnemyAllianceMapping,
  );
  test(
    'engineer uses defense-adjusted collision damage',
    _testEngineerCollision,
  );
  test(
    'hero keeps 42mm damage against engineer target',
    _testHeroWeaponAgainstEngineer,
  );
  test('infantry and sentry use 17mm damage', _testSmallProjectileRoles);
  test(
    'engineer collision ignores attack buff and zero damage',
    _testEngineerCollisionBoundaries,
  );
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
  _handleKillLine(engine, start.add(const Duration(seconds: 3)), 500, config);
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

void _testOperatorWeaponAndBuffs() {
  final events = _handleKillLineForRobot(
    selectedRobotId: 1,
    targetHealth: 180,
    buffs: const CombatBuffLevels(attack: {1: 150}, defense: {101: 25}),
  );

  expect(events.single.headline, '敌方 1 号机器人进入斩杀线');
  expect(events.single.detail, contains('预计还需 2 发弹丸'));
}

void _testEnemyAllianceMapping() {
  final redEvents = _handleKillLineForRobot(
    selectedRobotId: 1,
    targetHealth: 180,
    buffs: const CombatBuffLevels(attack: {1: 150}, defense: {101: 25}),
  );
  final blueEvents = _handleKillLineForRobot(
    selectedRobotId: 101,
    targetHealth: 180,
    buffs: const CombatBuffLevels(attack: {101: 150}, defense: {1: 25}),
  );

  expect(redEvents.single.detail, contains('预计还需 2 发弹丸'));
  expect(blueEvents.single.detail, contains('预计还需 2 发弹丸'));
}

void _testEngineerCollision() {
  final events = _handleKillLineForRobot(
    selectedRobotId: 2,
    targetHealth: 1,
    buffs: const CombatBuffLevels(defense: {101: 50}),
  );

  expect(events.single.detail, contains('一次撞击扣血可清空当前血量'));
}

void _testHeroWeaponAgainstEngineer() {
  final events = _handleKillLineForRobot(
    selectedRobotId: 1,
    targetIndex: 1,
    targetHealth: 200,
  );

  expect(events.single.detail, contains('预计还需 2 发弹丸'));
}

void _testSmallProjectileRoles() {
  for (final selectedRobotId in const [3, 4, 6, 7, 103, 104, 106, 107]) {
    final events = _handleKillLineForRobot(
      selectedRobotId: selectedRobotId,
      targetHealth: 100,
    );
    expect(events, isEmpty, reason: 'robot $selectedRobotId must use 17mm');
  }
}

void _testEngineerCollisionBoundaries() {
  final attackBuffed = _handleKillLineForRobot(
    selectedRobotId: 2,
    targetHealth: 3,
    buffs: const CombatBuffLevels(attack: {2: 1000}),
  );
  final roundedToZero = _handleKillLineForRobot(
    selectedRobotId: 2,
    targetHealth: 1,
    buffs: const CombatBuffLevels(defense: {101: 99}),
  );

  expect(attackBuffed, isEmpty);
  expect(roundedToZero, isEmpty);
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

List<RuleNotificationEvent> _handleKillLineForRobot({
  required int selectedRobotId,
  required int targetHealth,
  int targetIndex = 0,
  CombatBuffLevels buffs = const CombatBuffLevels(),
}) {
  final enemy = List<int>.filled(notificationRobotCount, 0);
  enemy[targetIndex] = targetHealth;
  return NotificationRuleEngine().handleUnitHealth(
    _sample(
      DateTime(2026, 7, 22, 12),
      enemy: enemy,
      selectedRobotId: selectedRobotId,
      combatBuffs: buffs,
    ),
    killLine: const KillLineRuleConfig(),
    respawn: const RespawnRuleConfig(enabled: false),
    estimate: const KillEstimateConfig(),
  );
}

UnitHealthSample _sample(
  DateTime timestamp, {
  List<int> ally = const [500, 300, 300, 300, 600],
  List<int> enemy = const [500, 300, 300, 300, 600],
  int selectedRobotId = 1,
  CombatBuffLevels combatBuffs = const CombatBuffLevels(),
}) {
  return UnitHealthSample(
    allyHealth: ally,
    enemyHealth: enemy,
    selectedRobotId: selectedRobotId,
    combatBuffs: combatBuffs,
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
