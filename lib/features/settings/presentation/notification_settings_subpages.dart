/// 通知展示、事件与比赛规则二级设置页面。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_messenger.dart';
import '../../../core/responsive/responsive_ext.dart';
import '../logic/notification_profile_provider.dart';
import 'notification_settings_strings.dart';
import 'widgets/notification_display_event_sections.dart';
import 'widgets/notification_rule_config_sections.dart';
import 'widgets/notification_test_section.dart';

/// 嵌入式二级页面的不透明主题表面，用于过渡图层回归测试。
const notificationSettingsSubpageSurfaceKey = ValueKey<String>(
  'notification-settings-subpage-surface',
);

/// 通知展示与手动测试设置。
class NotificationDisplayTestSettingsScreen extends ConsumerWidget {
  /// 创建通知展示与测试页面。
  const NotificationDisplayTestSettingsScreen({
    super.key,
    this.embedded = false,
  });

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(notificationProfileProvider).activeProfile;
    return NotificationSettingsSubpage(
      title: notificationDisplayTestPageTitle,
      embedded: embedded,
      children: [
        NotificationDisplaySection(
          config: profile.display,
          editable: !profile.isOfficial,
          onChanged: (config) => _save(
            context,
            ref
                .read(notificationProfileProvider.notifier)
                .updateDisplay(config),
          ),
        ),
        const SizedBox(height: 24),
        const NotificationTestSection(),
      ],
    );
  }
}

/// 逐类事件通知设置。
class NotificationEventSettingsScreen extends ConsumerWidget {
  /// 创建事件通知页面。
  const NotificationEventSettingsScreen({super.key, this.embedded = false});

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(notificationProfileProvider).activeProfile;
    return NotificationSettingsSubpage(
      title: notificationEventsPageTitle,
      embedded: embedded,
      children: [
        NotificationEventSection(
          profile: profile,
          editable: !profile.isOfficial,
          onChanged: (type, setting) => _save(
            context,
            ref
                .read(notificationProfileProvider.notifier)
                .updateEvent(type, setting),
          ),
        ),
      ],
    );
  }
}

/// 敌方斩杀线与复活规则设置。
class NotificationCombatRuleSettingsScreen extends ConsumerWidget {
  /// 创建斩杀线与复活页面。
  const NotificationCombatRuleSettingsScreen({
    super.key,
    this.embedded = false,
  });

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(notificationProfileProvider).activeProfile;
    final notifier = ref.read(notificationProfileProvider.notifier);
    return NotificationSettingsSubpage(
      title: notificationCombatRulesPageTitle,
      embedded: embedded,
      children: [
        KillLineSettingsSection(
          config: profile.killLine,
          editable: !profile.isOfficial,
          onChanged: (config) =>
              _save(context, notifier.updateKillLine(config)),
        ),
        const SizedBox(height: 24),
        RespawnSettingsSection(
          config: profile.respawn,
          editable: !profile.isOfficial,
          onChanged: (config) => _save(context, notifier.updateRespawn(config)),
        ),
      ],
    );
  }
}

/// 英雄部署自动跳转设置。
class NotificationDeploymentSettingsScreen extends ConsumerWidget {
  /// 创建英雄部署跳转页面。
  const NotificationDeploymentSettingsScreen({
    super.key,
    this.embedded = false,
  });

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(notificationProfileProvider).activeProfile;
    return NotificationSettingsSubpage(
      title: notificationDeploymentPageTitle,
      embedded: embedded,
      children: [
        DeploymentNavigationSettingsSection(
          config: profile.deploymentNavigation,
          editable: !profile.isOfficial,
          onChanged: (config) => _save(
            context,
            ref
                .read(notificationProfileProvider.notifier)
                .updateDeploymentNavigation(config),
          ),
        ),
      ],
    );
  }
}

/// MQTT、UDP 与视频链路质量设置。
class NotificationConnectionQualitySettingsScreen extends ConsumerWidget {
  /// 创建连接质量页面。
  const NotificationConnectionQualitySettingsScreen({
    super.key,
    this.embedded = false,
  });

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(notificationProfileProvider).activeProfile;
    return NotificationSettingsSubpage(
      title: notificationConnectionPageTitle,
      embedded: embedded,
      children: [
        ConnectionQualitySettingsSection(
          config: profile.connectionQuality,
          editable: !profile.isOfficial,
          onChanged: (config) => _save(
            context,
            ref
                .read(notificationProfileProvider.notifier)
                .updateConnectionQuality(config),
          ),
        ),
      ],
    );
  }
}

/// 为紧凑布局提供 AppBar，为宽屏嵌入布局提供页内标题。
class NotificationSettingsSubpage extends StatelessWidget {
  /// 创建通用通知设置二级页。
  const NotificationSettingsSubpage({
    required this.title,
    required this.children,
    required this.embedded,
    super.key,
  });

  /// 页面标题。
  final String title;

  /// 按顺序展示的设置区段。
  final List<Widget> children;

  /// 是否嵌入设置详情区。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: context.insetAll(16),
          children: [
            if (embedded) ...[
              Text(title, style: context.textTheme.headlineSmall),
              const SizedBox(height: 16),
            ],
            ...children,
          ],
        ),
      ),
    );
    if (embedded) {
      return ColoredBox(
        key: notificationSettingsSubpageSurfaceKey,
        color: Theme.of(context).colorScheme.surface,
        child: body,
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

void _save(BuildContext context, Future<void> operation) {
  unawaited(_handleSave(context, operation));
}

Future<void> _handleSave(BuildContext context, Future<void> operation) async {
  try {
    await operation;
  } on Object catch (error) {
    if (context.mounted) {
      context.showErrorSnack('$notificationProfileSaveFailed: $error');
    }
  }
}
