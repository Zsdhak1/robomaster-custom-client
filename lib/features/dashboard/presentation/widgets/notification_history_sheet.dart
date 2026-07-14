/// 本次运行内的通知历史列表。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../logic/dashboard_notification_models.dart';
import '../../logic/notification_providers.dart';
import '../../logic/notification_runtime_strings.dart';

/// 打开通知历史底部面板。
Future<void> showNotificationHistory(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.72,
      child: NotificationHistorySheet(),
    ),
  );
}

/// 通知历史内容。
class NotificationHistorySheet extends ConsumerWidget {
  /// 创建历史面板。
  const NotificationHistorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(dashboardNotificationProvider).history;
    return Padding(
      padding: context.insetOnly(l: 16, r: 16, b: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                notificationHistoryTitle,
                style: context.textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: history.isEmpty
                    ? null
                    : ref
                          .read(dashboardNotificationProvider.notifier)
                          .clearHistory,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text(notificationHistoryClear),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: history.isEmpty
                ? const Center(child: Text(notificationHistoryEmpty))
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (_, index) =>
                        _HistoryTile(item: history[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final DashboardNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final time = item.createdAt.toLocal();
    final timeText =
        '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: item.accentColor.withValues(alpha: 0.16),
        foregroundColor: item.accentColor,
        child: Icon(item.icon),
      ),
      title: Text(item.headline),
      subtitle: Text(item.detail, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(timeText, style: context.textTheme.labelMedium),
    );
  }
}

String _two(int value) => value.toString().padLeft(2, '0');
