import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/mqtt_notification_tracker.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
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
}
