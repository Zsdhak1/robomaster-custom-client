/// 通知设置页面共用的 Material 3 区段组件。
library;

import 'package:flutter/material.dart';

/// 带标题、说明和 Card 容器的设置区段。
class NotificationSettingsSectionCard extends StatelessWidget {
  /// 创建设置区段。
  const NotificationSettingsSectionCard({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (subtitleText != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(child: Column(children: children)),
      ],
    );
  }
}

/// 显示当前数值的离散滑杆设置项。
class NotificationSettingsSliderTile extends StatelessWidget {
  /// 创建滑杆设置项。
  const NotificationSettingsSliderTile({
    required this.label,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 2),
          NotificationSettingsDescription(description),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 使用 MD3 辅助文本层级展示设置作用说明。
class NotificationSettingsDescription extends StatelessWidget {
  /// 创建设置说明文本。
  const NotificationSettingsDescription(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
