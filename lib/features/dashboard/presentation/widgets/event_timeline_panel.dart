/// Event timeline panel showing decoded game events with relative times.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final events = gameState.eventList;
    final matchStart = gameState.matchStartTime;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: rmCardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, events.length),
              const Divider(),
              Expanded(child: _buildEventList(events, matchStart)),
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
          size: 20,
        ),
        const SizedBox(width: 8),
        const Text(
          '事件时间轴',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildEventList(List<TimedEvent> events, DateTime? matchStart) {
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(decoded.icon, size: 18, color: decoded.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      decoded.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: decoded.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  decoded.detail,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
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
