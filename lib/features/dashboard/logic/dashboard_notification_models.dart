/// 仪表盘事件通知实验共享的模型。
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/domain/notification_preferences.dart';

/// 仪表盘渲染当前事件通知的方式。
enum DashboardNotificationStyle {
  /// 顶部居中且高可见度的横向横幅。
  topBanner,

  /// 靠近右上角的紧凑浮动卡片。
  rightCorner,

  /// 左边缘信标卡片，带明显进入方向。
  sideBeacon,
}

/// [DashboardNotificationStyle] 的面向用户文案。
extension DashboardNotificationStyleCopy on DashboardNotificationStyle {
  /// 显示在仪表盘实验面板中的短标签。
  String get label => switch (this) {
    DashboardNotificationStyle.topBanner => '顶部横幅',
    DashboardNotificationStyle.rightCorner => '右上卡片',
    DashboardNotificationStyle.sideBeacon => '侧边信标',
  };

  /// 显示在样式选项中的单行描述。
  String get description => switch (this) {
    DashboardNotificationStyle.topBanner => '顶部居中，存在感最强，适合极高优先级事件。',
    DashboardNotificationStyle.rightCorner => '右上悬浮，信息完整，对主监控区遮挡最小。',
    DashboardNotificationStyle.sideBeacon => '左侧贴边滑入，方向感强，连续事件更容易扫到。',
  };
}

/// 通知默认保持可见的时长。
const dashboardNotificationDefaultDuration = Duration(seconds: 5);

/// 通知在页面中实例化前使用的模板内容。
@immutable
class DashboardNotificationContent {
  /// 创建 [DashboardNotificationContent]。
  const DashboardNotificationContent({
    required this.headline,
    required this.detail,
    required this.badge,
    required this.icon,
    required this.accentColor,
    this.eventType,
    this.severity = NotificationSeverity.info,
    this.style = DashboardNotificationStyle.rightCorner,
    this.requiresAcknowledgement = false,
    this.autoDismiss = true,
    this.dedupKey = '',
    this.duration = dashboardNotificationDefaultDuration,
  });

  /// 单行主标题。
  final String headline;

  /// 辅助详情文本。
  final String detail;

  /// 显示在 UI 中的紧凑分类胶囊。
  final String badge;

  /// 前导图标。
  final IconData icon;

  /// 各候选样式使用的强调色。
  final Color accentColor;

  /// 对应的可配置通知事件；开发者预览可为空。
  final NotificationEventType? eventType;

  /// INFO 或 CRITICAL 严重级别。
  final NotificationSeverity severity;

  /// 当前通知独立使用的展示位置。
  final DashboardNotificationStyle style;

  /// 是否需要用户确认后才视为处理完成。
  final bool requiresAcknowledgement;

  /// 是否按 [duration] 自动关闭。
  final bool autoDismiss;

  /// 冷却、恢复关闭和历史识别使用的稳定键。
  final String dedupKey;

  /// 自动关闭时长。
  final Duration duration;

  /// 创建带唯一 ID 的具体通知实例。
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
      eventType: eventType,
      severity: severity,
      style: style,
      requiresAcknowledgement: requiresAcknowledgement,
      autoDismiss: autoDismiss,
      dedupKey: dedupKey,
      duration: duration,
      createdAt: createdAt,
    );
  }
}

/// 当前可见或排队中的具体通知项。
@immutable
class DashboardNotificationItem {
  /// 创建 [DashboardNotificationItem]。
  const DashboardNotificationItem({
    required this.id,
    required this.headline,
    required this.detail,
    required this.badge,
    required this.icon,
    required this.accentColor,
    required this.eventType,
    required this.severity,
    required this.style,
    required this.requiresAcknowledgement,
    required this.autoDismiss,
    required this.dedupKey,
    required this.duration,
    required this.createdAt,
  });

  /// 覆盖层动画使用的唯一键。
  final String id;

  /// 主单行标题。
  final String headline;

  /// 辅助详情文本。
  final String detail;

  /// 显示在 UI 中的紧凑分类胶囊。
  final String badge;

  /// 前导图标。
  final IconData icon;

  /// 各候选样式使用的强调色。
  final Color accentColor;

  /// 对应的配置事件；开发者预览可为空。
  final NotificationEventType? eventType;

  /// 通知严重级别。
  final NotificationSeverity severity;

  /// 该通知的展示位置。
  final DashboardNotificationStyle style;

  /// 是否要求确认。
  final bool requiresAcknowledgement;

  /// 是否自动关闭。
  final bool autoDismiss;

  /// 稳定去重键。
  final String dedupKey;

  /// 自动关闭时长。
  final Duration duration;

  /// 通知项创建时间。
  final DateTime createdAt;
}

/// 显示在仪表盘实验面板中的预览预设。
@immutable
class DashboardNotificationPreset {
  /// 创建 [DashboardNotificationPreset]。
  const DashboardNotificationPreset({
    required this.label,
    required this.content,
  });

  /// 短按钮标签。
  final String label;

  /// 用户点击按钮时创建的通知载荷。
  final DashboardNotificationContent content;
}

/// 控制器状态：当前并发可见通知的短列表。
@immutable
class DashboardNotificationState {
  /// 创建 [DashboardNotificationState]。
  const DashboardNotificationState({
    this.visible = const [],
    this.history = const [],
  });

  /// 当前渲染在页面上的通知，最新在前。
  final List<DashboardNotificationItem> visible;

  /// 本次运行内的通知历史，最新在前。
  final List<DashboardNotificationItem> history;

  /// 当前是否有通知可见。
  bool get hasVisible => visible.isNotEmpty;

  /// 复制状态并替换指定字段。
  DashboardNotificationState copyWith({
    List<DashboardNotificationItem>? visible,
    List<DashboardNotificationItem>? history,
  }) {
    return DashboardNotificationState(
      visible: visible ?? this.visible,
      history: history ?? this.history,
    );
  }
}

/// 规则引擎输出的纯通知事件。
@immutable
class RuleNotificationEvent {
  /// 创建规则事件。
  const RuleNotificationEvent({
    required this.type,
    required this.headline,
    required this.detail,
    required this.dedupKey,
    required this.occurredAt,
    this.recoveryKey,
  });

  /// 配置中的事件类型。
  final NotificationEventType type;

  /// 通知主标题。
  final String headline;

  /// 通知详情。
  final String detail;

  /// 冷却和重复检测键。
  final String dedupKey;

  /// 事件发生时间。
  final DateTime occurredAt;

  /// 若非空，在显示前关闭具有该去重键的恢复前通知。
  final String? recoveryKey;
}

/// 用于在仪表盘中直接比较样式的示例通知。
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
