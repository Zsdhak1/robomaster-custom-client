/// Reusable page-level floating action menu (Material 3 [MenuAnchor]).
///
/// Each top-level screen passes its own list of [FabAction]s; tapping the FAB
/// opens a menu of those actions. This replaces the per-page AppBar action
/// rows so the app bar stays clean and every screen exposes its operations
/// through a single, consistent entry point.
library;

import 'package:flutter/material.dart';

/// A single action entry shown in a [PageFabMenu].
class FabAction {
  /// Creates a [FabAction].
  const FabAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  /// Leading icon for the menu item.
  final IconData icon;

  /// Text label for the menu item.
  final String label;

  /// Called when the item is tapped. Ignored when [enabled] is false.
  final VoidCallback onSelected;

  /// Whether the item is selectable; disabled items render greyed out.
  final bool enabled;
}

/// A floating action button that opens a menu of [actions].
///
/// When [actions] is empty the menu renders nothing, so callers can pass a
/// dynamically-built list without guarding the FAB themselves.
class PageFabMenu extends StatelessWidget {
  /// Creates a [PageFabMenu].
  const PageFabMenu({
    required this.actions,
    this.tooltip = '操作',
    super.key,
  });

  /// The actions to list in the menu, top to bottom.
  final List<FabAction> actions;

  /// Tooltip shown on the FAB itself.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        for (final action in actions)
          MenuItemButton(
            leadingIcon: Icon(action.icon),
            onPressed: action.enabled ? action.onSelected : null,
            child: Text(action.label),
          ),
      ],
      builder: (context, controller, _) => FloatingActionButton(
        tooltip: tooltip,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Icon(controller.isOpen ? Icons.close : Icons.more_horiz),
      ),
    );
  }
}
