/// 通知规则页面的高级参数组件。
library;

import 'package:flutter/material.dart';

import '../../domain/combat_notification_rules.dart';
import '../notification_settings_strings.dart';
import 'notification_settings_components.dart';

/// 斩杀线冷却和再武装参数。
class KillLineAdvancedSettings extends StatelessWidget {
  const KillLineAdvancedSettings({
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
    return Column(
      children: [
        _intSlider(
          notificationKillLineCooldown,
          notificationKillLineCooldownDescription,
          config.cooldownSeconds,
          0,
          60,
          notificationSecondsUnit,
          (value) => config.copyWith(cooldownSeconds: value),
        ),
        _intSlider(
          notificationKillLineRearm,
          notificationKillLineRearmDescription,
          config.rearmDelta,
          1,
          10,
          notificationProgressUnit,
          (value) => config.copyWith(rearmDelta: value),
        ),
      ],
    );
  }

  Widget _intSlider(
    String label,
    String description,
    int value,
    int min,
    int max,
    String unit,
    KillLineRuleConfig Function(int) update,
  ) {
    return NotificationSettingsSliderTile(
      label: label,
      description: description,
      value: value.toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: max - min,
      valueLabel: '$value $unit',
      onChanged: editable ? (next) => onChanged(update(next.round())) : null,
    );
  }
}

/// 免费复活公式参数。
class RespawnFormulaSettings extends StatelessWidget {
  const RespawnFormulaSettings({
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
    return Column(children: [..._progressTiles(), ..._timingTiles()]);
  }

  List<Widget> _progressTiles() {
    return [
      _slider(
        notificationRespawnBaseProgress,
        notificationRespawnBaseProgressDescription,
        config.baseProgress,
        1,
        100,
        (v) => config.copyWith(baseProgress: v),
      ),
      _slider(
        notificationBuybackPenalty,
        notificationBuybackPenaltyDescription,
        config.progressPenaltyPerBuyback,
        0,
        100,
        (v) => config.copyWith(progressPenaltyPerBuyback: v),
      ),
      _slider(
        notificationTimeDivisor,
        notificationTimeDivisorDescription,
        config.timeDivisor,
        1,
        60,
        (v) => config.copyWith(timeDivisor: v),
      ),
    ];
  }

  List<Widget> _timingTiles() {
    return [
      _slider(
        notificationMatchDuration,
        notificationMatchDurationDescription,
        config.matchDurationSeconds,
        60,
        600,
        (v) => config.copyWith(matchDurationSeconds: v),
        unit: notificationSecondsUnit,
      ),
      _slider(
        notificationNormalProgressRate,
        notificationNormalProgressRateDescription,
        config.normalProgressPerSecond,
        1,
        10,
        (v) => config.copyWith(normalProgressPerSecond: v),
      ),
      _slider(
        notificationAcceleratedProgressRate,
        notificationAcceleratedProgressRateDescription,
        config.acceleratedProgressPerSecond,
        1,
        10,
        (v) => config.copyWith(acceleratedProgressPerSecond: v),
      ),
      _slider(
        notificationLowBaseThreshold,
        notificationLowBaseThresholdDescription,
        config.lowBaseHealthThreshold,
        0,
        10000,
        (v) => config.copyWith(lowBaseHealthThreshold: v),
        unit: notificationHealthUnit,
        divisions: 100,
      ),
    ];
  }

  Widget _slider(
    String label,
    String description,
    int value,
    int min,
    int max,
    RespawnRuleConfig Function(int) update, {
    String unit = notificationProgressUnit,
    int? divisions,
  }) {
    return NotificationSettingsSliderTile(
      label: label,
      description: description,
      value: value.toDouble().clamp(min, max).toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: divisions ?? max - min,
      valueLabel: '$value $unit',
      onChanged: editable ? (next) => onChanged(update(next.round())) : null,
    );
  }
}

/// 部署跳转失败和本场取消策略。
class DeploymentAdvancedSettings extends StatelessWidget {
  const DeploymentAdvancedSettings({
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
    return Column(
      children: [
        SwitchListTile(
          title: const Text(notificationDeploymentCancelForMatch),
          subtitle: const Text(notificationDeploymentCancelForMatchDescription),
          value: config.cancelForCurrentMatch,
          onChanged: editable
              ? (value) =>
                    onChanged(config.copyWith(cancelForCurrentMatch: value))
              : null,
        ),
        SwitchListTile(
          title: const Text(notificationDeploymentStayOnFailure),
          subtitle: const Text(notificationDeploymentStayOnFailureDescription),
          value: config.stayWhenVideoStartFails,
          onChanged: editable
              ? (value) =>
                    onChanged(config.copyWith(stayWhenVideoStartFails: value))
              : null,
        ),
      ],
    );
  }
}

/// UDP、自定义图传和恢复防抖参数。
class ConnectionQualityAdvancedSettings extends StatelessWidget {
  const ConnectionQualityAdvancedSettings({
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
    return Column(children: [..._streamTiles(), ..._stabilityTiles()]);
  }

  List<Widget> _streamTiles() {
    return [
      _seconds(
        notificationUdpWindow,
        notificationUdpWindowDescription,
        config.udpWindowSeconds,
        1,
        60,
        (v) => config.copyWith(udpWindowSeconds: v),
      ),
      _percent(
        notificationUdpCritical,
        notificationUdpCriticalDescription,
        config.udpCriticalLossPercent,
        (v) => config.copyWith(udpCriticalLossPercent: v),
      ),
      _seconds(
        notificationCustomVideoStale,
        notificationCustomVideoStaleDescription,
        config.customVideoStaleSeconds,
        1,
        60,
        (v) => config.copyWith(customVideoStaleSeconds: v),
      ),
      _seconds(
        notificationDecoderStale,
        notificationDecoderStaleDescription,
        config.decoderStaleSeconds,
        1,
        60,
        (v) => config.copyWith(decoderStaleSeconds: v),
      ),
    ];
  }

  List<Widget> _stabilityTiles() {
    return [
      _seconds(
        notificationRecoveryStable,
        notificationRecoveryStableDescription,
        config.recoveryStableSeconds,
        1,
        60,
        (v) => config.copyWith(recoveryStableSeconds: v),
      ),
      NotificationSettingsSliderTile(
        label: notificationQualityDebounce,
        description: notificationQualityDebounceDescription,
        value: config.debounceMilliseconds / 1000,
        min: 0,
        max: 10,
        divisions: 20,
        valueLabel:
            '${(config.debounceMilliseconds / 1000).toStringAsFixed(1)} $notificationSecondsUnit',
        onChanged: editable
            ? (value) => onChanged(
                config.copyWith(debounceMilliseconds: (value * 1000).round()),
              )
            : null,
      ),
    ];
  }

  Widget _seconds(
    String label,
    String description,
    int value,
    int min,
    int max,
    ConnectionQualityRuleConfig Function(int) update,
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

  Widget _percent(
    String label,
    String description,
    int value,
    ConnectionQualityRuleConfig Function(int) update,
  ) {
    return NotificationSettingsSliderTile(
      label: label,
      description: description,
      value: value.toDouble(),
      min: 0,
      max: 100,
      divisions: 100,
      valueLabel: '$value$notificationPercentUnit',
      onChanged: editable ? (next) => onChanged(update(next.round())) : null,
    );
  }
}
