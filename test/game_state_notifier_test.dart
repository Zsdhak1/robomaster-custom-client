/// [GameStateNotifier] 比赛开始时间锚点的单元测试。
///
/// 关注 [GameState.matchStartTime] 在阶段切换中的生命周期；自动导出兜底逻辑依赖它
/// 识别每场比赛并约束比赛时间范围。
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
        // 新比赛周期开始：准备阶段会清空锚点。
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
      // 不同比赛周期会产生新的锚点对象。
      expect(identical(secondAnchor, firstAnchor), isFalse);
    });
  });
}
