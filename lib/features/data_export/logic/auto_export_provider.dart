/// 由比赛阶段和连接状态驱动的后台自动导出服务。
///
/// 目标是始终把一场比赛保存为单个、可合并的记录文件：
/// - **正常路径**：比赛进入结算阶段（阶段 5）后立即导出完整记录，此时时间戳最准确。
/// - **断线兜底**：MQTT 在比赛中掉线时不立刻保存半场文件，避免拆碎比赛并破坏跨客户端时间戳合并；
///   只有等到理论结束时间（[matchDurationWithBuffer] 之后）仍未恢复时，才持久化已记录数据。
/// - **延迟重连**：MQTT 恢复后继续写入同一个内存缓冲区，重新导出会覆盖同名文件，
///   文件名来自比赛开始时间，因此整场比赛仍保持为单个文件。
/// - **去重**：每场比赛由 [GameState.matchStartTime] 标识；同一触发原因最多导出一次，
///   结算与兜底同时竞争时，先触发的一方生效，另一方跳过。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/state/session_providers.dart';
import '../../../services/mqtt_service.dart';
import '../../dashboard/logic/game_state.dart';
import '../../dashboard/logic/stream_providers.dart';
import '../../settings/logic/settings_providers.dart';
import '../data/json_exporter.dart';
import 'data_export_providers.dart';
import 'data_recorder_provider.dart';

/// 执行自动导出的全局副作用 Provider。
///
/// 由 `MainApp` 等入口监听该 Provider 后，内部监听器才会生效。
final autoExportProvider = Provider<void>((ref) {
  final controller = _AutoExportController(ref);

  ref
    ..listen(gameStateProvider, controller.onGameStateChanged)
    ..listen(mqttConnectionStateProvider, (_, next) {
      next.whenData(controller.onConnectionChanged);
    })
    ..onDispose(controller.dispose);
});

/// 协调结算导出和断线兜底导出的状态机。
class _AutoExportController {
  _AutoExportController(this._ref);

  final Ref _ref;

  /// 已自动导出的比赛开始时间锚点，用于去重。
  ///
  /// null 表示当前比赛尚未导出。
  DateTime? _exportedMatchStart;

  /// 比赛中断线后启动的兜底定时器。
  Timer? _fallbackTimer;

  void onGameStateChanged(GameState? previous, GameState next) {
    final prevStage = previous?.gameStatus?.currentStage;
    final nextStage = next.gameStatus?.currentStage;
    if (prevStage == nextStage) return;

    if (nextStage == stageSettlement) {
      // 正常路径：进入结算阶段后立即导出完整比赛。
      _cancelFallback();
      unawaited(_exportCurrentMatch(reason: 'settlement'));
    } else if (prevStage == stageSettlement && nextStage != stageSettlement) {
      // 新比赛周期已经开始：清空记录器并重置去重状态，让下一场比赛重新记录和导出。
      _cancelFallback();
      _exportedMatchStart = null;
      _ref.read(dataRecorderProvider.notifier).clear();
    }
  }

  void onConnectionChanged(MqttConnectionState connectionState) {
    if (connectionState == MqttConnectionState.connected) {
      // 重连后取消待执行兜底。记录继续写入同一缓冲区，后续结算或兜底会导出整场比赛。
      _cancelFallback();
      return;
    }

    // 已断开或出错。如果比赛正在进行且已有数据，则安排在理论结束时间触发兜底。
    // 不要立即保存半场文件，否则无法与其他客户端记录干净合并。
    _armFallbackIfMidMatch();
  }

  void _armFallbackIfMidMatch() {
    if (_fallbackTimer != null) return; // 兜底定时器已启动。

    final gameState = _ref.read(gameStateProvider);
    final matchStart = gameState.matchStartTime;
    if (matchStart == null) return; // 当前尚未处于比赛中。
    if (_exportedMatchStart == matchStart) return; // 当前比赛已经导出。

    if (_ref.read(dataRecorderProvider).totalCount == 0) return; // 没有可保存的数据。

    final theoreticalEnd = matchStart.add(matchDurationWithBuffer);
    final remaining = theoreticalEnd.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      // 已超过理论结束时间，立即保存当前记录作为兜底。
      unawaited(_exportCurrentMatch(reason: 'fallback-immediate'));
      return;
    }

    debugPrint(
      'Auto-export fallback armed: will save in ${remaining.inSeconds}s '
      'if still disconnected',
    );
    _fallbackTimer = Timer(remaining, () {
      _fallbackTimer = null;
      // 仍处于断开状态时才触发；重连会取消该定时器。
      final state = _ref.read(mqttConnectionStateSyncProvider);
      if (state == MqttConnectionState.connected) return;
      unawaited(_exportCurrentMatch(reason: 'fallback-timeout'));
    });
  }

  void _cancelFallback() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  Future<void> _exportCurrentMatch({required String reason}) async {
    final directory = _ref.read(exportDirectoryProvider);
    if (directory.isEmpty) {
      debugPrint('Auto-export skipped ($reason): export directory not set');
      return;
    }

    final recorder = _ref.read(dataRecorderProvider);
    if (recorder.totalCount == 0) {
      debugPrint('Auto-export skipped ($reason): no recorded data');
      return;
    }

    final gameState = _ref.read(gameStateProvider);
    final matchStart = gameState.matchStartTime;

    // 去重：同一场比赛如果已由结算导出，后续兜底不再重复保存。
    // 延迟重连后再次进入结算时会重新导出同名文件，这是期望的“追加到同场比赛”行为；
    // 因此仅阻止兜底路径的重复触发。
    if (reason.startsWith('fallback') && _exportedMatchStart == matchStart) {
      debugPrint('Auto-export skipped ($reason): match already exported');
      return;
    }

    final robotId = _ref.read(selectedRobotIdProvider);
    final exporter = JsonExporter(
      robotId: robotId,
      exportDirectory: directory,
      matchStartTime: matchStart,
    );

    try {
      final path = await exporter.export(recorder);
      _exportedMatchStart = matchStart;
      _ref.invalidate(matchRecordsProvider);
      debugPrint('Auto-exported ($reason) to $path');
    } on Exception catch (e) {
      debugPrint('Auto-export failed ($reason): $e');
    }
  }

  void dispose() => _cancelFallback();
}
