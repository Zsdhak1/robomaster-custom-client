/// 使用 fl_chart 绘制的血量趋势折线图。
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/state/session_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

/// 计入己方总血量的机器人数量。
const int _allyRobotCount = 5;

/// X 轴显示的历史窗口，单位秒。
const double _historyWindowSec = 120;

/// 显示最近 120 秒内的己方总血量趋势。
class HealthChart extends ConsumerWidget {
  /// 创建 [HealthChart]。
  const HealthChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    final history = gameState.statusHistory;
    final ownIsBlue = isBlueSide(ref.watch(selectedRobotIdProvider));
    final lineColor = Theme.of(context).colorScheme.primary;

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
          child: Padding(
            padding: context.insetAll(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartHeader(context, ownIsBlue: ownIsBlue),
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
                      : _buildLineChart(
                          context,
                          buildSpots(history, now: DateTime.now()),
                          lineColor,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartHeader(BuildContext context, {required bool ownIsBlue}) {
    return Row(
      children: [
        Text(
          '己方总血量趋势 · ${ownIsBlue ? '蓝方' : '红方'}',
          style: context.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        context.sizedBox(w: 8),
        Text(
          '（最近 120 秒 →）',
          style: context.textTheme.labelSmall!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, List<FlSpot> spots, Color lineColor) {
    final (minY, maxY) = _yRange(spots);

    return LineChart(
      LineChartData(
        minX: -_historyWindowSec,
        maxX: 0,
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 2,
        ),
        titlesData: FlTitlesData(
          // X 轴时间不显示密集刻度，方向由标题"最近120秒 →"说明。
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.sp(48),
              interval: (maxY - minY) / 2,
              getTitlesWidget: _leftTitle,
            ),
          ),
        ),
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

  static Widget _leftTitle(double value, TitleMeta meta) {
    if (value <= meta.min || value >= meta.max) {
      return const SizedBox.shrink();
    }
    final label = value >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}K'
        : value.round().toString();
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        label,
        // 特殊情况：fl_chart 轴刻度回调拿不到 BuildContext，
        // 因此这里为 Y 轴标签使用固定的小字号。
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  /// 计算带留白的 Y 轴范围，避免平直曲线被渲染成细线。
  static (double, double) _yRange(List<FlSpot> spots) {
    if (spots.isEmpty) return (0, 100);
    var min = spots.first.y;
    var max = spots.first.y;
    for (final s in spots) {
      if (s.y < min) min = s.y;
      if (s.y > max) max = s.y;
    }
    final pad = (max - min) < 1 ? 200.0 : (max - min) * 0.2;
    final low = (min - pad).clamp(0.0, double.infinity);
    return (low, max + pad);
  }

  /// 构建 x 为负“距今秒数”的点，使时间从左到右流动。
  ///
  /// 下采样到每秒最多一个点：`GlobalUnitStatus` 可能以数十 Hz 到达，
  /// 120 秒窗口会在每次重建时向曲线渲染器推入数千个点。
  /// 按整数“距今秒数”分桶可把折线保持在不超过 120 个点，同时尽量不改变形状。
  ///
  /// [now] 可注入以便测试；生产调用方传入当前墙钟时间。
  static List<FlSpot> buildSpots(
    List<StatusSnapshot> history, {
    required DateTime now,
  }) {
    // 每个整数秒桶保留最新样本。按历史顺序（最旧到最新）遍历，
    // 表示每个桶最后写入的样本就是最新代表值。
    final bySecond = <int, FlSpot>{};
    for (final snapshot in history) {
      final healthList = snapshot.status.robotHealth;
      var total = 0;
      for (var j = 0; j < healthList.length && j < _allyRobotCount; j++) {
        total += healthList[j];
      }
      final secondsAgo =
          now.difference(snapshot.timestamp).inMilliseconds / 1000.0;
      // floor() 按整数距今秒数分桶：[N, N+1) 都映射到桶 N，
      // 因此每个一秒窗口只保留一个最新代表点。
      bySecond[secondsAgo.floor()] = FlSpot(-secondsAgo, total.toDouble());
    }
    final result = bySecond.values.toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    return result;
  }
}
