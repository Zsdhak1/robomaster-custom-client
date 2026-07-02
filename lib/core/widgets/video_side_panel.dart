/// Shared right-side panel for the video pages.
///
/// Lays out, top to bottom:
///  1. Basic connection info ([basicInfo]) — always shown.
///  2. Debug section ([debugSection]) — only when developer mode is on.
///  3. The dashboard's enemy 血量 list — fills the remaining ~3/5 of the height.
///     It is the exact dashboard [RobotStatusList] in enemy-focus mode, only
///     scaled down to fit the narrower video-page panel; no other change.
///
/// Both the UDP 3334 line and the custom 0x0310 line use this so their side
/// panels are visually and behaviourally identical.
library;

import 'package:flutter/material.dart';

import '../../features/dashboard/presentation/widgets/robot_status_list.dart';
import '../responsive/responsive_ext.dart';
import '../state/session_providers.dart';

/// Right-hand information + health panel beside a video feed.
class VideoSidePanel extends StatelessWidget {
  /// Creates a [VideoSidePanel].
  const VideoSidePanel({
    required this.title,
    required this.basicInfo,
    required this.developerMode,
    this.debugSection,
    super.key,
  });

  /// Panel title (e.g. '视频流状态').
  final String title;

  /// Always-visible basic connection info widget.
  final Widget basicInfo;

  /// Whether developer mode is enabled (gates [debugSection] visibility).
  final bool developerMode;

  /// Full debug content, shown only when [developerMode] is true.
  final Widget? debugSection;

  @override
  Widget build(BuildContext context) {
    final showDebug = developerMode && debugSection != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top: basic info + (dev) debug inside a card.
        Expanded(
          flex: showDebug ? 2 : 1,
          child: Card(
            child: Padding(
              padding: context.insetAll(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textTheme.titleMedium!.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  context.sizedBox(h: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          basicInfo,
                          if (showDebug) ...[
                            const Divider(height: 24),
                            VideoDebugSection(child: debugSection!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Bottom ~3/5: the dashboard enemy 血量 list, scaled to fit.
        const Expanded(flex: 3, child: _ScaledEnemyHealth()),
      ],
    );
  }
}

/// Decorated debug section shared by video side panels.
class VideoDebugSection extends StatelessWidget {
  /// Creates a decorated debug section.
  const VideoDebugSection({required this.child, super.key});

  /// Debug content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: context.insetAll(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: child,
    );
  }
}

/// Shared status row for video side panels.
class VideoStatusRow extends StatelessWidget {
  /// Creates a status row with a coloured dot.
  const VideoStatusRow({
    required this.isRunning,
    required this.runningLabel,
    this.stoppedLabel = '已停止',
    super.key,
  });

  /// Whether the stream is running.
  final bool isRunning;

  /// Label shown while running.
  final String runningLabel;

  /// Label shown while stopped.
  final String stoppedLabel;

  @override
  Widget build(BuildContext context) {
    final color = isRunning
        ? Colors.green
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Container(
          width: context.rmStatusDotSize,
          height: context.rmStatusDotSize,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        context.sizedBox(w: 8),
        Text(
          isRunning ? runningLabel : stoppedLabel,
          style: context.textTheme.bodyMedium!.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Shared label/value row for video side panels.
class VideoInfoRow extends StatelessWidget {
  /// Creates an info row.
  const VideoInfoRow({required this.label, required this.value, super.key});

  /// Left label.
  final String label;

  /// Right value.
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.insetSym(v: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: context.textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashboard [RobotStatusList] in enemy-focus mode, scaled down to fit the
/// narrower side panel.
///
/// The list authors every dimension against the window size via
/// `context.scale`; on the video page it shares only ~1/3 of the width, so we
/// shrink the [MediaQuery] size reported to it. That uniformly scales fonts,
/// icons, bars and padding — a pure size adjustment that keeps all of the
/// dashboard's information (icon, label pill, health bar, value, header) intact.
class _ScaledEnemyHealth extends StatelessWidget {
  const _ScaledEnemyHealth();

  /// Fraction of the real window size reported to the embedded list so it
  /// renders at a smaller scale suited to the side panel.
  static const double _scaleFraction = 0.62;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(size: media.size * _scaleFraction),
      child: const RobotStatusList(
        modeOverride: DashboardDisplayMode.enemyFocus,
      ),
    );
  }
}
