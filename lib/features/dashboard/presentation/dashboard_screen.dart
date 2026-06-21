/// Main dashboard screen displaying game status, robot health, and events.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/page_fab_menu.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../../services/mqtt_service.dart';
import '../../connection/domain/robot_identity.dart';
import '../../connection/presentation/connection_screen.dart';
import '../../settings/logic/settings_providers.dart';
import '../logic/game_state.dart';
import '../logic/stream_providers.dart';
import 'widgets/debug_panel.dart';
import 'widgets/event_timeline_panel.dart';
import 'widgets/game_status_card.dart';
import 'widgets/health_chart.dart';
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

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameStateProvider);
    final devMode = ref.watch(developerModeProvider);

    return Scaffold(
      body: Stack(
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
        ],
      ),
      floatingActionButton: _DashboardFab(
        devMode: devMode,
        isDebugOpen: _isDebugOpen,
        onToggleDebug: () => setState(() => _isDebugOpen = !_isDebugOpen),
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
  });

  final bool devMode;
  final bool isDebugOpen;
  final VoidCallback onToggleDebug;

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

/// Bottom strip: game status, health trend chart and connection control.
class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: context.sp(200), child: const GameStatusCard()),
        const Expanded(child: HealthChart()),
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
              style: TextStyle(
                color: Colors.white,
                fontSize: context.fontSize(16),
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: context.fontSize(13),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Small connection indicator dot.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.sp(8),
      height: context.sp(8),
      decoration: BoxDecoration(
        color: isConnected ? Colors.greenAccent : Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}
