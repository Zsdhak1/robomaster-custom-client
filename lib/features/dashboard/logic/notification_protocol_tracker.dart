/// 协议事件、英雄部署和本机模块转换跟踪。
library;

import 'dart:math' as math;

import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';

const List<String> _moduleLabels = [
  '电源管理',
  'RFID',
  '灯条',
  '17mm 发射机构',
  '42mm 发射机构',
  '定位',
  '装甲',
  '图传',
  '电容',
  '主控',
  '激光检测',
];

/// 跟踪不依赖机器人血量的协议状态转换。
class NotificationProtocolTracker {
  List<int>? _previousModuleStatus;
  int? _previousDeployStatus;

  /// 处理通知计划中使用的全局 Event。
  RuleNotificationEvent? handleEvent({
    required int eventId,
    required String param,
    required DateTime timestamp,
  }) {
    if (eventId == 14) {
      return RuleNotificationEvent(
        type: NotificationEventType.enemyRequestedLevelFour,
        headline: '敌方申请四级装配',
        detail: '敌方进入四级装配强制退出缓冲期',
        dedupKey: 'enemy-level-four',
        occurredAt: timestamp,
      );
    }
    if (eventId == 15 && param.split(',').first.trim() == '0') {
      return RuleNotificationEvent(
        type: NotificationEventType.allyAssemblyCompleted,
        headline: '己方装配完成',
        detail: '科技核心装配成功，可关注后续性能体系变化',
        dedupKey: 'ally-assembly-completed',
        occurredAt: timestamp,
      );
    }
    return null;
  }

  /// 观察英雄部署状态；仅 0→1 返回 true。
  bool observeDeployStatus(int status) {
    final previous = _previousDeployStatus;
    _previousDeployStatus = status;
    return previous == 0 && status == 1;
  }

  /// 检测本机各模块在线状态变化。
  List<RuleNotificationEvent> handleModuleStatus(
    List<int> statuses,
    DateTime timestamp,
  ) {
    final previous = _previousModuleStatus;
    _previousModuleStatus = List<int>.from(statuses);
    if (previous == null) return const [];
    final events = <RuleNotificationEvent>[];
    final count = math.min(statuses.length, previous.length);
    for (var index = 0; index < count; index++) {
      final wasOffline = previous[index] == 0;
      final isOffline = statuses[index] == 0;
      if (wasOffline != isOffline) {
        events.add(_moduleEvent(index, isOffline, timestamp));
      }
    }
    return events;
  }

  /// 新比赛开始时重置部署转换基线。
  void resetMatch() {
    _previousDeployStatus = null;
  }

  RuleNotificationEvent _moduleEvent(
    int index,
    bool offline,
    DateTime timestamp,
  ) {
    final label = index < _moduleLabels.length
        ? _moduleLabels[index]
        : '模块 ${index + 1}';
    final key = 'module-offline-$index';
    return RuleNotificationEvent(
      type: offline
          ? NotificationEventType.moduleDisconnected
          : NotificationEventType.moduleRecovered,
      headline: offline ? '$label模块断联' : '$label模块恢复',
      detail: offline ? '检测到模块状态由在线变为离线' : '模块已重新上报非离线状态',
      dedupKey: offline ? key : 'module-recovered-$index',
      recoveryKey: offline ? null : key,
      occurredAt: timestamp,
    );
  }
}
