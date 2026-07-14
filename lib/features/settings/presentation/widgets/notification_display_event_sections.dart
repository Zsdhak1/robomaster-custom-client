/// 通知总览和事件开关区段。
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../../domain/notification_preferences.dart';
import '../../domain/notification_rule_profile.dart';
import '../notification_settings_strings.dart';
import 'notification_settings_components.dart';

/// 通知全局展示偏好。
class NotificationDisplaySection extends StatelessWidget {
  /// 创建展示偏好区段。
  const NotificationDisplaySection({
    required this.config,
    required this.editable,
    required this.onChanged,
    super.key,
  });

  final NotificationDisplayConfig config;
  final bool editable;
  final ValueChanged<NotificationDisplayConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationSettingsSectionCard(
      title: notificationOverviewTitle,
      subtitle: notificationOverviewSubtitle,
      children: _tiles(),
    );
  }

  List<Widget> _tiles() => [
    ..._statusTiles(),
    ..._feedbackTiles(),
    ..._durationTiles(),
    ..._capacityTiles(),
    _CriticalDismissPicker(
      config: config,
      editable: editable,
      onChanged: onChanged,
    ),
  ];

  List<Widget> _statusTiles() => [
    _boolTile(
      notificationEnabled,
      notificationEnabledDescription,
      value: config.enabled,
      update: (value) => onChanged(config.copyWith(enabled: value)),
    ),
    _SensitivityPicker(
      config: config,
      editable: editable,
      onChanged: onChanged,
    ),
    _placementTile(
      notificationInfoPlacement,
      notificationInfoPlacementDescription,
      config.infoPlacement,
      info: true,
    ),
    _placementTile(
      notificationCriticalPlacement,
      notificationCriticalPlacementDescription,
      config.criticalPlacement,
      info: false,
    ),
  ];

  Widget _placementTile(
    String label,
    String description,
    NotificationPlacement value, {
    required bool info,
  }) {
    return _PlacementPicker(
      label: label,
      description: description,
      value: value,
      editable: editable,
      onChanged: (next) => onChanged(
        info
            ? config.copyWith(infoPlacement: next)
            : config.copyWith(criticalPlacement: next),
      ),
    );
  }

  List<Widget> _feedbackTiles() => [
    _boolTile(
      notificationSoundEnabled,
      notificationSoundEnabledDescription,
      value: config.soundEnabled,
      update: (value) => onChanged(config.copyWith(soundEnabled: value)),
    ),
    _boolTile(
      notificationMuteWhenPaused,
      notificationMuteWhenPausedDescription,
      value: config.muteWhenPaused,
      update: (value) => onChanged(config.copyWith(muteWhenPaused: value)),
    ),
    if (Platform.isAndroid)
      _boolTile(
        notificationVibrationEnabled,
        notificationVibrationEnabledDescription,
        value: config.vibrationEnabled,
        update: (value) => onChanged(config.copyWith(vibrationEnabled: value)),
      ),
    _boolTile(
      notificationKeepHistory,
      notificationKeepHistoryDescription,
      value: config.keepHistory,
      update: (value) => onChanged(config.copyWith(keepHistory: value)),
    ),
  ];

  Widget _boolTile(
    String title,
    String description, {
    required bool value,
    required ValueChanged<bool> update,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(description),
      value: value,
      onChanged: editable ? update : null,
    );
  }

  List<Widget> _durationTiles() => [
    _durationTile(
      notificationInfoDuration,
      notificationInfoDurationDescription,
      config.infoDurationSeconds,
      15,
      (value) => config.copyWith(infoDurationSeconds: value),
    ),
    _durationTile(
      notificationCriticalDuration,
      notificationCriticalDurationDescription,
      config.criticalDurationSeconds,
      60,
      (value) => config.copyWith(criticalDurationSeconds: value),
    ),
  ];

  Widget _durationTile(
    String label,
    String description,
    int value,
    int max,
    NotificationDisplayConfig Function(int) update,
  ) {
    return NotificationSettingsSliderTile(
      label: label,
      description: description,
      value: value.toDouble(),
      min: 3,
      max: max.toDouble(),
      divisions: max - 3,
      valueLabel: '$value $notificationSecondsUnit',
      onChanged: editable ? (next) => onChanged(update(next.round())) : null,
    );
  }

  List<Widget> _capacityTiles() => [
    NotificationSettingsSliderTile(
      label: notificationMaxVisibleInfo,
      description: notificationMaxVisibleInfoDescription,
      value: config.maxVisibleInfo.toDouble(),
      min: 1,
      max: 4,
      divisions: 3,
      valueLabel: '${config.maxVisibleInfo} $notificationCountUnit',
      onChanged: editable
          ? (value) => onChanged(config.copyWith(maxVisibleInfo: value.round()))
          : null,
    ),
    if (config.keepHistory)
      NotificationSettingsSliderTile(
        label: notificationHistoryLimit,
        description: notificationHistoryLimitDescription,
        value: config.historyLimit.toDouble().clamp(10, 200),
        min: 10,
        max: 200,
        divisions: 19,
        valueLabel: '${config.historyLimit} $notificationCountUnit',
        onChanged: editable
            ? (value) => onChanged(config.copyWith(historyLimit: value.round()))
            : null,
      ),
  ];
}

class _PlacementPicker extends StatelessWidget {
  const _PlacementPicker({
    required this.label,
    required this.description,
    required this.value,
    required this.editable,
    required this.onChanged,
  });

  final String label;
  final String description;
  final NotificationPlacement value;
  final bool editable;
  final ValueChanged<NotificationPlacement> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(description),
      trailing: DropdownButton<NotificationPlacement>(
        value: value,
        onChanged: editable
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
        items: [
          for (final option in NotificationPlacement.values)
            DropdownMenuItem(
              value: option,
              child: Text(notificationPlacementLabel(option)),
            ),
        ],
      ),
    );
  }
}

class _CriticalDismissPicker extends StatelessWidget {
  const _CriticalDismissPicker({
    required this.config,
    required this.editable,
    required this.onChanged,
  });

  final NotificationDisplayConfig config;
  final bool editable;
  final ValueChanged<NotificationDisplayConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text(notificationCriticalDismiss),
      subtitle: const Text(notificationCriticalDismissDescription),
      trailing: DropdownButton<CriticalDismissMode>(
        value: config.criticalDismissMode,
        onChanged: editable
            ? (value) {
                if (value != null) {
                  onChanged(config.copyWith(criticalDismissMode: value));
                }
              }
            : null,
        items: [
          for (final option in CriticalDismissMode.values)
            DropdownMenuItem(
              value: option,
              child: Text(criticalDismissModeLabel(option)),
            ),
        ],
      ),
    );
  }
}

class _SensitivityPicker extends StatelessWidget {
  const _SensitivityPicker({
    required this.config,
    required this.editable,
    required this.onChanged,
  });

  final NotificationDisplayConfig config;
  final bool editable;
  final ValueChanged<NotificationDisplayConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(notificationSensitivityTitle),
          const SizedBox(height: 2),
          const NotificationSettingsDescription(
            notificationSensitivityDescription,
          ),
          const SizedBox(height: 8),
          SegmentedButton<NotificationSensitivity>(
            segments: [
              for (final value in NotificationSensitivity.values)
                ButtonSegment(
                  value: value,
                  label: Text(notificationSensitivityLabel(value)),
                ),
            ],
            selected: {config.sensitivity},
            onSelectionChanged: editable
                ? (values) =>
                      onChanged(config.copyWith(sensitivity: values.first))
                : null,
          ),
        ],
      ),
    );
  }
}

/// 所有通知事件的独立开关。
class NotificationEventSection extends StatelessWidget {
  /// 创建事件开关区段。
  const NotificationEventSection({
    required this.profile,
    required this.editable,
    required this.onChanged,
    super.key,
  });

  final NotificationRuleProfile profile;
  final bool editable;
  final void Function(
    NotificationEventType type,
    NotificationEventSetting setting,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationSettingsSectionCard(
      title: notificationEventSectionTitle,
      subtitle: notificationEventSectionSubtitle,
      children: [
        for (final type in NotificationEventType.values)
          _NotificationEventTile(
            type: type,
            setting:
                profile.eventSettings[type] ?? const NotificationEventSetting(),
            editable: editable,
            onChanged: (setting) => onChanged(type, setting),
          ),
      ],
    );
  }
}

class _NotificationEventTile extends StatelessWidget {
  const _NotificationEventTile({
    required this.type,
    required this.setting,
    required this.editable,
    required this.onChanged,
  });

  final NotificationEventType type;
  final NotificationEventSetting setting;
  final bool editable;
  final ValueChanged<NotificationEventSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Switch.adaptive(
        value: setting.enabled,
        onChanged: editable
            ? (value) => onChanged(setting.copyWith(enabled: value))
            : null,
      ),
      title: Text(notificationEventLabel(type)),
      subtitle: Text(
        '${notificationEventDescription(type)}\n'
        '$notificationEventToggleDescription · '
        '${notificationSeverityLabel(setting.severity)}',
      ),
      children: [
        _severityPicker(),
        SwitchListTile(
          title: const Text(notificationEventSound),
          subtitle: const Text(notificationEventSoundDescription),
          value: setting.playSound,
          onChanged: editable
              ? (value) => onChanged(setting.copyWith(playSound: value))
              : null,
        ),
        SwitchListTile(
          title: const Text(notificationEventAcknowledgement),
          subtitle: const Text(notificationEventAcknowledgementDescription),
          value: setting.requiresAcknowledgement,
          onChanged: editable
              ? (value) =>
                    onChanged(setting.copyWith(requiresAcknowledgement: value))
              : null,
        ),
        NotificationSettingsSliderTile(
          label: notificationEventCooldown,
          description: notificationEventCooldownDescription,
          value: setting.cooldownSeconds.toDouble(),
          min: 0,
          max: 60,
          divisions: 60,
          valueLabel: '${setting.cooldownSeconds} $notificationSecondsUnit',
          onChanged: editable
              ? (value) =>
                    onChanged(setting.copyWith(cooldownSeconds: value.round()))
              : null,
        ),
      ],
    );
  }

  Widget _severityPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NotificationSettingsDescription(
            notificationEventSeverityDescription,
          ),
          const SizedBox(height: 8),
          SegmentedButton<NotificationSeverity>(
            segments: [
              for (final severity in NotificationSeverity.values)
                ButtonSegment(
                  value: severity,
                  label: Text(notificationSeverityLabel(severity)),
                ),
            ],
            selected: {setting.severity},
            onSelectionChanged: editable
                ? (values) =>
                      onChanged(setting.copyWith(severity: values.first))
                : null,
          ),
        ],
      ),
    );
  }
}
