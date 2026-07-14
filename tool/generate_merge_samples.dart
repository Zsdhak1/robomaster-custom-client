/// 生成用于测试多文件合并器的 JSON 比赛记录样例。
///
/// 运行方式：
///   dart run tool/generate_merge_samples.dart [output_directory]
///
/// 为同一场模拟比赛生成三份红方记录（英雄、步兵、哨兵）。全队共享 topic
///（GameStatus、Event）会跨文件重复，用于验证去重；机器人私有 topic 携带不同
/// 机器人 ID，用于验证按机器人重组。
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

final _matchStart = DateTime.utc(2026, 6, 10, 14, 30);

String _iso(DateTime dt) => dt.toUtc().toIso8601String();

DateTime _at(int sec) => _matchStart.add(Duration(seconds: sec));

Map<String, dynamic> _gameStatus({
  required int sec,
  required int stage,
  int redScore = 0,
  int blueScore = 0,
  int elapsed = 0,
}) =>
    {
      'timestamp': _iso(_at(sec)),
      'topic': 'GameStatus',
      'type': 'GameStatus',
      'payload': {
        'currentRound': 1,
        'totalRounds': 3,
        'redScore': redScore,
        'blueScore': blueScore,
        'currentStage': stage,
        'stageCountdownSec': 420 - elapsed,
        'stageElapsedSec': elapsed,
        'isPaused': false,
      },
    };

Map<String, dynamic> _event({required int sec, required int eventId}) => {
  'timestamp': _iso(_at(sec)),
  'topic': 'Event',
  'type': 'Event',
  'payload': {
    'eventId': eventId,
    'param': 'event-$eventId',
  },
};

Map<String, dynamic> _robotDynamic({
  required int sec,
  required int robotId,
  required int health,
}) =>
    {
      'timestamp': _iso(_at(sec)),
      'topic': 'RobotDynamicStatus',
      'type': 'RobotDynamicStatus',
      'payload': {
        'robotId': robotId,
        'currentHealth': health,
        'currentHeat': 80.0,
        'lastProjectileFireRate': 15.0,
        'currentChassisEnergy': 60,
        'currentBufferEnergy': 30,
        'currentExperience': 5,
        'experienceForUpgrade': 3,
        'totalProjectilesFired': 120,
        'remainingAmmo': 400,
        'isOutOfCombat': false,
        'outOfCombatCountdown': 0,
        'canRemoteHeal': true,
        'canRemoteAmmo': false,
      },
    };

Map<String, dynamic> _robotPosition({
  required int sec,
  required int robotId,
  required double x,
  required double y,
}) =>
    {
      'timestamp': _iso(_at(sec)),
      'topic': 'RobotPosition',
      'type': 'RobotPosition',
      'payload': {
        'robotId': robotId,
        'x': x,
        'y': y,
        'z': 0.0,
        'yaw': 45.0,
      },
    };

Map<String, dynamic> _customByteBlock({required int sec, required int robotId}) =>
    {
      'timestamp': _iso(_at(sec)),
      'topic': 'CustomByteBlock',
      'type': 'CustomByteBlock',
      'payload': {
        'raw_base64': base64Encode(utf8.encode('robot-$robotId-payload')),
      },
    };

Map<String, dynamic> _buildRecord({
  required int robotId,
  required List<Map<String, dynamic>> messages,
}) =>
    {
      'schema_version': '2.0',
      'export_time': _iso(DateTime.now().toUtc()),
      'app_version': '0.1.0+1',
      'metadata': {
        'robot_id': robotId,
        'match_start_time': _iso(_matchStart),
        'duration_seconds': 180,
        'message_count': messages.length,
        'bucket_count': {...messages.map((m) => m['type'] as String)}.length,
      },
      'messages': messages,
    };

void main(List<String> args) {
  final outDir = args.isNotEmpty ? args.first : 'test_data/merge_samples';
  final dir = Directory(outDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final shared = [
    _gameStatus(sec: 0, stage: 1),
    _gameStatus(sec: 60, stage: 2, elapsed: 60),
    _gameStatus(sec: 120, stage: 3, elapsed: 120),
    _gameStatus(sec: 180, stage: 5, redScore: 2, blueScore: 1, elapsed: 180),
    _event(sec: 30, eventId: 1),
    _event(sec: 90, eventId: 2),
  ];

  final heroMessages = [
    ...shared,
    _robotDynamic(sec: 5, robotId: 1, health: 500),
    _robotDynamic(sec: 65, robotId: 1, health: 420),
    _robotDynamic(sec: 125, robotId: 1, health: 380),
    _robotPosition(sec: 10, robotId: 1, x: 1.5, y: 2.5),
    _customByteBlock(sec: 20, robotId: 1),
  ];

  final infantryMessages = [
    ...shared,
    _robotDynamic(sec: 5, robotId: 3, health: 300),
    _robotDynamic(sec: 65, robotId: 3, health: 280),
    _robotDynamic(sec: 125, robotId: 3, health: 200),
    _robotPosition(sec: 10, robotId: 3, x: 4.5, y: 1.5),
    _customByteBlock(sec: 22, robotId: 3),
  ];

  final sentryMessages = [
    ...shared,
    _robotDynamic(sec: 5, robotId: 7, health: 600),
    _robotDynamic(sec: 65, robotId: 7, health: 580),
    _robotDynamic(sec: 125, robotId: 7, health: 550),
    _robotPosition(sec: 10, robotId: 7, x: 8.0, y: 8.0),
    _customByteBlock(sec: 24, robotId: 7),
  ];

  final records = {
    'rm_export_1_20260610_143000.json': _buildRecord(
      robotId: 1,
      messages: heroMessages,
    ),
    'rm_export_3_20260610_143000.json': _buildRecord(
      robotId: 3,
      messages: infantryMessages,
    ),
    'rm_export_7_20260610_143000.json': _buildRecord(
      robotId: 7,
      messages: sentryMessages,
    ),
  };

  for (final entry in records.entries) {
    final path = p.join(outDir, entry.key);
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(entry.value),
    );
    stdout.writeln('Wrote $path (${entry.value['messages'].length} messages)');
  }

  stdout.writeln('Done. Open these files in the data-export screen and merge them.');
}
