/// Settings top-level menu — each category opens a dedicated sub-screen.
library;

import 'package:flutter/material.dart';

import '../../../core/responsive/responsive_ext.dart';
import 'about_screen.dart';
import 'dashboard_settings_screen.dart';
import 'developer_settings_screen.dart';
import 'general_settings_screen.dart';
import 'playback_settings_screen.dart';
import 'video_settings_screen.dart';

// ======================================================================
// 目录项描述
// ======================================================================

/// Descriptor for one settings category on the main menu.
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

  /// Full‑screen page (with its own Scaffold + AppBar) – used in narrow mode.
  final WidgetBuilder screenBuilder;

  /// Just the body content (no Scaffold, no AppBar) – used in the detail panel.
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
// 主页面 — 设置目录（master–detail）
// ======================================================================

/// Settings page with a master–detail layout.
///
/// Left panel (~1/3): category list.  Right panel (~2/3): selected sub‑screen
/// with a slide‑from‑right entrance.  The left navigation rail stays visible
/// because we never push a full‑screen route on top of the app shell.
class SettingsScreen extends StatefulWidget {
  /// Creates a [SettingsScreen].
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Index into [_categories], or -1 when no sub‑screen is open.
  int _selectedIndex = -1;

  /// Key for the nested Navigator inside the detail panel so we can pop
  /// sub‑sub‑screens (e.g. "硬件解码器") before closing the panel itself.
  final GlobalKey<NavigatorState> _detailNavKey = GlobalKey<NavigatorState>();

  void _onCloseDetail() {
    // Pop any sub‑sub‑screen inside the nested Navigator first.
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
      // No AppBar — the sub‑screens provide their own, and in master–detail
      // mode the back‑arrow row above the content serves as navigation.
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) return _narrowLayout();
          return _wideLayout();
        },
      ),
    );
  }

  // ------------------------------------------------------------------
  // Narrow layout (<600 dp) — simple list, pushes animated routes
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
                onTap: () =>
                    Navigator.of(context).push(
                      _slideInRightRoute(_categories[i].screenBuilder),
                    ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Wide layout (>=600 dp) — master–detail
  // ------------------------------------------------------------------

  Widget _wideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left master panel (~1/3), capped at 360dp
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
        // Divider
        Container(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        // Right detail panel (~2/3)
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

/// Wraps [child] in a one-shot slide-from-right entrance animation.
///
/// The widget is keyed by the top-level [index], so Flutter unmounts any
/// previous page before mounting a fresh controller → no overlap with the
/// outgoing content, only a clean entrance for the incoming one.
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
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubicEmphasized,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: widget.child,
    );
  }
}

/// Right-side detail panel.
///
/// Shows a thin back‑arrow header at top, then the sub‑screen's **body**
/// wrapped in a nested [Navigator] so sub‑sub‑screens pushed from within
/// the body (e.g. "硬件解码器") are constrained to the detail area and
/// never cover the side navigation rail.
///
/// Only the entrance is animated; the previous content disappears instantly.
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
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
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
        // Detail header with back button + category title
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
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
        // Sub‑screen body with entrance‑only slide.
        // The widget is keyed by [index] so Flutter unmounts the previous
        // page entirely before mounting the new one → zero overlap.
        Expanded(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: _AnimatedDetailPage(
              key: ValueKey<int>(index),
              child: Navigator(
                key: navKey,
                pages: [
                  MaterialPage(
                    child: _buildBody(cat, index, context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Renders the sub‑screen's body (no outer Scaffold/AppBar).
  Widget _buildBody(_Category cat, int index, BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(index),
      child: cat.bodyBuilder(context),
    );
  }
}

/// Animated slide-from-right route used on narrow layouts.
Route<void> _slideInRightRoute(WidgetBuilder builder) {
  return PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) =>
        builder(context),
    transitionsBuilder: (context, animation, _, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(
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

/// A single tappable card in the settings master list.
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
        elevation: 0, // MD3: use tonal surface, not shadow
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
                // Icon in a tinted circular container
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
                // Title + subtitle
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
