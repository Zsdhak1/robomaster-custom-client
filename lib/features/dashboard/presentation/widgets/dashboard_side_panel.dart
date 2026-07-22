/// 主仪表盘侧栏在事件时间轴与模块状态之间切换。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/module_status_monitor.dart';
import 'event_timeline_panel.dart';
import 'module_status_panel.dart';

/// 任一已知模块离线时用状态面板替换事件时间轴。
class DashboardSidePanel extends ConsumerWidget {
  /// 创建 [DashboardSidePanel]。
  const DashboardSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(moduleStatusMonitorProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: modules.hasOffline
          ? const ModuleStatusPanel(key: ValueKey('module-status'))
          : const EventTimelinePanel(key: ValueKey('event-timeline')),
    );
  }
}
