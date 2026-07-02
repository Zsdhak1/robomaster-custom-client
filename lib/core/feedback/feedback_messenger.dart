/// Unified user feedback via SnackBars.
///
/// Centralizes the SnackBar styling so every page reports success, errors and
/// info with consistent colors and behavior, instead of each call site building
/// its own ad-hoc `SnackBar`. Use the [BuildContext] extension methods.
library;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Severity of a feedback message, controlling its accent color and icon.
enum FeedbackLevel {
  /// Neutral information.
  info,

  /// Successful operation.
  success,

  /// Recoverable error / failure.
  error,
}

/// SnackBar feedback helpers on [BuildContext].
///
/// When calling these *after* an `await`, guard with `if (!context.mounted)
/// return;` first — using a [BuildContext] across an async gap is unsafe. The
/// helpers themselves no-op when no [ScaffoldMessenger] is in scope, but that
/// does not cover a context whose element has been unmounted.
extension FeedbackMessenger on BuildContext {
  /// Shows an error SnackBar with [message].
  void showErrorSnack(String message) =>
      _showSnack(message, FeedbackLevel.error);

  /// Shows a success SnackBar with [message].
  void showSuccessSnack(String message) =>
      _showSnack(message, FeedbackLevel.success);

  /// Shows a neutral info SnackBar with [message].
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
