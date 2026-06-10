/// Shared app navigation drawer (Material 3 NavigationDrawer).
///
/// Lists the top-level destinations — the monitoring dashboard and the
/// video-stream page — and switches between them with [Navigator.pushReplacement]
/// so no back-stack accumulates. Riverpod providers live at the root
/// [ProviderScope], so connection and video-stream state survive the switch.
library;

import 'package:flutter/material.dart';

/// Top-level app destinations reachable from the navigation drawer.
enum AppDestination {
  /// The main monitoring dashboard (index 0).
  dashboard,

  /// The UDP video-stream page (index 1).
  video,
}

/// Builder for a destination's screen widget.
typedef DestinationBuilder = Widget Function();

/// Material 3 navigation drawer listing the app's top-level destinations.
///
/// [current] marks the active destination. Selecting a different one closes
/// the drawer and calls [onSelect]; selecting the current one just closes it.
class AppNavigationDrawer extends StatelessWidget {
  /// Creates an [AppNavigationDrawer].
  const AppNavigationDrawer({
    required this.current,
    required this.onSelect,
    super.key,
  });

  /// The destination currently shown.
  final AppDestination current;

  /// Called with the chosen destination when the user picks a different one.
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return NavigationDrawer(
      selectedIndex: current.index,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        final target = AppDestination.values[index];
        if (target != current) onSelect(target);
      },
      children: [
        _buildHeader(primary),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('监控面板'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.videocam_outlined),
          selectedIcon: Icon(Icons.videocam),
          label: Text('视频流'),
        ),
      ],
    );
  }

  Widget _buildHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
      child: Row(
        children: [
          Icon(Icons.memory, color: primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'RoboMaster 监控',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
