/// 英雄部署模式自动进入自定义图传的倒计时控制器。
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/domain/combat_notification_rules.dart';
import 'notification_runtime_strings.dart';

/// 部署跳转当前阶段。
enum DeploymentNavigationPhase { idle, counting, preparing, failed }

/// 部署自动跳转的可渲染状态。
class DeploymentNavigationState {
  /// 创建部署跳转状态。
  const DeploymentNavigationState({
    this.phase = DeploymentNavigationPhase.idle,
    this.remainingSeconds = 0,
    this.config = const DeploymentNavigationConfig(),
    this.errorMessage,
  });

  final DeploymentNavigationPhase phase;
  final int remainingSeconds;
  final DeploymentNavigationConfig config;
  final String? errorMessage;

  /// 当前是否应显示部署提示。
  bool get isVisible => phase != DeploymentNavigationPhase.idle;

  /// 创建更新后的状态。
  DeploymentNavigationState copyWith({
    DeploymentNavigationPhase? phase,
    int? remainingSeconds,
    DeploymentNavigationConfig? config,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DeploymentNavigationState(
      phase: phase ?? this.phase,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      config: config ?? this.config,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

/// 管理倒计时、预启动、取消和最终导航。
class DeploymentNavigationController
    extends StateNotifier<DeploymentNavigationState> {
  /// 创建控制器。
  DeploymentNavigationController(
    this._prepareVideo,
    this._stopPreparedVideo,
    this._navigateToCustomVideo, [
    this._tickInterval = const Duration(seconds: 1),
  ]) : super(const DeploymentNavigationState());

  final Future<bool> Function() _prepareVideo;
  final void Function() _stopPreparedVideo;
  final void Function() _navigateToCustomVideo;
  final Duration _tickInterval;
  Timer? _timer;
  Future<bool>? _prepareFuture;
  bool _startedVideo = false;
  bool _suppressedForMatch = false;
  int _generation = 0;

  /// 启动一次部署倒计时；已在运行或本场抑制时返回 false。
  bool start(DeploymentNavigationConfig config) {
    if (!config.enabled || state.isVisible || _suppressedForMatch) return false;
    _generation++;
    state = DeploymentNavigationState(
      phase: DeploymentNavigationPhase.counting,
      remainingSeconds: config.countdownSeconds,
      config: config,
    );
    if (config.prestartVideo) unawaited(_prepare());
    if (config.countdownSeconds == 0) {
      unawaited(enterNow());
    } else {
      _timer = Timer.periodic(_tickInterval, (_) => _tick());
    }
    return true;
  }

  /// 用户立即进入，或倒计时归零时执行。
  Future<void> enterNow() async {
    try {
      if (!state.isVisible) return;
      _timer?.cancel();
      _timer = null;
      final generation = _generation;
      final config = state.config;
      state = state.copyWith(
        phase: DeploymentNavigationPhase.preparing,
        clearError: true,
      );
      if (config.prestartVideo) {
        final ready = await _prepare();
        if (generation != _generation || !state.isVisible) return;
        if (!ready && config.stayWhenVideoStartFails) {
          state = state.copyWith(
            phase: DeploymentNavigationPhase.failed,
            errorMessage: deploymentVideoStartFailed,
          );
          return;
        }
      }
      _navigateToCustomVideo();
      _finish();
    } on Object {
      state = state.copyWith(
        phase: DeploymentNavigationPhase.failed,
        errorMessage: deploymentNavigationFailed,
      );
    }
  }

  /// 取消当前倒计时。
  void cancel() {
    if (!state.isVisible || !state.config.allowCancel) return;
    if (state.config.cancelForCurrentMatch) _suppressedForMatch = true;
    if (_startedVideo) _stopPreparedVideo();
    _finish();
  }

  /// 新比赛开始前清理本场抑制状态和遗留倒计时。
  void resetMatch() {
    _suppressedForMatch = false;
    if (state.isVisible) cancelIgnoringPolicy();
  }

  /// 忽略用户取消策略，供比赛重置和资源释放使用。
  void cancelIgnoringPolicy() {
    if (_startedVideo) _stopPreparedVideo();
    _finish();
  }

  void _tick() {
    if (state.phase != DeploymentNavigationPhase.counting) return;
    final next = state.remainingSeconds - 1;
    if (next <= 0) {
      state = state.copyWith(remainingSeconds: 0);
      unawaited(enterNow());
      return;
    }
    state = state.copyWith(remainingSeconds: next);
  }

  Future<bool> _prepare() {
    final existing = _prepareFuture;
    if (existing != null) return existing;
    final future = _runPrepare(_generation);
    _prepareFuture = future;
    return future;
  }

  Future<bool> _runPrepare(int generation) async {
    try {
      final started = await _prepareVideo();
      if (generation != _generation) {
        if (started) _stopPreparedVideo();
        return false;
      }
      _startedVideo = started;
      return true;
    } on Object {
      return false;
    } finally {
      _prepareFuture = null;
    }
  }

  void _finish() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _prepareFuture = null;
    _startedVideo = false;
    state = const DeploymentNavigationState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
