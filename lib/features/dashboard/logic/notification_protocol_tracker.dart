/// 协议事件、英雄部署和本机模块转换跟踪。
library;

import '../../settings/domain/notification_preferences.dart';
import 'dashboard_notification_models.dart';
import 'module_status_monitor.dart';

/// 跟踪不依赖机器人血量的协议状态转换。
class NotificationProtocolTracker {
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

  /// 新比赛开始时重置部署转换基线。
  void resetMatch() {
    _previousDeployStatus = null;
  }

  /// 将已确认的模块状态转换映射为通知事件。
  RuleNotificationEvent moduleEvent(
    ModuleStatusTransition transition,
    DateTime timestamp,
  ) {
    final offline = transition.becameOffline;
    final label = transition.module.label;
    final key = 'module-offline-${transition.module.name}';
    return RuleNotificationEvent(
      type: offline
          ? NotificationEventType.moduleDisconnected
          : NotificationEventType.moduleRecovered,
      headline: offline ? '$label模块离线' : '$label模块恢复在线',
      detail: offline ? '检测到模块状态由在线变为离线' : '模块已重新上报非离线状态',
      dedupKey: offline ? key : 'module-recovered-${transition.module.name}',
      recoveryKey: offline ? null : key,
      occurredAt: timestamp,
    );
  }
}
