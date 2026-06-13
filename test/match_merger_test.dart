/// Unit tests for [MatchMerger].
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:robomaster_custom_client_1/features/data_export/domain/match_merger.dart';

void main() {
  _mergeValidationTests();
  _deduplicationTests();
  _privateMessageTests();
  _commandDropTests();
  _mergeOutputTests();
}

void _withTmpDirAndMerger(void Function(Directory Function(), MatchMerger Function()) run) {
  group('with temp directory', () {
    late Directory tmpDir;
    late MatchMerger merger;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('merge_test_');
      merger = const MatchMerger();
    });

    tearDown(() async {
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    run(() => tmpDir, () => merger);
  });
}

void _mergeValidationTests() {
  _withTmpDirAndMerger((tmpDirFn, mergerFn) {
    test('rejects fewer than two files', () async {
      final single = await _writeSingleRecord(tmpDirFn(), robotId: 1);
      final result = await mergerFn().merge(
        filePaths: [single],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeFailure>());
      expect((result as MergeFailure).reason, contains('至少选择 2 个'));
    });

    test('rejects different sides', () async {
      final red = await _writeSingleRecord(tmpDirFn(), robotId: 1);
      final blue = await _writeSingleRecord(tmpDirFn(), robotId: 101);
      final result = await mergerFn().merge(
        filePaths: [red, blue],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeFailure>());
      expect((result as MergeFailure).reason, contains('同一阵营'));
    });

    test('rejects match times too far apart', () async {
      final a = await _writeSingleRecord(
        tmpDirFn(),
        robotId: 1,
        matchTime: DateTime(2026, 6, 12, 10),
      );
      final b = await _writeSingleRecord(
        tmpDirFn(),
        robotId: 2,
        matchTime: DateTime(2026, 6, 12, 11),
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeFailure>());
      expect((result as MergeFailure).reason, contains('时间相差'));
    });

    test('rejects inconsistent scores', () async {
      final a = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 1,
          matchTime: DateTime(2026, 6, 12, 10),
          messages: [
            _gameStatus(redScore: 1, blueScore: 2),
          ],
        ),
        'a.json',
      );
      final b = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 2,
          matchTime: DateTime(2026, 6, 12, 10),
          messages: [
            _gameStatus(redScore: 3, blueScore: 4),
          ],
        ),
        'b.json',
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeFailure>());
      expect((result as MergeFailure).reason, contains('蓝方比分不一致'));
    });
  });
}

Future<String> _writeSingleRecord(
  Directory tmpDir, {
  required int robotId,
  DateTime? matchTime,
}) async => _writeRecord(
      tmpDir,
      _buildRecord(
        robotId: robotId,
        matchTime: matchTime ?? DateTime(2026, 6, 12, 10),
      ),
      'r$robotId.json',
    );

void _deduplicationTests() {
  _withTmpDirAndMerger((tmpDirFn, mergerFn) {
    test('team-shared messages are de-duplicated across sources', () async {
      final time = DateTime(2026, 6, 12, 10);
      final sharedTime = time.add(const Duration(seconds: 5));
      final a = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 1,
          matchTime: time,
          messages: [
            _gameStatus(
              redScore: 0,
              blueScore: 0,
              currentStage: 1,
              time: sharedTime,
            ),
          ],
        ),
        'a.json',
      );
      final b = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 2,
          matchTime: time,
          messages: [
            _gameStatus(
              redScore: 0,
              blueScore: 0,
              currentStage: 1,
              time: sharedTime,
            ),
          ],
        ),
        'b.json',
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeSuccess>());
      final success = result as MergeSuccess;
      expect(success.record.messageCount, 1);
    });
  });
}

void _privateMessageTests() {
  _withTmpDirAndMerger((tmpDirFn, mergerFn) {
    test('robot-private messages are kept per robot id', () async {
      final time = DateTime(2026, 6, 12, 10);
      final msgTime = time.add(const Duration(seconds: 1));
      final a = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 1,
          matchTime: time,
          messages: [
            _robotDynamicStatus(robotId: 1, health: 300, time: msgTime),
          ],
        ),
        'a.json',
      );
      final b = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 2,
          matchTime: time,
          messages: [
            _robotDynamicStatus(robotId: 2, health: 250, time: msgTime),
          ],
        ),
        'b.json',
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeSuccess>());
      final success = result as MergeSuccess;
      expect(success.record.messageCount, 2);

      final written = File(success.record.filePath).readAsStringSync();
      final decoded = jsonDecode(written) as Map<String, dynamic>;
      final messages = decoded['messages'] as List<dynamic>;
      final healths = messages
          .map(
            (m) =>
                ((m as Map<String, dynamic>)['payload'] as Map<String, dynamic>)['currentHealth']
                    as int,
          )
          .toSet();
      expect(healths, {300, 250});
    });
  });
}

void _commandDropTests() {
  _withTmpDirAndMerger((tmpDirFn, mergerFn) {
    test('command topics are dropped during merge', () async {
      final time = DateTime(2026, 6, 12, 10);
      final msgTime = time.add(const Duration(seconds: 1));
      final a = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 1,
          matchTime: time,
          messages: [
            {
              'timestamp': msgTime.toUtc().toIso8601String(),
              'topic': 'CommonCommand',
              'type': 'CommonCommand',
              'payload': {'cmdType': 1, 'param': 2},
            },
          ],
        ),
        'a.json',
      );
      final b = await _writeRecord(
        tmpDirFn(),
        _buildRecord(robotId: 2, matchTime: time),
        'b.json',
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeSuccess>());
      expect((result as MergeSuccess).record.messageCount, 0);
    });
  });
}

void _mergeOutputTests() {
  _withTmpDirAndMerger((tmpDirFn, mergerFn) {
    test('merged file metadata marks merge provenance', () async {
      final time = DateTime(2026, 6, 12, 10);
      final msgTime = time.add(const Duration(seconds: 1));
      final a = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 1,
          matchTime: time,
          messages: [
            {
              'timestamp': msgTime.toUtc().toIso8601String(),
              'topic': 'Event',
              'type': 'Event',
              'payload': {'eventId': 1, 'param': 'start'},
            },
          ],
        ),
        'a.json',
      );
      final b = await _writeRecord(
        tmpDirFn(),
        _buildRecord(robotId: 2, matchTime: time),
        'b.json',
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeSuccess>());
      final success = result as MergeSuccess;

      final written = File(success.record.filePath).readAsStringSync();
      final decoded = jsonDecode(written) as Map<String, dynamic>;
      final metadata = decoded['metadata'] as Map<String, dynamic>;
      expect(metadata['merged'], isTrue);
      expect(metadata['source_robot_ids'], containsAll([1, 2]));
      expect(metadata['merged_from'], containsAll(['a.json', 'b.json']));
      expect(decoded['schema_version'], '2.0');
    });

    test('written merged file is re-importable by scanner', () async {
      final time = DateTime(2026, 6, 12, 10);
      final msgTime = time.add(const Duration(seconds: 1));
      final a = await _writeRecord(
        tmpDirFn(),
        _buildRecord(
          robotId: 1,
          matchTime: time,
          messages: [
            _gameStatus(
              redScore: 1,
              blueScore: 2,
              currentStage: 5,
              stageElapsedSec: 420,
              time: msgTime,
            ),
          ],
        ),
        'a.json',
      );
      final b = await _writeRecord(
        tmpDirFn(),
        _buildRecord(robotId: 2, matchTime: time),
        'b.json',
      );
      final result = await mergerFn().merge(
        filePaths: [a, b],
        exportDirectory: tmpDirFn().path,
      );
      expect(result, isA<MergeSuccess>());
      final filePath = (result as MergeSuccess).record.filePath;
      expect(File(filePath).existsSync(), isTrue);
    });
  });
}

Map<String, dynamic> _buildRecord({
  required int robotId,
  required DateTime matchTime,
  List<Map<String, dynamic>>? messages,
}) {
  return {
    'schema_version': '2.0',
    'metadata': {
      'robot_id': robotId,
      'match_start_time': matchTime.toUtc().toIso8601String(),
    },
    'messages': messages ?? [],
  };
}

Map<String, dynamic> _gameStatus({
  required int redScore,
  required int blueScore,
  int? currentStage,
  int? stageElapsedSec,
  DateTime? time,
}) {
  return {
    'timestamp': (time ?? DateTime(2026, 6, 12, 10, 1)).toUtc().toIso8601String(),
    'topic': 'GameStatus',
    'type': 'GameStatus',
    'payload': {
      'redScore': redScore,
      'blueScore': blueScore,
      'currentStage': ?currentStage,
      'stageElapsedSec': ?stageElapsedSec,
    },
  };
}

Map<String, dynamic> _robotDynamicStatus({
  required int robotId,
  required int health,
  DateTime? time,
}) {
  return {
    'timestamp': (time ?? DateTime(2026, 6, 12, 10, 1)).toUtc().toIso8601String(),
    'topic': 'RobotDynamicStatus',
    'type': 'RobotDynamicStatus',
    'payload': {'robotId': robotId, 'currentHealth': health},
  };
}

Future<String> _writeRecord(
  Directory tmpDir,
  Map<String, dynamic> data,
  String name,
) async {
  final path = p.join(tmpDir.path, name);
  await File(path).writeAsString(jsonEncode(data));
  return path;
}
