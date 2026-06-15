/// Widget that listens for update-check results and shows the update dialog
/// once when a new version is detected.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/github_release.dart';
import '../logic/update_providers.dart';
import 'update_dialog.dart';

/// Wraps [child] and conditionally shows the update dialog on app startup.
class UpdateCheckerListener extends ConsumerStatefulWidget {
  /// Creates an [UpdateCheckerListener].
  const UpdateCheckerListener({required this.child, super.key});

  /// The widget below this listener in the tree (usually [MaterialApp]).
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
        // Startup checks should not spam; rely on the About screen for manual
        // feedback.
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

/// Tracks which update-dialog tags have already been shown in this session
/// to prevent duplicates.
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

/// Provides the session-scoped shown-tags set for [UpdateCheckerListener].
class UpdateCheckerHost extends StatelessWidget {
  /// Creates an [UpdateCheckerHost].
  const UpdateCheckerHost({required this.child, super.key});

  /// The widget below this host in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _UpdateDialogScope(
      shownTags: const <String>{},
      child: child,
    );
  }
}
