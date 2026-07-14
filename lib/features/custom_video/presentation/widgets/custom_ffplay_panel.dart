/// 外部 ffplay 验证后端使用的应用内状态面板。
///
/// ffplay 会在自己的系统窗口中渲染（主要用于 Windows 验证），所以该面板不承载视频；
/// 它只驱动 [CustomFfplayLauncher] 生命周期并报告状态。让 ffplay 直接连接回环 TCP 桥接，
/// 可以独立于应用内播放器验证字节流是否可解码。
library;

import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_ffplay_launcher.dart';

/// 根据 [streamUrl] 启动 ffplay，并显示运行状态。
class CustomFfplayPanel extends StatefulWidget {
  /// 创建指向 [streamUrl] 的 ffplay 面板。
  const CustomFfplayPanel({
    required this.streamUrl,
    required this.tsWrap,
    required this.codec,
    super.key,
  });

  /// ffplay 应打开的 `tcp://127.0.0.1:<端口>` 桥接 URL。
  final String streamUrl;

  /// 为 true 时桥接输出 MPEG-TS，因此 ffplay 使用 `-f mpegts`。
  final bool tsWrap;

  /// 视频编解码器：H.264 对应 `-f h264`，H.265 对应 `-f hevc`。
  final CustomVideoCodec codec;

  @override
  State<CustomFfplayPanel> createState() => _CustomFfplayPanelState();
}

class _CustomFfplayPanelState extends State<CustomFfplayPanel> {
  final CustomFfplayLauncher _launcher = CustomFfplayLauncher();

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _launcher.start(
      widget.streamUrl,
      tsWrap: widget.tsWrap,
      codec: widget.codec,
    );
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CustomFfplayPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl ||
        oldWidget.tsWrap != widget.tsWrap ||
        oldWidget.codec != widget.codec) {
      _launcher.stop();
      _start();
    }
  }

  @override
  void dispose() {
    _launcher.dispose();
    super.dispose();
  }

  Future<void> _restart() async {
    _launcher.stop();
    await _start();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.open_in_new, size: 56, color: Colors.white38),
                const SizedBox(height: 16),
                Text(
                  'ffplay 在独立窗口播放',
                  style: context.textTheme.titleMedium!.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _launcher.isRunning
                      ? 'ffplay 已启动并连接 TCP 桥。\n若 ffplay 窗口出图，说明码流正确，问题在 app 内解码器。'
                      : 'ffplay 未运行',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall!.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '命令: ${_launcher.resolvedPath ?? "ffplay"} '
                  '-f ${widget.tsWrap ? "mpegts" : widget.codec == CustomVideoCodec.h265 ? "hevc" : "h264"} -i ${widget.streamUrl}',
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelSmall!.copyWith(
                    color: Colors.white30,
                  ),
                ),
                if (_launcher.lastError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _launcher.lastError!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.labelSmall!.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重启 ffplay'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
