/// Shared Scaffold shell for the two video-stream pages.
///
/// Keeps AppBar, MQTT badge placement and stream FAB behaviour visually
/// identical while each page still owns its stream controller and actions.
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';
import 'mqtt_login_badge.dart';
import 'stream_connection_fab.dart';

/// Common page shell for UDP and custom video streams.
class VideoStreamPageScaffold extends StatelessWidget {
  /// Creates a shared video-stream page scaffold.
  const VideoStreamPageScaffold({
    required this.title,
    required this.body,
    required this.isRunning,
    required this.onToggle,
    this.appBarActions = const [],
    this.secondaryActions = const [],
    super.key,
  });

  /// AppBar title.
  final String title;

  /// Full-screen page body, usually a video two-pane layout.
  final Widget body;

  /// Whether the backing stream is currently running.
  final bool isRunning;

  /// Starts or stops the backing stream.
  final Future<void> Function() onToggle;

  /// Optional compact controls in the AppBar.
  final List<Widget> appBarActions;

  /// Optional secondary FAB actions.
  final List<StreamFabAction> secondaryActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: appBarActions),
      body: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: context.sp(12),
            right: context.sp(12),
            child: const MqttLoginBadge(),
          ),
        ],
      ),
      floatingActionButton: StreamConnectionFab(
        isRunning: isRunning,
        onToggle: onToggle,
        secondaryActions: secondaryActions,
      ),
    );
  }
}
