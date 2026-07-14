/// 为敌方血量监控优化的机器人状态列表。
///
/// 协议 `robot_health` 的顺序为 `[己方 0-4，对方 5-9]`，每侧依次为
/// 英雄/工程/步兵3/步兵4/哨兵。已连接侧（己方）由登录机器人 ID 决定，另一侧为敌方。
///
/// ## 设计特性
/// - **队伍血量摘要栏**：并排比较己方与敌方总 HP。
/// - **血量渐变色**：绿色（>60%）→ 橙色（30-60%）→ 红色（<30%）。
/// - **低血量脉冲**：机器人低于 25% HP 时显示动画光晕。
/// - **平滑过渡**：每条血量栏使用 `TweenAnimationBuilder`。
/// - **游戏 HUD 字体**：数字使用等宽字形，视觉层级更清晰。
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/state/session_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../../settings/domain/kill_estimate_config.dart';
import '../../../settings/logic/kill_estimate_provider.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

// ======================================================================
// 常量
// ======================================================================

/// 血量颜色编码使用的阈值。
const double _healthHigh = 0.60; // 绿色
const double _healthMid = 0.30; // 橙色
// 下方 _healthMid → 红方

/// 低于该比例的机器人会触发低血量脉冲。
const double _criticalThreshold = 0.25;

// ======================================================================
// 机器人定义辅助函数
// ======================================================================

/// 机器人类型定义，包含显示名称、资源和数据映射。
class _RobotDef {
  const _RobotDef({
    required this.name,
    required this.iconAsset,
    required this.dataIndex,
    required this.maxHealth,
    required this.role,
    required this.sideColor,
    required this.isEnemy,
    this.isDrone = false,
  });

  final String name;
  final String iconAsset;
  final int dataIndex;
  final int maxHealth;
  final KillEstimateRobotRole? role;
  final Color sideColor;
  final bool isEnemy;
  final bool isDrone;
}

/// 一个队伍的机器人行分组。
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

/// 构建一个队伍中需要显示的五个机器人。
///
/// [isBlue] 选择红/蓝方资源和名称；[isEnemy] 将数据索引从己方块（0-4）
/// 平移到敌方块（5-9）。
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
    KillEstimateRobotRole? estimateRole,
    bool drone = false,
  }) => _RobotDef(
    name: '$sideName $role',
    iconAsset: 'assets/$asset.png',
    dataIndex: drone ? -1 : base + offset,
    maxHealth: maxHp,
    role: estimateRole,
    sideColor: color,
    isEnemy: isEnemy,
    isDrone: drone,
  );
  return [
    def(
      '英雄',
      '${prefix}Hero',
      0,
      500,
      estimateRole: KillEstimateRobotRole.hero,
    ),
    // 按设计规范，工程（偏移 1）不在 UI 中展示。
    def(
      '步兵3',
      '${prefix}SentryInfantry',
      2,
      300,
      estimateRole: KillEstimateRobotRole.infantry3,
    ),
    def(
      '步兵4',
      '${prefix}SentryInfantry',
      3,
      300,
      estimateRole: KillEstimateRobotRole.infantry4,
    ),
    def(
      '哨兵',
      '${prefix}SentryInfantry',
      4,
      600,
      estimateRole: KillEstimateRobotRole.sentry,
    ),
    def('无人机', '${prefix}Drone', 0, 100, drone: true),
  ];
}

// ======================================================================
// 血量颜色辅助函数
// ======================================================================

/// 按 [ratio] 从绿色 → 橙色 → 红色插值出血量颜色。
Color _healthColor(double ratio, Color sideColor) {
  if (ratio >= _healthHigh) return sideColor;
  if (ratio >= _healthMid) return rmHealthMidColor;
  return rmHealthLowColor;
}

// ======================================================================
// RobotStatusList 机器人状态列表
// ======================================================================

/// 带队伍血量比较的机器人状态面板。
///
/// 默认显示敌方机器人血量详情，也可通过 [dashboardDisplayModeProvider] 显示双方。
/// 顶部摘要栏比较己方与敌方总血量；下方逐机器人显示带渐变色和低血量脉冲的血量条。
class RobotStatusList extends ConsumerWidget {
  /// 创建 [RobotStatusList]。
  const RobotStatusList({
    this.gameState,
    this.ownIsBlueOverride,
    this.modeOverride,
    super.key,
  });

  /// 回放使用的可选固定状态；null 表示使用实时状态。
  final GameState? gameState;

  /// 回放使用的己方阵营覆盖值；null 表示读取 [selectedRobotIdProvider]。
  final bool? ownIsBlueOverride;

  /// 回放使用的显示模式覆盖值；null 表示读取实时 Provider。
  final DashboardDisplayMode? modeOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState effectiveState = gameState ?? ref.watch(gameStateProvider);
    final bool ownIsBlue =
        ownIsBlueOverride ?? isBlueSide(ref.watch(selectedRobotIdProvider));
    final DashboardDisplayMode mode =
        modeOverride ?? ref.watch(dashboardDisplayModeProvider);
    final estimateConfig = ref.watch(killEstimateConfigProvider);

    final sections = _resolveSections(ownIsBlue: ownIsBlue, mode: mode);
    final enemyDefs = _enemyDefs(ownIsBlue: ownIsBlue, sections: sections);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.2, 0, 0, 1), // MD3 强调减速曲线
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
                // --- 队伍血量比较栏 ---
                _TeamHealthSummary(
                  gameState: effectiveState,
                  ownIsBlue: ownIsBlue,
                ),

                context.sizedBox(h: 10),

                // --- 按机器人血量列表 ---
                Expanded(
                  child: _buildSectionList(context, sections, effectiveState),
                ),

                // --- 敌方集火建议（仅 enemyFocus 模式）---
                if (mode == DashboardDisplayMode.enemyFocus &&
                    enemyDefs.isNotEmpty)
                  _buildSuggestionBar(
                    context,
                    effectiveState,
                    enemyDefs,
                    estimateConfig,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 提取敌方区段的机器人定义；不存在时返回空列表。
  static List<_RobotDef> _enemyDefs({
    required bool ownIsBlue,
    required List<_TeamSection> sections,
  }) {
    for (final s in sections) {
      if (s.title == 'enemy') return s.defs;
    }
    return [];
  }

  /// 根据 [mode] 和己方阵营解析要显示的队伍区段。
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

  /// 为一个队伍区段构建完整可见的单列。
  Widget _buildSectionColumn(
    BuildContext context,
    _TeamSection section,
    GameState gameState, {
    required bool isSingle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !isSingle || constraints.maxHeight < context.sp(318);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(title: section.title, color: section.color),
            context.sizedBox(h: 6),
            for (final def in section.defs)
              _RobotStatusRow(
                def: def,
                gameState: gameState,
                compact: compact,
              ),
          ],
        );
      },
    );
  }

  /// 建议栏：高亮当前血量比例最低的敌方机器人。
  Widget _buildSuggestionBar(
    BuildContext context,
    GameState gameState,
    List<_RobotDef> enemyDefs,
    KillEstimateConfig estimateConfig,
  ) {
    _RobotDef? lowestDef;
    var lowestHp = double.infinity;
    int? lowestHealth;
    for (final def in enemyDefs) {
      final hp = _getHealth(def, gameState);
      final role = def.role;
      final maxHp = role == null
          ? def.maxHealth
          : estimateConfig.maxHealth(role);
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
    final targetRole = lowestDef.role;
    final targetMax = targetRole == null
        ? lowestDef.maxHealth
        : estimateConfig.maxHealth(targetRole);

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
                '集火目标 · ${lowestDef.name}  剩余 $lowestHealth / '
                '$targetMax',
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

  /// 从 [gameState] 中读取 [def] 对应的血量。
  static int _getHealth(_RobotDef def, GameState gameState) {
    if (def.dataIndex < 0) return 0;
    final list = gameState.globalUnitStatus?.robotHealth;
    if (list == null || def.dataIndex >= list.length) return 0;
    return list[def.dataIndex];
  }
}

// ======================================================================
// _TeamHealthSummary - 紧凑的并排 HP 栏
// ======================================================================

/// 用一组红/蓝方进度条显示己方与敌方总血量，并叠加 HP 数值。
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
          // 己方血量段。
          Expanded(
            flex: (allyRatio * 100).round().clamp(1, 99),
            child: _TeamBarSegment(
              value: allyRatio,
              color: allyColor,
              label: 'HP $allyTotal',
            ),
          ),
          context.sizedBox(w: 2),
          // 敌方血量段。
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
// _TeamBarSegment - 带 HP 标签的单侧彩色栏
// ======================================================================

/// 血量比较栏中的单侧分段，包含动画填充和左侧紧凑 HP 标签。
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
                // 背景轨道。
                Positioned.fill(
                  child: Container(color: color.withValues(alpha: 0.10)),
                ),
                // 动画填充。
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
                // HP 标签（始终可见）。
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
// _SectionHeader - 最小队伍强调色条
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
// _RobotStatusRow - 带动画条的单个机器人血量行
// ======================================================================

/// 单个机器人血量行，包含渐变血量条、百分比标签和低血量脉冲动画。
class _RobotStatusRow extends ConsumerWidget {
  const _RobotStatusRow({
    required this.def,
    required this.gameState,
    this.compact = false,
  });

  final _RobotDef def;
  final GameState gameState;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(killEstimateConfigProvider);
    final health = _getHealth();
    final hasData =
        def.dataIndex >= 0 &&
        (gameState.globalUnitStatus?.robotHealth.length ?? 0) > def.dataIndex;
    final role = def.role;
    final maxHealth = role == null ? def.maxHealth : config.maxHealth(role);
    final healthPercent = hasData ? (health / maxHealth).clamp(0.0, 1.0) : 0.0;
    final isCritical = hasData && healthPercent < _criticalThreshold;
    final projectileMode = _projectileMode(ref.watch(selectedRobotIdProvider));
    final expectedProjectiles = projectileMode == null || !hasData
        ? null
        : config.expectedProjectiles(
            currentHealth: health,
            useLargeProjectile: projectileMode,
          );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.sp(compact ? 2 : 3)),
      child: _AnimatedHealthRow(
        def: def,
        health: health,
        maxHealth: maxHealth,
        healthPercent: healthPercent,
        hasData: hasData,
        isCritical: isCritical,
        compact: compact,
        gameState: gameState,
        expectedProjectiles: expectedProjectiles,
        canEstimate: projectileMode != null,
      ),
    );
  }

  int _getHealth() {
    if (def.dataIndex < 0) return 0;
    final list = gameState.globalUnitStatus?.robotHealth;
    if (list == null || def.dataIndex >= list.length) return 0;
    return list[def.dataIndex];
  }

  bool? _projectileMode(int robotId) {
    final baseId = robotId >= 100 ? robotId - 100 : robotId;
    if (baseId == 1) return true;
    if (baseId == 3 || baseId == 4 || baseId == 7) return false;
    return null;
  }
}

// ======================================================================
// _AnimatedHealthRow - 平滑动画化血量变化
// ======================================================================

class _AnimatedHealthRow extends StatefulWidget {
  const _AnimatedHealthRow({
    required this.def,
    required this.health,
    required this.maxHealth,
    required this.healthPercent,
    required this.hasData,
    required this.isCritical,
    required this.compact,
    required this.gameState,
    required this.expectedProjectiles,
    required this.canEstimate,
  });

  final _RobotDef def;
  final int health;
  final int maxHealth;
  final double healthPercent;
  final bool hasData;
  final bool isCritical;
  final bool compact;
  final GameState gameState;
  final int? expectedProjectiles;
  final bool canEstimate;

  @override
  State<_AnimatedHealthRow> createState() => _AnimatedHealthRowState();
}

class _AnimatedHealthRowState extends State<_AnimatedHealthRow>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scanController;

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
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.isCritical) {
      _pulseController.repeat(reverse: true);
    }
    if (_shouldScan) _scanController.repeat();
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
    if (_shouldScan && !_scanController.isAnimating) {
      _scanController.repeat();
    } else if (!_shouldScan && _scanController.isAnimating) {
      _scanController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  bool get _shouldScan => !widget.hasData && !widget.def.isDrone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = widget.def.isDrone
        ? rmCounterBarColor
        : widget.hasData
        ? _healthColor(widget.healthPercent, widget.def.sideColor)
        : widget.def.sideColor;
    final progress = widget.def.isDrone
        ? _droneProgress()
        : widget.healthPercent;
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _scanController]),
      builder: (context, _) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Container(
          height: context.sp(widget.compact ? 48 : 54),
          clipBehavior: Clip.antiAlias,
          decoration: _rowDecoration(context, barColor),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: _shouldScan
                      ? widget.def.sideColor.withValues(alpha: 0.07)
                      : scheme.surfaceContainerHigh,
                ),
              ),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: ColoredBox(color: barColor),
              ),
              if (_shouldScan) _buildScanGlow(),
              Positioned.fill(child: _buildRowContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanGlow() {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final glowWidth = constraints.maxWidth * 0.28;
            final travel = constraints.maxWidth + glowWidth;
            return Stack(
              children: [
                Positioned(
                  key: const ValueKey<String>('health-scan-glow'),
                  left: travel * _scanController.value - glowWidth,
                  top: 0,
                  bottom: 0,
                  width: glowWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.def.sideColor.withValues(alpha: 0),
                          widget.def.sideColor.withValues(alpha: 0.34),
                          widget.def.sideColor.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  BoxDecoration _rowDecoration(BuildContext context, Color barColor) {
    final pulse = widget.isCritical ? _pulseAnimation.value : 0.0;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(context.rmCardRadius),
      border: Border.all(
        color: barColor.withValues(alpha: 0.45 + pulse * 0.35),
      ),
      boxShadow: [
        BoxShadow(
          color: barColor.withValues(alpha: 0.12 + pulse * 0.16),
          blurRadius: context.sp(6 + pulse * 4),
          offset: Offset(0, context.sp(2)),
        ),
      ],
    );
  }

  Widget _buildRowContent(BuildContext context) {
    return Row(
      children: [
        _AcrylicSurface(
          width: context.sp(widget.compact ? 190 : 220),
          padding: context.insetSym(h: 10, v: 4),
          child: Row(
            children: [
              _buildIcon(context),
              context.sizedBox(w: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _buildInfoColumn(context),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _buildValueDisplay(context),
        context.sizedBox(w: 8),
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
            // 角色名称胶囊。
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
            // 低血量徽标。
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
        // 血量文本。
        if (widget.def.isDrone)
          _droneLabel(context)
        else
          Text(
            widget.hasData
                ? 'HP ${widget.health} / ${widget.maxHealth}  ·  ${(healthPercent * 100).round()}%'
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
    if (widget.def.isDrone) {
      final sync = widget.gameState.airSupportStatusSync;
      final text = (widget.def.isEnemy || sync == null)
          ? '—'
          : '${sync.shooterStatus.clamp(0, 100)}';
      return _valueText(context, text, '反制', rmCounterBarColor);
    }
    final text = !widget.canEstimate
        ? '—'
        : widget.expectedProjectiles?.toString() ?? '等待';
    return _valueText(
      context,
      text,
      '预计弹丸',
      Theme.of(context).colorScheme.onSurface,
    );
  }

  Widget _valueText(
    BuildContext context,
    String text,
    String label,
    Color color,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _AcrylicSurface(
      width: context.sp(82),
      padding: context.insetSym(h: 8, v: 5),
      borderRadius: BorderRadius.circular(context.sp(10)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: context.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              label,
              maxLines: 1,
              style: context.textTheme.labelSmall!.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _droneProgress() {
    if (widget.def.isEnemy) return 0;
    final sync = widget.gameState.airSupportStatusSync;
    if (sync == null) return 0;
    return sync.shooterStatus.clamp(0, 100) / 100.0;
  }

  /// 从“蓝方英雄”这类名称中提取“英雄”这样的短角色名。
  static String _shortName(String full) {
    final idx = full.indexOf(' ');
    return idx >= 0 ? full.substring(idx + 1) : full;
  }
}

/// 允许底层血量颜色透出的半透明亚克力信息表面。
class _AcrylicSurface extends StatelessWidget {
  const _AcrylicSurface({
    required this.child,
    required this.width,
    required this.padding,
    this.borderRadius,
  });

  final Widget child;
  final double width;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius =
        borderRadius ??
        BorderRadius.horizontal(left: Radius.circular(context.rmCardRadius));
    final alpha = theme.brightness == Brightness.dark ? 0.48 : 0.62;
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: alpha),
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
