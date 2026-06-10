/// StateNotifier that aggregates MQTT messages into [GameState].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../../generated/robomaster_custom_client.pb.dart';
import 'game_state.dart';

/// Match stage value meaning "比赛中" (per protocol §2.2.3 current_stage).
const int _stageInMatch = 4;

/// Notifier that incrementally builds [GameState] from MQTT envelopes.
class GameStateNotifier extends StateNotifier<GameState> {
  /// Creates an empty [GameStateNotifier].
  GameStateNotifier() : super(const GameState());

  static const int _maxEventHistory = 50;
  static const Duration _maxHistoryDuration = Duration(seconds: 120);

  /// Processes a single [ProtobufEnvelope] and updates state.
  void handleEnvelope(ProtobufEnvelope envelope) {
    final msg = envelope.protobufMessage;
    if (msg == null) return;

    switch (msg) {
      case final GameStatus s:
        _updateGameStatus(s);
      case final GlobalUnitStatus s:
        _updateUnitStatus(s);
      case final GlobalLogisticsStatus s:
        state = state.copyWith(globalLogisticsStatus: s);
      case final GlobalSpecialMechanism s:
        state = state.copyWith(globalSpecialMechanism: s);
      case final AirSupportStatusSync s:
        state = state.copyWith(airSupportStatusSync: s);
      case final Event e:
        _addEvent(e);
      default:
        // Other message types are not part of game state aggregation.
        break;
    }
  }

  void _updateGameStatus(GameStatus status) {
    // Record the wall-clock match start the first time the stage enters
    // "比赛中" (4). The protocol carries no absolute start timestamp, so
    // we anchor relative event times to this transition.
    var startTime = state.matchStartTime;
    if (startTime == null && status.currentStage == _stageInMatch) {
      startTime = DateTime.now();
    }
    state = state.copyWith(
      gameStatus: status,
      matchStartTime: startTime,
    );
  }

  void _updateUnitStatus(GlobalUnitStatus status) {
    final now = DateTime.now();
    final newHistory = [
      ...state.statusHistory,
      StatusSnapshot(status: status, timestamp: now),
    ];
    // Remove entries older than _maxHistoryDuration.
    final cutoff = now.subtract(_maxHistoryDuration);
    final trimmed =
        newHistory.where((s) => s.timestamp.isAfter(cutoff)).toList();

    state = state.copyWith(
      globalUnitStatus: status,
      statusHistory: trimmed,
    );
  }

  void _addEvent(Event event) {
    final timed = TimedEvent(event: event, timestamp: DateTime.now());
    final newList = [timed, ...state.eventList];
    if (newList.length > _maxEventHistory) {
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
}
