/// 将实时协议事件映射为仪表盘通知内容。
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import '../../settings/domain/notification_preferences.dart';
import '../../settings/domain/notification_rule_profile.dart';
import 'dashboard_notification_models.dart';
import 'event_decoder.dart';

/// 根据协议 [event] 构建面向用户的仪表盘通知。
DashboardNotificationContent notificationFromEvent(Event event) {
  final decoded = decodeEvent(event.eventId, event.param);
  return DashboardNotificationContent(
    headline: decoded.title,
    detail: decoded.detail,
    badge: _badgeForCategory(decoded.category),
    icon: decoded.icon,
    accentColor: _accentForCategory(decoded.category),
  );
}

/// 按当前规则档案把 [event] 转为可显示通知内容。
DashboardNotificationContent notificationFromRuleEvent(
  RuleNotificationEvent event,
  NotificationRuleProfile profile,
) {
  final setting =
      profile.eventSettings[event.type] ?? const NotificationEventSetting();
  final severity = setting.severity;
  final display = profile.display;
  final placement = severity == NotificationSeverity.critical
      ? display.criticalPlacement
      : display.infoPlacement;
  final durationSeconds = severity == NotificationSeverity.critical
      ? display.criticalDurationSeconds
      : display.infoDurationSeconds;
  return DashboardNotificationContent(
    headline: event.headline,
    detail: event.detail,
    badge: severity == NotificationSeverity.critical ? 'CRITICAL' : 'INFO',
    icon: _iconForType(event.type),
    accentColor: _accentForSeverity(severity),
    eventType: event.type,
    severity: severity,
    style: _styleForPlacement(placement),
    requiresAcknowledgement: setting.requiresAcknowledgement,
    autoDismiss: _shouldAutoDismiss(severity, setting, display),
    dedupKey: event.dedupKey,
    duration: Duration(seconds: durationSeconds),
  );
}

DashboardNotificationStyle _styleForPlacement(NotificationPlacement placement) {
  return switch (placement) {
    NotificationPlacement.topBanner => DashboardNotificationStyle.topBanner,
    NotificationPlacement.rightCorner => DashboardNotificationStyle.rightCorner,
    NotificationPlacement.sideBeacon => DashboardNotificationStyle.sideBeacon,
  };
}

bool _shouldAutoDismiss(
  NotificationSeverity severity,
  NotificationEventSetting setting,
  NotificationDisplayConfig display,
) {
  if (setting.requiresAcknowledgement) return false;
  if (severity == NotificationSeverity.info) return true;
  return display.criticalDismissMode == CriticalDismissMode.timed;
}

IconData _iconForType(NotificationEventType type) => switch (type) {
  NotificationEventType.mqttDisconnected => Icons.link_off_rounded,
  NotificationEventType.mqttReconnected => Icons.link_rounded,
  NotificationEventType.connectionQualityChanged => Icons.network_check,
  NotificationEventType.allyAssemblyCompleted => Icons.build_circle_outlined,
  NotificationEventType.allyRespawned => Icons.favorite_rounded,
  NotificationEventType.heroDeployAutoNavigation => Icons.visibility_rounded,
  NotificationEventType.enemyRespawned => Icons.autorenew_rounded,
  NotificationEventType.enemyBoughtRespawn => Icons.paid_rounded,
  NotificationEventType.enemyKillLine => Icons.gps_fixed_rounded,
  NotificationEventType.enemyRequestedLevelFour => Icons.upgrade_rounded,
  NotificationEventType.moduleDisconnected => Icons.warning_amber_rounded,
  NotificationEventType.moduleRecovered => Icons.check_circle_outline_rounded,
};

Color _accentForSeverity(NotificationSeverity severity) =>
    severity == NotificationSeverity.critical
    ? rmRedTeamColor
    : rmBlueTeamColor;

String _badgeForCategory(EventCategory category) => switch (category) {
  EventCategory.combat => '战斗事件',
  EventCategory.structure => '据点事件',
  EventCategory.rune => '能量机关',
  EventCategory.airSupport => '空中支援',
  EventCategory.dart => '飞镖事件',
  EventCategory.assembly => '装配事件',
  EventCategory.generic => '全局事件',
};

Color _accentForCategory(EventCategory category) => switch (category) {
  EventCategory.combat => Colors.redAccent,
  EventCategory.structure => Colors.deepOrange,
  EventCategory.rune => Colors.orange,
  EventCategory.airSupport => Colors.lightBlue,
  EventCategory.dart => Colors.teal,
  EventCategory.assembly => Colors.amber,
  EventCategory.generic => Colors.blueGrey,
};
