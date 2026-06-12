/// Background auto-export service driven by match stage and connection state.
///
/// Goals (so that a match is always saved as a single, mergeable file):
/// - **Normal path** — when the match enters settlement (stage 5), export the
///   whole recording immediately. Timestamps are most accurate here.
/// - **Disconnect fallback** — if MQTT drops mid-match, do NOT save a partial
///   file right away (that would split one match into misaligned fragments and
///   break cross-client timestamp merging). Instead wait until the match's
///   theoretical end time ([matchDurationWithBuffer] after the anchor); only
///   then, as a last resort, persist whatever was recorded.
/// - **Late reconnect** — if MQTT comes back, recording continues into the same
///   in-memory buffer and a re-export overwrites the same file (the file name is
///   derived from the match start time), so the match stays a single file.
/// - **Dedup** — each match (identified by its [GameState.matchStartTime]) is
///   exported at most once per trigger reason; settlement and fallback race and
///   the first to fire wins, the other is skipped.
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

/// Global side-effect provider that auto-exports recordings.
///
/// Watch this provider (e.g., from `MainApp`) to activate the listeners.
final autoExportProvider = Provider<void>((ref) {
  final controller = _AutoExportController(ref);

  ref
    ..listen(gameStateProvider, controller.onGameStateChanged)
    ..listen(mqttConnectionStateProvider, (_, next) {
      next.whenData(controller.onConnectionChanged);
    })
    ..onDispose(controller.dispose);
});

/// State machine coordinating settlement and disconnect-fallback exports.
class _AutoExportController {
  _AutoExportController(this._ref);

  final Ref _ref;

  /// The match-start anchor of the match that has already been auto-exported,
  /// used to dedup. Null means the current match has not been exported yet.
  DateTime? _exportedMatchStart;

  /// Pending fallback timer armed while disconnected mid-match.
  Timer? _fallbackTimer;

  void onGameStateChanged(GameState? previous, GameState next) {
    final prevStage = previous?.gameStatus?.currentStage;
    final nextStage = next.gameStatus?.currentStage;
    if (prevStage == nextStage) return;

    if (nextStage == stageSettlement) {
      // Normal path: settlement reached, export the full match now.
      _cancelFallback();
      unawaited(_exportCurrentMatch(reason: 'settlement'));
    } else if (prevStage == stageSettlement && nextStage != stageSettlement) {
      // A new match cycle has begun: clear the recorder and reset dedup so the
      // next match records and exports fresh.
      _cancelFallback();
      _exportedMatchStart = null;
      _ref.read(dataRecorderProvider.notifier).clear();
    }
  }

  void onConnectionChanged(MqttConnectionState connectionState) {
    if (connectionState == MqttConnectionState.connected) {
      // Reconnected: cancel any pending fallback. Recording resumes into the
      // same buffer; settlement (or a later fallback) will export the whole
      // match as one file.
      _cancelFallback();
      return;
    }

    // Disconnected (or error). If we are mid-match with data, arm the fallback
    // to fire at the match's theoretical end time. Do not save immediately —
    // a partial mid-match file cannot be cleanly merged with other clients.
    _armFallbackIfMidMatch();
  }

  void _armFallbackIfMidMatch() {
    if (_fallbackTimer != null) return; // already armed

    final gameState = _ref.read(gameStateProvider);
    final matchStart = gameState.matchStartTime;
    if (matchStart == null) return; // not in a match yet
    if (_exportedMatchStart == matchStart) return; // already exported

    if (_ref.read(dataRecorderProvider).totalCount == 0) return; // nothing to save

    final theoreticalEnd = matchStart.add(matchDurationWithBuffer);
    final remaining = theoreticalEnd.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      // Already past the theoretical end: save the partial recording now.
      unawaited(_exportCurrentMatch(reason: 'fallback-immediate'));
      return;
    }

    debugPrint(
      'Auto-export fallback armed: will save in ${remaining.inSeconds}s '
      'if still disconnected',
    );
    _fallbackTimer = Timer(remaining, () {
      _fallbackTimer = null;
      // Only fire if still disconnected; a reconnect cancels this timer.
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

    // Dedup: a settlement export wins over a later fallback for the same match.
    // A late reconnect that reaches settlement again re-exports the same file
    // (same name from matchStart), which is the desired "append to same match"
    // behavior, so only block when the trigger is the fallback path.
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
