/// Maps live protocol events into dashboard notification content.
library;

import 'package:flutter/material.dart';

import '../../../generated/robomaster_custom_client.pb.dart';
import 'dashboard_notification_models.dart';
import 'event_decoder.dart';

/// Builds a user-facing dashboard notification from a protocol [Event].
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
