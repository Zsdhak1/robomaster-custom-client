/// In-app status panel for the external-ffplay verification backend.
///
/// ffplay renders in its OWN OS window (Windows verification aid), so this panel
/// carries no video — it just drives the [CustomFfplayLauncher] lifecycle and
/// reports state. Connecting ffplay straight to the loopback TCP bridge proves
/// whether the byte stream is decodable independently of the in-app players.
library;

import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../features/settings/logic/settings_providers.dart';
import '../../logic/custom_ffplay_launcher.dart';

/// Launches ffplay against [streamUrl] and shows its status.
class CustomFfplayPanel extends StatefulWidget {
  /// Creates a panel that points ffplay at [streamUrl].
  const CustomFfplayPanel({
    required this.streamUrl,
    required this.tsWrap,
    required this.codec,
    super.key,
  });

  /// The `tcp://127.0.0.1:<port>` bridge URL ffplay should open.
  final String streamUrl;

  /// When true the bridge serves MPEG-TS, so ffplay is told `-f mpegts`.
  final bool tsWrap;

  /// The video codec: H.264 → `-f h264`, H.265 → `-f hevc`.
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
