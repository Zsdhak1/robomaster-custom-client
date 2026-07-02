/// Shared two-pane layout for video feed pages.
///
/// Wide windows use the canonical left video / right status panel split. Compact
/// windows stack the status panel below the video so the feed is not squeezed.
library;

import 'package:flutter/material.dart';

import '../responsive/responsive_ext.dart';

/// Responsive layout for a video player and its side panel.
class VideoTwoPaneLayout extends StatelessWidget {
  /// Creates a shared video two-pane layout.
  const VideoTwoPaneLayout({
    required this.player,
    required this.sidePanel,
    this.compactBreakpoint = 900,
    super.key,
  });

  /// Main video/player area.
  final Widget player;

  /// Status/debug/health side panel.
  final Widget sidePanel;

  /// Width below which the panes are stacked vertically.
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetAll(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < compactBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: player),
                context.sizedBox(h: 12),
                Expanded(flex: 2, child: sidePanel),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: player),
              context.sizedBox(w: 12),
              Expanded(child: sidePanel),
            ],
          );
        },
      ),
    );
  }
}
