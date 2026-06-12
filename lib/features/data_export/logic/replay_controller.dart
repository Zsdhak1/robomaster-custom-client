/// Replay controller: turns a saved match file into a seekable timeline of
/// [GameState] snapshots, fully isolated from the live dashboard state.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/protobuf/protobuf_parser.dart';
import '../../dashboard/logic/game_state.dart';
import '../../dashboard/logic/game_state_notifier.dart';
import '../data/json_importer.dart';
import 'data_import_provider.dart';

/// Keyframe interval: cache a [GameState] snapshot every N envelopes so seeking
/// only replays from the nearest earlier keyframe, not from the start.
const int _keyframeInterval = 200;

/// Available replay playback speeds.
const List<double> replaySpeeds = [0.5, 1, 2, 4];

/// Immutable view of the replay state for the UI.
@immutable
class ReplayState {
  /// Creates a [ReplayState].
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

  /// Whether the file is still being loaded/parsed.
  final bool isLoading;

  /// Error message if loading failed, null otherwise.
  final String? error;

  /// The reconstructed game state at the current [position].
  final GameState gameState;

  /// Whether playback is currently advancing.
  final bool isPlaying;

  /// Current playback speed multiplier.
  final double speed;

  /// Current playback position from match start.
  final Duration position;

  /// Total replay duration (last envelope minus first).
  final Duration total;

  /// Wall-clock match start anchor for relative event times.
  final DateTime? matchStart;

  /// Number of events visible at the current position.
  final int eventCount;

  /// Progress in 0..1 for the slider.
  double get progress {
    final t = total.inMilliseconds;
    if (t <= 0) return 0;
    return (position.inMilliseconds / t).clamp(0.0, 1.0);
  }

  /// Creates a copy with selected fields updated.
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

/// Drives playback of a saved match file as seekable [GameState] snapshots.
class ReplayController extends StateNotifier<ReplayState> {
  /// Creates a [ReplayController] and begins loading [filePath].
  ReplayController({required this.filePath, required JsonImporter importer})
      : _importer = importer, // ignore: prefer_initializing_formals
        super(const ReplayState()) {
    unawaited(_load());
  }

  /// Path of the match file being replayed.
  final String filePath;

  final JsonImporter _importer;

  /// Envelopes sorted by timestamp (oldest first).
  List<ProtobufEnvelope> _envelopes = [];

  /// Keyframe snapshots: envelope index -> aggregated state up to that index.
  final Map<int, GameState> _keyframes = {};

  DateTime? _t0;
  Duration _total = Duration.zero;
  Timer? _ticker;

  /// Playback tick interval; position advances by interval * speed.
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

      // Start positioned at the very beginning.
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

  /// Precomputes keyframe snapshots at fixed envelope intervals.
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

  /// Builds the aggregated state covering envelopes `[0..index]` inclusive,
  /// resuming from the nearest earlier keyframe.
  ({GameState state, int index}) _stateAtIndex(int index) {
    final target = index.clamp(0, _envelopes.length - 1);

    // Find nearest keyframe at or before target.
    var kfIndex = 0;
    for (final k in _keyframes.keys) {
      if (k <= target && k > kfIndex) kfIndex = k;
    }

    final notifier = GameStateNotifier()..replaying = true;
    final seed = _keyframes[kfIndex];
    var startFrom = 0;
    if (seed != null) {
      notifier.seedReplayState(seed);
      // Keyframe at kfIndex already includes envelope kfIndex.
      startFrom = kfIndex + 1;
    }
    for (var i = startFrom; i <= target; i++) {
      notifier.handleEnvelope(_envelopes[i]);
    }
    final result = notifier.state;
    return (state: result, index: target);
  }

  /// Returns the envelope index whose timestamp is closest to [position].
  int _indexForPosition(Duration position) {
    if (_t0 == null || _envelopes.isEmpty) return 0;
    final targetTime = _t0!.add(position);
    // Linear scan is fine: positions move monotonically and lists are bounded.
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

  /// Seeks to [progress] in 0..1 and rebuilds the snapshot.
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

  /// Starts or resumes playback.
  void play() {
    if (state.isPlaying || _envelopes.isEmpty) return;
    if (state.position >= _total) {
      // At the end: restart from the beginning.
      _seekTo(Duration.zero);
    }
    state = state.copyWith(isPlaying: true);
    _ticker = Timer.periodic(_tickInterval, (_) => _onTick());
  }

  /// Pauses playback.
  void pause() {
    _ticker?.cancel();
    _ticker = null;
    if (state.isPlaying) state = state.copyWith(isPlaying: false);
  }

  /// Toggles play/pause.
  void togglePlay() => state.isPlaying ? pause() : play();

  /// Sets the playback [speed] multiplier.
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

/// Provides a [ReplayController] for a given file path.
///
/// `autoDispose` so the controller (and its keyframe cache) is released when
/// the replay screen is popped. `family` keyed by file path so each record
/// gets its own isolated controller.
final replayControllerProvider = StateNotifierProvider.autoDispose
    .family<ReplayController, ReplayState, String>((ref, filePath) {
  final importer = ref.watch(jsonImporterProvider);
  return ReplayController(filePath: filePath, importer: importer);
});
