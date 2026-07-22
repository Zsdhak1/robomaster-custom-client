import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/combat_buff_tracker.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/module_status_monitor.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/mqtt_notification_tracker.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_rule_engine.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:robomaster_custom_client_1/services/mqtt_service.dart';

void main() {
  group('Buff protocol presence', _registerBuffPresenceTests);
  group('protocol scalar presence', _registerProtocolScalarPresenceTests);
  group('MQTT notification session fence', _registerMqttSessionFenceTests);
  group('UDP notification sampling', _registerUdpSamplingTests);
  test('notification runtime requires Buff topic', () {
    expect(notificationRequiredTopics, contains(topicBuff));
  });

  test('module mapper ignores absent protobuf fields', () {
    final reading = moduleStatusReadingFromProtocol(
      RobotModuleStatus(videoTransmission: 0, armor: 1),
    );

    expect(reading.statuses.keys, {
      RobotModuleType.videoTransmission,
      RobotModuleType.armor,
    });
    expect(reading.statuses, isNot(contains(RobotModuleType.bigShooter)));
  });

  test('module mapper treats protocol value two as offline', () {
    final reading = moduleStatusReadingFromProtocol(
      RobotModuleStatus(armor: 2),
    );

    expect(reading.statuses[RobotModuleType.armor], ModuleAvailability.offline);
  });

  test('module mapper ignores unknown protocol values', () {
    final reading = moduleStatusReadingFromProtocol(
      RobotModuleStatus(armor: 3),
    );

    expect(reading.statuses, isEmpty);
  });

  test('rule engine snapshots Buffs at the supplied envelope timestamp', () {
    final engine = NotificationRuleEngine();
    final receivedAt = DateTime(2026, 7, 22, 12);
    engine.observeBuff(
      CombatBuffSample(
        robotId: 1,
        buffType: combatAttackBuffType,
        level: 150,
        leftSeconds: 2,
        receivedAt: receivedAt,
      ),
    );

    expect(
      engine
          .combatBuffsAt(receivedAt.add(const Duration(seconds: 1)))
          .attack[1],
      150,
    );
    expect(
      engine.combatBuffsAt(receivedAt.add(const Duration(seconds: 2))).attack,
      isEmpty,
    );
  });

  test('Buff protocol mapper preserves the envelope timestamp', () {
    final engine = NotificationRuleEngine();
    final receivedAt = DateTime(2026, 7, 22, 12);

    observeBuffFromProtocol(
      engine: engine,
      buff: Buff(
        robotId: 1,
        buffType: combatAttackBuffType,
        buffLevel: 150,
        buffLeftTime: 2,
      ),
      timestamp: receivedAt,
    );

    expect(engine.combatBuffsAt(receivedAt).attack[1], 150);
  });

  test('notification match reset clears Buff and shared module state', () {
    final engine = NotificationRuleEngine();
    final monitor = ModuleStatusMonitorController();
    final now = DateTime(2026, 7, 22, 12);
    engine.observeBuff(
      CombatBuffSample(
        robotId: 1,
        buffType: combatAttackBuffType,
        level: 150,
        leftSeconds: 10,
        receivedAt: now,
      ),
    );
    monitor.observe(
      const ModuleStatusReading({
        RobotModuleType.armor: ModuleAvailability.offline,
      }),
    );

    resetNotificationMatchState(engine: engine, moduleMonitor: monitor);

    expect(engine.combatBuffsAt(now).attack, isEmpty);
    expect(engine.combatBuffsAt(now).defense, isEmpty);
    expect(monitor.state.statuses, isEmpty);
  });

  test('match reset detects a new round and every in-match exit', () {
    final inMatch = GameStatus(currentRound: 1, currentStage: stageInMatch);

    expect(
      shouldResetNotificationMatch(
        inMatch,
        GameStatus(currentRound: 2, currentStage: stageInMatch),
      ),
      isTrue,
    );
    expect(
      shouldResetNotificationMatch(
        inMatch,
        GameStatus(currentRound: 1, currentStage: stageSettlement),
      ),
      isTrue,
    );
  });

  test('match reset detects disconnect and selected identity changes', () {
    expect(
      shouldResetNotificationMatchForMqttTransition(
        MqttConnectionState.connected,
        MqttConnectionState.disconnected,
      ),
      isTrue,
    );
    expect(shouldResetNotificationMatchForIdentity(1, 101), isTrue);
  });

  test(
    'MQTT tracker ignores startup and reports disconnect then reconnect',
    () {
      final tracker = MqttNotificationTracker();
      final now = DateTime(2026, 7, 13, 12);
      expect(tracker.handle(MqttConnectionState.disconnected, now), isNull);
      expect(
        tracker.handle(
          MqttConnectionState.connected,
          now.add(const Duration(seconds: 1)),
        ),
        isNull,
      );
      final disconnected = tracker.handle(
        MqttConnectionState.disconnected,
        now.add(const Duration(seconds: 2)),
      );
      expect(disconnected?.type, NotificationEventType.mqttDisconnected);
      final reconnected = tracker.handle(
        MqttConnectionState.connected,
        now.add(const Duration(seconds: 3)),
      );
      expect(reconnected?.type, NotificationEventType.mqttReconnected);
      expect(reconnected?.recoveryKey, 'mqtt-disconnected');
    },
  );

  test('runtime module processing updates the injected monitor', () {
    final monitor = ModuleStatusMonitorController();
    final events = moduleStatusEventsFromReading(
      monitor: monitor,
      engine: NotificationRuleEngine(),
      status: RobotModuleStatus(videoTransmission: 0, armor: 1),
      timestamp: DateTime(2026, 7, 22, 12),
    );

    expect(events, hasLength(1));
    expect(
      events.any(
        (event) =>
            event.type == NotificationEventType.moduleDisconnected &&
            event.dedupKey == 'module-offline-videoTransmission',
      ),
      isTrue,
    );
    expect(
      monitor.state.statuses[RobotModuleType.videoTransmission],
      ModuleAvailability.offline,
    );
    expect(
      monitor.state.statuses[RobotModuleType.armor],
      ModuleAvailability.online,
    );
    expect(monitor.state.statuses, hasLength(2));
    expect(monitor.state.statuses, isNot(contains(RobotModuleType.bigShooter)));
    monitor.reset();
    expect(monitor.state.statuses, isEmpty);
  });

  test('RobotModuleStatus preserves scalar field presence', () {
    final status = RobotModuleStatus(videoTransmission: 0, armor: 1);

    expect(status.hasVideoTransmission(), isTrue);
    expect(status.hasArmor(), isTrue);
    expect(status.hasBigShooter(), isFalse);
  });

  test('runtime preserves an offline module omitted by a later message', () {
    final monitor = ModuleStatusMonitorController();
    final engine = NotificationRuleEngine();
    final timestamp = DateTime(2026, 7, 22, 12);
    moduleStatusEventsFromReading(
      monitor: monitor,
      engine: engine,
      status: RobotModuleStatus(armor: 0),
      timestamp: timestamp,
    );

    moduleStatusEventsFromReading(
      monitor: monitor,
      engine: engine,
      status: RobotModuleStatus(videoTransmission: 1),
      timestamp: timestamp.add(const Duration(seconds: 1)),
    );

    expect(
      monitor.state.statuses[RobotModuleType.armor],
      ModuleAvailability.offline,
    );
    expect(
      monitor.state.statuses[RobotModuleType.videoTransmission],
      ModuleAvailability.online,
    );
  });
}

void _registerProtocolScalarPresenceTests() {
  test('only maps explicitly present countdown and base health fields', () {
    expect(remainingMatchSecondsFromProtocol(GameStatus()), isNull);
    expect(enemyBaseHealthFromProtocol(GlobalUnitStatus()), isNull);
    expect(
      remainingMatchSecondsFromProtocol(GameStatus(stageCountdownSec: 0)),
      0,
    );
    expect(
      enemyBaseHealthFromProtocol(GlobalUnitStatus(enemyBaseHealth: 0)),
      0,
    );
  });
}

void _registerMqttSessionFenceTests() {
  test('rejects disconnected and stale envelopes but accepts this session', () {
    final connectedAt = DateTime(2026, 7, 22, 12);

    expect(
      shouldAcceptNotificationEnvelope(
        mqttState: MqttConnectionState.disconnected,
        connectedAt: connectedAt,
        envelopeTimestamp: connectedAt,
      ),
      isFalse,
    );
    expect(
      shouldAcceptNotificationEnvelope(
        mqttState: MqttConnectionState.connected,
        connectedAt: null,
        envelopeTimestamp: connectedAt,
      ),
      isFalse,
    );
    expect(
      shouldAcceptNotificationEnvelope(
        mqttState: MqttConnectionState.connected,
        connectedAt: connectedAt,
        envelopeTimestamp: connectedAt.subtract(
          const Duration(microseconds: 1),
        ),
      ),
      isFalse,
    );
    expect(
      shouldAcceptNotificationEnvelope(
        mqttState: MqttConnectionState.connected,
        connectedAt: connectedAt,
        envelopeTimestamp: connectedAt,
      ),
      isTrue,
    );
  });
}

void _registerUdpSamplingTests() {
  test('reset makes the next UDP sample start a fresh window', () {
    final sampler = UdpWindowSampler();
    final now = DateTime(2026, 7, 22, 12);
    expect(
      sampler.sample(now: now, received: 10, dropped: 0, windowSeconds: 5),
      isNull,
    );
    expect(
      sampler.sample(
        now: now.add(const Duration(seconds: 1)),
        received: 20,
        dropped: 10,
        windowSeconds: 5,
      ),
      50,
    );

    sampler.reset();

    expect(
      sampler.sample(
        now: now.add(const Duration(seconds: 2)),
        received: 30,
        dropped: 10,
        windowSeconds: 5,
      ),
      isNull,
    );
  });
}

void _registerBuffPresenceTests() {
  test(
    'ignores a Buff missing each required scalar field',
    _testMissingBuffFields,
  );
  test(
    'preserves explicit zero Buff values and complete samples',
    _testExplicitZeroAndCompleteBuffs,
  );
}

void _testMissingBuffFields() {
  final builders = <Buff Function()>[
    () => Buff(buffType: combatAttackBuffType, buffLevel: 25, buffLeftTime: 2),
    () => Buff(robotId: 1, buffLevel: 25, buffLeftTime: 2),
    () => Buff(robotId: 1, buffType: combatAttackBuffType, buffLeftTime: 2),
    () => Buff(robotId: 1, buffType: combatAttackBuffType, buffLevel: 25),
  ];
  for (final build in builders) {
    final engine = NotificationRuleEngine();
    final now = DateTime(2026, 7, 22, 12);
    _observeProtocolBuff(
      engine,
      Buff(
        robotId: 1,
        buffType: combatAttackBuffType,
        buffLevel: 150,
        buffLeftTime: 10,
      ),
      now,
    );
    _observeProtocolBuff(engine, build(), now.add(const Duration(seconds: 1)));
    expect(
      engine.combatBuffsAt(now.add(const Duration(seconds: 1))).attack[1],
      150,
    );
  }
}

void _testExplicitZeroAndCompleteBuffs() {
  final engine = NotificationRuleEngine();
  final now = DateTime(2026, 7, 22, 12);
  _observeProtocolBuff(
    engine,
    Buff(
      robotId: 1,
      buffType: combatAttackBuffType,
      buffLevel: 0,
      buffLeftTime: 2,
    ),
    now,
  );
  expect(engine.combatBuffsAt(now).attack[1], 0);

  _observeProtocolBuff(
    engine,
    Buff(
      robotId: 1,
      buffType: combatAttackBuffType,
      buffLevel: 0,
      buffLeftTime: 0,
    ),
    now.add(const Duration(seconds: 1)),
  );
  expect(
    engine.combatBuffsAt(now.add(const Duration(seconds: 1))).attack,
    isEmpty,
  );

  _observeProtocolBuff(
    engine,
    Buff(
      robotId: 1,
      buffType: combatDefenseBuffType,
      buffLevel: 25,
      buffLeftTime: 2,
    ),
    now.add(const Duration(seconds: 2)),
  );
  expect(
    engine.combatBuffsAt(now.add(const Duration(seconds: 2))).defense[1],
    25,
  );
}

void _observeProtocolBuff(
  NotificationRuleEngine engine,
  Buff buff,
  DateTime timestamp,
) {
  observeBuffFromProtocol(engine: engine, buff: buff, timestamp: timestamp);
}
