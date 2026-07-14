/// 监听更新检查结果，并在检测到新版本时显示一次更新对话框的组件。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/github_release.dart';
import '../logic/update_providers.dart';
import 'update_dialog.dart';

/// 包装 [child]，并在应用启动时按需显示更新对话框。
class UpdateCheckerListener extends ConsumerStatefulWidget {
  /// 创建 [UpdateCheckerListener]。
  const UpdateCheckerListener({required this.child, super.key});

  /// 该监听器下方的组件，通常是 [MaterialApp]。
  final Widget child;

  @override
  ConsumerState<UpdateCheckerListener> createState() =>
      _UpdateCheckerListenerState();
}

class _UpdateCheckerListenerState extends ConsumerState<UpdateCheckerListener> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _attachListener();
  }

  void _attachListener() {
    final autoCheck = ref.read(autoCheckEnabledProvider);
    if (!autoCheck) return;

    ref.listenManual(
      updateCheckResultProvider,
      (previous, next) => _onResultChanged(next),
    );
  }

  void _onResultChanged(AsyncValue<UpdateCheckResult> next) {
    if (_dialogShown) return;
    next.whenOrNull(
      data: (result) {
        if (!result.hasUpdate || result.release == null) return;
        _dialogShown = true;
        _showDialog(result);
      },
      error: (err, _) {
        // 启动检查不应打扰用户；错误反馈交给关于页的手动检查入口。
      },
    );
  }

  void _showDialog(UpdateCheckResult result) {
    final release = result.release!;
    final shown = _UpdateDialogScope.maybeOf(context)?.shownTags ?? {};
    if (shown.contains(release.tagName)) return;
    shown.add(release.tagName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(
          release: release,
          currentVersion: result.currentVersion,
          latestVersion: result.latestVersion,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// 跟踪当前会话中已经显示过的更新对话框 tag，避免重复弹出。
class _UpdateDialogScope extends InheritedWidget {
  const _UpdateDialogScope({required this.shownTags, required super.child});

  final Set<String> shownTags;

  static _UpdateDialogScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_UpdateDialogScope>();
  }

  @override
  bool updateShouldNotify(_UpdateDialogScope old) =>
      shownTags.length != old.shownTags.length;
}

/// 为 [UpdateCheckerListener] 提供会话范围内的已显示 tag 集合。
class UpdateCheckerHost extends StatelessWidget {
  /// 创建 [UpdateCheckerHost]。
  const UpdateCheckerHost({required this.child, super.key});

  /// 该主机下方的组件。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _UpdateDialogScope(
      shownTags: const <String>{},
      child: child,
    );
  }
}
