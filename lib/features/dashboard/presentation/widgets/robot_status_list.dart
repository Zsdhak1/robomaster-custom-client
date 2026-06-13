/// Robot status list rendered per selected side and display mode.
///
/// Protocol `robot_health` is ordered `[己方 0-4, 对方 5-9]`, each side as
/// 英雄/工程/步兵3/步兵4/哨兵. The connected side (己方) is decided by the
/// logged-in robot id; the opposing side is 对方. The list shows either the
/// enemy detail (enemyFocus) or both teams (both), per [dashboardDisplayModeProvider].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/session_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

/// Robot type definition with display name, asset and data mapping.
class _RobotDef {
  const _RobotDef({
    required this.name,
    required this.iconAsset,
    required this.dataIndex,
    required this.maxHealth,
    required this.sideColor,
    required this.isEnemy,
    this.isDrone = false,
  });

  /// Display name shown on the label pill.
  final String name;

  /// Asset path for the robot icon.
  final String iconAsset;

  /// Index into [GlobalUnitStatus.robotHealth]; -1 for the drone (no health).
  final int dataIndex;

  /// Maximum health used to scale the health bar.
  final int maxHealth;

  /// Team color (red/blue) used for the label, bar and value.
  final Color sideColor;

  /// Whether this robot belongs to the opposing (对方) side.
  final bool isEnemy;

  /// Whether this is the aerial drone (shows counter-progress, no ammo).
  final bool isDrone;
}

/// A titled group of robot rows for one team.
class _TeamSection {
  const _TeamSection({
    required this.title,
    required this.color,
    required this.defs,
  });

  final String title;
  final Color color;
  final List<_RobotDef> defs;
}

/// Builds the five display robots for one team.
///
/// [isBlue] selects red/blue assets and names; [isEnemy] shifts the data
/// indices from the 己方 block (0-4) to the 对方 block (5-9).
List<_RobotDef> _teamDefs({required bool isBlue, required bool isEnemy}) {
  final prefix = isBlue ? 'Blue' : 'Red';
  final sideName = isBlue ? '蓝方' : '红方';
  final color = isBlue ? rmBlueTeamColor : rmRedTeamColor;
  final base = isEnemy ? 5 : 0;
  _RobotDef def(String role, String asset, int offset, int maxHp,
          {bool drone = false}) =>
      _RobotDef(
        name: '$sideName $role',
        iconAsset: 'assets/$asset.png',
        dataIndex: drone ? -1 : base + offset,
        maxHealth: maxHp,
        sideColor: color,
        isEnemy: isEnemy,
        isDrone: drone,
      );
  return [
    def('英雄', '${prefix}Hero', 0, 500),
    def('步兵3', '${prefix}SentryInfantry', 2, 300),
    def('步兵4', '${prefix}SentryInfantry', 3, 300),
    def('哨兵', '${prefix}SentryInfantry', 4, 600),
    def('无人机', '${prefix}Drone', 0, 100, drone: true),
  ];
}

/// Displays robot status rows grouped by team, per side and display mode.
///
/// When [gameState] is provided (replay), it renders that snapshot with the
/// supplied [ownIsBlueOverride] / [modeOverride]; otherwise it watches the live
/// providers. Replay and live never share mutable state.
class RobotStatusList extends ConsumerWidget {
  /// Creates a [RobotStatusList].
  const RobotStatusList({
    this.gameState,
    this.ownIsBlueOverride,
    this.modeOverride,
    super.key,
  });

  /// Optional fixed state for replay; null means use live state.
  final GameState? gameState;

  /// Own-side override for replay; null means read [selectedRobotIdProvider].
  final bool? ownIsBlueOverride;

  /// Display-mode override for replay; null means read the live provider.
  final DashboardDisplayMode? modeOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState effectiveState =
        gameState ?? ref.watch(gameStateProvider);
    final bool ownIsBlue = ownIsBlueOverride ??
        isBlueSide(ref.watch(selectedRobotIdProvider));
    final DashboardDisplayMode mode =
        modeOverride ?? ref.watch(dashboardDisplayModeProvider);

    final sections = _resolveSections(ownIsBlue: ownIsBlue, mode: mode);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: rmCardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, effectiveState),
              const SizedBox(height: 8),
              Expanded(child: _buildSectionList(sections, effectiveState)),
            ],
          ),
        ),
      ),
    );
  }

  /// Resolves which team sections to show for [mode] and the own side.
  List<_TeamSection> _resolveSections({
    required bool ownIsBlue,
    required DashboardDisplayMode mode,
  }) {
    final enemy = _TeamSection(
      title: '敌方 · ${ownIsBlue ? '红方' : '蓝方'}',
      color: ownIsBlue ? rmRedTeamColor : rmBlueTeamColor,
      defs: _teamDefs(isBlue: !ownIsBlue, isEnemy: true),
    );
    if (mode == DashboardDisplayMode.enemyFocus) {
      return [enemy];
    }
    final own = _TeamSection(
      title: '己方 · ${ownIsBlue ? '蓝方' : '红方'}',
      color: ownIsBlue ? rmBlueTeamColor : rmRedTeamColor,
      defs: _teamDefs(isBlue: ownIsBlue, isEnemy: false),
    );
    return [own, enemy];
  }

  Widget _buildSectionList(List<_TeamSection> sections, GameState gameState) {
    // 双方都显示时（两栏）横向并列；单栏时（敌方详情）保持纵向铺满。
    if (sections.length > 1) {
      final columns = <Widget>[];
      for (var i = 0; i < sections.length; i++) {
        if (i > 0) columns.add(const SizedBox(width: 16));
        columns.add(
          Expanded(child: _buildSectionColumn(sections[i], gameState)),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns,
      );
    }
    return _buildSectionColumn(sections.first, gameState);
  }

  /// Builds a single scrollable column for one team section.
  Widget _buildSectionColumn(_TeamSection section, GameState gameState) {
    final children = <Widget>[
      _SectionHeader(title: section.title, color: section.color),
      for (final def in section.defs)
        _RobotStatusRow(def: def, gameState: gameState),
    ];
    return ListView(children: children);
  }

  Widget _buildHeader(BuildContext context, GameState gameState) {
    // 己方累计允许载弹量 = Σ robot_bullets[0..4]（协议字段12）。
    final totalBullets = gameState.allyTotalBullets;
    final muted = rmTextSecondary(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text(
          '机器人状态',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        Icon(Icons.adjust, size: 16, color: muted),
        const SizedBox(width: 4),
        Text(
          '己方累计载弹量: ',
          style: TextStyle(fontSize: 13, color: muted),
        ),
        Text(
          totalBullets?.toString() ?? '—',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: rmHealthBarColor,
          ),
        ),
      ],
    );
  }
}

/// A team divider pill used between robot groups.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single robot status row: icon, label, progress bar, value.
class _RobotStatusRow extends StatelessWidget {
  const _RobotStatusRow({required this.def, required this.gameState});

  final _RobotDef def;
  final GameState gameState;

  @override
  Widget build(BuildContext context) {
    final health = _getHealth();
    final healthPercent = (health / def.maxHealth).clamp(0.0, 1.0);
    final hasData = def.dataIndex >= 0 &&
        (gameState.globalUnitStatus?.robotHealth.length ?? 0) > def.dataIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _buildIcon(),
          const SizedBox(width: 10),
          _buildLabel(),
          const SizedBox(width: 10),
          _buildProgressSection(context, health, healthPercent, hasData),
          const SizedBox(width: 10),
          _buildValueDisplay(health, hasData),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return ClipOval(
      child: Image.asset(
        def.iconAsset,
        width: rmRobotIconSize,
        height: rmRobotIconSize,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(
          Icons.smart_toy,
          size: rmRobotIconSize,
        ),
      ),
    );
  }

  Widget _buildLabel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: def.sideColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        def.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: def.sideColor,
        ),
      ),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, int health, double healthPercent, bool hasData) {
    final (label, progressValue, barColor) = def.isDrone
        ? _droneCounterInfo()
        : (
            hasData ? '血量: $health / ${def.maxHealth}' : '血量: 等待数据',
            healthPercent,
            def.sideColor,
          );

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: rmTextSecondary(context)),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 12,
              backgroundColor: rmTrackFill(context),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the drone counter (标签, 进度0~1, 颜色).
  ///
  /// The air-support counter (AirSupportStatusSync) is己方-relative, so only
  /// the own-side drone shows live progress; the enemy drone has no telemetry.
  (String, double, Color) _droneCounterInfo() {
    if (def.isEnemy) {
      return ('反制进度: 无遥测', 0, rmCounterBarColor);
    }
    final sync = gameState.airSupportStatusSync;
    if (sync == null) {
      return ('反制进度: 等待数据', 0, rmCounterBarColor);
    }
    final progress = sync.shooterStatus.clamp(0, 100);
    return ('反制进度: $progress%', progress / 100.0, rmCounterBarColor);
  }

  Widget _buildValueDisplay(int health, bool hasData) {
    final String text;
    if (def.isDrone) {
      final sync = gameState.airSupportStatusSync;
      text = (def.isEnemy || sync == null)
          ? '—'
          : '${sync.shooterStatus.clamp(0, 100)}';
    } else {
      text = !hasData ? '—' : '$health';
    }
    return SizedBox(
      width: 56,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: def.sideColor,
        ),
      ),
    );
  }

  int _getHealth() {
    if (def.dataIndex < 0) return 0;
    final list = gameState.globalUnitStatus?.robotHealth;
    if (list == null || def.dataIndex >= list.length) return 0;
    return list[def.dataIndex];
  }
}
