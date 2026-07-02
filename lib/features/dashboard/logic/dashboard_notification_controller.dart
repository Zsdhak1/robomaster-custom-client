/// Controller for experimental dashboard event notifications.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_notification_models.dart';

/// Small controller for a capped stack of concurrent dashboard notifications.
class DashboardNotificationController
    extends StateNotifier<DashboardNotificationState> {
  /// Creates an empty controller.
  DashboardNotificationController() : super(const DashboardNotificationState());

  static const int _maxVisibleCount = 4;
  final Map<String, Timer> _dismissTimers = <String, Timer>{};

  /// Shows a new notification at the top of the visible stack.
  void show(DashboardNotificationContent content) {
    _showItem(content.instantiate());
  }

  /// Immediately hides the notification with the given [id].
  void dismiss(String id) {
    _removeItem(id);
  }

  void _showItem(DashboardNotificationItem item) {
    final visible = [item, ...state.visible];
    final trimmed = visible.take(_maxVisibleCount).toList(growable: false);
    _cancelDroppedTimers(trimmed);
    state = state.copyWith(visible: trimmed);
    _armDismiss(item);
  }

  void _armDismiss(DashboardNotificationItem item) {
    _dismissTimers[item.id]?.cancel();
    _dismissTimers[item.id] = Timer(
      item.duration,
      () => _removeItem(item.id),
    );
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
    super.dispose();
  }
}
