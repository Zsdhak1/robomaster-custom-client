/// 页面级可复用浮动操作菜单，基于 Material 3 [MenuAnchor]。
///
/// 每个顶层页面传入自己的 [FabAction] 列表；点击 FAB 后打开对应操作菜单。
/// 这取代了各页面 AppBar 的操作行，让应用栏保持干净，并为页面操作提供统一入口。
library;

import 'package:flutter/material.dart';

/// 显示在 [PageFabMenu] 中的单个操作项。
class FabAction {
  /// 创建 [FabAction]。
  const FabAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.enabled = true,
  });

  /// 菜单项前导图标。
  final IconData icon;

  /// 菜单项文本标签。
  final String label;

  /// 菜单项被点击时调用；[enabled] 为 false 时会被忽略。
  final VoidCallback onSelected;

  /// 该项是否可选择；禁用项会以灰化状态显示。
  final bool enabled;
}

/// 点击后打开 [actions] 菜单的浮动操作按钮。
///
/// 当 [actions] 为空时不会渲染菜单，因此调用方可以直接传入动态构建的列表。
///
/// 菜单打开/关闭时，FAB 图标会播放类似弹簧的旋转动画。
class PageFabMenu extends StatefulWidget {
  /// 创建 [PageFabMenu]。
  const PageFabMenu({required this.actions, this.tooltip = '操作', super.key});

  /// 菜单中自上而下排列的操作列表。
  final List<FabAction> actions;

  /// FAB 自身显示的工具提示。
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
    // 类弹簧旋转：stiffness=400、damping=24 形成自然过冲，并在约 300ms 收敛。
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
        heroTag: null,
        tooltip: widget.tooltip,
        onPressed: () => _toggleMenu(controller),
        child: AnimatedBuilder(
          animation: _rotationAnim,
          builder: (context, child) => Transform.rotate(
            angle: _rotationAnim.value * 1.5708, // 完整动画为 90°。
            child: child,
          ),
          child: Icon(controller.isOpen ? Icons.close : Icons.more_horiz),
        ),
      ),
    );
  }
}
