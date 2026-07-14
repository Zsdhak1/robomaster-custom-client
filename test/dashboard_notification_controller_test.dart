import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_controller.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/dashboard_notification_models.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_preferences.dart';
import 'package:robomaster_custom_client_1/features/settings/domain/notification_rule_profile.dart';

void main() {
  _testProfileApplication();
  _testRecoveryDismissal();
  _testPreviewBypassesGuards();
}

void _testProfileApplication() {
  test('applies profile severity, placement, history and cooldown', () {
    final controller = DashboardNotificationController();
    final profile = _profile(
      const NotificationDisplayConfig(
        infoPlacement: NotificationPlacement.sideBeacon,
        historyLimit: 10,
      ),
    );
    final now = DateTime(2026, 7, 13, 12);
    final event = _event(now, 'quality');

    final item = controller.showConfigured(event, profile, gamePaused: false);
    expect(item?.style, DashboardNotificationStyle.sideBeacon);
    expect(controller.state.visible, hasLength(1));
    expect(controller.state.history, hasLength(1));

    controller.showConfigured(
      _event(now.add(const Duration(seconds: 1)), 'quality'),
      profile,
      gamePaused: false,
    );
    expect(controller.state.history, hasLength(1));
    controller.dispose();
  });
}

void _testRecoveryDismissal() {
  test('recovery closes matching critical notification', () {
    final controller = DashboardNotificationController();
    final profile = _profile(const NotificationDisplayConfig());
    final now = DateTime(2026, 7, 13, 12);
    controller.showConfigured(
      RuleNotificationEvent(
        type: NotificationEventType.moduleDisconnected,
        headline: '模块断联',
        detail: '主控离线',
        dedupKey: 'module-offline-0',
        occurredAt: now,
      ),
      profile,
      gamePaused: false,
    );
    expect(controller.state.visible, hasLength(1));
    controller.showConfigured(
      RuleNotificationEvent(
        type: NotificationEventType.moduleRecovered,
        headline: '模块恢复',
        detail: '主控在线',
        dedupKey: 'module-recovered-0',
        recoveryKey: 'module-offline-0',
        occurredAt: now.add(const Duration(seconds: 10)),
      ),
      profile,
      gamePaused: false,
    );
    expect(
      controller.state.visible.any((item) => item.headline == '模块断联'),
      isFalse,
    );
    controller.dispose();
  });
}

void _testPreviewBypassesGuards() {
  test('preview bypasses disabled settings and cooldown', () {
    final controller = DashboardNotificationController();
    addTearDown(controller.dispose);
    final base = _profile(const NotificationDisplayConfig(enabled: false));
    final disabled = base
        .eventSettings[NotificationEventType.connectionQualityChanged]
        ?.copyWith(enabled: false);
    final profile = disabled == null
        ? base
        : base.withEventSetting(
            NotificationEventType.connectionQualityChanged,
            disabled,
          );
    final now = DateTime(2026, 7, 13, 12);
    final event = _event(now, 'manual-test');

    final first = controller.showPreview(
      event,
      profile,
      severityOverride: NotificationSeverity.critical,
    );
    controller.showPreview(event, profile);

    expect(first.severity, NotificationSeverity.critical);
    expect(first.style, DashboardNotificationStyle.topBanner);
    expect(controller.state.history, hasLength(2));
  });
}

NotificationRuleProfile _profile(NotificationDisplayConfig display) {
  final official = NotificationRuleProfile.official();
  final settings = {
    for (final entry in official.eventSettings.entries)
      entry.key: entry.value.copyWith(cooldownSeconds: 5),
  };
  return official.copyWith(
    isOfficial: false,
    display: display,
    eventSettings: settings,
  );
}

RuleNotificationEvent _event(DateTime now, String key) {
  return RuleNotificationEvent(
    type: NotificationEventType.connectionQualityChanged,
    headline: '连接质量变化',
    detail: 'MQTT 延迟',
    dedupKey: key,
    occurredAt: now,
  );
}
