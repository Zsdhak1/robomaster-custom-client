/// Shared app navigation rail (Material 3 NavigationRail).
///
/// A persistent rail pinned to the left of the [AppShell], listing the app's
/// destinations — monitoring dashboard, video stream, data management and
/// settings. The shell owns the selected index and the extended/collapsed
/// state; this widget is purely presentational plus a toggle callback.
///
/// The leading mark shows the robot icon of the currently logged-in identity
/// (same assets as the login screen). The two infantry robots (3 / 4) share
/// one icon, so a small number badge is overlaid to tell them apart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connection/domain/robot_identity.dart';
import '../state/session_providers.dart';

/// Top-level app destinations reachable from the navigation rail.
enum AppDestination {
  /// The main monitoring dashboard (index 0).
  dashboard,

  /// The UDP video-stream page (index 1).
  video,

  /// The custom H.264 video-stream page (index 2).
  customVideo,

  /// The data export/import management page (index 3).
  data,

  /// The settings page (index 4).
  settings,
}

/// Material 3 navigation rail listing the app's top-level destinations.
///
/// [current] marks the active destination; selecting a different one calls
/// [onSelect]. [extended] widens the rail to show labels; [onToggleExtended]
/// flips it.
class AppNavigationRail extends ConsumerWidget {
  /// Creates an [AppNavigationRail].
  const AppNavigationRail({
    required this.current,
    required this.extended,
    required this.onToggleExtended,
    required this.onSelect,
    super.key,
  });

  /// The destination currently shown.
  final AppDestination current;

  /// Whether the rail is expanded to show text labels.
  final bool extended;

  /// Toggles [extended].
  final VoidCallback onToggleExtended;

  /// Called with the chosen destination when the user picks a different one.
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selectedId = ref.watch(selectedRobotIdProvider);

    return NavigationRail(
      selectedIndex: current.index,
      extended: extended,
      backgroundColor: scheme.surface,
      labelType: extended ? NavigationRailLabelType.none : null,
      leading: _RailHeader(
        robotId: selectedId,
        extended: extended,
        onToggleExtended: onToggleExtended,
      ),
      onDestinationSelected: (index) =>
          onSelect(AppDestination.values[index]),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('监控面板'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.videocam_outlined),
          selectedIcon: Icon(Icons.videocam),
          label: Text('视频流'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.center_focus_weak_outlined),
          selectedIcon: Icon(Icons.center_focus_weak),
          label: Text('自定义图传'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.storage_outlined),
          selectedIcon: Icon(Icons.storage),
          label: Text('数据'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('设置'),
        ),
      ],
    );
  }
}

/// Leading area of the rail: expand toggle + the logged-in robot's avatar.
class _RailHeader extends StatelessWidget {
  const _RailHeader({
    required this.robotId,
    required this.extended,
    required this.onToggleExtended,
  });

  final int robotId;
  final bool extended;
  final VoidCallback onToggleExtended;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          IconButton(
            icon: Icon(extended ? Icons.menu_open : Icons.menu),
            tooltip: extended ? '收起' : '展开',
            onPressed: onToggleExtended,
          ),
          const SizedBox(height: 8),
          _RobotAvatar(robotId: robotId),
        ],
      ),
    );
  }
}

/// The logged-in robot's icon, with an infantry number badge when needed.
class _RobotAvatar extends StatelessWidget {
  const _RobotAvatar({required this.robotId});

  final int robotId;

  @override
  Widget build(BuildContext context) {
    final identity = robotIdentityById(robotId);
    final color = identity?.sideColor ?? Theme.of(context).colorScheme.primary;
    final badge = infantryBadgeNumber(robotId);

    return Tooltip(
      message: identity?.displayName ?? '离线模式',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: identity == null
                  ? _fallback(color)
                  : Image.asset(
                      identity.iconAsset,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(color),
                    ),
            ),
            if (badge != null)
              Positioned(
                right: -2,
                bottom: -2,
                child: _NumberBadge(number: badge, color: color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(Color color) => CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(Icons.memory, color: color, size: 22),
      );
}

/// A small circular digit badge overlaid on the infantry avatar.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
