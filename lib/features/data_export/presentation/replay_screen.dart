/// 二级回放页面，提供完整比赛回放和可拖动时间线。
///
/// 面向 Pad/PC 的宽屏布局。页面渲染 [ReplayController] 重建的 [GameState] 快照，
/// 与实时仪表盘 Provider 完全隔离。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/responsive_ext.dart';
import '../../../core/state/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../dashboard/logic/game_state.dart';
import '../../dashboard/presentation/widgets/event_timeline_panel.dart';
import '../../dashboard/presentation/widgets/game_status_card.dart';
import '../../dashboard/presentation/widgets/robot_status_list.dart';
import '../domain/match_record.dart';
import '../logic/replay_controller.dart';

/// 用于单个已保存比赛 [record] 的全屏回放页面。
class ReplayScreen extends ConsumerWidget {
  /// 创建 [ReplayScreen]。
  const ReplayScreen({required this.record, super.key});

  /// 正在回放的比赛记录。
  final MatchRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final replay = ref.watch(replayControllerProvider(record.filePath));
    final controller =
        ref.read(replayControllerProvider(record.filePath).notifier);
    final ownIsBlue = record.isBlue;

    return Scaffold(
      appBar: AppBar(
        title: Text('回放 · ${record.title}'),
      ),
      body: replay.isLoading
          ? const Center(child: CircularProgressIndicator())
          : replay.error != null
              ? Center(child: Text(replay.error!))
              : _ReplayBody(
                  replay: replay,
                  controller: controller,
                  ownIsBlue: ownIsBlue,
                ),
    );
  }
}

class _ReplayBody extends StatelessWidget {
  const _ReplayBody({
    required this.replay,
    required this.controller,
    required this.ownIsBlue,
  });

  final ReplayState replay;
  final ReplayController controller;
  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    final gameState = replay.gameState;

    return Column(
      children: [
        // 主宽屏区域：左侧机器人状态，右侧事件时间线。
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: RobotStatusList(
                  gameState: gameState,
                  ownIsBlueOverride: ownIsBlue,
                  modeOverride: DashboardDisplayMode.both,
                ),
              ),
              SizedBox(
                width: context.sp(320),
                child: _EventColumn(
                  gameState: gameState,
                  matchStart: replay.matchStart,
                ),
              ),
            ],
          ),
        ),
        // 底部：得分卡片和带回放游标的血量趋势。
        SizedBox(
          height: context.sp(180),
          child: Row(
            children: [
              SizedBox(
                width: context.sp(220),
                child: GameStatusCard(gameState: gameState),
              ),
              Expanded(
                child: _ReplayHealthChart(
                  gameState: gameState,
                  ownIsBlue: ownIsBlue,
                ),
              ),
            ],
          ),
        ),
        // 回放控件：进度滑块、播放/暂停和倍速选择。
        _PlaybackBar(replay: replay, controller: controller),
      ],
    );
  }
}

class _EventColumn extends StatelessWidget {
  const _EventColumn({required this.gameState, required this.matchStart});

  final GameState gameState;
  final DateTime? matchStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetAll(12),
      child: Card(
        child: Padding(
          padding: context.insetAll(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.timeline,
                    size: context.iconSize(20),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  context.sizedBox(w: 8),
                  Text(
                    '事件时间轴',
                    style: context.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${gameState.eventList.length}',
                    style: context.textTheme.bodySmall!.copyWith(
                      color: rmTextSecondary(context),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: EventTimelineView(
                  events: gameState.eventList,
                  matchStart: matchStart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 回放控制栏：拖动条、播放/暂停、倍速和时间标签。
class _PlaybackBar extends StatelessWidget {
  const _PlaybackBar({required this.replay, required this.controller});

  final ReplayState replay;
  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: context.insetSym(h: 16, v: 8),
      child: Row(
        children: [
          IconButton(
            iconSize: context.iconSize(36),
            icon: Icon(
              replay.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
            color: Theme.of(context).colorScheme.primary,
            tooltip: replay.isPlaying ? '暂停' : '播放',
            onPressed: controller.togglePlay,
          ),
          context.sizedBox(w: 8),
          Text(
            _fmt(replay.position),
            style: context.textTheme.bodyMedium!.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          Expanded(
            child: Slider(
              value: replay.progress,
              onChanged: controller.seekToProgress,
            ),
          ),
          Text(
            _fmt(replay.total),
            style: context.textTheme.bodyMedium!.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          context.sizedBox(w: 16),
          _SpeedSelector(replay: replay, controller: controller),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.replay, required this.controller});

  final ReplayState replay;
  final ReplayController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final speed in replaySpeeds)
          Padding(
            padding: context.insetSym(h: 2),
            child: ChoiceChip(
              label: Text('${_speedLabel(speed)}×'),
              selected: replay.speed == speed,
              onSelected: (_) => controller.setSpeed(speed),
            ),
          ),
      ],
    );
  }

  static String _speedLabel(double s) =>
      s == s.roundToDouble() ? s.toInt().toString() : s.toString();
}

/// 显示完整比赛血量曲线，并在当前回放位置绘制游标。
///
/// 与实时 [HealthChart] 的滚动窗口视图不同，这里展示整场比赛。
class _ReplayHealthChart extends StatelessWidget {
  const _ReplayHealthChart({required this.gameState, required this.ownIsBlue});

  final GameState gameState;
  final bool ownIsBlue;

  @override
  Widget build(BuildContext context) {
    final history = gameState.statusHistory;
    final lineColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: context.insetAll(12),
      child: Card(
        child: Padding(
          padding: context.insetAll(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '己方总血量趋势 · ${ownIsBlue ? '蓝方' : '红方'}',
                style: context.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              context.sizedBox(h: 8),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Text(
                          '暂无血量数据',
                          style: context.textTheme.bodyMedium!.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : _buildChart(context, history, lineColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<StatusSnapshot> history, Color lineColor) {
    final spots = <FlSpot>[];
    final t0 = history.first.timestamp;
    for (final snap in history) {
      var total = 0;
      final list = snap.status.robotHealth;
      for (var j = 0; j < list.length && j < GameState.allyRobotCount; j++) {
        total += list[j];
      }
      final sec = snap.timestamp.difference(t0).inMilliseconds / 1000.0;
      spots.add(FlSpot(sec, total.toDouble()));
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: spots.last.x,
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(reservedSize: context.sp(44)),
          ),
        ),
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
