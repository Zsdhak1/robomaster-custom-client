const int combatAttackBuffType = 1;
const int combatDefenseBuffType = 2;
const int combatRobotIdMin = 1;
const int combatRobotIdMax = 7;
const int combatAlternateRobotIdMin = 101;
const int combatAlternateRobotIdMax = 107;
const int combatBuffLevelMin = -1000;
const int combatBuffLevelMax = 1000;
const int combatBuffDurationMaxSeconds = 3600;

class CombatBuffSample {
  const CombatBuffSample({
    required this.robotId,
    required this.buffType,
    required this.level,
    required this.leftSeconds,
    required this.receivedAt,
  });

  final int robotId;
  final int buffType;
  final int level;
  final int leftSeconds;
  final DateTime receivedAt;
}

class CombatBuffLevels {
  const CombatBuffLevels({this.attack = const {}, this.defense = const {}});

  final Map<int, int> attack;
  final Map<int, int> defense;

  int? attackLevelFor(int robotId) => attack[robotId];

  int? defenseLevelFor(int robotId) => defense[robotId];
}

class CombatBuffTracker {
  final Map<(int, int), _TrackedCombatBuff> _buffs = {};

  void observe(CombatBuffSample sample) {
    if (!_isTrackable(sample)) {
      return;
    }

    final key = (sample.robotId, sample.buffType);
    final existing = _buffs[key];
    if (existing != null && sample.receivedAt.isBefore(existing.receivedAt)) {
      return;
    }
    if (sample.leftSeconds == 0) {
      _buffs.remove(key);
      return;
    }
    _buffs[key] = _TrackedCombatBuff(
      level: sample.level,
      receivedAt: sample.receivedAt,
      expiresAt: sample.receivedAt.add(Duration(seconds: sample.leftSeconds)),
    );
  }

  CombatBuffLevels snapshot(DateTime now) {
    final attack = <int, int>{};
    final defense = <int, int>{};
    final expiredKeys = <(int, int)>[];
    for (final entry in _buffs.entries) {
      if (!entry.value.expiresAt.isAfter(now)) {
        expiredKeys.add(entry.key);
        continue;
      }
      final (robotId, buffType) = entry.key;
      if (buffType == combatAttackBuffType) {
        attack[robotId] = entry.value.level;
      } else {
        defense[robotId] = entry.value.level;
      }
    }
    for (final key in expiredKeys) {
      _buffs.remove(key);
    }
    return CombatBuffLevels(
      attack: Map.unmodifiable(attack),
      defense: Map.unmodifiable(defense),
    );
  }

  void reset() => _buffs.clear();

  bool _isTrackable(CombatBuffSample sample) {
    return _isCombatRobotId(sample.robotId) &&
        _isCombatBuffType(sample.buffType) &&
        _isCombatBuffLevel(sample.level) &&
        _isCombatBuffDuration(sample.leftSeconds);
  }

  bool _isCombatRobotId(int robotId) {
    return (robotId >= combatRobotIdMin && robotId <= combatRobotIdMax) ||
        (robotId >= combatAlternateRobotIdMin &&
            robotId <= combatAlternateRobotIdMax);
  }

  bool _isCombatBuffType(int buffType) {
    return buffType == combatAttackBuffType ||
        buffType == combatDefenseBuffType;
  }

  bool _isCombatBuffLevel(int level) {
    return level >= combatBuffLevelMin && level <= combatBuffLevelMax;
  }

  bool _isCombatBuffDuration(int leftSeconds) {
    return leftSeconds >= 0 && leftSeconds <= combatBuffDurationMaxSeconds;
  }
}

class _TrackedCombatBuff {
  const _TrackedCombatBuff({
    required this.level,
    required this.receivedAt,
    required this.expiresAt,
  });

  final int level;
  final DateTime receivedAt;
  final DateTime expiresAt;
}
