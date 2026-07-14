/// 设置顶层菜单，每个分类打开一个独立子页面。
library;

import 'package:flutter/material.dart';

import '../../../core/responsive/design_constants.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/window/desktop_window_controller.dart';
import 'about_screen.dart';
import 'dashboard_settings_screen.dart';
import 'developer_settings_screen.dart';
import 'general_settings_screen.dart';
import 'notification_rules_settings_screen.dart';
import 'notification_settings_strings.dart';
import 'playback_settings_screen.dart';
import 'video_settings_screen.dart';

// ======================================================================
// 目录项描述
// ======================================================================

/// 主菜单中单个设置分类的描述。
class _Category {
  const _Category({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.screenBuilder,
    required this.bodyBuilder,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// 完整页面版本，包含自己的 [Scaffold] 和 [AppBar]，用于窄屏模式。
  final WidgetBuilder screenBuilder;

  /// 仅主体内容，不包含 [Scaffold] 或 [AppBar]，用于右侧详情面板。
  final WidgetBuilder bodyBuilder;
}

final _categories = <_Category>[
  _Category(
    icon: Icons.settings,
    title: '常规',
    subtitle: '主题外观、当前阵营',
    screenBuilder: (_) => const GeneralSettingsScreen(),
    bodyBuilder: (_) => const GeneralSettingsScreen(embedded: true),
  ),
  _Category(
    icon: Icons.dashboard,
    title: '仪表盘',
    subtitle: '机器人列表显示模式',
    screenBuilder: (_) => const DashboardSettingsScreen(),
    bodyBuilder: (_) => const DashboardSettingsScreen(embedded: true),
  ),
  _Category(
    icon: Icons.notifications_active_outlined,
    title: notificationSettingsCategoryTitle,
    subtitle: notificationSettingsCategorySubtitle,
    screenBuilder: (_) => const NotificationRulesSettingsScreen(),
    bodyBuilder: (_) => const NotificationRulesSettingsScreen(embedded: true),
  ),
  _Category(
    icon: Icons.videocam,
    title: '图传',
    subtitle: '解码后端、硬件解码、自定义图传参数',
    screenBuilder: (_) => const VideoSettingsScreen(),
    bodyBuilder: (_) => const VideoSettingsScreen(embedded: true),
  ),
  _Category(
    icon: Icons.replay,
    title: '回放',
    subtitle: '数据导出目录、记录配置',
    screenBuilder: (_) => const PlaybackSettingsScreen(),
    bodyBuilder: (_) => const PlaybackSettingsScreen(embedded: true),
  ),
  _Category(
    icon: Icons.developer_mode,
    title: '开发者选项',
    subtitle: '调试面板与状态浮层开关',
    screenBuilder: (_) => const DeveloperSettingsScreen(),
    bodyBuilder: (_) => const DeveloperSettingsScreen(embedded: true),
  ),
  _Category(
    icon: Icons.info_outline,
    title: '关于',
    subtitle: '版本信息、开源仓库、检查更新',
    screenBuilder: (_) => const AboutScreen(),
    bodyBuilder: (_) => const AboutScreen(embedded: true),
  ),
];

// ======================================================================
// 主页面 — 设置目录（主–详情）
// ======================================================================

/// 使用主从布局的设置页面。
///
/// 左侧面板约占三分之一宽度，用于分类列表；右侧面板约占三分之二宽度，
/// 用于显示当前选中的子页面，并带有从右侧滑入的进入动画。宽屏模式下不会在应用外壳
/// 顶部 push 完整页面路由，因此左侧导航栏始终可见。
class SettingsScreen extends StatefulWidget {
  /// 创建 [SettingsScreen]。
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// [_categories] 中当前选中项的索引；-1 表示未打开子页面。
  int _selectedIndex = -1;

  /// 详情面板内嵌 [Navigator] 的键，用于在关闭面板前先弹出子页面内的二级页面。
  final GlobalKey<NavigatorState> _detailNavKey = GlobalKey<NavigatorState>();

  void _onCloseDetail() {
    // 先弹出内嵌 Navigator 中的二级页面。
    final nav = _detailNavKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else {
      setState(() => _selectedIndex = -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 顶层不放 AppBar：窄屏子页面自带 AppBar，宽屏详情区由顶部返回行承担导航。
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) return _narrowLayout();
          return _wideLayout();
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // 窄屏布局（<600dp）：简单列表，点击后推入带动画的路由。
  // ------------------------------------------------------------------

  Widget _narrowLayout() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 840),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (int i = 0; i < _categories.length; i++)
              _CategoryTile(
                category: _categories[i],
                isSelected: _selectedIndex == i,
                onTap: () => Navigator.of(
                  context,
                ).push(_slideInRightRoute(_categories[i].screenBuilder)),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 宽屏布局（>=600dp）：左侧主列表，右侧详情面板。
  // ------------------------------------------------------------------

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧主面板约占三分之一宽度，并限制在 360dp。
        SizedBox(
          width: 360,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              for (int i = 0; i < _categories.length; i++)
                _CategoryTile(
                  category: _categories[i],
                  isSelected: _selectedIndex == i,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
            ],
          ),
        ),
        // 分隔线。
        Container(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        // 右侧详情面板约占三分之二宽度。
        Expanded(
          child: _DetailPanel(
            index: _selectedIndex,
            onClose: _onCloseDetail,
            navKey: _detailNavKey,
          ),
        ),
      ],
    );
  }
}

/// 为 [child] 包一层一次性的从右侧滑入动画。
///
/// 该组件由顶层 [index] 作为 key 控制，Flutter 会先卸载旧页面再挂载新控制器，
/// 避免出入场内容重叠，只保留新页面的进入动画。
class _AnimatedDetailPage extends StatefulWidget {
  const _AnimatedDetailPage({required this.child, super.key});

  final Widget child;

  @override
  State<_AnimatedDetailPage> createState() => _AnimatedDetailPageState();
}

class _AnimatedDetailPageState extends State<_AnimatedDetailPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(begin: const Offset(0.25, 0.0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOutCubicEmphasized,
          ),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}

/// 右侧详情面板。
///
/// 顶部显示一条轻量返回栏，下面放入子页面的主体内容。主体内部包了一层内嵌
/// [Navigator]，因此从子页面继续 push 的二级页面（例如“硬件解码器”）会被限制在
/// 详情区域内，不会覆盖侧边导航栏。
///
/// 只有进入动画，旧内容会立即卸载。
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.index,
    required this.onClose,
    required this.navKey,
  });

  final int index;
  final VoidCallback onClose;
  final GlobalKey<NavigatorState> navKey;

  @override
  Widget build(BuildContext context) {
    if (index < 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.touch_app,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              '选择一个设置项',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final cat = _categories[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 详情头部：返回按钮加分类标题。
        Padding(
          padding: EdgeInsets.fromLTRB(4, _detailHeaderTopInset, 16, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回设置目录',
                onPressed: onClose,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  cat.title,
                  style: context.textTheme.titleLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // 子页面主体只做进入滑动动画。
        // 组件由 [index] 作为 key 控制，因此旧页面会先完全卸载，避免内容重叠。
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: _AnimatedDetailPage(
              key: ValueKey<int>(index),
              child: Navigator(
                key: navKey,
                pages: [MaterialPage(child: _buildBody(cat, index, context))],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 渲染子页面主体，不包含外层 [Scaffold] 或 [AppBar]。
  Widget _buildBody(_Category cat, int index, BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(index),
      child: cat.bodyBuilder(context),
    );
  }

  double get _detailHeaderTopInset =>
      DesktopWindowController.isSupported ? desktopTitleBarHeight : 8;
}

/// 窄屏布局使用的从右侧滑入路由。
Route<void> _slideInRightRoute(WidgetBuilder builder) {
  return PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubicEmphasized,
              ),
            ),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}

/// 设置主列表中的单个可点击分类卡片。
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final _Category category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = isSelected ? scheme.onPrimary : scheme.primary;
    final bgColor = isSelected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        elevation: 0, // MD3：使用色调表面，不使用阴影。
        color: bgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                // 带色调背景的圆角图标容器。
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(category.icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                // 标题和副标题。
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: context.textTheme.titleSmall!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.subtitle,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
