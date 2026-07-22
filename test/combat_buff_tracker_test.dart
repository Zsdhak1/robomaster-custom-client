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

    expect(tracker.snapshot(now.add(const Duration(seconds: 1))).attackLevelFor(1), isNull);
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
}
