/// Persistent application shell hosting the navigation rail + page content.
///
/// The shell owns the navigation state. Layout adapts to the MD3 window size
/// class:
///  - compact (<600) → bottom NavigationBar
///  - medium (600–839) → collapsed NavigationRail
///  - expanded (≥840) → expanded NavigationRail with labels
///
/// All layouts use an [IndexedStack] so page and rail state survive tab switches.
library;

import 'package:flutter/material.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/responsive/window_size_class.dart';
import '../../features/custom_video/presentation/custom_video_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/video_screen.dart';
import '../../features/data_export/presentation/data_export_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_navigation_rail.dart';

/// Returns the navigation metadata (icon, selectedIcon, label) for [dest].
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

/// The root in-app shell shown after login / entering offline mode.
class AppShell extends StatefulWidget {
  /// Creates an [AppShell].
  ///
  /// [initial] selects which destination is shown first (defaults to the
  /// dashboard).
  const AppShell({this.initial = AppDestination.dashboard, super.key});

  /// The destination to show when the shell first mounts.
  final AppDestination initial;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppDestination _current = widget.initial;
  bool _railExtended = false;

  @override
  Widget build(BuildContext context) {
    final wsc = context.windowSizeClass;
    // Compact layout uses bottom NavigationBar; medium/expanded use rail.
    if (wsc == WindowSizeClass.compact) {
      return _compactLayout();
    }
    return _wideLayout();
  }

  // ------------------------------------------------------------------
  // Compact layout: bottom NavigationBar
  // ------------------------------------------------------------------

  Widget _compactLayout() {
    return Scaffold(
      body: IndexedStack(
        index: _current.index,
        children: const [
          DashboardScreen(),
          VideoScreen(),
          CustomVideoScreen(),
          DataExportScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _current.index,
        onDestinationSelected: (i) => setState(
          () => _current = AppDestination.values[i],
        ),
        destinations: _navigationDestinations(),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Wide layout: side NavigationRail with spring-animated expand/collapse
  // ------------------------------------------------------------------

  Widget _wideLayout() {
    // Animate rail width for a spring-like expand/collapse transition,
    // scaled proportionally with the window size.
    final railCollapsed = context.sp(72);
    final railExpanded = context.sp(256);
    final railWidth = _railExtended ? railExpanded : railCollapsed;

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.fastOutSlowIn,
            width: railWidth,
            child: AppNavigationRail(
              current: _current,
              extended: _railExtended,
              onToggleExtended: () =>
                  setState(() => _railExtended = !_railExtended),
              onSelect: (dest) => setState(() => _current = dest),
            ),
          ),
          VerticalDivider(width: context.sp(1)),
          Expanded(
            child: IndexedStack(
              index: _current.index,
              children: const [
                DashboardScreen(),
                VideoScreen(),
                CustomVideoScreen(),
                DataExportScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the [NavigationDestination] list for the compact [NavigationBar].
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
