/// 事件时间线面板，显示带相对时间的已解码比赛事件。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../logic/event_decoder.dart';
import '../../logic/game_state.dart';
import '../../logic/stream_providers.dart';

/// 右侧面板显示最近比赛事件，最新事件在最前。
class EventTimelinePanel extends ConsumerWidget {
  /// 创建 [EventTimelinePanel]。
  const EventTimelinePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: const Cubic(0.2, 0, 0, 1), // MD3 强调减速曲线
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 20),
            child: child,
          ),
        );
      },
      child: Padding(
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
          style: context.textTheme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: context.textTheme.bodySmall!.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}

/// 可复用的事件时间线视图。
///
/// 与 [gameStateProvider] 解耦，因此既能渲染导入或预览事件，也能渲染实时事件。
class EventTimelineView extends StatelessWidget {
  /// 创建 [EventTimelineView]。
  const EventTimelineView({required this.events, this.matchStart, super.key});

  /// 要显示的事件，最新在前。
  final List<TimedEvent> events;

  /// 用于计算相对时间戳的比赛开始时间。
  final DateTime? matchStart;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Text(
          '暂无事件',
          style: context.textTheme.bodyMedium!.copyWith(
            color: rmTextSecondary(context),
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final timed = events[index];
        return _EventTile(timed: timed, matchStart: matchStart);
      },
    );
  }
}

/// 时间线中的单个已解码事件条目。
class _EventTile extends StatelessWidget {
  /// 创建 [_EventTile]。
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
                      style: context.textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: decoded.color,
                      ),
                    ),
                    context.sizedBox(w: 6),
                    Text(
                      timeLabel,
                      style: context.textTheme.labelSmall!.copyWith(
                        color: rmTextSecondary(context),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                context.sizedBox(h: 2),
                Text(
                  decoded.detail,
                  style: context.textTheme.bodySmall!.copyWith(
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

  /// 将事件时间格式化为相对于比赛开始的 `mm:ss`。
  ///
  /// 比赛开始前或没有 [matchStart] 时显示墙钟时间 `HH:mm:ss`，
  /// 让事件仍然可排序、可识别。
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
