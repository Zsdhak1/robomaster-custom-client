/// 实验性仪表盘事件通知控制器。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/domain/notification_preferences.dart';
import '../../settings/domain/notification_rule_profile.dart';
import 'dashboard_notification_factory.dart';
import 'dashboard_notification_models.dart';

/// 控制并发仪表盘通知可见数量的小型控制器。
class DashboardNotificationController
    extends StateNotifier<DashboardNotificationState> {
  /// 创建空控制器。
  DashboardNotificationController() : super(const DashboardNotificationState());

  static const int _maxVisibleCount = 4;
  final Map<String, Timer> _dismissTimers = <String, Timer>{};
  final Map<String, DateTime> _lastShownAt = <String, DateTime>{};

  /// 在可见通知栈顶部显示一条新通知。
  void show(
    DashboardNotificationContent content, {
    DashboardNotificationStyle? style,
  }) {
    final item = content.instantiate();
    _showItem(
      style == null ? item : _copyWithStyle(item, style),
      maxVisibleInfo: _maxVisibleCount,
      keepHistory: false,
      historyLimit: 0,
    );
  }

  /// 按 [profile] 对规则事件执行开关、冷却和展示策略。
  DashboardNotificationItem? showConfigured(
    RuleNotificationEvent event,
    NotificationRuleProfile profile, {
    required bool gamePaused,
  }) {
    final recoveryKey = event.recoveryKey;
    if (recoveryKey != null) dismissByDedupKey(recoveryKey);
    final display = profile.display;
    final setting = profile.eventSettings[event.type];
    if (setting == null) return null;
    if (!_canShow(display, setting, gamePaused)) return null;
    if (_isCoolingDown(event, setting, display)) return null;
    final content = notificationFromRuleEvent(event, profile);
    final item = content.instantiate(now: event.occurredAt);
    _lastShownAt[_cooldownKey(event)] = event.occurredAt;
    _showItem(
      item,
      maxVisibleInfo: display.maxVisibleInfo,
      keepHistory: display.keepHistory,
      historyLimit: display.historyLimit,
    );
    return item;
  }

  /// 按当前档案展示测试通知，但绕过全局/事件开关和冷却。
  DashboardNotificationItem showPreview(
    RuleNotificationEvent event,
    NotificationRuleProfile profile, {
    NotificationSeverity? severityOverride,
  }) {
    final display = profile.display;
    final setting =
        profile.eventSettings[event.type] ?? const NotificationEventSetting();
    final previewSetting = setting.copyWith(
      enabled: true,
      severity: severityOverride ?? setting.severity,
      cooldownSeconds: 0,
    );
    final previewProfile = profile.copyWith(
      display: display.copyWith(enabled: true),
      eventSettings: {...profile.eventSettings, event.type: previewSetting},
    );
    final item = notificationFromRuleEvent(
      event,
      previewProfile,
    ).instantiate(now: event.occurredAt);
    _showItem(
      item,
      maxVisibleInfo: display.maxVisibleInfo,
      keepHistory: display.keepHistory,
      historyLimit: display.historyLimit,
    );
    return item;
  }

  /// 立即隐藏指定 [id] 的通知。
  void dismiss(String id) {
    _removeItem(id);
  }

  /// 关闭与 [dedupKey] 对应的可见通知。
  void dismissByDedupKey(String dedupKey) {
    final ids = state.visible
        .where((item) => item.dedupKey == dedupKey)
        .map((item) => item.id)
        .toList(growable: false);
    for (final id in ids) {
      _removeItem(id);
    }
  }

  /// 清空本次运行的通知历史。
  void clearHistory() {
    state = state.copyWith(history: const []);
  }

  /// 清理当前比赛会话的可见通知、定时器和冷却基线，保留历史记录。
  void resetRuntimeState() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _lastShownAt.clear();
    state = state.copyWith(visible: const []);
  }

  void _showItem(
    DashboardNotificationItem item, {
    required int maxVisibleInfo,
    required bool keepHistory,
    required int historyLimit,
  }) {
    final visible = [item, ...state.visible];
    final trimmed = _trimVisible(visible, maxVisibleInfo);
    final history = keepHistory
        ? [item, ...state.history].take(historyLimit).toList(growable: false)
        : state.history;
    _cancelDroppedTimers(trimmed);
    state = state.copyWith(visible: trimmed, history: history);
    if (item.autoDismiss) _armDismiss(item);
  }

  List<DashboardNotificationItem> _trimVisible(
    List<DashboardNotificationItem> items,
    int maxVisibleInfo,
  ) {
    final result = <DashboardNotificationItem>[];
    var infoCount = 0;
    for (final item in items) {
      if (result.length >= _maxVisibleCount) break;
      if (item.severity == NotificationSeverity.info) {
        if (infoCount >= maxVisibleInfo) continue;
        infoCount++;
      }
      result.add(item);
    }
    return result;
  }

  bool _canShow(
    NotificationDisplayConfig display,
    NotificationEventSetting? setting,
    bool gamePaused,
  ) {
    if (!display.enabled || setting == null || !setting.enabled) return false;
    return !(display.muteWhenPaused && gamePaused);
  }

  bool _isCoolingDown(
    RuleNotificationEvent event,
    NotificationEventSetting setting,
    NotificationDisplayConfig display,
  ) {
    final last = _lastShownAt[_cooldownKey(event)];
    if (last == null) return false;
    final factor = switch (display.sensitivity) {
      NotificationSensitivity.conservative => 1.5,
      NotificationSensitivity.standard => 1.0,
      NotificationSensitivity.sensitive => 0.5,
    };
    final cooldown = Duration(
      milliseconds: (setting.cooldownSeconds * 1000 * factor).round(),
    );
    return event.occurredAt.difference(last) < cooldown;
  }

  String _cooldownKey(RuleNotificationEvent event) =>
      '${event.type.name}:${event.dedupKey}';

  DashboardNotificationItem _copyWithStyle(
    DashboardNotificationItem item,
    DashboardNotificationStyle style,
  ) {
    return DashboardNotificationItem(
      id: item.id,
      headline: item.headline,
      detail: item.detail,
      badge: item.badge,
      icon: item.icon,
      accentColor: item.accentColor,
      eventType: item.eventType,
      severity: item.severity,
      style: style,
      requiresAcknowledgement: item.requiresAcknowledgement,
      autoDismiss: item.autoDismiss,
      dedupKey: item.dedupKey,
      duration: item.duration,
      createdAt: item.createdAt,
    );
  }

  void _armDismiss(DashboardNotificationItem item) {
    _dismissTimers[item.id]?.cancel();
    _dismissTimers[item.id] = Timer(item.duration, () => _removeItem(item.id));
  }

  void _cancelDroppedTimers(List<DashboardNotificationItem> trimmed) {
    final allowedIds = trimmed.map((item) => item.id).toSet();
    final droppedIds = _dismissTimers.keys
        .where((id) => !allowedIds.contains(id))
        .toList(growable: false);
    for (final id in droppedIds) {
      _dismissTimers.remove(id)?.cancel();
    }
  }

  void _removeItem(String id) {
    _dismissTimers.remove(id)?.cancel();
    final visible = state.visible
        .where((item) => item.id != id)
        .toList(growable: false);
    state = state.copyWith(visible: visible);
  }

  @override
  void dispose() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _lastShownAt.clear();
    super.dispose();
  }
}
