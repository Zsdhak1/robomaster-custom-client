/// 通知规则档案选择和文件操作区段。
library;

import 'package:flutter/material.dart';

import '../../domain/notification_rule_profile.dart';
import '../notification_settings_strings.dart';

/// 展示规则档案、版本信息和管理操作。
class NotificationProfileSection extends StatelessWidget {
  /// 创建档案区段。
  const NotificationProfileSection({
    required this.state,
    required this.onSelected,
    required this.onDuplicate,
    required this.onImport,
    required this.onExport,
    required this.onReset,
    required this.onDelete,
    super.key,
  });

  final NotificationProfileState state;
  final ValueChanged<String?> onSelected;
  final VoidCallback onDuplicate;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final profile = state.activeProfile;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._header(context, scheme),
        const SizedBox(height: 8),
        _profileCard(context, scheme, profile),
      ],
    );
  }

  List<Widget> _header(BuildContext context, ColorScheme scheme) => [
    Text(
      notificationProfileSectionTitle,
      style: Theme.of(context).textTheme.titleSmall,
    ),
    const SizedBox(height: 4),
    Text(
      notificationProfileSectionSubtitle,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
    ),
  ];

  Widget _profileCard(
    BuildContext context,
    ColorScheme scheme,
    NotificationRuleProfile profile,
  ) {
    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfilePicker(state: state, onSelected: onSelected),
            const SizedBox(height: 12),
            _VersionRow(profile: profile),
            const SizedBox(height: 12),
            _ProfileActions(
              isOfficial: profile.isOfficial,
              onDuplicate: onDuplicate,
              onImport: onImport,
              onExport: onExport,
              onReset: onReset,
              onDelete: onDelete,
            ),
            if (profile.isOfficial) ...[
              const SizedBox(height: 12),
              Text(
                notificationOfficialHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePicker extends StatelessWidget {
  const _ProfilePicker({required this.state, required this.onSelected});

  final NotificationProfileState state;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: state.activeProfileId,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        labelText: notificationProfileSectionTitle,
        helperText: notificationProfilePickerDescription,
      ),
      items: [
        for (final profile in state.profiles)
          DropdownMenuItem(
            value: profile.id,
            child: Text(profile.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onSelected,
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.profile});

  final NotificationRuleProfile profile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.memory, size: 18),
          label: Text(
            '$notificationProfileProtocol ${profile.protocolVersion}',
          ),
        ),
        Chip(
          avatar: const Icon(Icons.gavel, size: 18),
          label: Text('$notificationProfileRule ${profile.ruleVersion}'),
        ),
        Chip(
          avatar: Icon(
            profile.isOfficial ? Icons.lock_outline : Icons.edit_outlined,
            size: 18,
          ),
          label: Text(
            profile.isOfficial
                ? notificationProfileReadOnly
                : notificationProfileEditable,
          ),
        ),
      ],
    );
  }
}

class _ProfileActions extends StatelessWidget {
  const _ProfileActions({
    required this.isOfficial,
    required this.onDuplicate,
    required this.onImport,
    required this.onExport,
    required this.onReset,
    required this.onDelete,
  });

  final bool isOfficial;
  final VoidCallback onDuplicate;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onReset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: onDuplicate,
          icon: const Icon(Icons.copy_outlined),
          label: const Text(notificationProfileCopy),
        ),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text(notificationProfileImport),
        ),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.save_alt_outlined),
          label: const Text(notificationProfileExport),
        ),
        if (!isOfficial)
          TextButton(
            onPressed: onReset,
            child: const Text(notificationProfileReset),
          ),
        if (!isOfficial)
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            label: const Text(notificationProfileDelete),
          ),
      ],
    );
  }
}
