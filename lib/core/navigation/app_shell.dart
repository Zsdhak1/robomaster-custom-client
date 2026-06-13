/// Persistent application shell hosting the navigation rail + page content.
///
/// The shell owns the navigation state: a single [Scaffold] keeps the
/// [AppNavigationRail] mounted on the left while the body switches between the
/// four top-level pages via an [IndexedStack]. Because the pages are never
/// torn down, switching tabs preserves their state and the rail itself never
/// rebuilds from scratch — fixing the "whole screen reloads on every switch"
/// behaviour of the previous push-replacement approach.
///
/// Each page is a plain content [Scaffold] (its own AppBar + FAB), so the app
/// bars render inside the content column to the right of the rail rather than
/// spanning across the top of it.
library;

import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/dashboard/presentation/video_screen.dart';
import '../../features/data_export/presentation/data_export_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_navigation_rail.dart';

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
    return Scaffold(
      body: Row(
        children: [
          AppNavigationRail(
            current: _current,
            extended: _railExtended,
            onToggleExtended: () =>
                setState(() => _railExtended = !_railExtended),
            onSelect: (dest) => setState(() => _current = dest),
          ),
          const VerticalDivider(width: 1),
          // IndexedStack keeps every page alive; only the visible index
          // changes on navigation, so page + rail state both survive.
          Expanded(
            child: IndexedStack(
              index: _current.index,
              children: const [
                DashboardScreen(),
                VideoScreen(),
                DataExportScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
