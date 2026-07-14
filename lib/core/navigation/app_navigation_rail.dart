/// 共享应用导航栏，基于 Material 3 [NavigationRail]。
///
/// 这是固定在 [AppShell] 左侧的持久化导航栏，列出应用顶层页面：监控、视频、
/// 自定义图传、数据和设置。选中索引以及展开/收起状态由外壳持有；本组件只负责展示
/// 并通过回调上报选择变化。
///
/// 前导区域显示当前登录身份的机器人图标，与登录页使用同一资源。两个步兵机器人
/// （3 / 4）共享图标，因此会叠加一个小数字徽标用于区分。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/connection/domain/robot_identity.dart';
import '../responsive/responsive_ext.dart';
import '../state/session_providers.dart';

/// 可从导航栏访问的应用顶层目标页。
enum AppDestination {
  /// 主监控仪表盘（索引 0）。
  dashboard,

  /// UDP 视频流页面（索引 1）。
  video,

  /// 自定义 H.264 视频流页面（索引 2）。
  customVideo,

  /// 数据导出/导入管理页面（索引 3）。
  data,

  /// 设置页面（索引 4）。
  settings,
}

/// 当前顶层目标页，允许部署规则等运行时安全请求页面切换。
final appDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.dashboard,
);

/// 列出应用顶层目标页的 Material 3 导航栏。
///
/// [current] 标记当前目标页；选择其他目标页会调用 [onSelect]。
/// [extended] 控制导航栏是否展开显示标签，[onToggleExtended] 用于切换该状态。
class AppNavigationRail extends ConsumerWidget {
  /// 创建 [AppNavigationRail]。
  const AppNavigationRail({
    required this.current,
    required this.extended,
    required this.onToggleExtended,
    required this.onSelect,
    super.key,
  });

  /// 当前显示的目标页。
  final AppDestination current;

  /// 导航栏是否展开以显示文本标签。
  final bool extended;

  /// 切换 [extended]。
  final VoidCallback onToggleExtended;

  /// 用户选择不同目标页时调用，并传入被选中的目标页。
  final ValueChanged<AppDestination> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final selectedId = ref.watch(selectedRobotIdProvider);
    final iconSize = context.iconSize(24);

    // NavigationRail 将目标项间距硬编码为 12px（_verticalDestinationSpacingM3），
    // 且没有主题属性可覆盖，因此不会随窗口缩放。这里给每个目标项补充等比垂直内边距，
    // 让间距随图标大小一起增长。12px 基础间距等分为上下 6px；若要达到 12*scale，
    // 每侧需额外 `6 * (scale - 1)`。小于参考分辨率时无法通过内边距缩小固定基础间距，
    // 因此将额外值钳制为 >= 0。
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

/// 导航栏前导区域：展开切换按钮和当前登录机器人的头像。
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

/// 当前登录机器人的图标；必要时叠加步兵编号徽标。
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

/// 叠加在步兵头像上的小圆形数字徽标。
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
          // 微型数字徽标需要显式字号，因为它本身是很小的圆形；
          // 通过 context.sp() 缩放以适配全屏布局。
          fontSize: context.sp(11),
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
