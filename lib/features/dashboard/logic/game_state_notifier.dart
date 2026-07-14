/// 将 MQTT 消息聚合进 [GameState] 的 StateNotifier。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/protobuf/protobuf_parser.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import 'game_state.dart';

/// 根据 MQTT 信封增量构建 [GameState] 的通知器。
class GameStateNotifier extends StateNotifier<GameState> {
  /// 创建空的 [GameStateNotifier]。
  GameStateNotifier() : super(const GameState());

  static const int _maxEventHistory = 50;
  static const Duration _maxHistoryDuration = Duration(seconds: 120);

  /// 当前是否正在回放导入的信封。
///
  /// 为 true 时禁用历史上限，以便保留完整导入比赛用于赛后分析；
  /// 实时数据仍遵守滚动历史限制。
  bool _isReplaying = false;

  /// 处理单个 [ProtobufEnvelope] 并更新状态。
  void handleEnvelope(ProtobufEnvelope envelope) {
    final msg = envelope.protobufMessage;
    if (msg == null) return;

    switch (msg) {
      case final GameStatus s:
        _updateGameStatus(s);
      case final GlobalUnitStatus s:
        _updateUnitStatus(s, envelope.timestamp);
      case final GlobalLogisticsStatus s:
        state = state.copyWith(globalLogisticsStatus: s);
      case final GlobalSpecialMechanism s:
        state = state.copyWith(globalSpecialMechanism: s);
      case final AirSupportStatusSync s:
        state = state.copyWith(airSupportStatusSync: s);
      case final Event e:
        _addEvent(e, envelope.timestamp);
      default:
        // 其他消息类型不参与比赛状态聚合。
        break;
    }
  }

  void _updateGameStatus(GameStatus status) {
    // 首次进入“比赛中”（阶段 4）时，用墙钟时间锚定比赛开始。
    // 协议不携带绝对开始时间戳，因此相对事件时间都基于该阶段转换。
    //
    // 当阶段回退到赛前阶段（0 未开始 / 1 准备 / 2 自检 / 3 倒计时）时重置锚点，
    // 让每场比赛都能被区分，并在下一次进入“比赛中”时重新锚定。
    // 否则第一场比赛的锚点会泄漏到后续比赛，破坏事件时间线和自动导出兜底定时器。
    var startTime = state.matchStartTime;
    if (status.currentStage == stageInMatch) {
      startTime ??= DateTime.now();
    } else if (status.currentStage < stageInMatch) {
      startTime = null;
    }
    state = GameState(
      gameStatus: status,
      globalUnitStatus: state.globalUnitStatus,
      globalLogisticsStatus: state.globalLogisticsStatus,
      globalSpecialMechanism: state.globalSpecialMechanism,
      airSupportStatusSync: state.airSupportStatusSync,
      eventList: state.eventList,
      statusHistory: state.statusHistory,
      matchStartTime: startTime,
      isConnected: state.isConnected,
    );
  }

  void _updateUnitStatus(GlobalUnitStatus status, DateTime timestamp) {
    var newHistory = [
      ...state.statusHistory,
      StatusSnapshot(status: status, timestamp: timestamp),
    ];
    if (!_isReplaying) {
      // 移除早于 _maxHistoryDuration 的历史条目。
      final cutoff = timestamp.subtract(_maxHistoryDuration);
      newHistory = newHistory.where((s) => s.timestamp.isAfter(cutoff)).toList();
    }

    state = state.copyWith(
      globalUnitStatus: status,
      statusHistory: newHistory,
    );
  }

  void _addEvent(Event event, DateTime timestamp) {
    final timed = TimedEvent(event: event, timestamp: timestamp);
    final newList = [timed, ...state.eventList];
    if (!_isReplaying && newList.length > _maxEventHistory) {
      newList.removeLast();
    }
    state = state.copyWith(eventList: newList);
  }

  /// 更新 MQTT 连接状态。
  void setConnected({required bool connected}) {
    state = state.copyWith(isConnected: connected);
  }

  /// 清空所有聚合状态。
  void clear() {
    state = const GameState();
  }

  /// 回放一组导入信封，用于重建状态和历史。
///
  /// 回放期间禁用历史限制，以便保留完整导入比赛用于赛后分析。
  void replayEnvelopes(List<ProtobufEnvelope> envelopes) {
    _isReplaying = true;
    for (final envelope in envelopes) {
      handleEnvelope(envelope);
    }
    _isReplaying = false;
  }

  /// 将通知器置为已知 [snapshot]，用于回放 seek。
///
  /// 所有聚合历史都位于 [GameState] 中，因此恢复一个关键帧快照即可完整恢复通知器。
  /// 后续以 [replaying] 为 true 调用 [handleEnvelope] 时，会从该快照继续累积。
  /// 回放控制器的关键帧缓存依赖该能力，避免每次拖动进度都从开头重放。
  void seedReplayState(GameState snapshot) {
    state = snapshot;
  }

  /// 启用或关闭回放模式；回放模式会禁用滚动历史上限。
  set replaying(bool value) => _isReplaying = value;
}
