// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/combat_buff_tracker.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_models.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/module_status_monitor.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_rule_engine.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/combat_notification_rules.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/kill_estimate_config.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';

void main() {
  group('NotificationRuleEngine kill line', _registerKillLineTests);
  group('NotificationRuleEngine respawn', () {
    _registerRespawnClassificationTests();
    _registerRespawnEvidenceTests();
  });
  test('maps protocol and deploy transitions', _testTransitions);
  test(
    'maps a supplied module transition without a status snapshot',
    _testModuleTransition,
  );
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
  test('zero damage rearms the kill line', _testZeroDamageRearm);
  test('supports health percent and fixed modes', _testOtherKillLineModes);
}

void _registerRespawnClassificationTests() {
  test('classifies a normal free respawn', _testNormalFreeRespawn);
  test(
    'classifies supply-zone accelerated free respawn',
    _testSupplyZoneAcceleratedRespawn,
  );
  test(
    'classifies low-base-health accelerated free respawn',
    _testLowBaseHealthAcceleratedRespawn,
  );
  test('classifies a paid respawn', _testPaidRespawn);
  test('uses protocol robot number in enemy respawn title', _testRespawnTitle);
  test(
    'applies tolerance before classifying paid respawn',
    _testRespawnTolerance,
  );
  test(
    'keeps respawn method uncertain when timing is missing',
    _testUncertainRespawn,
  );
  test('normalizes an inverted accelerated rate', _testInvertedRespawnRates);
  test(
    'keeps classifying free respawns when buyback detection is disabled',
    _testDisabledBuybackFreeRespawns,
  );
  test(
    'keeps a paid-speed respawn uncertain when detection is disabled',
    _testDisabledBuybackPaidRespawn,
  );
}

void _registerRespawnEvidenceTests() {
  test(
    'suppresses uncertain respawns when configured',
    _testSuppressesUncertainRespawn,
  );
  test(
    'suppresses disabled paid detection when configured',
    _testSuppressesDisabledPaidDetection,
  );
  test(
    'does not suppress known free respawns',
    _testUncertainSettingDoesNotSuppressFreeRespawns,
  );
  test(
    'reports an unknown accelerated-respawn reason without base evidence',
    _testUnknownAcceleratedRespawnReason,
  );
  test(
    'keeps low base evidence across missing and high samples',
    _testLowBaseEvidencePersists,
  );
  test(
    'promotes unknown base evidence to not-low on a high sample',
    _testUnknownBaseEvidenceBecomesNotLow,
  );
  test(
    'does not penalize a later death after non-paid respawns',
    _testNonPaidRespawnsDoNotIncreasePenalty,
  );
  test(
    'applies a paid-respawn penalty to the next death',
    _testPaidRespawnIncreasesPenalty,
  );
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
  final positive = _handleKillLineForRobot(
    selectedRobotId: 3,
    targetHealth: 24,
  );
  expect(positive.single.detail, contains('预计还需 2 发弹丸'));

  for (final selectedRobotId in const [3, 4, 6, 7, 103, 104, 106, 107]) {
    final events = _handleKillLineForRobot(
      selectedRobotId: selectedRobotId,
      targetHealth: 100,
    );
    expect(events, isEmpty, reason: 'robot $selectedRobotId must use 17mm');
  }
}

void _testZeroDamageRearm() {
  final engine = NotificationRuleEngine();
  final start = DateTime(2026, 7, 22, 12);
  final first = _handleKillLineForRobot(
    engine: engine,
    timestamp: start,
    selectedRobotId: 1,
    targetHealth: 100,
  );
  final zeroDamage = _handleKillLineForRobot(
    engine: engine,
    timestamp: start.add(const Duration(seconds: 1)),
    selectedRobotId: 1,
    targetHealth: 100,
    buffs: const CombatBuffLevels(defense: {101: 100}),
  );
  final reentered = _handleKillLineForRobot(
    engine: engine,
    timestamp: start.add(const Duration(seconds: 6)),
    selectedRobotId: 1,
    targetHealth: 100,
  );

  expect(first, hasLength(1));
  expect(zeroDamage, isEmpty);
  expect(reentered, hasLength(1));
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

void _testNormalFreeRespawn() {
  final event = _enemyRespawnAfter(const Duration(seconds: 10));

  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.headline, '敌方 1 号机器人复活');
  expect(event.detail, contains('敌方复活用时 10 秒'));
  expect(event.detail, contains('推断为普通免费复活'));
}

void _testSupplyZoneAcceleratedRespawn() {
  final event = _enemyRespawnAfter(const Duration(seconds: 4));

  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.detail, contains('推断为补给区加速免费复活'));
}

void _testLowBaseHealthAcceleratedRespawn() {
  final engine = NotificationRuleEngine();
  const config = RespawnRuleConfig(toleranceMilliseconds: 0);
  final start = DateTime(2026, 7, 13, 12);
  _recordEnemyDeath(engine, start, config);
  _handle(
    engine,
    _sample(
      start.add(const Duration(seconds: 2)),
      enemy: const [0, 300, 300, 300, 600],
      enemyBaseHealth: 2000,
    ),
    config,
  );

  final event = _respawnEnemy(
    engine,
    start,
    const Duration(seconds: 4),
    config,
  );

  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.detail, contains('推断为基地低血量加速免费复活'));
}

void _testPaidRespawn() {
  final event = _enemyRespawnAfter(const Duration(seconds: 2));

  expect(event.type, NotificationEventType.enemyBoughtRespawn);
  expect(event.headline, '敌方 1 号机器人复活');
  expect(event.detail, contains('敌方复活用时 2 秒'));
  expect(event.detail, contains('推断为付费复活'));
}

void _testRespawnTitle() {
  final event = _enemyRespawnAfter(const Duration(seconds: 10), targetIndex: 4);

  expect(event.headline, '敌方 7 号机器人复活');
}

void _testRespawnTolerance() {
  const config = RespawnRuleConfig(toleranceMilliseconds: 1500);
  final event = _enemyRespawnAfter(const Duration(seconds: 1), config: config);

  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.detail, contains('推断为补给区加速免费复活'));
}

void _testUncertainRespawn() {
  final event = _enemyRespawnAfter(
    const Duration(seconds: 2),
    remainingMatchSeconds: null,
  );

  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.headline, '敌方 1 号机器人复活');
  expect(event.detail, '敌方复活用时 2 秒，复活方式不确定');
}

void _testInvertedRespawnRates() {
  const config = RespawnRuleConfig(
    normalProgressPerSecond: 4,
    acceleratedProgressPerSecond: 1,
    toleranceMilliseconds: 0,
  );
  final bounds = expectedFreeRespawnBounds(
    config: config,
    remainingMatchSeconds: 420,
    priorBuybackCount: 0,
  );
  final event = _enemyRespawnAfter(const Duration(seconds: 3), config: config);

  expect(bounds?.normal, const Duration(milliseconds: 2500));
  expect(bounds?.fastest, const Duration(milliseconds: 2500));
  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.detail, contains('推断为普通免费复活'));
}

void _testDisabledBuybackFreeRespawns() {
  const config = RespawnRuleConfig(
    buybackDetectionEnabled: false,
    toleranceMilliseconds: 0,
  );
  final normal = _enemyRespawnAfter(
    const Duration(seconds: 10),
    config: config,
  );
  final accelerated = _enemyRespawnAfter(
    const Duration(seconds: 4),
    config: config,
  );

  expect(normal.detail, contains('推断为普通免费复活'));
  expect(accelerated.detail, contains('推断为补给区加速免费复活'));
}

void _testDisabledBuybackPaidRespawn() {
  const config = RespawnRuleConfig(
    buybackDetectionEnabled: false,
    toleranceMilliseconds: 0,
  );
  final event = _enemyRespawnAfter(const Duration(seconds: 2), config: config);

  expect(event.type, NotificationEventType.enemyRespawned);
  expect(event.detail, '敌方复活用时 2 秒，复活方式不确定');
}

void _testSuppressesUncertainRespawn() {
  const config = RespawnRuleConfig(
    uncertainBehavior: UncertainBuybackBehavior.suppress,
    toleranceMilliseconds: 0,
  );

  final events = _enemyRespawnEventsAfter(
    const Duration(seconds: 2),
    config: config,
    remainingMatchSeconds: null,
  );

  expect(events, isEmpty);
}

void _testSuppressesDisabledPaidDetection() {
  const config = RespawnRuleConfig(
    buybackDetectionEnabled: false,
    uncertainBehavior: UncertainBuybackBehavior.suppress,
    toleranceMilliseconds: 0,
  );

  expect(
    _enemyRespawnEventsAfter(const Duration(seconds: 2), config: config),
    isEmpty,
  );
}

void _testUncertainSettingDoesNotSuppressFreeRespawns() {
  const config = RespawnRuleConfig(
    buybackDetectionEnabled: false,
    uncertainBehavior: UncertainBuybackBehavior.suppress,
    toleranceMilliseconds: 0,
  );

  final normal = _enemyRespawnEventsAfter(
    const Duration(seconds: 10),
    config: config,
  );
  final accelerated = _enemyRespawnEventsAfter(
    const Duration(seconds: 4),
    config: config,
  );

  expect(normal.single.detail, contains('普通免费复活'));
  expect(accelerated.single.detail, contains('补给区加速免费复活'));
}

void _testUnknownAcceleratedRespawnReason() {
  final event = _acceleratedRespawnWithBaseSamples(const [null]);

  expect(event.detail, contains('加速原因不确定'));
  expect(event.detail, isNot(contains('补给区')));
  expect(event.detail, isNot(contains('基地低血量')));
}

void _testLowBaseEvidencePersists() {
  final event = _acceleratedRespawnWithBaseSamples(const [2000, null, 5000]);

  expect(event.detail, contains('基地低血量加速免费复活'));
}

void _testUnknownBaseEvidenceBecomesNotLow() {
  final event = _acceleratedRespawnWithBaseSamples(const [null, 5000]);

  expect(event.detail, contains('补给区加速免费复活'));
}

RuleNotificationEvent _acceleratedRespawnWithBaseSamples(
  List<int?> baseHealthSamples,
) {
  final engine = NotificationRuleEngine();
  const config = RespawnRuleConfig(toleranceMilliseconds: 0);
  final start = DateTime(2026, 7, 22, 12);
  _handle(engine, _sample(start), config);
  for (var index = 0; index < baseHealthSamples.length; index++) {
    _handle(
      engine,
      _sample(
        start.add(Duration(seconds: index + 1)),
        enemy: const [0, 300, 300, 300, 600],
        enemyBaseHealth: baseHealthSamples[index],
      ),
      config,
    );
  }
  return _handle(
    engine,
    _sample(
      start.add(const Duration(seconds: 5)),
      enemyBaseHealth: baseHealthSamples.last,
    ),
    config,
  ).single;
}

void _testNonPaidRespawnsDoNotIncreasePenalty() {
  const config = RespawnRuleConfig(toleranceMilliseconds: 0);
  final cases = <({Duration elapsed, int? remaining})>[
    (elapsed: const Duration(seconds: 10), remaining: 420),
    (elapsed: const Duration(seconds: 4), remaining: 420),
    (elapsed: const Duration(seconds: 2), remaining: null),
  ];
  for (final first in cases) {
    final engine = NotificationRuleEngine();
    final start = DateTime(2026, 7, 22, 12);
    _handle(engine, _sample(start), config);
    _respawnCycle(
      engine,
      start.add(const Duration(seconds: 1)),
      first.elapsed,
      config,
      remainingMatchSeconds: first.remaining,
    );
    final second = _respawnCycle(
      engine,
      start.add(const Duration(seconds: 30)),
      const Duration(seconds: 4),
      config,
    );
    expect(second.type, NotificationEventType.enemyRespawned);
    expect(second.detail, contains('推断为补给区加速免费复活'));
  }
}

void _testPaidRespawnIncreasesPenalty() {
  const config = RespawnRuleConfig(toleranceMilliseconds: 0);
  final engine = NotificationRuleEngine();
  final start = DateTime(2026, 7, 22, 12);
  _handle(engine, _sample(start), config);
  final first = _respawnCycle(
    engine,
    start.add(const Duration(seconds: 1)),
    const Duration(seconds: 2),
    config,
  );
  final second = _respawnCycle(
    engine,
    start.add(const Duration(seconds: 30)),
    const Duration(seconds: 12),
    config,
  );

  expect(first.type, NotificationEventType.enemyBoughtRespawn);
  expect(second.type, NotificationEventType.enemyRespawned);
  expect(second.detail, contains('推断为补给区加速免费复活'));
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
  final bounds = expectedFreeRespawnBounds(
    config: config,
    remainingMatchSeconds: 320,
    priorBuybackCount: 1,
  );
  final duration = expectedFreeRespawnDuration(
    config: config,
    remainingMatchSeconds: 320,
    enemyBaseHealth: 1500,
    priorBuybackCount: 1,
  );
  expect(bounds?.normal, const Duration(seconds: 40));
  expect(bounds?.fastest, const Duration(seconds: 10));
  expect(duration, const Duration(seconds: 40));
}

RuleNotificationEvent _enemyRespawnAfter(
  Duration elapsed, {
  RespawnRuleConfig config = const RespawnRuleConfig(toleranceMilliseconds: 0),
  int? remainingMatchSeconds = 420,
  int targetIndex = 0,
}) {
  return _enemyRespawnEventsAfter(
    elapsed,
    config: config,
    remainingMatchSeconds: remainingMatchSeconds,
    targetIndex: targetIndex,
  ).single;
}

List<RuleNotificationEvent> _enemyRespawnEventsAfter(
  Duration elapsed, {
  RespawnRuleConfig config = const RespawnRuleConfig(toleranceMilliseconds: 0),
  int? remainingMatchSeconds = 420,
  int targetIndex = 0,
}) {
  final engine = NotificationRuleEngine();
  final start = DateTime(2026, 7, 13, 12);
  _recordEnemyDeath(
    engine,
    start,
    config,
    remainingMatchSeconds: remainingMatchSeconds,
    targetIndex: targetIndex,
  );
  final enemy = List<int>.from(const [500, 300, 300, 300, 600]);
  return _handle(
    engine,
    _sample(start.add(const Duration(seconds: 1)).add(elapsed), enemy: enemy),
    config,
  );
}

void _recordEnemyDeath(
  NotificationRuleEngine engine,
  DateTime start,
  RespawnRuleConfig config, {
  int? remainingMatchSeconds = 420,
  int targetIndex = 0,
}) {
  final enemy = List<int>.from(const [500, 300, 300, 300, 600]);
  enemy[targetIndex] = 0;
  _handle(engine, _sample(start), config);
  _handle(
    engine,
    _sample(
      start.add(const Duration(seconds: 1)),
      enemy: enemy,
      remainingMatchSeconds: remainingMatchSeconds,
    ),
    config,
  );
}

RuleNotificationEvent _respawnEnemy(
  NotificationRuleEngine engine,
  DateTime start,
  Duration elapsed,
  RespawnRuleConfig config,
) {
  final enemy = List<int>.from(const [500, 300, 300, 300, 600]);
  final events = _handle(
    engine,
    _sample(start.add(const Duration(seconds: 1)).add(elapsed), enemy: enemy),
    config,
  );
  return events.single;
}

RuleNotificationEvent _respawnCycle(
  NotificationRuleEngine engine,
  DateTime deathAt,
  Duration elapsed,
  RespawnRuleConfig config, {
  int? remainingMatchSeconds = 420,
}) {
  _handle(
    engine,
    _sample(
      deathAt,
      enemy: const [0, 300, 300, 300, 600],
      remainingMatchSeconds: remainingMatchSeconds,
    ),
    config,
  );
  return _handle(engine, _sample(deathAt.add(elapsed)), config).single;
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
}

void _testModuleTransition() {
  final engine = NotificationRuleEngine();
  final now = DateTime(2026, 7, 13, 12);
  final offline = ModuleStatusTransition.from(
    ModuleAvailability.online,
    const MapEntry(
      RobotModuleType.videoTransmission,
      ModuleAvailability.offline,
    ),
  );
  final recovered = ModuleStatusTransition.from(
    ModuleAvailability.offline,
    const MapEntry(
      RobotModuleType.videoTransmission,
      ModuleAvailability.online,
    ),
  );
  expect(offline, isNotNull);
  expect(recovered, isNotNull);
  final transitions = [offline, recovered].whereType<ModuleStatusTransition>();
  final events = transitions.map(
    (transition) => engine.moduleEvent(transition, now),
  );
  final eventList = events.toList(growable: false);
  expect(eventList, hasLength(2));
  final offlineEvent = eventList[0];
  final recoveryEvent = eventList[1];
  expect(offlineEvent.type, NotificationEventType.moduleDisconnected);
  expect(offlineEvent.headline, '图传模块离线');
  expect(offlineEvent.dedupKey, 'module-offline-videoTransmission');
  expect(recoveryEvent.type, NotificationEventType.moduleRecovered);
  expect(recoveryEvent.headline, '图传模块恢复在线');
  expect(recoveryEvent.recoveryKey, offlineEvent.dedupKey);
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
  NotificationRuleEngine? engine,
  DateTime? timestamp,
  int targetIndex = 0,
  CombatBuffLevels buffs = const CombatBuffLevels(),
}) {
  final enemy = List<int>.filled(notificationRobotCount, 0);
  enemy[targetIndex] = targetHealth;
  return (engine ?? NotificationRuleEngine()).handleUnitHealth(
    _sample(
      timestamp ?? DateTime(2026, 7, 22, 12),
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
  int? remainingMatchSeconds = 420,
  int? enemyBaseHealth = 5000,
}) {
  return UnitHealthSample(
    allyHealth: ally,
    enemyHealth: enemy,
    selectedRobotId: selectedRobotId,
    combatBuffs: combatBuffs,
    timestamp: timestamp,
    remainingMatchSeconds: remainingMatchSeconds,
    enemyBaseHealth: enemyBaseHealth,
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
