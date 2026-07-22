/// 通知规则引擎使用的协议无关输入模型和机器人标签。
library;

import 'combat_buff_tracker.dart';

const List<int> notificationRobotBaseIds = [1, 2, 3, 4, 7];
const List<String> notificationRobotRoleLabels = [
  '英雄',
  '工程',
  '3 号步兵',
  '4 号步兵',
  '哨兵',
];

/// 规则引擎支持的机器人数量。
const int notificationRobotCount = 5;

/// 敌方免费复活在普通速率和加快速率下的预计时长边界。
class RespawnDurationBounds {
  /// 创建免费复活时长边界。
  const RespawnDurationBounds({required this.normal, required this.fastest});

  /// 普通进度速率对应的免费复活时长。
  final Duration normal;

  /// 加速进度速率对应的最快免费复活时长。
  final Duration fastest;
}

/// 单次全局机器人血量快照。
class UnitHealthSample {
  /// 创建血量快照。
  const UnitHealthSample({
    required this.allyHealth,
    required this.enemyHealth,
    required this.selectedRobotId,
    required this.timestamp,
    this.combatBuffs = const CombatBuffLevels(),
    this.remainingMatchSeconds,
    this.enemyBaseHealth,
  });

  final List<int> allyHealth;
  final List<int> enemyHealth;
  final int selectedRobotId;
  final DateTime timestamp;
  final CombatBuffLevels combatBuffs;
  final int? remainingMatchSeconds;
  final int? enemyBaseHealth;
}

/// 返回血量数组 [index] 对应的完整机器人名称。
String notificationRobotName(
  int index,
  int selectedRobotId, {
  required bool enemy,
}) {
  final ownBlue = selectedRobotId >= 100;
  final blue = enemy ? !ownBlue : ownBlue;
  final id = notificationRobotBaseIds[index] + (blue ? 100 : 0);
  final side = blue ? '蓝方' : '红方';
  return '$side${notificationRobotRoleLabels[index]}（$id）';
}
