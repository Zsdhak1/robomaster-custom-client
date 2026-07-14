/// [parseMatchSummary] 的单元测试；该解析器适合在 isolate 中运行。
///
/// 关注得分提取、完整性（结算阶段）检测、持续时间，以及基于落盘 JSON Schema 的按类型计数。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:robomaster_custom_client_1/features/data_export/data/match_record_scanner.dart';

String buildJson({
  required List<Map<String, dynamic>> messages,
  int robotId = 1,
  String? matchStart,
  int? durationSeconds,
}) {
  return jsonEncode({
    'schema_version': '2.0',
    'metadata': {
      'robot_id': robotId,
      'match_start_time': matchStart,
      'duration_seconds': durationSeconds,
      'message_count': messages.length,
    },
    'messages': messages,
  });
}

Map<String, dynamic> gameStatus({int? red, int? blue, int? stage}) {
  return {
    'type': 'GameStatus',
    'topic': 'GameStatus',
    'timestamp': '2026-06-12T10:00:00.000Z',
    'payload': {
      'redScore': ?red,
      'blueScore': ?blue,
      'currentStage': ?stage,
    },
  };
}

Map<String, dynamic> event() {
  return {
    'type': 'Event',
    'topic': 'Event',
    'timestamp': '2026-06-12T10:01:00.000Z',
    'payload': {'eventId': 1, 'param': 0},
  };
}

void main() {
  _scoreTests();
  _completenessTests();
  _countingTests();
  _mergedRecordTests();
}

void _scoreTests() {
  group('score extraction', () {
    test('extracts final score from the last GameStatus', () {
      final json = buildJson(
        messages: [
          gameStatus(red: 1, blue: 2, stage: 4),
          gameStatus(red: 5, blue: 8, stage: 5),
        ],
        durationSeconds: 450,
      );
      final record = parseMatchSummary(
        const ScanInput(text: '', path: '/x/match.json', sizeBytes: 100),
      );
      expect(record, isNull);

      final parsed = parseMatchSummary(
        ScanInput(text: json, path: '/x/match.json', sizeBytes: 100),
      );
      expect(parsed, isNotNull);
      expect(parsed!.redScore, 5);
      expect(parsed.blueScore, 8);
    });
  });
}

void _completenessTests() {
  group('completeness detection', () {
    test('detects completeness when settlement stage present', () {
      final complete = parseMatchSummary(
        ScanInput(
          text: buildJson(messages: [gameStatus(stage: 5)]),
          path: '/x/a.json',
          sizeBytes: 1,
        ),
      );
      expect(complete!.isComplete, isTrue);

      final incomplete = parseMatchSummary(
        ScanInput(
          text: buildJson(messages: [gameStatus(stage: 4)]),
          path: '/x/b.json',
          sizeBytes: 1,
        ),
      );
      expect(incomplete!.isComplete, isFalse);
    });
  });
}

void _countingTests() {
  group('counting and metadata', () {
    test('counts events and message types, reads duration', () {
      final parsed = parseMatchSummary(
        ScanInput(
          text: buildJson(
            messages: [
              gameStatus(stage: 4),
              event(),
              event(),
            ],
            durationSeconds: 200,
          ),
          path: '/x/c.json',
          sizeBytes: 2048,
        ),
      );
      expect(parsed, isNotNull);
      expect(parsed!.eventCount, 2);
      expect(parsed.typeCounts['GameStatus'], 1);
      expect(parsed.typeCounts['Event'], 2);
      expect(parsed.duration, const Duration(seconds: 200));
      expect(parsed.fileSizeBytes, 2048);
      expect(parsed.robotId, 1);
    });

    test('blue-side robot id flags isBlue', () {
      final parsed = parseMatchSummary(
        ScanInput(
          text: buildJson(messages: [gameStatus(stage: 4)], robotId: 103),
          path: '/x/d.json',
          sizeBytes: 1,
        ),
      );
      expect(parsed!.isBlue, isTrue);
    });
  });
}

void _mergedRecordTests() {
  group('merged records', () {
    test('detects merged records and derives side from metadata', () {
      final mergedBlue = _mergedJson(side: 'blue');
      final parsed = parseMatchSummary(
        ScanInput(text: mergedBlue, path: '/x/merged.json', sizeBytes: 1),
      );
      expect(parsed, isNotNull);
      expect(parsed!.isMerged, isTrue);
      expect(parsed.isBlue, isTrue);

      final mergedRed = _mergedJson(side: 'red');
      final red = parseMatchSummary(
        ScanInput(text: mergedRed, path: '/x/merged_red.json', sizeBytes: 1),
      );
      expect(red!.isMerged, isTrue);
      expect(red.isBlue, isFalse);
    });

    test('non-merged record reports isMerged false', () {
      final parsed = parseMatchSummary(
        ScanInput(
          text: buildJson(messages: [gameStatus(stage: 4)]),
          path: '/x/plain.json',
          sizeBytes: 1,
        ),
      );
      expect(parsed!.isMerged, isFalse);
    });
  });
}

String _mergedJson({required String side}) {
  return jsonEncode({
    'schema_version': '2.0',
    'metadata': {
      'robot_id': 0,
      'merged': true,
      'side': side,
      'message_count': 1,
    },
    'messages': [gameStatus(stage: 5)],
  });
}
