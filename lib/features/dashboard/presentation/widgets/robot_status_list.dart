/// Professionally designed robot status list optimized for enemy health monitoring.
///
/// Protocol `robot_health` is ordered `[己方 0-4, 对方 5-9]`, each side as
/// 英雄/工程/步兵3/步兵4/哨兵. The connected side (己方) is decided by the
/// logged-in robot id; the opposing side is 对方.
///
/// ## Design Features
/// - **Team Health Summary Bar**: Side-by-side ally vs enemy total HP comparison.
/// - **Health Gradient Colors**: Green (>60%) → Orange (30-60%) → Red (<30%).
/// - **Critical-Health Pulse**: Animated glow for robots below 25% HP.
/// - **Smooth Transitions**: `TweenAnimationBuilder` on every health bar.
/// - **Game-HUD Typography**: Monospaced numbers, clear visual hierarchy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/state/session_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

// ======================================================================
// Constants
// ======================================================================

/// Thresholds for health color coding.
const double _healthHigh = 0.60; // green
const double _healthMid = 0.30; // orange
// below _healthMid → red

/// Below this fraction the robot gets a critical-pulse badge.
const double _criticalThreshold = 0.25;

// ======================================================================
// Robot definition helpers
// ======================================================================

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

  final String name;
  final String iconAsset;
  final int dataIndex;
  final int maxHealth;
  final Color sideColor;
  final bool isEnemy;
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
  _RobotDef def(
    String role,
    String asset,
    int offset,
    int maxHp, {
    bool drone = false,
  }) => _RobotDef(
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
    // Note: 工程 (offset 1) is intentionally omitted from UI per spec.
    def('步兵3', '${prefix}SentryInfantry', 2, 300),
    def('步兵4', '${prefix}SentryInfantry', 3, 300),
    def('哨兵', '${prefix}SentryInfantry', 4, 600),
    def('无人机', '${prefix}Drone', 0, 100, drone: true),
  ];
}

// ======================================================================
// Health color helpers
// ======================================================================

/// Returns a color interpolated from green → orange → red based on [ratio].
Color _healthColor(double ratio) {
  if (ratio >= _healthHigh) {
    // Green -> Yellow-Orange
    final t = (ratio - _healthHigh) / (1.0 - _healthHigh);
    return Color.lerp(rmHealthMidColor, rmHealthHighColor, t)!;
  } else if (ratio >= _healthMid) {
    // Yellow-Orange -> Orange-Red
    final t = (ratio - _healthMid) / (_healthHigh - _healthMid);
    return Color.lerp(rmHealthLowColor, rmHealthMidColor, t)!;
  } else {
    return rmHealthLowColor;
  }
}

// ======================================================================
// RobotStatusList
// ======================================================================

/// Professionally designed robot status panel with team health comparison.
///
/// Shows enemy robot health details (default) or both teams, configurable via
/// [dashboardDisplayModeProvider]. Includes a summary bar at the top comparing
/// ally vs enemy total health, and per-robot health bars with gradient coloring
/// and critical-health pulse effects.
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
    final GameState effectiveState = gameState ?? ref.watch(gameStateProvider);
    final bool ownIsBlue =
        ownIsBlueOverride ?? isBlueSide(ref.watch(selectedRobotIdProvider));
    final DashboardDisplayMode mode =
        modeOverride ?? ref.watch(dashboardDisplayModeProvider);

    final sections = _resolveSections(ownIsBlue: ownIsBlue, mode: mode);
    final enemyDefs = _enemyDefs(ownIsBlue: ownIsBlue, sections: sections);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.2, 0, 0, 1), // MD3 emphasized decelerate
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: context.insetAll(12),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: context.insetAll(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Team Health Comparison Bar ---
                _TeamHealthSummary(
                  gameState: effectiveState,
                  ownIsBlue: ownIsBlue,
                ),

                context.sizedBox(h: 10),

                // --- Per-robot health list ---
                Expanded(
                  child: _buildSectionList(context, sections, effectiveState),
                ),

                // --- Enemy gang-up suggestion (only in enemyFocus mode) ---
                if (mode == DashboardDisplayMode.enemyFocus &&
                    enemyDefs.isNotEmpty)
                  _buildSuggestionBar(context, effectiveState, enemyDefs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Extracts the enemy section defs, if any.
  static List<_RobotDef> _enemyDefs({
    required bool ownIsBlue,
    required List<_TeamSection> sections,
  }) {
    for (final s in sections) {
      if (s.title == 'enemy') return s.defs;
    }
    return [];
  }

  /// Resolves which team sections to show for [mode] and the own side.
  List<_TeamSection> _resolveSections({
    required bool ownIsBlue,
    required DashboardDisplayMode mode,
  }) {
    final enemy = _TeamSection(
      title: 'enemy',
      color: ownIsBlue ? rmRedTeamColor : rmBlueTeamColor,
      defs: _teamDefs(isBlue: !ownIsBlue, isEnemy: true),
    );
    if (mode == DashboardDisplayMode.enemyFocus) {
      return [enemy];
    }
    final own = _TeamSection(
      title: 'own',
      color: ownIsBlue ? rmBlueTeamColor : rmRedTeamColor,
      defs: _teamDefs(isBlue: ownIsBlue, isEnemy: false),
    );
    return [own, enemy];
  }

  Widget _buildSectionList(
    BuildContext context,
    List<_TeamSection> sections,
    GameState gameState,
  ) {
    if (sections.length > 1) {
      final columns = <Widget>[];
      for (var i = 0; i < sections.length; i++) {
        if (i > 0) columns.add(context.sizedBox(w: 16));
        columns.add(
          Expanded(
            child: _buildSectionColumn(
              context,
              sections[i],
              gameState,
              isSingle: false,
            ),
          ),
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: columns,
      );
    }
    return _buildSectionColumn(
      context,
      sections.first,
      gameState,
      isSingle: true,
    );
  }

  /// Builds a single scrollable column for one team section.
  Widget _buildSectionColumn(
    BuildContext context,
    _TeamSection section,
    GameState gameState, {
    required bool isSingle,
  }) {
    final children = <Widget>[
      _SectionHeader(title: section.title, color: section.color),
      context.sizedBox(h: 6),
      for (final def in section.defs)
        _RobotStatusRow(def: def, gameState: gameState, compact: !isSingle),
    ];
    return ListView(children: children);
  }

  /// Suggestion bar: highlights which enemy robot has the lowest health.
  Widget _buildSuggestionBar(
    BuildContext context,
    GameState gameState,
    List<_RobotDef> enemyDefs,
  ) {
    _RobotDef? lowestDef;
    var lowestHp = double.infinity;
    int? lowestHealth;
    for (final def in enemyDefs) {
      final hp = _getHealth(def, gameState);
      final maxHp = def.maxHealth;
      if (maxHp <= 0) continue;
      final ratio = hp / maxHp;
      if (ratio < lowestHp) {
        lowestHp = ratio;
        lowestDef = def;
        lowestHealth = hp;
      }
    }

    if (lowestDef == null || lowestHp > _criticalThreshold) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: context.sp(8)),
      child: Container(
        padding: context.insetSym(h: 12, v: 8),
        decoration: BoxDecoration(
          color: rmHealthLowColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(context.sp(8)),
          border: Border.all(color: rmHealthLowColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.whatshot,
              size: context.iconSize(18),
              color: rmHealthLowColor,
            ),
            context.sizedBox(w: 8),
            Expanded(
              child: Text(
                '集火目标 · ${lowestDef.name}  剩余 $lowestHealth / ${lowestDef.maxHealth}',
                style: context.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: rmHealthLowColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reads health from [gameState] for [def].
  static int _getHealth(_RobotDef def, GameState gameState) {
    if (def.dataIndex < 0) return 0;
    final list = gameState.globalUnitStatus?.robotHealth;
    if (list == null || def.dataIndex >= list.length) return 0;
    return list[def.dataIndex];
  }
}

// ======================================================================
// _TeamHealthSummary — compact side-by-side HP bars
// ======================================================================

/// Compact bar showing ally vs enemy total health as a pair of
/// red/blue progress bars with HP values overlaid.
class _TeamHealthSummary extends StatelessWidget {
  const _TeamHealthSummary({required this.gameState, required this.ownIsBlue});

  final GameState gameState;
  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    final allyTotal = gameState.allyTotalHealth ?? 0;
    final enemyTotal = gameState.enemyTotalHealth ?? 0;
    final combined = (allyTotal + enemyTotal).toDouble();
    final allyRatio = combined > 0 ? allyTotal / combined : 0.5;
    final enemyRatio = combined > 0 ? enemyTotal / combined : 0.5;

    final allyColor = ownIsBlue ? rmBlueTeamColor : rmRedTeamColor;
    final enemyColor = ownIsBlue ? rmRedTeamColor : rmBlueTeamColor;

    return Container(
      padding: context.insetSym(h: 10, v: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(context.sp(6)),
      ),
      child: Row(
        children: [
          // Ally bar segment
          Expanded(
            flex: (allyRatio * 100).round().clamp(1, 99),
            child: _TeamBarSegment(
              value: allyRatio,
              color: allyColor,
              label: 'HP $allyTotal',
            ),
          ),
          context.sizedBox(w: 2),
          // Enemy bar segment
          Expanded(
            flex: (enemyRatio * 100).round().clamp(1, 99),
            child: _TeamBarSegment(
              value: enemyRatio,
              color: enemyColor,
              label: 'HP $enemyTotal',
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// _TeamBarSegment — single colored bar with HP label
// ======================================================================

/// A single side of the health comparison bar with an animated fill
/// and a compact HP label overlaid on the left side.
class _TeamBarSegment extends StatelessWidget {
  const _TeamBarSegment({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(context.sp(3)),
          child: SizedBox(
            height: context.sp(16),
            child: Stack(
              children: [
                // Background track
                Positioned.fill(
                  child: Container(color: color.withValues(alpha: 0.10)),
                ),
                // Animated fill
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: t,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.7), color],
                      ),
                    ),
                  ),
                ),
                // HP label (always visible)
                Positioned(
                  left: context.sp(6),
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: context.textTheme.labelSmall!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================================================================
// _SectionHeader — minimal team accent bar
// ======================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.sp(2), bottom: context.sp(4)),
      child: Container(
        height: context.sp(2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(context.sp(1)),
        ),
      ),
    );
  }
}

// ======================================================================
// _RobotStatusRow — single robot health row with animated bar
// ======================================================================

/// A single robot health row with a gradient health bar, percentage label,
/// and critical-health pulse animation.
class _RobotStatusRow extends StatelessWidget {
  const _RobotStatusRow({
    required this.def,
    required this.gameState,
    this.compact = false,
  });

  final _RobotDef def;
  final GameState gameState;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final health = _getHealth();
    final hasData =
        def.dataIndex >= 0 &&
        (gameState.globalUnitStatus?.robotHealth.length ?? 0) > def.dataIndex;
    final healthPercent = hasData
        ? (health / def.maxHealth).clamp(0.0, 1.0)
        : 0.0;
    final isCritical = hasData && healthPercent < _criticalThreshold;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(compact ? 4 : 6)),
      child: _AnimatedHealthRow(
        def: def,
        health: health,
        healthPercent: healthPercent,
        hasData: hasData,
        isCritical: isCritical,
        compact: compact,
        gameState: gameState,
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

// ======================================================================
// _AnimatedHealthRow — smoothly animates health changes
// ======================================================================

class _AnimatedHealthRow extends StatefulWidget {
  const _AnimatedHealthRow({
    required this.def,
    required this.health,
    required this.healthPercent,
    required this.hasData,
    required this.isCritical,
    required this.compact,
    required this.gameState,
  });

  final _RobotDef def;
  final int health;
  final double healthPercent;
  final bool hasData;
  final bool isCritical;
  final bool compact;
  final GameState gameState;

  @override
  State<_AnimatedHealthRow> createState() => _AnimatedHealthRowState();
}

class _AnimatedHealthRowState extends State<_AnimatedHealthRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
    if (widget.isCritical) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedHealthRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCritical && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isCritical && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildIcon(context),
            context.sizedBox(w: 10),
            Expanded(child: _buildInfoColumn(context)),
            context.sizedBox(w: 8),
            _buildValueDisplay(context),
          ],
        ),
        context.sizedBox(h: 4),
        _buildCompactBar(context),
      ],
    );
  }

  Widget _buildIcon(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseValue = widget.isCritical
            ? 0.7 + _pulseAnimation.value * 0.3
            : 1.0;
        return Transform.scale(
          scale: pulseValue,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: widget.isCritical
                  ? [
                      BoxShadow(
                        color: rmHealthLowColor.withValues(
                          alpha: 0.4 * _pulseAnimation.value,
                        ),
                        blurRadius: context.sp(8),
                        spreadRadius: context.sp(2),
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Image.asset(
                widget.def.iconAsset,
                width: context.rmRobotIconSize * (widget.compact ? 0.75 : 0.85),
                height:
                    context.rmRobotIconSize * (widget.compact ? 0.75 : 0.85),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.smart_toy,
                  size: context.rmRobotIconSize * 0.85,
                  color: widget.def.sideColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoColumn(BuildContext context) {
    final muted = rmTextSecondary(context);
    final healthPercent = widget.healthPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Role name pill
            Container(
              padding: context.insetSym(h: 8, v: 2),
              decoration: BoxDecoration(
                color: widget.def.sideColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(context.sp(12)),
              ),
              child: Text(
                _shortName(widget.def.name),
                style: context.textTheme.bodySmall!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.def.sideColor,
                ),
              ),
            ),
            context.sizedBox(w: 6),
            // Critical badge
            if (widget.isCritical)
              Container(
                padding: context.insetSym(h: 6, v: 1),
                decoration: BoxDecoration(
                  color: rmHealthLowColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(context.sp(8)),
                ),
                child: Text(
                  '致命',
                  style: context.textTheme.labelSmall!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rmHealthLowColor,
                  ),
                ),
              ),
          ],
        ),
        context.sizedBox(h: 3),
        // Health text
        if (widget.def.isDrone)
          _droneLabel(context)
        else
          Text(
            widget.hasData
                ? 'HP ${widget.health} / ${widget.def.maxHealth}  ·  ${(healthPercent * 100).round()}%'
                : '血量: 等待数据',
            style: context.textTheme.labelSmall!.copyWith(
              color: muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }

  Widget _droneLabel(BuildContext context) {
    final muted = rmTextSecondary(context);
    final sync = widget.gameState.airSupportStatusSync;
    if (widget.def.isEnemy || sync == null) {
      return Text(
        '反制进度: 无遥测',
        style: context.textTheme.labelSmall!.copyWith(color: muted),
      );
    }
    final progress = sync.shooterStatus.clamp(0, 100);
    return Text(
      '反制 $progress%',
      style: context.textTheme.labelSmall!.copyWith(
        color: rmCounterBarColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildValueDisplay(BuildContext context) {
    final healthPercent = widget.healthPercent;
    final healthColor = widget.hasData
        ? _healthColor(healthPercent)
        : rmTextSecondary(context);

    if (widget.def.isDrone) {
      final sync = widget.gameState.airSupportStatusSync;
      final text = (widget.def.isEnemy || sync == null)
          ? '—'
          : '${sync.shooterStatus.clamp(0, 100)}';
      return _valueText(context, text, rmCounterBarColor);
    }

    final text = !widget.hasData ? '—' : '${widget.health}';
    return _valueText(context, text, healthColor);
  }

  Widget _valueText(BuildContext context, String text, Color color) {
    return SizedBox(
      width: context.sp(48),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: context.textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  /// Compact progress bar positioned below the info row.
  Widget _buildCompactBar(BuildContext context) {
    final progressValue = widget.def.isDrone
        ? _droneProgress()
        : widget.healthPercent;
    final barColor = widget.def.isDrone
        ? rmCounterBarColor
        : (widget.hasData
              ? _healthColor(widget.healthPercent)
              : rmTrackFill(context));

    return ClipRRect(
      borderRadius: BorderRadius.circular(context.sp(3)),
      child: _AnimatedHealthBar(
        value: progressValue,
        color: barColor,
        height: widget.compact ? context.sp(4) : context.sp(6),
      ),
    );
  }

  double _droneProgress() {
    if (widget.def.isEnemy) return 0;
    final sync = widget.gameState.airSupportStatusSync;
    if (sync == null) return 0;
    return sync.shooterStatus.clamp(0, 100) / 100.0;
  }

  /// Extracts the short role name from "蓝方 英雄" → "英雄".
  static String _shortName(String full) {
    final idx = full.indexOf(' ');
    return idx >= 0 ? full.substring(idx + 1) : full;
  }
}

// ======================================================================
// _AnimatedHealthBar — animated linear progress indicator
// ======================================================================

/// Smoothly animated health bar that transitions when [value] or [color] changes.
class _AnimatedHealthBar extends StatelessWidget {
  const _AnimatedHealthBar({
    required this.value,
    required this.color,
    this.height = 6,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.8), color],
                ),
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
