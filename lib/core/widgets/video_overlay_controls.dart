/// Shared overlay controls for video players.
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';

/// Translucent rounded overlay container used on top of video players.
class VideoOverlayPill extends StatelessWidget {
  /// Creates a translucent overlay pill.
  const VideoOverlayPill({required this.child, super.key});

  /// Pill content.
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

/// Compact reconnect chip shared by video decoders.
class VideoReconnectChip extends StatelessWidget {
  /// Creates a reconnect chip.
  const VideoReconnectChip({
    required this.onReconnect,
    this.attempt,
    this.backendLabel,
    this.showAttempt = true,
    super.key,
  });

  /// Optional backend label, such as `media_kit`.
  final String? backendLabel;

  /// Optional reconnect/open attempt number.
  final int? attempt;

  /// Whether to include [attempt] in the label.
  final bool showAttempt;

  /// Reconnect callback.
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
