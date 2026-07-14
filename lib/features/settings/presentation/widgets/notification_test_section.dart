/// “通知与规则”设置页中的手动通知测试区段。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/feedback_messenger.dart';
import '../../domain/notification_preferences.dart';
import '../../logic/notification_test_provider.dart';
import '../notification_settings_strings.dart';
import 'notification_settings_components.dart';

/// 提供 INFO、CRITICAL 与各事件类型的手动测试入口。
class NotificationTestSection extends ConsumerWidget {
  /// 创建通知测试区段。
  const NotificationTestSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationSettingsSectionCard(
      title: notificationTestTitle,
      subtitle: notificationTestSubtitle,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _severityButtons(context, ref),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                notificationTestEventTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _eventChips(context, ref),
            ],
          ),
        ),
      ],
    );
  }

  Widget _severityButtons(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => _dispatch(
            context,
            ref,
            NotificationEventType.connectionQualityChanged,
            severity: NotificationSeverity.info,
          ),
          icon: const Icon(Icons.info_outline_rounded),
          label: const Text(notificationTestInfo),
        ),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
          ),
          onPressed: () => _dispatch(
            context,
            ref,
            NotificationEventType.connectionQualityChanged,
            severity: NotificationSeverity.critical,
          ),
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text(notificationTestCritical),
        ),
      ],
    );
  }

  Widget _eventChips(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in NotificationEventType.values)
          ActionChip(
            avatar: const Icon(Icons.notifications_active_outlined, size: 18),
            label: Text(notificationEventLabel(type)),
            onPressed: () => _dispatch(context, ref, type),
          ),
      ],
    );
  }

  void _dispatch(
    BuildContext context,
    WidgetRef ref,
    NotificationEventType type, {
    NotificationSeverity? severity,
  }) {
    final request = NotificationTestRequest(
      type: type,
      headline: notificationTestHeadline(type, severity),
      detail: notificationTestDetail,
      severityOverride: severity,
    );
    final accepted = ref.read(notificationTestDispatcherProvider)(request);
    if (!accepted && context.mounted) {
      context.showErrorSnack(notificationTestUnavailable);
    }
  }
}
