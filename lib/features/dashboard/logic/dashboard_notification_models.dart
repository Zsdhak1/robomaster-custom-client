/// Models shared by the dashboard event-notification experiment.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// How the dashboard should render the active event notification.
enum DashboardNotificationStyle {
  /// A top-centered, highly visible horizontal banner.
  topBanner,

  /// A compact floating card near the top-right corner.
  rightCorner,

  /// A left-edge beacon card with a strong entry direction.
  sideBeacon,
}

/// User-facing copy for [DashboardNotificationStyle].
extension DashboardNotificationStyleCopy on DashboardNotificationStyle {
  /// Short label shown in the dashboard lab panel.
  String get label => switch (this) {
        DashboardNotificationStyle.topBanner => '顶部横幅',
        DashboardNotificationStyle.rightCorner => '右上卡片',
        DashboardNotificationStyle.sideBeacon => '侧边信标',
      };

  /// One-line description shown under the style option.
  String get description => switch (this) {
        DashboardNotificationStyle.topBanner =>
          '顶部居中，存在感最强，适合极高优先级事件。',
        DashboardNotificationStyle.rightCorner =>
          '右上悬浮，信息完整，对主监控区遮挡最小。',
        DashboardNotificationStyle.sideBeacon =>
          '左侧贴边滑入，方向感强，连续事件更容易扫到。',
      };
}

/// Default amount of time a notification stays visible.
const dashboardNotificationDefaultDuration = Duration(seconds: 5);

/// Template content for a notification before it is instantiated on screen.
@immutable
class DashboardNotificationContent {
  /// Creates a [DashboardNotificationContent].
  const DashboardNotificationContent({
    required this.headline,
    required this.detail,
    required this.badge,
    required this.icon,
    required this.accentColor,
    this.duration = dashboardNotificationDefaultDuration,
  });

  /// Main one-line headline.
  final String headline;

  /// Supporting detail text.
  final String detail;

  /// Compact category pill shown in the UI.
  final String badge;

  /// Leading icon.
  final IconData icon;

  /// Accent color used by every candidate style.
  final Color accentColor;

  /// Auto-dismiss duration.
  final Duration duration;

  /// Creates a concrete item instance with a unique id.
  DashboardNotificationItem instantiate({DateTime? now}) {
    final createdAt = now ?? DateTime.now();
    final id = '${createdAt.microsecondsSinceEpoch}-${headline.hashCode}';
    return DashboardNotificationItem(
      id: id,
      headline: headline,
      detail: detail,
      badge: badge,
      icon: icon,
      accentColor: accentColor,
      duration: duration,
      createdAt: createdAt,
    );
  }
}

/// Concrete notification item currently visible or queued.
@immutable
class DashboardNotificationItem {
  /// Creates a [DashboardNotificationItem].
  const DashboardNotificationItem({
    required this.id,
    required this.headline,
    required this.detail,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.duration,
    required this.createdAt,
  });

  /// Unique key used by the overlay animation.
  final String id;

  /// Main one-line headline.
  final String headline;

  /// Supporting detail text.
  final String detail;

  /// Compact category pill shown in the UI.
  final String badge;

  /// Leading icon.
  final IconData icon;

  /// Accent color used by every candidate style.
  final Color accentColor;

  /// Auto-dismiss duration.
  final Duration duration;

  /// Time when the item was created.
  final DateTime createdAt;
}

/// Preview preset shown in the dashboard lab panel.
@immutable
class DashboardNotificationPreset {
  /// Creates a [DashboardNotificationPreset].
  const DashboardNotificationPreset({
    required this.label,
    required this.content,
  });

  /// Short button label.
  final String label;

  /// Notification payload created when the user taps the button.
  final DashboardNotificationContent content;
}

/// Controller state: a short list of concurrently visible notifications.
@immutable
class DashboardNotificationState {
  /// Creates a [DashboardNotificationState].
  const DashboardNotificationState({
    this.visible = const [],
  });

  /// Notifications currently rendered on screen, newest first.
  final List<DashboardNotificationItem> visible;

  /// Whether something is currently visible.
  bool get hasVisible => visible.isNotEmpty;

  /// Copies the state with selected fields replaced.
  DashboardNotificationState copyWith({
    List<DashboardNotificationItem>? visible,
  }) {
    return DashboardNotificationState(
      visible: visible ?? this.visible,
    );
  }
}

/// Sample notifications used to compare styles directly on the dashboard.
const List<DashboardNotificationPreset> dashboardNotificationPreviewPresets = [
  DashboardNotificationPreset(
    label: '大能量机关',
    content: DashboardNotificationContent(
      headline: '敌方激活大能量机关',
      detail: '20 环 · 伤害增益 35% · 持续 45 秒',
      badge: '高优先级',
      icon: Icons.bolt_rounded,
      accentColor: Colors.orange,
    ),
  ),
  DashboardNotificationPreset(
    label: '步兵买活',
    content: DashboardNotificationContent(
      headline: '敌方 3 号步兵买活',
      detail: '花费 180 金币 · 12 秒后返场',
      badge: '战场告警',
      icon: Icons.autorenew_rounded,
      accentColor: rmRedTeamColor,
    ),
  ),
  DashboardNotificationPreset(
    label: '空中支援',
    content: DashboardNotificationContent(
      headline: '对方呼叫空中支援',
      detail: '激光照射预警已开启 · 反制窗口 8 秒',
      badge: '空域告警',
      icon: Icons.flight_takeoff_rounded,
      accentColor: Colors.lightBlue,
    ),
  ),
  DashboardNotificationPreset(
    label: '基地告警',
    content: DashboardNotificationContent(
      headline: '己方基地遭到攻击',
      detail: '对方已进入基地进攻窗口',
      badge: '防守告警',
      icon: Icons.shield_rounded,
      accentColor: Colors.deepOrange,
    ),
  ),
];
