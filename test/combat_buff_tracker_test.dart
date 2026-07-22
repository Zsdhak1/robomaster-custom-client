import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/combat_buff_tracker.dart';

void main() {
  test('keeps newest combat buffs until protocol remaining time expires', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(
        CombatBuffSample(
          robotId: 1,
          buffType: combatAttackBuffType,
          level: 150,
          leftSeconds: 5,
          receivedAt: now,
        ),
      )
      ..observe(
        CombatBuffSample(
          robotId: 101,
          buffType: combatDefenseBuffType,
          level: -25,
          leftSeconds: 5,
          receivedAt: now,
        ),
      );

    final active = tracker.snapshot(now.add(const Duration(seconds: 4)));
    expect(active.attackLevelFor(1), 150);
    expect(active.defenseLevelFor(101), -25);
    expect(
      tracker.snapshot(now.add(const Duration(seconds: 6))).attackLevelFor(1),
      isNull,
    );
  });

  test('ignores an older sample for the same robot and buff type', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(
        CombatBuffSample(
          robotId: 1,
          buffType: combatAttackBuffType,
          level: 150,
          leftSeconds: 5,
          receivedAt: now,
        ),
      )
      ..observe(
        CombatBuffSample(
          robotId: 1,
          buffType: combatAttackBuffType,
          level: 50,
          leftSeconds: 5,
          receivedAt: now.subtract(const Duration(seconds: 1)),
        ),
      );

    expect(tracker.snapshot(now).attackLevelFor(1), 150);
  });

  test('removes the matching buff when remaining time is zero', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(
        CombatBuffSample(
          robotId: 1,
          buffType: combatAttackBuffType,
          level: 150,
          leftSeconds: 5,
          receivedAt: now,
        ),
      )
      ..observe(
        CombatBuffSample(
          robotId: 1,
          buffType: combatAttackBuffType,
          level: 0,
          leftSeconds: 0,
          receivedAt: now.add(const Duration(seconds: 1)),
        ),
      );

    expect(
      tracker.snapshot(now.add(const Duration(seconds: 1))).attackLevelFor(1),
      isNull,
    );
  });

  test('reset returns an empty snapshot', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(
        CombatBuffSample(
          robotId: 1,
          buffType: combatAttackBuffType,
          level: 150,
          leftSeconds: 5,
          receivedAt: now,
        ),
      )
      ..reset();

    final snapshot = tracker.snapshot(now);
    expect(snapshot.attack, isEmpty);
    expect(snapshot.defense, isEmpty);
  });

  test('ignores Buff samples with an invalid robot identity', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(_sample(robotId: 8, receivedAt: now))
      ..observe(_sample(robotId: 108, receivedAt: now));

    expect(tracker.snapshot(now).attack, isEmpty);
  });

  test('ignores Buff samples with an invalid level', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(_sample(level: -1001, receivedAt: now))
      ..observe(_sample(level: 1001, receivedAt: now));

    expect(tracker.snapshot(now).attack, isEmpty);
  });

  test('ignores Buff samples with an invalid duration', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(_sample(leftSeconds: -1, receivedAt: now))
      ..observe(_sample(leftSeconds: 3601, receivedAt: now));

    expect(tracker.snapshot(now).attack, isEmpty);
  });

  test('keeps valid Buff boundary values', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(
        _sample(
          level: -1000,
          buffType: combatDefenseBuffType,
          leftSeconds: 3600,
          receivedAt: now,
        ),
      )
      ..observe(
        _sample(robotId: 107, level: 1000, leftSeconds: 3600, receivedAt: now),
      );

    final snapshot = tracker.snapshot(now);
    expect(snapshot.defenseLevelFor(1), -1000);
    expect(snapshot.attackLevelFor(107), 1000);
  });

  test('expired Buff cleanup accepts a previously older sample', () {
    final tracker = CombatBuffTracker();
    final now = DateTime(2026, 7, 22, 12);
    tracker
      ..observe(_sample(leftSeconds: 1, receivedAt: now))
      ..snapshot(now.add(const Duration(seconds: 2)))
      ..observe(
        _sample(
          level: 50,
          leftSeconds: 3600,
          receivedAt: now.subtract(const Duration(seconds: 1)),
        ),
      );

    expect(
      tracker.snapshot(now.add(const Duration(seconds: 2))).attackLevelFor(1),
      50,
    );
  });
}

CombatBuffSample _sample({
  required DateTime receivedAt,
  int robotId = 1,
  int buffType = combatAttackBuffType,
  int level = 150,
  int leftSeconds = 5,
}) {
  return CombatBuffSample(
    robotId: robotId,
    buffType: buffType,
    level: level,
    leftSeconds: leftSeconds,
    receivedAt: receivedAt,
  );
}
