/// 设置页手动通知测试的跨模块请求接口。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_preferences.dart';

/// 描述一次由用户手动触发的通知测试。
@immutable
class NotificationTestRequest {
  /// 创建通知测试请求。
  const NotificationTestRequest({
    required this.type,
    required this.headline,
    required this.detail,
    this.severityOverride,
  });

  /// 使用哪一类事件的图标、声音与确认设置。
  final NotificationEventType type;

  /// 测试通知标题。
  final String headline;

  /// 测试通知详情。
  final String detail;

  /// 强制测试指定级别；为空时使用当前档案的事件级别。
  final NotificationSeverity? severityOverride;
}

/// 返回 true 表示测试请求已交给全局通知运行时。
typedef NotificationTestDispatcher =
    bool Function(NotificationTestRequest request);

/// 由 AppShell 在组合层绑定的通知测试调度器。
final notificationTestDispatcherProvider = Provider<NotificationTestDispatcher>(
  (ref) =>
      (request) => false,
);
