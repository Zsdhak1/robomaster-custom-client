/// StateNotifier that aggregates MQTT messages into [GameState].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';
import '../../../core/protobuf/protobuf_parser.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import 'game_state.dart';

/// Notifier that incrementally builds [GameState] from MQTT envelopes.
class GameStateNotifier extends StateNotifier<GameState> {
  /// Creates an empty [GameStateNotifier].
  GameStateNotifier() : super(const GameState());

  static const int _maxEventHistory = 50;
  static const Duration _maxHistoryDuration = Duration(seconds: 120);

  /// Whether currently replaying imported envelopes.
  ///
  /// When true, history caps are disabled so the full imported match is kept
  /// for post-match analysis; live data still respects the rolling limits.
  bool _isReplaying = false;

  /// Processes a single [ProtobufEnvelope] and updates state.
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
        // Other message types are not part of game state aggregation.
        break;
    }
  }

  void _updateGameStatus(GameStatus status) {
    // Anchor the wall-clock match start the first time the stage enters
    // "比赛中" (4). The protocol carries no absolute start timestamp, so we
    // anchor relative event times to this transition.
    //
    // Reset the anchor whenever the stage falls back to a pre-match phase
    // (0未开始/1准备/2自检/3倒计时) so that each match is distinguishable and
    // the next "比赛中" transition re-anchors. Without this, a single anchor
    // from the first match would leak across every subsequent match and break
    // both event timelines and the auto-export fallback timer.
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
      // Remove entries older than _maxHistoryDuration.
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

  /// Updates the MQTT connection state.
  void setConnected({required bool connected}) {
    state = state.copyWith(isConnected: connected);
  }

  /// Clears all aggregated state.
  void clear() {
    state = const GameState();
  }

  /// Replays a list of imported envelopes to rebuild state and history.
  ///
  /// History limits are disabled during replay so the full imported match is
  /// retained for post-match analysis.
  void replayEnvelopes(List<ProtobufEnvelope> envelopes) {
    _isReplaying = true;
    for (final envelope in envelopes) {
      handleEnvelope(envelope);
    }
    _isReplaying = false;
  }

  /// Seeds the notifier to a known [snapshot] for replay seeking.
  ///
  /// Because all aggregated history lives in [GameState], restoring a keyframe
  /// snapshot fully restores the notifier; subsequent [handleEnvelope] calls
  /// (with [replaying] true) continue accumulating from there. Used by the
  /// replay controller's keyframe cache to avoid replaying from the start on
  /// every seek.
  void seedReplayState(GameState snapshot) {
    state = snapshot;
  }

  /// Enables or disables replay mode (disables rolling history caps).
  set replaying(bool value) => _isReplaying = value;
}
