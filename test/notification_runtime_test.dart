import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/module_status_monitor.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/mqtt_notification_tracker.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_providers.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/notification_rule_engine.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';
import 'package:robomaster_custom_client_1/services/mqtt_service.dart';

void main() {
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
      events.any((event) =>
          event.type == NotificationEventType.moduleDisconnected &&
          event.dedupKey == 'module-offline-videoTransmission'),
      isTrue,
    );
    expect(
      monitor.state.statuses[RobotModuleType.videoTransmission],
      ModuleAvailability.offline,
    );
    expect(monitor.state.statuses[RobotModuleType.armor], ModuleAvailability.online);
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

    expect(monitor.state.statuses[RobotModuleType.armor], ModuleAvailability.offline);
    expect(monitor.state.statuses[RobotModuleType.videoTransmission], ModuleAvailability.online);
  });
}
