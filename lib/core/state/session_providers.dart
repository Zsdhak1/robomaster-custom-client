/// App-wide session state shared across features (connection, dashboard,
/// settings). Kept in `core` so any feature may depend on it without
/// introducing cross-feature dependencies.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default selected robot id (red hero, protocol id 1).
const int defaultSelectedRobotId = 1;

/// The robot identity the client logged in as.
///
/// Red side ids are 1-7, blue side ids are 101-107. The selected side drives
/// the app-wide theme color and which team counts as "己方" on the dashboard.
final selectedRobotIdProvider =
    StateProvider<int>((ref) => defaultSelectedRobotId);

/// How the dashboard robot list presents the two teams.
enum DashboardDisplayMode {
  /// Show the enemy team's per-robot detail; own total health drives the trend.
  enemyFocus,

  /// Show both teams' per-robot detail side by side.
  both,
}

/// Human-readable label for a [DashboardDisplayMode].
extension DashboardDisplayModeLabel on DashboardDisplayMode {
  /// Short Chinese label shown in the settings page.
  String get label => switch (this) {
        DashboardDisplayMode.enemyFocus => '敌方详情 + 己方趋势',
        DashboardDisplayMode.both => '双方都显示',
      };

  /// One-line description of what the mode shows.
  String get description => switch (this) {
        DashboardDisplayMode.enemyFocus =>
          '机器人列表展示敌方逐个血量，便于集火监控；下方趋势图展示己方总血量。',
        DashboardDisplayMode.both =>
          '机器人列表分两栏同时展示己方与敌方所有机器人的详细血量。',
      };
}

/// Current dashboard display mode (defaults to enemy-focused monitoring).
final dashboardDisplayModeProvider =
    StateProvider<DashboardDisplayMode>((ref) => DashboardDisplayMode.enemyFocus);
