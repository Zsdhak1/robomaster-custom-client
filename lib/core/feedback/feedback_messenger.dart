/// 通过 SnackBar 统一展示用户反馈。
///
/// 这里集中管理 SnackBar 样式，让各页面的成功、错误和提示反馈拥有一致颜色和行为，
/// 避免每个调用点临时构建自己的 `SnackBar`。使用 [BuildContext] 扩展方法调用。
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 反馈消息级别，用于控制强调色和图标。
enum FeedbackLevel {
  /// 普通信息。
  info,

  /// 操作成功。
  success,

  /// 可恢复错误或失败。
  error,
}

/// [BuildContext] 上的 SnackBar 反馈辅助函数。
///
/// 如果在 `await` 之后调用这些方法，请先用 `if (!context.mounted) return;` 保护。
/// 跨异步间隔使用 [BuildContext] 不安全。辅助函数在找不到 [ScaffoldMessenger] 时会
/// 空操作，但无法保护已经卸载的 context。
extension FeedbackMessenger on BuildContext {
  /// 显示携带 [message] 的错误 SnackBar。
  void showErrorSnack(String message) =>
      _showSnack(message, FeedbackLevel.error);

  /// 显示携带 [message] 的成功 SnackBar。
  void showSuccessSnack(String message) =>
      _showSnack(message, FeedbackLevel.success);

  /// 显示携带 [message] 的普通信息 SnackBar。
  void showInfoSnack(String message) =>
      _showSnack(message, FeedbackLevel.info);

  void _showSnack(String message, FeedbackLevel level) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    final scheme = Theme.of(this).colorScheme;
    final (background, icon) = switch (level) {
      FeedbackLevel.info => (scheme.inverseSurface, Icons.info_outline),
      FeedbackLevel.success => (rmSuccessColor, Icons.check_circle_outline),
      FeedbackLevel.error => (scheme.error, Icons.error_outline),
    };
    final foreground = switch (level) {
      FeedbackLevel.info => scheme.onInverseSurface,
      FeedbackLevel.success => Colors.white,
      FeedbackLevel.error => scheme.onError,
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ],
          ),
        ),
      );
  }
}
