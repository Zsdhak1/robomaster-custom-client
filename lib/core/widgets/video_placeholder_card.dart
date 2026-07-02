/// Shared empty/loading/error cards for video-stream pages.
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';

/// Placeholder card shown before a video stream is ready.
class VideoPlaceholderCard extends StatelessWidget {
  /// Creates an empty or waiting placeholder.
  const VideoPlaceholderCard({
    required this.title,
    required this.subtitle,
    this.icon = Icons.videocam_off,
    this.loading = false,
    super.key,
  });

  /// Main message.
  final String title;

  /// Secondary explanatory message.
  final String subtitle;

  /// Icon used when [loading] is false.
  final IconData icon;

  /// Whether to show a progress indicator instead of [icon].
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: Center(
          child: Padding(
            padding: context.insetAll(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  SizedBox(
                    width: context.sp(48),
                    height: context.sp(48),
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Icon(
                    icon,
                    size: context.iconSize(64),
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.38),
                  ),
                context.sizedBox(h: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                context.sizedBox(h: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error card shown when a decoder fails to initialise or render.
class VideoErrorCard extends StatelessWidget {
  /// Creates a shared video error card.
  const VideoErrorCard({
    required this.message,
    this.hint,
    this.onRetry,
    this.retryLabel = '重连',
    super.key,
  });

  /// Error message to surface.
  final String message;

  /// Optional human-readable recovery hint.
  final String? hint;

  /// Optional retry callback.
  final Future<void> Function()? onRetry;

  /// Retry button label.
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: scheme.surfaceContainerLowest,
        child: Center(
          child: Padding(
            padding: context.insetAll(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: context.iconSize(48),
                  color: scheme.error,
                ),
                context.sizedBox(h: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium!.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (hint != null) ...[
                  context.sizedBox(h: 8),
                  Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  context.sizedBox(h: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(retryLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
