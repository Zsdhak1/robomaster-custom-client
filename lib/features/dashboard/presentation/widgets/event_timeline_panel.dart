/// Event timeline panel showing decoded game events with relative times.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/event_decoder.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

/// Right-side panel displaying recent game events, newest first.
class EventTimelinePanel extends ConsumerWidget {
  /// Creates an [EventTimelinePanel].
  const EventTimelinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);

    return Padding(
      padding: context.insetAll(12),
      child: Card(
        child: Padding(
          padding: context.insetAll(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, gameState.eventList.length),
              const Divider(),
              Expanded(
                child: EventTimelineView(
                  events: gameState.eventList,
                  matchStart: gameState.matchStartTime,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Row(
      children: [
        Icon(
          Icons.timeline,
          color: Theme.of(context).colorScheme.primary,
          size: context.iconSize(20),
        ),
        context.sizedBox(w: 8),
        Text(
          '事件时间轴',
          style: TextStyle(
            fontSize: context.fontSize(16),
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(fontSize: context.fontSize(13), color: rmTextSecondary(context)),
        ),
      ],
    );
  }
}

/// Reusable event timeline view.
///
/// Decoupled from [gameStateProvider] so it can render imported/previewed
/// events as well as live ones.
class EventTimelineView extends StatelessWidget {
  /// Creates an [EventTimelineView].
  const EventTimelineView({
    required this.events,
    this.matchStart,
    super.key,
  });

  /// Events to display, newest first.
  final List<TimedEvent> events;

  /// Match start time used for relative timestamps.
  final DateTime? matchStart;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(
        child: Text(
          '暂无事件',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final timed = events[index];
        return _EventTile(
          timed: timed,
          matchStart: matchStart,
        );
      },
    );
  }
}

/// Single decoded event entry in the timeline.
class _EventTile extends StatelessWidget {
  /// Creates an [_EventTile].
  const _EventTile({required this.timed, required this.matchStart});

  final TimedEvent timed;
  final DateTime? matchStart;

  @override
  Widget build(BuildContext context) {
    final decoded = decodeEvent(timed.event.eventId, timed.event.param);
    final timeLabel = _relativeTime();

    return Padding(
      padding: context.insetSym(v: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(decoded.icon, size: context.iconSize(18), color: decoded.color),
          context.sizedBox(w: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      decoded.title,
                      style: TextStyle(
                        fontSize: context.fontSize(13),
                        fontWeight: FontWeight.w600,
                        color: decoded.color,
                      ),
                    ),
                    context.sizedBox(w: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: context.fontSize(11),
                        color: rmTextSecondary(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                context.sizedBox(h: 2),
                Text(
                  decoded.detail,
                  style: TextStyle(
                    fontSize: context.fontSize(12),
                    color: rmTextPrimary(context).withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Formats the event time relative to match start as `mm:ss`.
  ///
  /// Before the match begins (no [matchStart]), shows wall-clock `HH:mm:ss`
  /// so events are still ordered/identifiable.
  String _relativeTime() {
    if (matchStart == null) {
      final t = timed.timestamp;
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      final s = t.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    final diff = timed.timestamp.difference(matchStart!);
    final negative = diff.isNegative;
    final total = diff.abs().inSeconds;
    final mm = (total ~/ 60).toString().padLeft(2, '0');
    final ss = (total % 60).toString().padLeft(2, '0');
    return negative ? '-$mm:$ss' : '$mm:$ss';
  }
}
