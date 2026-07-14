/// 通知与比赛规则设置目录。
library;

import 'package:flutter/material.dart';

import '../../../core/responsive/responsive_ext.dart';
import 'notification_profile_settings_screen.dart';
import 'notification_settings_strings.dart';
import 'notification_settings_subpages.dart';

/// 将通知设置按职责整理为二级页面入口。
class NotificationRulesSettingsScreen extends StatelessWidget {
  /// 创建通知设置目录。
  const NotificationRulesSettingsScreen({super.key, this.embedded = false});

  /// 为 true 时只渲染主体，供设置 Master–Detail 右侧嵌入。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = _NotificationSettingsDirectory(embedded: embedded);
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text(notificationSettingsTitle)),
      body: body,
    );
  }
}

class _NotificationSettingsDirectory extends StatelessWidget {
  const _NotificationSettingsDirectory({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: context.insetAll(16),
          children: [
            const _DirectoryIntro(),
            const SizedBox(height: 24),
            _DestinationGroup(
              title: notificationManagementGroupTitle,
              destinations: const [
                _NotificationDestination.profile,
                _NotificationDestination.displayAndTest,
                _NotificationDestination.events,
              ],
              onSelected: (destination) => _open(context, destination),
            ),
            const SizedBox(height: 24),
            _DestinationGroup(
              title: notificationRulesGroupTitle,
              destinations: const [
                _NotificationDestination.killLineAndRespawn,
                _NotificationDestination.deployment,
                _NotificationDestination.connectionQuality,
              ],
              onSelected: (destination) => _open(context, destination),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, _NotificationDestination destination) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _destinationScreen(destination, embedded),
      ),
    );
  }
}

class _DirectoryIntro extends StatelessWidget {
  const _DirectoryIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notificationDirectoryTitle,
          style: context.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          notificationDirectorySubtitle,
          style: context.textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DestinationGroup extends StatelessWidget {
  const _DestinationGroup({
    required this.title,
    required this.destinations,
    required this.onSelected,
  });

  final String title;
  final List<_NotificationDestination> destinations;
  final ValueChanged<_NotificationDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(title, style: context.textTheme.titleSmall),
        ),
        Card(
          color: colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < destinations.length; index++) ...[
                _DestinationTile(
                  destination: destinations[index],
                  onTap: () => onSelected(destinations[index]),
                ),
                if (index < destinations.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: colorScheme.outlineVariant,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.destination, required this.onTap});

  final _NotificationDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 72,
      leading: Icon(destination.icon),
      title: Text(destination.title),
      subtitle: Text(destination.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

enum _NotificationDestination {
  profile(
    Icons.rule_folder_outlined,
    notificationProfilePageTitle,
    notificationProfilePageSubtitle,
  ),
  displayAndTest(
    Icons.notifications_outlined,
    notificationDisplayTestPageTitle,
    notificationDisplayTestPageSubtitle,
  ),
  events(
    Icons.notification_important_outlined,
    notificationEventsPageTitle,
    notificationEventsPageSubtitle,
  ),
  killLineAndRespawn(
    Icons.gps_fixed,
    notificationCombatRulesPageTitle,
    notificationCombatRulesPageSubtitle,
  ),
  deployment(
    Icons.slow_motion_video_outlined,
    notificationDeploymentPageTitle,
    notificationDeploymentPageSubtitle,
  ),
  connectionQuality(
    Icons.network_check,
    notificationConnectionPageTitle,
    notificationConnectionPageSubtitle,
  );

  const _NotificationDestination(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}

Widget _destinationScreen(_NotificationDestination destination, bool embedded) {
  return switch (destination) {
    _NotificationDestination.profile => NotificationProfileSettingsScreen(
      embedded: embedded,
    ),
    _NotificationDestination.displayAndTest =>
      NotificationDisplayTestSettingsScreen(embedded: embedded),
    _NotificationDestination.events => NotificationEventSettingsScreen(
      embedded: embedded,
    ),
    _NotificationDestination.killLineAndRespawn =>
      NotificationCombatRuleSettingsScreen(embedded: embedded),
    _NotificationDestination.deployment => NotificationDeploymentSettingsScreen(
      embedded: embedded,
    ),
    _NotificationDestination.connectionQuality =>
      NotificationConnectionQualitySettingsScreen(embedded: embedded),
  };
}
