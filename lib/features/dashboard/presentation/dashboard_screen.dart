/// Main dashboard screen displaying game status, robot health, and events.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/page_fab_menu.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/mqtt_service.dart';
import '../../connection/domain/robot_identity.dart';
import '../../connection/presentation/connection_screen.dart';
import '../../settings/logic/settings_providers.dart';
import '../logic/dashboard_notification_models.dart';
import '../logic/game_state.dart';
import '../logic/stream_providers.dart';
import 'widgets/connection_quality_panel.dart';
import 'widgets/dashboard_notification_overlay.dart';
import 'widgets/debug_panel.dart';
import 'widgets/event_timeline_panel.dart';
import 'widgets/game_status_card.dart';
import 'widgets/health_chart.dart';
import 'widgets/operation_panel.dart';
import 'widgets/robot_status_list.dart';

/// Main monitoring dashboard.
class DashboardScreen extends ConsumerStatefulWidget {
  /// Creates a [DashboardScreen].
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isDebugOpen = false;
  bool _isNotificationLabOpen = false;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final devMode = ref.watch(developerModeProvider);
    final notificationState = ref.watch(dashboardNotificationProvider);
    final notificationStyle = ref.watch(dashboardNotificationStyleProvider);
    final visibleNotifications = notificationState.visible;

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              _TopStatusBar(gameState: gameState),
              const Expanded(child: _MainContent()),
              SizedBox(height: context.sp(200), child: const _BottomBar()),
            ],
          ),
          if (devMode && _isDebugOpen)
            Positioned(
              right: context.sp(16),
              bottom: context.sp(80),
              child: DebugPanel(key: ValueKey<bool>(_isDebugOpen)),
            ),
          if (_isNotificationLabOpen)
            Positioned(
              right: context.sp(16),
              top: context.rmTopBarHeight + context.sp(18),
              child: _NotificationLabPanel(
                style: notificationStyle,
                onStyleSelected: (style) => ref
                    .read(dashboardNotificationStyleProvider.notifier)
                    .set(style),
                onTriggerPreview: (content) => ref
                    .read(dashboardNotificationProvider.notifier)
                    .show(content),
              ),
            ),
          if (visibleNotifications.isNotEmpty)
            DashboardNotificationOverlay(
              items: visibleNotifications,
              style: notificationStyle,
              onDismiss: (id) =>
                  ref.read(dashboardNotificationProvider.notifier).dismiss(id),
            ),
        ],
      ),
      floatingActionButton: _DashboardFab(
        devMode: devMode,
        isDebugOpen: _isDebugOpen,
        onToggleDebug: () => setState(() => _isDebugOpen = !_isDebugOpen),
        isNotificationLabOpen: _isNotificationLabOpen,
        onToggleNotificationLab: () =>
            setState(() => _isNotificationLabOpen = !_isNotificationLabOpen),
      ),
    );
  }
}

/// Page-level FAB menu for the dashboard: connection toggle + debug panel.
class _DashboardFab extends ConsumerWidget {
  const _DashboardFab({
    required this.devMode,
    required this.isDebugOpen,
    required this.onToggleDebug,
    required this.isNotificationLabOpen,
    required this.onToggleNotificationLab,
  });

  final bool devMode;
  final bool isDebugOpen;
  final VoidCallback onToggleDebug;
  final bool isNotificationLabOpen;
  final VoidCallback onToggleNotificationLab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected =
        ref.watch(mqttConnectionStateSyncProvider) ==
        MqttConnectionState.connected;

    return PageFabMenu(
      actions: [
        FabAction(
          icon: isConnected ? Icons.link_off : Icons.link,
          label: isConnected ? '断开连接' : '重新连接',
          onSelected: () => isConnected
              ? ref.read(mqttServiceProvider).disconnect()
              : Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const ConnectionScreen(),
                  ),
                ),
        ),
        FabAction(
          icon: isNotificationLabOpen
              ? Icons.notifications_active
              : Icons.notifications_none,
          label: isNotificationLabOpen ? '隐藏通知实验台' : '通知样式实验台',
          onSelected: onToggleNotificationLab,
        ),
        if (devMode)
          FabAction(
            icon: isDebugOpen ? Icons.bug_report : Icons.bug_report_outlined,
            label: isDebugOpen ? '隐藏调试面板' : '显示调试面板',
            onSelected: onToggleDebug,
          ),
      ],
    );
  }
}

/// Middle area: robot status list (2/3) + event timeline (1/3).
class _MainContent extends StatelessWidget {
  const _MainContent();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(flex: 2, child: RobotStatusList()),
        Expanded(child: EventTimelinePanel()),
      ],
    );
  }
}

/// Bottom strip: game status, health trend chart (optional) / operation + connection panels.
class _BottomBar extends ConsumerWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHealth = ref.watch(showHealthTrendProvider);

    return Row(
      children: [
        SizedBox(width: context.sp(200), child: const GameStatusCard()),
        Expanded(
          child: showHealth
              ? const HealthChart()
              : Row(
                  children: [
                    const Expanded(child: OperationPanel()),
                    SizedBox(width: context.sp(8)),
                    const Expanded(child: ConnectionQualityPanel()),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Top bar showing connection state, own side badge and settings access.
class _TopStatusBar extends ConsumerWidget {
  /// Creates a [_TopStatusBar].
  const _TopStatusBar({required this.gameState});

  final GameState gameState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = gameState.isConnected;
    final selectedId = ref.watch(selectedRobotIdProvider);
    final ownIsBlue = isBlueSide(selectedId);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: context.rmTopBarHeight,
      color: primary,
      padding: context.insetSym(h: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isConnected
                  ? '已作为 ${robotDisplayName(selectedId)} 登录（ID：$selectedId）'
                  : '未连接（离线模式）',
              style: context.textTheme.titleMedium!.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _SideBadge(ownIsBlue: ownIsBlue),
          context.sizedBox(w: 12),
          _StatusDot(isConnected: isConnected),
        ],
      ),
    );
  }
}

/// White pill badge showing the own side (己方 红/蓝).
class _SideBadge extends StatelessWidget {
  const _SideBadge({required this.ownIsBlue});

  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: context.insetSym(h: 10, v: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.sp(12)),
      ),
      child: Text(
        ownIsBlue ? '己方 · 蓝方' : '己方 · 红方',
        style: context.textTheme.bodySmall!.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Small connection indicator dot with spring-animated color transition.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      width: context.sp(8),
      height: context.sp(8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.greenAccent : Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NotificationLabPanel extends StatelessWidget {
  const _NotificationLabPanel({
    required this.style,
    required this.onStyleSelected,
    required this.onTriggerPreview,
  });

  final DashboardNotificationStyle style;
  final ValueChanged<DashboardNotificationStyle> onStyleSelected;
  final ValueChanged<DashboardNotificationContent> onTriggerPreview;

  @override
  Widget build(BuildContext context) {
    final width = context.windowSizeClass.isCompact
        ? context.sp(320)
        : context.sp(360);
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Card(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.98),
          child: Padding(
            padding: context.insetAll(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: context.iconSize(20),
                    ),
                    context.sizedBox(w: 8),
                    Text(
                      '通知样式实验台',
                      style: context.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                context.sizedBox(h: 6),
                Text(
                  '切换样式后直接点样例事件，观察在监控页中的实际遮挡与醒目程度。',
                  style: context.textTheme.bodySmall!.copyWith(
                    color: rmTextSecondary(context),
                  ),
                ),
                context.sizedBox(h: 12),
                for (final option in DashboardNotificationStyle.values)
                  _NotificationStyleTile(
                    option: option,
                    selected: option == style,
                    onTap: () => onStyleSelected(option),
                  ),
                context.sizedBox(h: 10),
                Wrap(
                  spacing: context.sp(8),
                  runSpacing: context.sp(8),
                  children: [
                    for (final preset in dashboardNotificationPreviewPresets)
                      OutlinedButton.icon(
                        onPressed: () => onTriggerPreview(preset.content),
                        icon: Icon(
                          preset.content.icon,
                          size: context.iconSize(16),
                        ),
                        label: Text(preset.label),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationStyleTile extends StatelessWidget {
  const _NotificationStyleTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DashboardNotificationStyle option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: context.insetOnly(b: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.sp(14)),
        child: Container(
          padding: context.insetAll(12),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.08)
                : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(context.sp(14)),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? scheme.primary : rmTextSecondary(context),
                size: context.iconSize(18),
              ),
              context.sizedBox(w: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: context.textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    context.sizedBox(h: 3),
                    Text(
                      option.description,
                      style: context.textTheme.bodySmall!.copyWith(
                        color: rmTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
