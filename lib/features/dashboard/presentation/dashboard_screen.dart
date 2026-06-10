/// Main dashboard screen displaying game status, robot health, and events.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_navigation_drawer.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../connection/domain/robot_identity.dart';
import '../../settings/logic/settings_providers.dart';
import '../../settings/presentation/settings_screen.dart';
import '../logic/game_state.dart';
import '../logic/stream_providers.dart';
import 'app_navigation.dart';
import 'widgets/connection_control.dart';
import 'widgets/debug_fab.dart';
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
      drawer: AppNavigationDrawer(
        current: AppDestination.dashboard,
        onSelect: (dest) => navigateToDestination(context, dest),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _TopStatusBar(gameState: gameState),
              const Expanded(child: _MainContent()),
              const SizedBox(height: 200, child: _BottomBar()),
            ],
          ),
          if (devMode && _isDebugOpen)
            Positioned(
              right: 16,
              bottom: 80,
              child: DebugPanel(key: ValueKey<bool>(_isDebugOpen)),
            ),
        ],
      ),
      floatingActionButton: devMode
          ? DebugFab(
              isOpen: _isDebugOpen,
              onToggle: () => setState(() => _isDebugOpen = !_isDebugOpen),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
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
    return const Row(
      children: [
        SizedBox(width: 200, child: GameStatusCard()),
        Expanded(child: HealthChart()),
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
      height: rmTopBarHeight,
      color: primary,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: '菜单',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              isConnected
                  ? '已作为 ${robotDisplayName(selectedId)} 登录（ID：$selectedId）'
                  : '未连接',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _SideBadge(ownIsBlue: ownIsBlue),
          const SizedBox(width: 12),
          _StatusDot(isConnected: isConnected),
          const SizedBox(width: 4),
          const ConnectionAppBarAction(),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ownIsBlue ? '己方 · 蓝方' : '己方 · 红方',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 13,
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
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: isConnected ? Colors.greenAccent : Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}
