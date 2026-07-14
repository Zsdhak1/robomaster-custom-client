/// 持久化应用外壳，承载导航栏和页面内容。
///
/// 外壳持有导航状态，并按 MD3 窗口大小类别适配布局：
///  - 紧凑 (<600) → 底部 NavigationBar
///  - 中等 (600–839) → 收起的 NavigationRail
///  - 展开 (≥840) → 带标签的展开 NavigationRail
///
/// 所有布局都使用 [IndexedStack]，确保页面和导航状态在切换标签时保留。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/desktop_design_canvas.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/responsive/window_size_class.dart';
import '../../features/custom_video/presentation/custom_video_screen.dart';
import '../../features/dashboard/logic/dashboard_notification_models.dart';
import '../../features/dashboard/logic/notification_providers.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/video_screen.dart';
import '../../features/dashboard/presentation/widgets/dashboard_notification_overlay.dart';
import '../../features/dashboard/presentation/widgets/deployment_countdown_overlay.dart';
import '../../features/data_export/presentation/data_export_screen.dart';
import '../../features/settings/domain/notification_preferences.dart';
import '../../features/settings/logic/notification_profile_provider.dart';
import '../../features/settings/logic/notification_test_provider.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_navigation_rail.dart';

/// 返回 [dest] 对应的导航元数据（图标、选中图标、标签）。
({IconData icon, IconData selectedIcon, String label}) _navMeta(
  AppDestination dest,
) {
  return switch (dest) {
    AppDestination.dashboard => (
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      label: '监控',
    ),
    AppDestination.video => (
      icon: Icons.videocam_outlined,
      selectedIcon: Icons.videocam,
      label: '视频',
    ),
    AppDestination.customVideo => (
      icon: Icons.visibility_outlined,
      selectedIcon: Icons.visibility,
      label: '自定义图传',
    ),
    AppDestination.data => (
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: '数据',
    ),
    AppDestination.settings => (
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: '设置',
    ),
  };
}

/// 登录后或进入离线模式后显示的应用根外壳。
class AppShell extends ConsumerStatefulWidget {
  /// 创建 [AppShell]。
  ///
  /// [initial] 指定首次显示的目标页，默认显示仪表盘。
  const AppShell({this.initial = AppDestination.dashboard, super.key});

  /// 外壳首次挂载时显示的目标页。
  final AppDestination initial;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _railExtended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appDestinationProvider.notifier).state = widget.initial;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (DesktopDesignCanvas.isSupported) {
      return _wideLayout(context);
    }
    final wsc = context.windowSizeClass;
    // 紧凑布局使用底部 NavigationBar；中等/展开布局使用侧边 NavigationRail。
    if (wsc == WindowSizeClass.compact) {
      return _compactLayout();
    }
    return _wideLayout(context);
  }

  // ------------------------------------------------------------------
  // 紧凑布局：底部 NavigationBar
  // ------------------------------------------------------------------

  Widget _compactLayout() {
    final current = ref.watch(appDestinationProvider);
    return Scaffold(
      body: _contentStack(current),
      bottomNavigationBar: NavigationBar(
        selectedIndex: current.index,
        onDestinationSelected: (i) => _select(AppDestination.values[i]),
        destinations: _navigationDestinations(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 宽布局：侧边 NavigationRail，带展开/收起动画
  // ------------------------------------------------------------------

  Widget _wideLayout(BuildContext context) {
    final current = ref.watch(appDestinationProvider);
    // 导航栏宽度使用类弹簧展开/收起过渡，并随窗口大小等比缩放。
    final railCollapsed = context.sp(72);
    final railExpanded = context.sp(256);
    final railWidth = _railExtended ? railExpanded : railCollapsed;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            width: railWidth,
            child: AppNavigationRail(
              current: current,
              extended: _railExtended,
              onToggleExtended: () =>
                  setState(() => _railExtended = !_railExtended),
              onSelect: _select,
            ),
          ),
          VerticalDivider(width: context.sp(1)),
          Expanded(child: _contentStack(current)),
        ],
      ),
    );
  }

  Widget _contentStack(AppDestination current) {
    final notificationState = ref.watch(dashboardNotificationProvider);
    return ProviderScope(
      overrides: [
        notificationTestDispatcherProvider.overrideWithValue(
          _dispatchNotificationTest,
        ),
      ],
      child: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: current.index, children: _pages),
          ),
          for (final style in DashboardNotificationStyle.values)
            if (_itemsForStyle(notificationState.visible, style).isNotEmpty)
              DashboardNotificationOverlay(
                items: _itemsForStyle(notificationState.visible, style),
                style: style,
                onDismiss: (id) => ref
                    .read(dashboardNotificationProvider.notifier)
                    .dismiss(id),
              ),
          const DeploymentCountdownOverlay(),
        ],
      ),
    );
  }

  bool _dispatchNotificationTest(NotificationTestRequest request) {
    try {
      final profile = ref.read(activeNotificationProfileProvider);
      final setting =
          profile.eventSettings[request.type] ??
          const NotificationEventSetting();
      final event = RuleNotificationEvent(
        type: request.type,
        headline: request.headline,
        detail: request.detail,
        dedupKey: 'manual-test-${DateTime.now().microsecondsSinceEpoch}',
        occurredAt: DateTime.now(),
      );
      ref
          .read(dashboardNotificationProvider.notifier)
          .showPreview(
            event,
            profile,
            severityOverride: request.severityOverride,
          );
      unawaited(playNotificationFeedback(profile.display, setting));
      return true;
    } on Object {
      return false;
    }
  }

  List<DashboardNotificationItem> _itemsForStyle(
    List<DashboardNotificationItem> items,
    DashboardNotificationStyle style,
  ) {
    return items.where((item) => item.style == style).toList(growable: false);
  }

  void _select(AppDestination destination) {
    ref.read(appDestinationProvider.notifier).state = destination;
  }

  static const List<Widget> _pages = [
    DashboardScreen(),
    VideoScreen(),
    CustomVideoScreen(),
    DataExportScreen(),
    SettingsScreen(),
  ];

  /// 为紧凑布局的 [NavigationBar] 构建 [NavigationDestination] 列表。
  List<NavigationDestination> _navigationDestinations() {
    return AppDestination.values.map((dest) {
      final meta = _navMeta(dest);
      return NavigationDestination(
        icon: Icon(meta.icon),
        selectedIcon: Icon(meta.selectedIcon),
        label: meta.label,
      );
    }).toList();
  }
}
