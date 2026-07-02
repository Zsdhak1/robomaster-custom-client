/// Unified stream connection Extended FAB for the video pages.
///
/// A single bottom-right [FloatingActionButton.extended] whose label, icon and
/// action switch with the live stream state: 连接 when stopped, 断开连接 when
/// running. Both video pages share it so their connection controls look and
/// behave identically. Optional [secondaryActions] surface page-specific
/// operations (e.g. 自定义图传's 录制保存) in a small menu above the FAB.
library;

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A page-specific secondary action shown above the main connection FAB.
class StreamFabAction {
  /// Creates a [StreamFabAction].
  const StreamFabAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  /// Leading icon for the mini action button.
  final IconData icon;

  /// Tooltip / label describing the action.
  final String label;

  /// Called when tapped; ignored when [enabled] is false.
  final VoidCallback onPressed;

  /// Whether the action is selectable.
  final bool enabled;
}

/// Extended FAB that connects/disconnects a video stream.
class StreamConnectionFab extends ConsumerWidget {
  /// Creates a [StreamConnectionFab].
  const StreamConnectionFab({
    required this.isRunning,
    required this.onToggle,
    this.connectLabel = '连接',
    this.disconnectLabel = '断开连接',
    this.secondaryActions = const [],
    super.key,
  });

  /// Whether the stream is currently running.
  final bool isRunning;

  /// Toggles the stream on/off.
  final Future<void> Function() onToggle;

  /// Label shown when the stream is stopped.
  final String connectLabel;

  /// Label shown when the stream is running.
  final String disconnectLabel;

  /// Page-specific secondary actions shown as mini FABs above the main FAB.
  final List<StreamFabAction> secondaryActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final action in secondaryActions) ...[
          FloatingActionButton.small(
            tooltip: action.label,
            onPressed: action.enabled ? action.onPressed : null,
            backgroundColor: action.enabled
                ? null
                : scheme.surfaceContainerHighest,
            child: Icon(action.icon),
          ),
          const SizedBox(height: 12),
        ],
        FloatingActionButton.extended(
          onPressed: onToggle,
          backgroundColor: isRunning ? scheme.errorContainer : null,
          foregroundColor: isRunning ? scheme.onErrorContainer : null,
          icon: Icon(isRunning ? Icons.link_off : Icons.link),
          label: Text(isRunning ? disconnectLabel : connectLabel),
        ),
      ],
    );
  }
}
