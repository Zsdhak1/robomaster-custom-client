/// 比赛状态卡片，显示当前比赛阶段和得分。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../generated/robomaster_custom_client.pb.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

/// 左下角显示比赛状态的卡片。
///
/// 提供 [gameState] 时用于回放并渲染该快照；否则监听实时 [gameStateProvider]。
/// 两条路径不共享可变状态，因此回放视图不会影响实时仪表盘。
class GameStatusCard extends ConsumerWidget {
  /// 创建 [GameStatusCard]。
  const GameStatusCard({this.gameState, super.key});

  /// 回放使用的可选固定状态；null 表示使用实时状态。
  final GameState? gameState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GameState effectiveState = gameState ?? ref.watch(gameStateProvider);
    final status = effectiveState.gameStatus;

    return Padding(
      padding: EdgeInsets.zero,
      child: Card(
        margin: EdgeInsets.zero,
        child: SizedBox.expand(
          child: Padding(
            padding: context.insetAll(12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, status),
                  context.sizedBox(h: 2),
                  Text(
                    '比赛阶段',
                    style: context.textTheme.bodySmall!.copyWith(
                      color: rmTextSecondary(context),
                    ),
                  ),
                  _buildDetails(context, status),
                  _buildLogistics(context, effectiveState),
                  _buildMechanisms(context, effectiveState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GameStatus? status) {
    final phaseText = _phaseLabel(status?.currentStage ?? 0);
    return Text(
      phaseText,
      style: context.textTheme.headlineSmall!.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDetails(BuildContext context, GameStatus? status) {
    if (status == null) return const SizedBox.shrink();

    final children = <Widget>[];

    final roundText = '第 ${status.currentRound} / ${status.totalRounds} 回合';
    children
      ..add(context.sizedBox(h: 6))
      ..add(Text(roundText, style: context.textTheme.bodySmall));

    final scoreText = '红 ${status.redScore} : ${status.blueScore} 蓝';
    children
      ..add(context.sizedBox(h: 4))
      ..add(
        Text(
          scoreText,
          style: context.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

    if (status.hasStageCountdownSec()) {
      final countdownText = '剩余 ${status.stageCountdownSec} 秒';
      children
        ..add(context.sizedBox(h: 4))
        ..add(Text(countdownText, style: context.textTheme.bodySmall));
    }

    if (status.hasStageElapsedSec()) {
      children
        ..add(context.sizedBox(h: 4))
        ..add(
          Text(
            '已进行 ${status.stageElapsedSec} 秒',
            style: context.textTheme.bodySmall,
          ),
        );
    }
    if (status.isPaused) {
      children
        ..add(context.sizedBox(h: 4))
        ..add(
          Text(
            '比赛暂停',
            style: context.textTheme.labelLarge!.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildLogistics(BuildContext context, GameState state) {
    final logistics = state.globalLogisticsStatus;
    if (logistics == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: context.sp(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '经济 ${logistics.remainingEconomy}',
            style: context.textTheme.bodySmall,
          ),
          Text(
            '科技 Lv.${logistics.techLevel} · 加密 Lv.${logistics.encryptionLevel}',
            style: context.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildMechanisms(BuildContext context, GameState state) {
    final mechanism = state.globalSpecialMechanism;
    if (mechanism == null || mechanism.mechanismId.isEmpty) {
      return const SizedBox.shrink();
    }
    final labels = <String>[];
    for (var i = 0; i < mechanism.mechanismId.length; i++) {
      final seconds = i < mechanism.mechanismTimeSec.length
          ? mechanism.mechanismTimeSec[i]
          : null;
      labels.add(
        seconds == null
            ? '#${mechanism.mechanismId[i]}'
            : '#${mechanism.mechanismId[i]} ${seconds}s',
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: context.sp(8)),
      child: Text(
        '特殊机制 ${labels.join(' · ')}',
        style: context.textTheme.bodySmall,
      ),
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
