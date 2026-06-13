/// Tests for [HealthChart.buildSpots] downsampling.
///
/// `GlobalUnitStatus` can arrive at tens of Hz; over the 120-second window the
/// raw history would push thousands of points into the curve renderer. These
/// tests pin the per-second downsampling contract: at most one point per whole
/// second, keeping the freshest sample in each bucket, sorted left→right.
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
      // 30 samples spread across the same whole-second bucket (0..0.9s ago).
      final history = [
        for (var i = 0; i < 30; i++)
          _snap(now.subtract(Duration(milliseconds: i * 30)),
              [100, 0, 0, 0, 0]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      // All within <0.5s ago → round() == 0 → one bucket.
      expect(spots.length, 1);
    });

    test('caps a high-frequency 120s window at ~120 points', () {
      // 20 Hz for 120 seconds = 2400 raw samples.
      final history = [
        for (var i = 0; i < 2400; i++)
          _snap(now.subtract(Duration(milliseconds: i * 50)),
              [500, 0, 0, 0, 0]),
      ];
      final spots = HealthChart.buildSpots(history, now: now);
      // One point per second over 120s → at most 121 buckets (0..120).
      expect(spots.length, lessThanOrEqualTo(121));
      expect(spots.length, greaterThan(100));
    });

    test('keeps the freshest sample per second bucket', () {
      // Two samples in the same second: older total 200, newer total 100.
      // Iterating oldest→newest, the newer one must win the bucket.
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
      // Most negative x (oldest) first.
      expect(spots.first.x, lessThan(spots.last.x));
    });
  });
}
