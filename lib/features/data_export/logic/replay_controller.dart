/// 回放控制器：将已保存比赛文件转换为可 seek 的 [GameState] 快照时间线，
/// 并与实时仪表盘状态完全隔离。
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../dashboard/logic/game_state.dart';
import '../../dashboard/logic/game_state_notifier.dart';
import '../data/json_importer.dart';
import 'data_import_provider.dart';

/// 关键帧间隔：每 N 个信封缓存一个 [GameState] 快照。
///
/// seek 时只需从最近的早期关键帧重放，而不用从开头重放。
const int _keyframeInterval = 200;

/// 可用的回放速度。
const List<double> replaySpeeds = [0.5, 1, 2, 4];

/// UI 使用的不可变回放状态视图。
@immutable
class ReplayState {
  /// 创建 [ReplayState]。
  const ReplayState({
    this.isLoading = true,
    this.error,
    this.gameState = const GameState(),
    this.isPlaying = false,
    this.speed = 1,
    this.position = Duration.zero,
    this.total = Duration.zero,
    this.matchStart,
    this.eventCount = 0,
  });

  /// 文件是否仍在加载或解析。
  final bool isLoading;

  /// 加载失败时的错误消息；成功时为 null。
  final String? error;

  /// 当前 [position] 对应的重建比赛状态。
  final GameState gameState;

  /// 回放当前是否正在推进。
  final bool isPlaying;

  /// 当前回放速度倍率。
  final double speed;

  /// 相对于比赛开始的当前回放位置。
  final Duration position;

  /// 总回放时长，即最后一个信封时间减去第一个信封时间。
  final Duration total;

  /// 比赛开始的墙钟时间锚点，用于相对事件计时。
  final DateTime? matchStart;

  /// 当前回放位置可见的事件数量。
  final int eventCount;

  /// 滑块使用的 0..1 进度值。
  double get progress {
    final t = total.inMilliseconds;
    if (t <= 0) return 0;
    return (position.inMilliseconds / t).clamp(0.0, 1.0);
  }

  /// 创建更新部分字段后的副本。
  ReplayState copyWith({
    bool? isLoading,
    String? error,
    GameState? gameState,
    bool? isPlaying,
    double? speed,
    Duration? position,
    Duration? total,
    DateTime? matchStart,
    int? eventCount,
  }) {
    return ReplayState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      gameState: gameState ?? this.gameState,
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      position: position ?? this.position,
      total: total ?? this.total,
      matchStart: matchStart ?? this.matchStart,
      eventCount: eventCount ?? this.eventCount,
    );
  }
}

/// 将已保存比赛文件驱动为可 seek 的 [GameState] 快照回放。
class ReplayController extends StateNotifier<ReplayState> {
  /// 创建 [ReplayController] 并开始加载 [filePath]。
  ReplayController({required this.filePath, required JsonImporter importer})
      : _importer = importer, // ignore: prefer_initializing_formals
        super(const ReplayState()) {
    unawaited(_load());
  }

  /// 正在回放的比赛文件路径。
  final String filePath;

  final JsonImporter _importer;

  /// 按时间戳排序的信封列表，最旧在前。
  List<ProtobufEnvelope> _envelopes = [];

  /// 关键帧快照：信封索引 -> 聚合到该索引的状态。
  final Map<int, GameState> _keyframes = {};

  DateTime? _t0;
  Duration _total = Duration.zero;
  Timer? _ticker;

  /// 回放 tick 间隔；位置每次推进 `间隔 * speed`。
  static const Duration _tickInterval = Duration(milliseconds: 100);

  Future<void> _load() async {
    try {
      final envelopes = await _importer.import(filePath);
      if (envelopes.isEmpty) {
        state = state.copyWith(isLoading: false, error: '记录为空或无法解析');
        return;
      }
      envelopes.sort(
        (ProtobufEnvelope a, ProtobufEnvelope b) =>
            a.timestamp.compareTo(b.timestamp),
      );
      _envelopes = envelopes;
      _t0 = envelopes.first.timestamp;
      _total = envelopes.last.timestamp.difference(_t0!);

      _buildKeyframes();

      // 初始位置放在时间线开头。
      final initial = _stateAtIndex(0);
      state = state.copyWith(
        isLoading: false,
        gameState: initial.state,
        total: _total,
        matchStart: initial.state.matchStartTime ?? _t0,
        position: Duration.zero,
        eventCount: initial.state.eventList.length,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: '加载失败: $e');
    }
  }

  /// 按固定信封间隔预计算关键帧快照。
  void _buildKeyframes() {
    _keyframes.clear();
    final notifier = GameStateNotifier()..replaying = true;
    for (var i = 0; i < _envelopes.length; i++) {
      notifier.handleEnvelope(_envelopes[i]);
      if (i % _keyframeInterval == 0) {
        _keyframes[i] = notifier.state;
      }
    }
  }

  /// 构建覆盖信封 `[0..index]`（含）的聚合状态，并从最近的早期关键帧恢复。
  ({GameState state, int index}) _stateAtIndex(int index) {
    final target = index.clamp(0, _envelopes.length - 1);

    // 查找目标索引之前或等于目标索引的最近关键帧。
    var kfIndex = 0;
    for (final k in _keyframes.keys) {
      if (k <= target && k > kfIndex) kfIndex = k;
    }

    final notifier = GameStateNotifier()..replaying = true;
    final seed = _keyframes[kfIndex];
    var startFrom = 0;
    if (seed != null) {
      notifier.seedReplayState(seed);
      // kfIndex 处的关键帧已经包含该索引对应的信封。
      startFrom = kfIndex + 1;
    }
    for (var i = startFrom; i <= target; i++) {
      notifier.handleEnvelope(_envelopes[i]);
    }
    final result = notifier.state;
    return (state: result, index: target);
  }

  /// 返回时间戳最接近 [position] 的信封索引。
  int _indexForPosition(Duration position) {
    if (_t0 == null || _envelopes.isEmpty) return 0;
    final targetTime = _t0!.add(position);
    // 线性扫描足够：位置单调推进且列表有界。
    var idx = 0;
    for (var i = 0; i < _envelopes.length; i++) {
      if (!_envelopes[i].timestamp.isAfter(targetTime)) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  /// seek 到 0..1 范围内的 [progress]，并重建快照。
  void seekToProgress(double progress) {
    final clamped = progress.clamp(0.0, 1.0);
    final position = Duration(
      milliseconds: (_total.inMilliseconds * clamped).round(),
    );
    _seekTo(position);
  }

  void _seekTo(Duration position) {
    final index = _indexForPosition(position);
    final built = _stateAtIndex(index);
    state = state.copyWith(
      gameState: built.state,
      position: position,
      eventCount: built.state.eventList.length,
    );
  }

  /// 启动或继续回放。
  void play() {
    if (state.isPlaying || _envelopes.isEmpty) return;
    if (state.position >= _total) {
      // 如果已经在末尾，则从开头重新开始。
      _seekTo(Duration.zero);
    }
    state = state.copyWith(isPlaying: true);
    _ticker = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  /// 暂停回放。
  void pause() {
    _ticker?.cancel();
    _ticker = null;
    if (state.isPlaying) state = state.copyWith(isPlaying: false);
  }

  /// 切换播放或暂停。
  void togglePlay() => state.isPlaying ? pause() : play();

  /// 设置回放速度倍率 [speed]。
  void setSpeed(double speed) => state = state.copyWith(speed: speed);

  void _onTick() {
    final advance = _tickInterval * state.speed;
    final next = state.position + advance;
    if (next >= _total) {
      _seekTo(_total);
      pause();
      return;
    }
    _seekTo(next);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// 为给定文件路径提供 [ReplayController]。
///
/// 使用 `autoDispose`，回放页面退出后会释放控制器和关键帧缓存。`family` 以文件路径
/// 为 key，使每条记录拥有独立控制器。
final replayControllerProvider = StateNotifierProvider.autoDispose
    .family<ReplayController, ReplayState, String>((ref, filePath) {
  final importer = ref.watch(jsonImporterProvider);
  return ReplayController(filePath: filePath, importer: importer);
});
