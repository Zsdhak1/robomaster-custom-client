/// 跨功能共享的应用会话状态（连接、仪表盘、设置）。
///
/// 放在 `core` 中，避免功能之间产生直接依赖。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 默认选中的机器人 ID（红方英雄，协议 ID 1）。
const int defaultSelectedRobotId = 1;

/// 当前客户端登录使用的机器人身份。
///
/// 红方 ID 为 1-7，蓝方 ID 为 101-107。所选阵营会驱动全局主题颜色，
/// 并决定仪表盘中哪一队计为“己方”。
final selectedRobotIdProvider = StateProvider<int>(
  (ref) => defaultSelectedRobotId,
);

/// 仪表盘机器人列表展示双方队伍的方式。
enum DashboardDisplayMode {
  /// 显示敌方逐机器人详情；己方总血量用于驱动趋势图。
  enemyFocus,

  /// 并排显示双方逐机器人详情。
  both,
}

/// [DashboardDisplayMode] 的可读标签和说明。
extension DashboardDisplayModeLabel on DashboardDisplayMode {
  /// 设置页中显示的短中文标签。
  String get label => switch (this) {
    DashboardDisplayMode.enemyFocus => '敌方详情 + 己方趋势',
    DashboardDisplayMode.both => '双方都显示',
  };

  /// 描述该模式展示内容的单行说明。
  String get description => switch (this) {
    DashboardDisplayMode.enemyFocus =>
      '机器人列表展示敌方逐个血量，便于快速查看各机器人状态；下方趋势图展示己方总血量。',
    DashboardDisplayMode.both => '机器人列表分两栏同时展示己方与敌方所有机器人的详细血量。',
  };
}

/// 当前仪表盘显示模式，默认聚焦敌方监控。
final dashboardDisplayModeProvider = StateProvider<DashboardDisplayMode>(
  (ref) => DashboardDisplayMode.enemyFocus,
);
