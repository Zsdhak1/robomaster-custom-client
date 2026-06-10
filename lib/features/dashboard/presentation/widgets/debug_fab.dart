/// Floating action button that toggles the debug panel overlay.
library;

import 'package:flutter/material.dart';

/// FAB that toggles debug panel visibility.
class DebugFab extends StatelessWidget {
  /// Creates a [DebugFab].
  const DebugFab({
    required this.isOpen,
    required this.onToggle,
    super.key,
  });

  /// Whether the panel is currently open.
  final bool isOpen;

  /// Called when the FAB is pressed.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onToggle,
      backgroundColor: Colors.grey.shade800,
      mini: true,
      child: Icon(
        isOpen ? Icons.bug_report : Icons.bug_report_outlined,
        color: Colors.white,
      ),
    );
  }
}
