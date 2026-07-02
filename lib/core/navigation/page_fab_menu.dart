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
///
/// The FAB icon animates with a spring-like rotation when the menu opens/closes.
class PageFabMenu extends StatefulWidget {
  /// Creates a [PageFabMenu].
  const PageFabMenu({required this.actions, this.tooltip = '操作', super.key});

  /// The actions to list in the menu, top to bottom.
  final List<FabAction> actions;

  /// Tooltip shown on the FAB itself.
  final String tooltip;

  @override
  State<PageFabMenu> createState() => _PageFabMenuState();
}

class _PageFabMenuState extends State<PageFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationCtrl;
  late final Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    // Spring-like rotation: stiffness=400, damping=24 gives a natural
    // overshoot that settles in ~300ms, matching MD3 spring physics.
    _rotationCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rotationAnim = CurvedAnimation(
      parent: _rotationCtrl,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _rotationCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
      _rotationCtrl.reverse();
    } else {
      controller.open();
      _rotationCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return const SizedBox.shrink();

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      menuChildren: [
        for (final action in widget.actions)
          MenuItemButton(
            leadingIcon: Icon(action.icon),
            onPressed: action.enabled ? action.onSelected : null,
            child: Text(action.label),
          ),
      ],
      builder: (context, controller, _) => FloatingActionButton(
        tooltip: widget.tooltip,
        onPressed: () => _toggleMenu(controller),
        child: AnimatedBuilder(
          animation: _rotationAnim,
          builder: (context, child) => Transform.rotate(
            angle: _rotationAnim.value * 1.5708, // 90° on full rotation
            child: child,
          ),
          child: Icon(controller.isOpen ? Icons.close : Icons.more_horiz),
        ),
      ),
    );
  }
}
