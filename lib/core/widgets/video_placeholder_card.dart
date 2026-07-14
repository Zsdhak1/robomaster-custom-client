/// 视频流页面共用的空状态、加载和错误卡片。
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';

/// 视频流就绪前显示的占位卡片。
class VideoPlaceholderCard extends StatelessWidget {
  /// 创建空状态或等待占位。
  const VideoPlaceholderCard({
    required this.title,
    required this.subtitle,
    this.icon = Icons.videocam_off,
    this.loading = false,
    super.key,
  });

  /// 主消息。
  final String title;

  /// 次级说明消息。
  final String subtitle;

  /// [loading] 为 false 时显示的图标。
  final IconData icon;

  /// 是否显示进度指示器而不是 [icon]。
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

/// 解码器初始化或渲染失败时显示的错误卡片。
class VideoErrorCard extends StatelessWidget {
  /// 创建共享视频错误卡片。
  const VideoErrorCard({
    required this.message,
    this.hint,
    this.onRetry,
    this.retryLabel = '重连',
    super.key,
  });

  /// 要展示的错误消息。
  final String message;

  /// 可选的可读恢复提示。
  final String? hint;

  /// 可选重试回调。
  final Future<void> Function()? onRetry;

  /// 重试按钮标签。
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
