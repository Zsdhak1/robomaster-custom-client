/// Unit tests for [GameStateNotifier] match-start anchoring.
///
/// Focus: the lifecycle of [GameState.matchStartTime] across stage
/// transitions, which the auto-export fallback relies on to identify and
/// time-bound each match.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/core/constants/protocol_constants.dart';
import 'package:robomaster_custom_client_1/core/protobuf/protobuf_parser.dart';
import 'package:robomaster_custom_client_1/features/dashboard/logic/game_state_notifier.dart';
import 'package:robomaster_custom_client_1/generated/robomaster_custom_client.pb.dart';

ProtobufEnvelope stageEnvelope(int stage) {
  final status = GameStatus()..currentStage = stage;
  return ProtobufEnvelope(
    topic: topicGameStatus,
    messageType: topicGameStatus,
    protobufMessage: status,
    rawBytes: status.writeToBuffer(),
    timestamp: DateTime.now(),
  );
}

void main() {
  group('GameStateNotifier matchStartTime', () {
    test('anchors when entering 比赛中 (stage 4)', () {
      final notifier = GameStateNotifier();
      expect(notifier.state.matchStartTime, isNull);

      notifier.handleEnvelope(stageEnvelope(stageInMatch));
      expect(notifier.state.matchStartTime, isNotNull);
    });

    test('keeps the same anchor through settlement (stage 5)', () {
      final notifier = GameStateNotifier()
        ..handleEnvelope(stageEnvelope(stageInMatch));
      final anchor = notifier.state.matchStartTime;

      notifier.handleEnvelope(stageEnvelope(stageSettlement));
      expect(notifier.state.matchStartTime, anchor);
    });

    test('resets the anchor when falling back to a pre-match stage', () {
      final notifier = GameStateNotifier()
        ..handleEnvelope(stageEnvelope(stageInMatch))
        ..handleEnvelope(stageEnvelope(stageSettlement))
        // New cycle begins: preparation phase clears the anchor.
        ..handleEnvelope(stageEnvelope(stagePreparation));
      expect(notifier.state.matchStartTime, isNull);
    });

    test('re-anchors a distinct second match', () {
      final notifier = GameStateNotifier()
        ..handleEnvelope(stageEnvelope(stageInMatch));
      final firstAnchor = notifier.state.matchStartTime;

      notifier
        ..handleEnvelope(stageEnvelope(stageSettlement))
        ..handleEnvelope(stageEnvelope(stageNotStarted));
      expect(notifier.state.matchStartTime, isNull);

      notifier.handleEnvelope(stageEnvelope(stageInMatch));
      final secondAnchor = notifier.state.matchStartTime;
      expect(secondAnchor, isNotNull);
      // Distinct match cycle yields a fresh anchor object.
      expect(identical(secondAnchor, firstAnchor), isFalse);
    });
  });
}
