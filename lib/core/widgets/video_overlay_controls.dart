/// 视频播放器共享覆盖层控件。
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';

/// 视频播放器顶部使用的半透明圆角覆盖层容器。
class VideoOverlayPill extends StatelessWidget {
  /// 创建半透明覆盖层胶囊。
  const VideoOverlayPill({required this.child, super.key});

  /// 胶囊内容。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(context.sp(6)),
      ),
      child: Padding(padding: context.insetSym(h: 8, v: 4), child: child),
    );
  }
}

/// 视频解码器共享的紧凑重连 chip。
class VideoReconnectChip extends StatelessWidget {
  /// 创建重连 chip。
  const VideoReconnectChip({
    required this.onReconnect,
    this.attempt,
    this.backendLabel,
    this.showAttempt = true,
    super.key,
  });

  /// 可选后端标签，例如 `media_kit`。
  final String? backendLabel;

  /// 可选重连或打开尝试次数。
  final int? attempt;

  /// 是否在标签中包含 [attempt]。
  final bool showAttempt;

  /// 重连回调。
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final label = [
      if (backendLabel != null) backendLabel,
      '重连',
      if (showAttempt && attempt != null) '(第 $attempt 次)',
    ].join(' ');

    return VideoOverlayPill(
      child: InkWell(
        onTap: onReconnect,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.refresh,
              color: Colors.white,
              size: context.iconSize(14),
            ),
            context.sizedBox(w: 4),
            Text(
              label,
              style: context.textTheme.labelSmall!.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
