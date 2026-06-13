/// Robot identity for client login selection.
///
/// IDs follow RoboMaster protocol: red side = 1/2/3/4/6/7,
/// blue side = red + 100 (e.g. 101 = blue hero).
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A selectable robot identity with display name, side color, and protocol ID.
class RobotIdentity {
  /// Creates a [RobotIdentity].
  const RobotIdentity({
    required this.displayName,
    required this.id,
    required this.sideColor,
    required this.iconAsset,
  });

  /// Display name shown in the grid selector (e.g. '红方英雄').
  final String displayName;

  /// Protocol robot ID (red side: 1,2,3,4,6,7; blue side: +100).
  final int id;

  /// Team color for visual distinction.
  final Color sideColor;

  /// Asset path for the robot avatar image.
  final String iconAsset;
}

/// Red side robot definitions.
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

/// Blue side robot definitions (id = red id + 100 per protocol).
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

/// All selectable robot identities: red side first, then blue side.
const List<RobotIdentity> allRobotIdentities = [
  ..._redRobots,
  ..._blueRobots,
];

/// Red side robot identities (protocol ids 1-7).
const List<RobotIdentity> redRobotIdentities = _redRobots;

/// Blue side robot identities (protocol ids 101-107).
const List<RobotIdentity> blueRobotIdentities = _blueRobots;

/// Resolves a robot ID to its display name.
String robotDisplayName(int id) {
  for (final robot in allRobotIdentities) {
    if (robot.id == id) return robot.displayName;
  }
  return '未知 ($id)';
}

/// Resolves a robot ID to its [RobotIdentity], or null if unknown.
RobotIdentity? robotIdentityById(int id) {
  for (final robot in allRobotIdentities) {
    if (robot.id == id) return robot;
  }
  return null;
}

/// The infantry number (3 or 4) overlaid on the shared infantry icon, or null
/// for robots that don't share an icon.
///
/// Red 3/4 (ids 3/4) and blue 3/4 (ids 103/104) reuse the same
/// `*SentryInfantry.png` asset, so the digit is the only visual distinction.
int? infantryBadgeNumber(int id) {
  final base = id >= 100 ? id - 100 : id;
  return (base == 3 || base == 4) ? base : null;
}

/// Whether [id] belongs to the blue side (protocol ids >= 100).
bool isBlueSide(int id) => id >= 100;

/// Resolves the team accent color used for login theme switching.
///
/// Blue side (id >= 100) → [rmBlueTeamColor], red side → [rmRedTeamColor].
Color teamAccentColor(int id) =>
    isBlueSide(id) ? rmBlueTeamColor : rmRedTeamColor;
