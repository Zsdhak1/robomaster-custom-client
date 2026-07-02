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
import '../responsive/responsive_ext.dart';
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
    final iconSize = context.iconSize(24);

    // NavigationRail hard-codes the gap between destinations as a fixed 12px
    // (`_verticalDestinationSpacingM3`), which is not exposed through any theme
    // property and so never scales with the window. Add proportional vertical
    // padding to each destination so the spacing grows in step with the icons.
    // The 12px base is split 6/6 top+bottom; to reach a total gap of 12*scale
    // each destination needs `6*(scale-1)` extra per side. Clamp at >=0 because
    // the fixed 12px base cannot be shrunk via padding (only relevant below the
    // reference resolution, where scale < 1).
    final destPadding = EdgeInsets.symmetric(
      vertical: (context.sp(6) - 6).clamp(0.0, double.infinity),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        navigationRailTheme: NavigationRailThemeData(
          groupAlignment: -0.8,
          minWidth: context.sp(56),
        ),
      ),
      child: NavigationRail(
        selectedIndex: current.index,
        extended: extended,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(
          size: iconSize,
          color: scheme.onSecondaryContainer,
        ),
        unselectedIconTheme: IconThemeData(
          size: iconSize,
          color: scheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: context.textTheme.labelLarge!.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: context.textTheme.labelLarge!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelType: extended ? NavigationRailLabelType.none : null,
        leading: _RailHeader(
          robotId: selectedId,
          extended: extended,
          onToggleExtended: onToggleExtended,
        ),
        onDestinationSelected: (index) =>
            onSelect(AppDestination.values[index]),
        destinations: [
          NavigationRailDestination(
            padding: destPadding,
            icon: Icon(Icons.dashboard_outlined, size: iconSize),
            selectedIcon: Icon(Icons.dashboard, size: iconSize),
            label: Text('监控面板', style: context.textTheme.labelMedium),
          ),
          NavigationRailDestination(
            padding: destPadding,
            icon: Icon(Icons.videocam_outlined, size: iconSize),
            selectedIcon: Icon(Icons.videocam, size: iconSize),
            label: Text('视频流', style: context.textTheme.labelMedium),
          ),
          NavigationRailDestination(
            padding: destPadding,
            icon: Icon(Icons.center_focus_weak_outlined, size: iconSize),
            selectedIcon: Icon(Icons.center_focus_weak, size: iconSize),
            label: Text('自定义图传', style: context.textTheme.labelMedium),
          ),
          NavigationRailDestination(
            padding: destPadding,
            icon: Icon(Icons.storage_outlined, size: iconSize),
            selectedIcon: Icon(Icons.storage, size: iconSize),
            label: Text('数据', style: context.textTheme.labelMedium),
          ),
          NavigationRailDestination(
            padding: destPadding,
            icon: Icon(Icons.settings_outlined, size: iconSize),
            selectedIcon: Icon(Icons.settings, size: iconSize),
            label: Text('设置', style: context.textTheme.labelMedium),
          ),
        ],
      ),
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
    final iconSize = context.iconSize(24);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(12)),
      child: Column(
        children: [
          IconButton(
            icon: Icon(extended ? Icons.menu_open : Icons.menu, size: iconSize),
            tooltip: extended ? '收起' : '展开',
            onPressed: onToggleExtended,
          ),
          SizedBox(height: context.sp(8)),
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
    final avatarSize = context.sp(44);

    return Tooltip(
      message: identity?.displayName ?? '离线模式',
      child: SizedBox(
        width: avatarSize,
        height: avatarSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: identity == null
                  ? _fallback(color, avatarSize)
                  : Image.asset(
                      identity.iconAsset,
                      width: avatarSize,
                      height: avatarSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _fallback(color, avatarSize),
                    ),
            ),
            if (badge != null)
              Positioned(
                right: -context.sp(2),
                bottom: -context.sp(2),
                child: _NumberBadge(number: badge, color: color),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(Color color, double size) => CircleAvatar(
    radius: size / 2,
    backgroundColor: color.withValues(alpha: 0.15),
    child: Icon(Icons.memory, color: color, size: size / 2),
  );
}

/// A small circular digit badge overlaid on the infantry avatar.
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final badgeSize = context.sp(18);
    return Container(
      width: badgeSize,
      height: badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: context.sp(1.5),
        ),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: Theme.of(context).colorScheme.surface,
          // Micro number badge: explicit size is intentional because the badge
          // itself is a tiny circle; scale via context.sp() for proportional
          // fullscreen layout.
          fontSize: context.sp(11),
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
