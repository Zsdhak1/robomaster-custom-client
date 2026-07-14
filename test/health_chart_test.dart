/// [HealthChart.buildSpots] 降采样逻辑的测试。
///
/// `GlobalUnitStatus` 可能以几十 Hz 到达；120 秒窗口内原始历史会向曲线渲染器推入数千点。
/// 这些测试固定按秒降采样约定：每个整秒最多一个点，并保留每个桶中最新的样本，
/// 最终按从左到右排序。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/game_state.dart';
import 'package:robomaster_custom_client_1/features/dashboard/presentation/widgets/health_chart.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';

StatusSnapshot _snap(DateTime t, List<int> health) => StatusSnapshot(
      status: GlobalUnitStatus(robotHealth: health),
      timestamp: t,
    );

void main() {
  final now = DateTime(2025, 1, 1, 12);

  group('HealthChart.buildSpots downsampling', () {
    test('empty history yields no spots', () {
      expect(HealthChart.buildSpots([], now: now), isEmpty);
    });

    test('collapses many samples within one second to a single spot', () {
      // 30 个样本分布在同一个整秒桶内（0..0.9s 前）。
      final history = [
        for (var i = 0; i < 30; i++)
          _snap(now.subtract(Duration(milliseconds: i * 30)),
              [100, 0, 0, 0, 0]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      // 所有样本都在 0.5s 内 → floor() == 0 → 同一个桶。
      expect(spots.length, 1);
    });

    test('caps a high-frequency 120s window at ~120 points', () {
      // 20 Hz 用于 120 秒 = 2400 原始 samples。
      final history = [
        for (var i = 0; i < 2400; i++)
          _snap(now.subtract(Duration(milliseconds: i * 50)),
              [500, 0, 0, 0, 0]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      // 120s 内每秒一个点 → 最多 121 个桶（0..120）。
      expect(spots.length, lessThanOrEqualTo(121));
      expect(spots.length, greaterThan(100));
    });

    test('keeps the freshest sample per second bucket', () {
      // 两个样本位于同一秒：较旧样本总血量 200，较新样本总血量 100。
      // 从旧到新迭代时，较新样本必须覆盖该桶。
      final history = [
        _snap(now.subtract(const Duration(milliseconds: 900)),
            [200, 0, 0, 0, 0]),
        _snap(now.subtract(const Duration(milliseconds: 100)),
            [100, 0, 0, 0, 0]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      expect(spots.length, 1);
      expect(spots.first.y, 100);
    });

    test('sums only the five ally robots, ignoring enemy slots', () {
      final history = [
        _snap(now, [100, 100, 100, 100, 100, 999, 999, 999, 999, 999]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      expect(spots.single.y, 500);
    });

    test('spots are sorted left to right by x (oldest first)', () {
      final history = [
        _snap(now.subtract(const Duration(seconds: 5)), [100, 0, 0, 0, 0]),
        _snap(now.subtract(const Duration(seconds: 3)), [200, 0, 0, 0, 0]),
        _snap(now.subtract(const Duration(seconds: 1)), [300, 0, 0, 0, 0]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      for (var i = 1; i < spots.length; i++) {
        expect(spots[i].x, greaterThan(spots[i - 1].x));
      }
      // 最多 negative x (最旧) 第一个。
      expect(spots.first.x, lessThan(spots.last.x));
    });
  });
}
