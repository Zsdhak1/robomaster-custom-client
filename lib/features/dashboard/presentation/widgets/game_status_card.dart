/// Game status card showing current match phase and score.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../generated/robomaster_custom_client.pb.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

/// Bottom-left card displaying match status.
///
/// When [gameState] is provided (replay), it renders that snapshot; otherwise
/// it watches the live [gameStateProvider]. The two paths never share mutable
/// state, so a replay view cannot affect the live dashboard.
class GameStatusCard extends ConsumerWidget {
  /// Creates a [GameStatusCard].
  const GameStatusCard({this.gameState, super.key});

  /// Optional fixed state for replay; null means use live state.
  final GameState? gameState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState effectiveState =
        gameState ?? ref.watch(gameStateProvider);
    final status = effectiveState.gameStatus;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: rmCardPadding,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(status),
                const SizedBox(height: 2),
                const Text(
                  '比赛阶段',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                _buildDetails(context, status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GameStatus? status) {
    final phaseText = _phaseLabel(status?.currentStage ?? 0);
    return Text(
      phaseText,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDetails(BuildContext context, GameStatus? status) {
    if (status == null) return const SizedBox.shrink();

    final children = <Widget>[];

    final roundText =
        '第 ${status.currentRound} / ${status.totalRounds} 回合';
    children
      ..add(const SizedBox(height: 6))
      ..add(Text(roundText, style: const TextStyle(fontSize: 13)));

    final scoreText = '红 ${status.redScore} : ${status.blueScore} 蓝';
    children
      ..add(const SizedBox(height: 4))
      ..add(
        Text(
          scoreText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

    if (status.hasStageCountdownSec()) {
      final countdownText = '剩余 ${status.stageCountdownSec} 秒';
      children
        ..add(const SizedBox(height: 4))
        ..add(Text(countdownText, style: const TextStyle(fontSize: 13)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _phaseLabel(int stage) => switch (stage) {
        0 => '未开始',
        1 => '准备阶段',
        2 => '裁判系统自检',
        3 => '五秒倒计时',
        4 => '比赛中',
        5 => '比赛结算中',
        _ => '未知',
      };
}
