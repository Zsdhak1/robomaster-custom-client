/// MQTT 断开与重连通知的状态转换跟踪器。
library;

import '../../../services/mqtt_service.dart';
import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';

/// 忽略初始状态，只对曾连接后的断开和恢复产生通知。
class MqttNotificationTracker {
  MqttConnectionState? _state;
  bool _everConnected = false;

  /// 处理一次连接状态更新。
  RuleNotificationEvent? handle(MqttConnectionState next, DateTime now) {
    final previous = _state;
    if (next == MqttConnectionState.connecting) return null;
    _state = next;
    if (next == MqttConnectionState.connected) {
      final shouldNotify =
          _everConnected &&
          previous != null &&
          previous != MqttConnectionState.connected;
      _everConnected = true;
      return shouldNotify ? _connectionEvent(true, now) : null;
    }
    if (previous == MqttConnectionState.connected) {
      return _connectionEvent(false, now);
    }
    return null;
  }
}

RuleNotificationEvent _connectionEvent(bool reconnected, DateTime now) {
  return RuleNotificationEvent(
    type: reconnected
        ? NotificationEventType.mqttReconnected
        : NotificationEventType.mqttDisconnected,
    headline: reconnected ? 'MQTT 已重新连接' : 'MQTT 连接已断开',
    detail: reconnected ? '比赛数据链路恢复接收' : '正在等待自动重连，请检查网络链路',
    dedupKey: reconnected ? 'mqtt-reconnected' : 'mqtt-disconnected',
    recoveryKey: reconnected ? 'mqtt-disconnected' : null,
    occurredAt: now,
  );
}
