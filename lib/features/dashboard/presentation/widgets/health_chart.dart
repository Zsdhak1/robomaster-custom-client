/// Health trend line chart using fl_chart.
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

/// Number of ally robots counted into the total health sum.
const int _allyRobotCount = 5;

/// History window shown on the X-axis (seconds).
const double _historyWindowSec = 120;

/// Displays ally total health trend over the last 120 seconds.
class HealthChart extends ConsumerWidget {
  /// Creates a [HealthChart].
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
        // Special case: fl_chart axis-tick callback exposes no BuildContext,
        // so a fixed micro size is used for the chart's Y-axis labels.
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

  /// Computes a padded Y range so a flat line is not rendered as a sliver.
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

  /// Builds spots with x = negative seconds-ago so time flows left → right.
  ///
  /// Downsamples to at most one point per second: `GlobalUnitStatus` can arrive
  /// at tens of Hz, which over the 120-second window would push thousands of
  /// points into the curve renderer every rebuild. Bucketing by whole-second
  /// "seconds ago" keeps the line at ≤120 points without changing its shape.
  ///
  /// [now] is injectable for testing; production callers pass the wall clock.
  static List<FlSpot> buildSpots(
    List<StatusSnapshot> history, {
    required DateTime now,
  }) {
    // Keep the latest sample per integer second bucket. Iterating in history
    // order (oldest→newest) means the last write per bucket is the freshest.
    final bySecond = <int, FlSpot>{};
    for (final snapshot in history) {
      final healthList = snapshot.status.robotHealth;
      var total = 0;
      for (var j = 0; j < healthList.length && j < _allyRobotCount; j++) {
        total += healthList[j];
      }
      final secondsAgo =
          now.difference(snapshot.timestamp).inMilliseconds / 1000.0;
      // floor() buckets by whole seconds-ago: [N, N+1) all map to bucket N,
      // so each one-second window keeps exactly one (freshest) representative.
      bySecond[secondsAgo.floor()] = FlSpot(-secondsAgo, total.toDouble());
    }
    final result = bySecond.values.toList()
      ..sort((a, b) => a.x.compareTo(b.x));
    return result;
  }
}
