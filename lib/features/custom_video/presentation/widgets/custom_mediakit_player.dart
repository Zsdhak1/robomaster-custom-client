/// 自定义图传链路（0x0310）使用的 media_kit（libmpv）解码器。
///
/// 与官方链路的 media_kit 播放器保持一致，但会强制使用原始编解码器解复用器
/// （`demuxer-lavf-format=h264` 或 `=hevc`）。注意：media_kit 捆绑的 libmpv
/// 并不保证每个平台都带原始 H.264 lavf 解复用器；缺失时会在覆盖层显示 libmpv
/// 的真实错误，便于和 fvp 做显式 A/B 对比，而不是静默白屏。
/// MPEG-TS 封装（`tsWrap`）用于绕过两种编解码器在该限制上的差异。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/widgets/video_overlay_controls.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_video_providers.dart';
import 'crosshair_painter.dart';

/// 使用 libmpv 解码自定义原始视频 TCP 桥接，并叠加准星。
class CustomMediaKitPlayer extends ConsumerStatefulWidget {
  /// 创建从 [url] 读取的 [CustomMediaKitPlayer]。
  const CustomMediaKitPlayer({
    required this.url,
    required this.tsWrap,
    required this.codec,
    super.key,
  });

  /// `tcp://127.0.0.1:<端口>` 形式的桥接 URL。
  final String url;

  /// 为 true 时桥接输出 MPEG-TS，libmpv 可直接解复用；此时强制解复用器为 `mpegts`。
  final bool tsWrap;

  /// 视频编解码器：H.264 对应 `h264`，H.265 对应 `hevc`。
  final CustomVideoCodec codec;

  @override
  ConsumerState<CustomMediaKitPlayer> createState() =>
      _CustomMediaKitPlayerState();
}

class _CustomMediaKitPlayerState extends ConsumerState<CustomMediaKitPlayer> {
  late final Player _player;
  late final VideoController _controller;
  final List<StreamSubscription<Object?>> _subs = [];
  String? _error;
  int _attempt = 0;
  Offset? _crosshairCenter;

  /// 自动重连看门狗；完整原因见 [_FvpPlayerState]。
  ///
  /// 播放器会在关键帧闸门刚打开时立即创建，可能抢跑刚启动的流。
  /// 如果首次尝试时可探测数据还不够，旧行为会让用户停在错误横幅直到手动重连。
  /// 该看门狗会进行有界自动重试，直到回放开始。
  Timer? _connectWatchdog;

  /// libmpv 是否已报告实际播放中，这是成功信号。
  bool _playing = false;

  /// 自上次成功连接以来已消耗的自动重试次数。
  int _autoRetries = 0;

  /// 等待手动重连前允许的最大自动重连次数。
  static const int _maxAutoRetries = 8;

  /// 单次连接尝试在未开始播放前可等待的最长时间。
  static const Duration _connectTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _controller = VideoController(_player);
    _attachDiagnostics();
    _configureAndOpen();
  }

  /// 当连接尝试超时仍未开始播放时触发；通过有界重试修复首次尝试抢跑流启动的问题。
  void _onConnectTimeout() {
    if (!mounted || _playing) return;
    if (_autoRetries >= _maxAutoRetries) return;
    _autoRetries++;
    _reconnect(auto: true);
  }

  /// 将 libmpv 的实时状态（错误、播放中、缓冲、分辨率）同步到
  /// [customVideoDecoderInfoProvider]，供调试面板显示。
  void _attachDiagnostics() {
    final info = ref.read(customVideoDecoderInfoProvider.notifier);
    int? width;
    int? height;
    _subs
      ..add(
        _player.stream.error.listen((msg) {
          debugPrint('[custom media_kit error] $msg');
          info.setError(msg);
          if (mounted) setState(() => _error = msg);
        }),
      )
      ..add(
        _player.stream.playing.listen((p) {
          info.setPlaying(playing: p);
          if (p) {
            // 回放已启动，取消看门狗并清空重试预算。
            _playing = true;
            _connectWatchdog?.cancel();
            _connectWatchdog = null;
            _autoRetries = 0;
          }
        }),
      )
      ..add(
        _player.stream.buffering.listen((b) {
          info.setBuffering(buffering: b);
        }),
      )
      ..add(
        _player.stream.width.listen((w) {
          width = w;
          info.setResolution(width, height);
        }),
      )
      ..add(
        _player.stream.height.listen((h) {
          height = h;
          info.setResolution(width, height);
        }),
      );
  }

  Future<void> _configureAndOpen() async {
    _attempt++;
    _playing = false;
    if (mounted) setState(() => _error = null);
    // 设置看门狗：如果回放未按时开始，则自动重试。
    _connectWatchdog?.cancel();
    _connectWatchdog = Timer(_connectTimeout, _onConnectTimeout);
    ref
        .read(customVideoDecoderInfoProvider.notifier)
        .beginSession('media_kit', attempt: _attempt);
    final platform = _player.platform;
    if (platform is NativePlayer) {
      try {
        // libmpv 默认拒绝播放列表里的 tcp:// 条目，必须先启用该选项。
        await platform.setProperty('load-unsafe-playlists', 'yes');
        // 强制解复用器并跳过探测。原始模式下 libmpv 可能缺少原始 H.264 解复用器；
        // HEVC 原始解复用器通常可用。TS 模式强制 `mpegts`，这是 libmpv 内置格式，
        // 也是 media_kit 后端启用 MPEG-TS 封装的核心目的。
        await platform.setProperty(
          'demuxer-lavf-format',
          widget.tsWrap
              ? 'mpegts'
              : widget.codec == CustomVideoCodec.h265
              ? 'hevc'
              : 'h264',
        );
        // 低延迟解复用参数。注意：demuxer-lavf-o 会替换整个选项字典，
        // 所有参数必须放在同一个逗号分隔值里；第二次 setProperty 会覆盖第一次。
        //
        // 两种模式的关键探测预算不同：
        // - TS 模式：MPEG-TS 是容器，lavf 必须读取 PAT/PMT，并探测到视频 elementary stream
        //   （PID 0x100）。探测预算过小会打开容器却找不到视频轨，导致黑屏。因此给出真实预算
        //   （约 1 MB / 数百毫秒）。
        // - 原始模式：流是单个 ES，没有容器需要解复用，极小探测预算更安全且能降低延迟；
        //   保留 framerate=60，让原始 ES 获得时间线。
        // +nobuffer / +low_delay 是低延迟缓冲参数，对探测无害，两种模式都保留。
        await platform.setProperty(
          'demuxer-lavf-o',
          widget.tsWrap
              ? 'fflags=+nobuffer,flags=+low_delay,'
                  'probesize=1000000,analyzeduration=500000'
              : 'framerate=60,fflags=+nobuffer,flags=+low_delay,'
                  'probesize=32,analyzeduration=0',
        );
        // 实时抗重新缓冲调优，等价于 mpv 自身 low-latency profile 的关键开关。
        // 真实源帧率不稳定；正确做法是帧一到就渲染，不在短暂缓存耗尽时进入暂停缓冲状态。
        // 否则每次短暂断流都会变成约 1 秒的冻结/恢复循环。
        await platform.setProperty('cache', 'yes'); // MPEG-TS 锁定需要缓存。
        await platform.setProperty('cache-secs', '0'); // 不做前向填充。
        await platform.setProperty('demuxer-readahead-secs', '0');
        // 主修复：继续渲染，而不是暂停等待重新缓冲。
        await platform.setProperty('cache-pause', 'no');
        await platform.setProperty('cache-pause-initial', 'no'); // 启动时不阻塞。
        await platform.setProperty('framedrop', 'vo'); // 丢弃过期帧，避免累积延迟。
        await platform.setProperty('video-sync', 'audio'); // 轻量同步，不引入重采样缓冲。
        await platform.setProperty('interpolation', 'no');
        await platform.setProperty('video-latency-hacks', 'yes');
        await platform.setProperty('stream-buffer-size', '4k');
      } on Object catch (e) {
        debugPrint('[custom media_kit] property warning: $e');
      }
    }
    try {
      await _player.open(Media(widget.url));
    } on Object catch (e) {
      ref.read(customVideoDecoderInfoProvider.notifier).setError('打开失败: $e');
      if (mounted) setState(() => _error = '打开失败: $e');
    }
  }

  /// 关闭并重新打开回放。[auto] 表示看门狗触发的重试；
  /// 手动重连（auto=false）会重置自动重试预算。
  Future<void> _reconnect({bool auto = false}) async {
    if (!auto) _autoRetries = 0;
    _connectWatchdog?.cancel();
    _connectWatchdog = null;
    try {
      await _player.stop();
    } on Object {
      // 播放器从未完整打开时 stop 可能抛错；这里可安全忽略。
    }
    await _configureAndOpen();
  }

  @override
  void didUpdateWidget(covariant CustomMediaKitPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _reconnect();
    }
  }

  @override
  void dispose() {
    _connectWatchdog?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTapDown: (details) {
                setState(() {
                  _crosshairCenter = details.localPosition;
                });
              },
              child: CustomPaint(
                foregroundPainter: CrosshairPainter(
                  aimCenter: _crosshairCenter,
                ),
                child: Video(controller: _controller),
              ),
            ),
          ),
          if (_error != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: _ErrorBanner(message: _error!, onReconnect: _reconnect),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: VideoReconnectChip(
              backendLabel: 'media_kit',
              attempt: _attempt,
              onReconnect: _reconnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onReconnect});

  final String message;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall!.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
            TextButton(onPressed: onReconnect, child: const Text('重连')),
          ],
        ),
      ),
    );
  }
}
