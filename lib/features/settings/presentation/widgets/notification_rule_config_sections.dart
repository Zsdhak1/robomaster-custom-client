/// 战术判定、部署跳转和连接质量设置区段。
library;

import 'package:flutter/material.dart';

import '../../domain/combat_notification_rules.dart';
import '../notification_settings_strings.dart';
import 'notification_advanced_rule_sections.dart';
import 'notification_settings_components.dart';

/// 敌方斩杀线设置。
class KillLineSettingsSection extends StatelessWidget {
  /// 创建斩杀线设置。
  const KillLineSettingsSection({
    required this.config,
    required this.editable,
    required this.onChanged,
    super.key,
  });

  final KillLineRuleConfig config;
  final bool editable;
  final ValueChanged<KillLineRuleConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationSettingsSectionCard(
      title: notificationKillLineTitle,
      subtitle: notificationKillLineSubtitle,
      children: [
        SwitchListTile(
          title: const Text(notificationKillLineEnabled),
          subtitle: const Text(notificationKillLineEnabledDescription),
          value: config.enabled,
          onChanged: editable
              ? (value) => onChanged(config.copyWith(enabled: value))
              : null,
        ),
        _KillLineModePicker(
          config: config,
          editable: editable,
          onChanged: onChanged,
        ),
        ..._thresholdTiles(),
        KillLineAdvancedSettings(
          config: config,
          editable: editable,
          onChanged: onChanged,
        ),
      ],
    );
  }

  List<Widget> _thresholdTiles() {
    return switch (config.mode) {
      KillLineMode.healthPercent => [_healthPercentTile()],
      KillLineMode.fixedHealth => [_fixedHealthTile()],
      KillLineMode.expectedProjectiles => _projectileTiles(),
    };
  }

  Widget _healthPercentTile() {
    return NotificationSettingsSliderTile(
      label: notificationHealthPercentThreshold,
      description: notificationHealthPercentThresholdDescription,
      value: config.healthPercentThreshold.toDouble(),
      min: 1,
      max: 100,
      divisions: 99,
      valueLabel: '${config.healthPercentThreshold}$notificationPercentUnit',
      onChanged: editable
          ? (value) => onChanged(
              config.copyWith(healthPercentThreshold: value.round()),
            )
          : null,
    );
  }

  Widget _fixedHealthTile() {
    return NotificationSettingsSliderTile(
      label: notificationFixedHealthThreshold,
      description: notificationFixedHealthThresholdDescription,
      value: config.fixedHealthThreshold.toDouble().clamp(50, 5000),
      min: 50,
      max: 5000,
      divisions: 99,
      valueLabel: '${config.fixedHealthThreshold} $notificationHealthUnit',
      onChanged: editable
          ? (value) =>
                onChanged(config.copyWith(fixedHealthThreshold: value.round()))
          : null,
    );
  }

  List<Widget> _projectileTiles() {
    return [
      _projectileThreshold(
        notificationHeroThreshold,
        notificationHeroThresholdDescription,
        config.heroThreshold,
        (value) => config.copyWith(heroThreshold: value),
      ),
      _projectileThreshold(
        notificationInfantryThreshold,
        notificationInfantryThresholdDescription,
        config.infantryThreshold,
        (value) => config.copyWith(infantryThreshold: value),
      ),
      _projectileThreshold(
        notificationSentryThreshold,
        notificationSentryThresholdDescription,
        config.sentryThreshold,
        (value) => config.copyWith(sentryThreshold: value),
      ),
    ];
  }

  Widget _projectileThreshold(
    String label,
    String description,
    int value,
    KillLineRuleConfig Function(int value) update,
  ) {
    return NotificationSettingsSliderTile(
      label: label,
      description: description,
      value: value.toDouble(),
      min: 1,
      max: 20,
      divisions: 19,
      valueLabel: '$value $notificationProjectileUnit',
      onChanged: editable ? (next) => onChanged(update(next.round())) : null,
    );
  }
}

class _KillLineModePicker extends StatelessWidget {
  const _KillLineModePicker({
    required this.config,
    required this.editable,
    required this.onChanged,
  });

  final KillLineRuleConfig config;
  final bool editable;
  final ValueChanged<KillLineRuleConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(notificationKillLineMode),
          const SizedBox(height: 2),
          const NotificationSettingsDescription(
            notificationKillLineModeDescription,
          ),
          const SizedBox(height: 8),
          SegmentedButton<KillLineMode>(
            segments: [
              for (final value in KillLineMode.values)
                ButtonSegment(
                  value: value,
                  label: Text(killLineModeLabel(value)),
                ),
            ],
            selected: {config.mode},
            onSelectionChanged: editable
                ? (values) => onChanged(config.copyWith(mode: values.first))
                : null,
          ),
        ],
      ),
    );
  }
}

/// 敌方复活和买活设置。
class RespawnSettingsSection extends StatelessWidget {
  /// 创建复活设置。
  const RespawnSettingsSection({
    required this.config,
    required this.editable,
    required this.onChanged,
    super.key,
  });

  final RespawnRuleConfig config;
  final bool editable;
  final ValueChanged<RespawnRuleConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationSettingsSectionCard(
      title: notificationRespawnTitle,
      subtitle: notificationRespawnSubtitle,
      children: _tiles(),
    );
  }

  List<Widget> _tiles() => [
    SwitchListTile(
      title: const Text(notificationRespawnEnabled),
      subtitle: const Text(notificationRespawnEnabledDescription),
      value: config.enabled,
      onChanged: editable
          ? (value) => onChanged(config.copyWith(enabled: value))
          : null,
    ),
    SwitchListTile(
      title: const Text(notificationBuybackEnabled),
      subtitle: const Text(notificationBuybackEnabledDescription),
      value: config.buybackDetectionEnabled,
      onChanged: editable
          ? (value) =>
                onChanged(config.copyWith(buybackDetectionEnabled: value))
          : null,
    ),
    _UncertainBehaviorPicker(
      config: config,
      editable: editable,
      onChanged: onChanged,
    ),
    NotificationSettingsSliderTile(
      label: notificationTolerance,
      description: notificationToleranceDescription,
      value: config.toleranceMilliseconds / 1000,
      min: 0,
      max: 5,
      divisions: 10,
      valueLabel:
          '${config.toleranceMilliseconds / 1000} $notificationSecondsUnit',
      onChanged: editable
          ? (value) => onChanged(
              config.copyWith(toleranceMilliseconds: (value * 1000).round()),
            )
          : null,
    ),
    RespawnFormulaSettings(
      config: config,
      editable: editable,
      onChanged: onChanged,
    ),
  ];
}

class _UncertainBehaviorPicker extends StatelessWidget {
  const _UncertainBehaviorPicker({
    required this.config,
    required this.editable,
    required this.onChanged,
  });

  final RespawnRuleConfig config;
  final bool editable;
  final ValueChanged<RespawnRuleConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(notificationUncertainBehavior),
          const SizedBox(height: 2),
          const NotificationSettingsDescription(
            notificationUncertainBehaviorDescription,
          ),
          const SizedBox(height: 8),
          SegmentedButton<UncertainBuybackBehavior>(
            segments: [
              for (final value in UncertainBuybackBehavior.values)
                ButtonSegment(
                  value: value,
                  label: Text(uncertainBuybackLabel(value)),
                ),
            ],
            selected: {config.uncertainBehavior},
            onSelectionChanged: editable
                ? (values) => onChanged(
                    config.copyWith(uncertainBehavior: values.first),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// 英雄部署自动跳转设置。
class DeploymentNavigationSettingsSection extends StatelessWidget {
  /// 创建部署跳转设置。
  const DeploymentNavigationSettingsSection({
    required this.config,
    required this.editable,
    required this.onChanged,
    super.key,
  });

  final DeploymentNavigationConfig config;
  final bool editable;
  final ValueChanged<DeploymentNavigationConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationSettingsSectionCard(
      title: notificationDeploymentTitle,
      subtitle: notificationDeploymentSubtitle,
      children: _tiles(),
    );
  }

  List<Widget> _tiles() => [
    SwitchListTile(
      title: const Text(notificationDeploymentEnabled),
      subtitle: const Text(notificationDeploymentEnabledDescription),
      value: config.enabled,
      onChanged: editable
          ? (value) => onChanged(config.copyWith(enabled: value))
          : null,
    ),
    NotificationSettingsSliderTile(
      label: notificationDeploymentCountdown,
      description: notificationDeploymentCountdownDescription,
      value: config.countdownSeconds.toDouble(),
      min: 0,
      max: 10,
      divisions: 10,
      valueLabel: '${config.countdownSeconds} $notificationSecondsUnit',
      onChanged: editable
          ? (value) =>
                onChanged(config.copyWith(countdownSeconds: value.round()))
          : null,
    ),
    _switchTile(
      title: notificationDeploymentAllowCancel,
      description: notificationDeploymentAllowCancelDescription,
      value: config.allowCancel,
      update: (value) => onChanged(config.copyWith(allowCancel: value)),
    ),
    _switchTile(
      title: notificationDeploymentEnterNow,
      description: notificationDeploymentEnterNowDescription,
      value: config.showEnterNow,
      update: (value) => onChanged(config.copyWith(showEnterNow: value)),
    ),
    _switchTile(
      title: notificationDeploymentPrestart,
      description: notificationDeploymentPrestartDescription,
      value: config.prestartVideo,
      update: (value) => onChanged(config.copyWith(prestartVideo: value)),
    ),
    DeploymentAdvancedSettings(
      config: config,
      editable: editable,
      onChanged: onChanged,
    ),
  ];

  Widget _switchTile({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> update,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(description),
      value: value,
      onChanged: editable
          ? (next) {
              update(next);
            }
          : null,
    );
  }
}

/// 连接质量阈值设置。
class ConnectionQualitySettingsSection extends StatelessWidget {
  /// 创建连接质量设置。
  const ConnectionQualitySettingsSection({
    required this.config,
    required this.editable,
    required this.onChanged,
    super.key,
  });

  final ConnectionQualityRuleConfig config;
  final bool editable;
  final ValueChanged<ConnectionQualityRuleConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    return NotificationSettingsSectionCard(
      title: notificationQualityTitle,
      subtitle: notificationQualitySubtitle,
      children: [
        _secondsSlider(
          notificationMqttWarning,
          notificationMqttWarningDescription,
          config.mqttWarningSeconds,
          1,
          30,
          (value) => config.copyWith(mqttWarningSeconds: value),
        ),
        _secondsSlider(
          notificationMqttCritical,
          notificationMqttCriticalDescription,
          config.mqttCriticalSeconds,
          1,
          60,
          (value) => config.copyWith(mqttCriticalSeconds: value),
        ),
        NotificationSettingsSliderTile(
          label: notificationUdpWarning,
          description: notificationUdpWarningDescription,
          value: config.udpWarningLossPercent.toDouble(),
          min: 0,
          max: 50,
          divisions: 50,
          valueLabel: '${config.udpWarningLossPercent}$notificationPercentUnit',
          onChanged: editable
              ? (value) => onChanged(
                  config.copyWith(udpWarningLossPercent: value.round()),
                )
              : null,
        ),
        ConnectionQualityAdvancedSettings(
          config: config,
          editable: editable,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _secondsSlider(
    String label,
    String description,
    int value,
    int min,
    int max,
    ConnectionQualityRuleConfig Function(int value) update,
  ) {
    return NotificationSettingsSliderTile(
      label: label,
      description: description,
      value: value.toDouble().clamp(min, max).toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: max - min,
      valueLabel: '$value $notificationSecondsUnit',
      onChanged: editable ? (next) => onChanged(update(next.round())) : null,
    );
  }
}
