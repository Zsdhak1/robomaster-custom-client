/// 客户端登录选择使用的机器人身份。
///
/// ID 遵循 RoboMaster 协议：红方 = 1/2/3/4/6/7，蓝方 = 红方 + 100
/// （例如 101 = 蓝方英雄）。
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 一个可选择的机器人身份，包含显示名称、阵营颜色和协议 ID。
class RobotIdentity {
  /// 创建 [RobotIdentity]。
  const RobotIdentity({
    required this.displayName,
    required this.id,
    required this.sideColor,
    required this.iconAsset,
  });

  /// 网格选择器中显示的名称，例如“红方英雄”。
  final String displayName;

  /// 协议机器人 ID（红方：1,2,3,4,6,7；蓝方：+100）。
  final int id;

  /// 用于视觉区分的队伍颜色。
  final Color sideColor;

  /// 机器人头像图片资源路径。
  final String iconAsset;
}

/// 红方机器人定义。
const _redRobots = [
  RobotIdentity(
    displayName: '红方英雄',
    id: 1,
    sideColor: rmRedTeamColor,
    iconAsset: 'assets/RedHero.png',
  ),
  RobotIdentity(
    displayName: '红方工程',
    id: 2,
    sideColor: rmRedTeamColor,
    iconAsset: 'assets/RedEngineer.png',
  ),
  RobotIdentity(
    displayName: '红方3号步兵',
    id: 3,
    sideColor: rmRedTeamColor,
    iconAsset: 'assets/RedSentryInfantry.png',
  ),
  RobotIdentity(
    displayName: '红方4号步兵',
    id: 4,
    sideColor: rmRedTeamColor,
    iconAsset: 'assets/RedSentryInfantry.png',
  ),
  RobotIdentity(
    displayName: '红方6号无人机',
    id: 6,
    sideColor: rmRedTeamColor,
    iconAsset: 'assets/RedDrone.png',
  ),
  RobotIdentity(
    displayName: '红方7号哨兵',
    id: 7,
    sideColor: rmRedTeamColor,
    iconAsset: 'assets/RedSentryInfantry.png',
  ),
];

/// 蓝方机器人定义；按协议 ID = 红方 ID + 100。
const _blueRobots = [
  RobotIdentity(
    displayName: '蓝方英雄',
    id: 101,
    sideColor: rmBlueTeamColor,
    iconAsset: 'assets/BlueHero.png',
  ),
  RobotIdentity(
    displayName: '蓝方工程',
    id: 102,
    sideColor: rmBlueTeamColor,
    iconAsset: 'assets/BlueEngineer.png',
  ),
  RobotIdentity(
    displayName: '蓝方3号步兵',
    id: 103,
    sideColor: rmBlueTeamColor,
    iconAsset: 'assets/BlueSentryInfantry.png',
  ),
  RobotIdentity(
    displayName: '蓝方4号步兵',
    id: 104,
    sideColor: rmBlueTeamColor,
    iconAsset: 'assets/BlueSentryInfantry.png',
  ),
  RobotIdentity(
    displayName: '蓝方6号无人机',
    id: 106,
    sideColor: rmBlueTeamColor,
    iconAsset: 'assets/BlueDrone.png',
  ),
  RobotIdentity(
    displayName: '蓝方7号哨兵',
    id: 107,
    sideColor: rmBlueTeamColor,
    iconAsset: 'assets/BlueSentryInfantry.png',
  ),
];

/// 所有可选择机器人身份：红方在前，蓝方在后。
const List<RobotIdentity> allRobotIdentities = [
  ..._redRobots,
  ..._blueRobots,
];

/// 红方机器人身份（协议 ID 1-7）。
const List<RobotIdentity> redRobotIdentities = _redRobots;

/// 蓝方机器人身份（协议 ID 101-107）。
const List<RobotIdentity> blueRobotIdentities = _blueRobots;

/// 将机器人 ID 解析为显示名称。
String robotDisplayName(int id) {
  for (final robot in allRobotIdentities) {
    if (robot.id == id) return robot.displayName;
  }
  return '未知 ($id)';
}

/// 将机器人 ID 解析为 [RobotIdentity]；未知时返回 null。
RobotIdentity? robotIdentityById(int id) {
  for (final robot in allRobotIdentities) {
    if (robot.id == id) return robot;
  }
  return null;
}

/// 需要叠加在共享步兵图标上的编号（3 或 4）；其他机器人返回 null。
///
/// 红方 3/4（ID 3/4）和蓝方 3/4（ID 103/104）复用同一
/// `*SentryInfantry.png` 资源，因此数字是唯一视觉区分。
int? infantryBadgeNumber(int id) {
  final base = id >= 100 ? id - 100 : id;
  return (base == 3 || base == 4) ? base : null;
}

/// [id] 是否属于蓝方（协议 ID >= 100）。
bool isBlueSide(int id) => id >= 100;

/// 解析登录主题切换使用的队伍强调色。
///
/// 蓝方（ID >= 100）→ [rmBlueTeamColor]，红方 → [rmRedTeamColor]。
Color teamAccentColor(int id) =>
    isBlueSide(id) ? rmBlueTeamColor : rmRedTeamColor;
