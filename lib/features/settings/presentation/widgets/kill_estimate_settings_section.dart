/// 仪表盘设置中的击杀估算参数编辑区。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/feedback_messenger.dart';
import '../../../../core/responsive/responsive_ext.dart';
import '../../domain/kill_estimate_config.dart';
import '../../logic/kill_estimate_provider.dart';

const String _sectionTitle = '击杀估算参数';
const String _sectionDescription = '用于计算当前血量下预计需要发射的弹丸数量。';

/// 编辑并保存击杀估算参数。
class KillEstimateSettingsSection extends ConsumerWidget {
  /// 创建设置区段。
  const KillEstimateSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(killEstimateConfigProvider);
    return Card(
      child: Padding(
        padding: context.insetAll(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_sectionTitle, style: context.textTheme.titleMedium),
            context.sizedBox(h: 4),
            Text(_sectionDescription, style: context.textTheme.bodySmall),
            context.sizedBox(h: 12),
            _Summary(config: config),
            context.sizedBox(h: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _openEditor(context, ref, config),
                  icon: const Icon(Icons.tune),
                  label: const Text('编辑参数'),
                ),
                context.sizedBox(w: 8),
                TextButton(
                  onPressed: () => _reset(context, ref),
                  child: const Text('恢复默认值'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    KillEstimateConfig config,
  ) async {
    final result = await showDialog<KillEstimateConfig>(
      context: context,
      builder: (_) => _KillEstimateDialog(initial: config),
    );
    if (result == null || !context.mounted) return;
    await ref.read(killEstimateConfigProvider.notifier).setConfig(result);
    if (context.mounted) context.showSuccessSnack('估算参数已保存');
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    await ref.read(killEstimateConfigProvider.notifier).reset();
    if (context.mounted) context.showSuccessSnack('已恢复默认参数');
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.config});

  final KillEstimateConfig config;

  @override
  Widget build(BuildContext context) {
    final healthText = KillEstimateRobotRole.values
        .map((role) => '${role.label} ${config.maxHealth(role)}')
        .join(' · ');
    return Text(
      '命中率 ${(config.hitRate * 100).round()}% · '
      '17mm ${_number(config.smallProjectileDamage)} · '
      '42mm ${_number(config.largeProjectileDamage)}\n$healthText',
      style: context.textTheme.bodySmall,
    );
  }

  String _number(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

class _KillEstimateDialog extends StatefulWidget {
  const _KillEstimateDialog({required this.initial});

  final KillEstimateConfig initial;

  @override
  State<_KillEstimateDialog> createState() => _KillEstimateDialogState();
}

class _KillEstimateDialogState extends State<_KillEstimateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hitRate;
  late final TextEditingController _smallDamage;
  late final TextEditingController _largeDamage;
  late final Map<KillEstimateRobotRole, TextEditingController> _health;

  @override
  void initState() {
    super.initState();
    _hitRate = _controller(widget.initial.hitRate * 100);
    _smallDamage = _controller(widget.initial.smallProjectileDamage);
    _largeDamage = _controller(widget.initial.largeProjectileDamage);
    _health = {
      for (final role in KillEstimateRobotRole.values)
        role: _controller(widget.initial.maxHealth(role)),
    };
  }

  TextEditingController _controller(num value) => TextEditingController(
    text: value == value.roundToDouble() ? '${value.toInt()}' : '$value',
  );

  @override
  void dispose() {
    _hitRate.dispose();
    _smallDamage.dispose();
    _largeDamage.dispose();
    for (final controller in _health.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(_sectionTitle),
      content: SizedBox(
        width: context.sp(520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(child: _fields()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  Widget _fields() {
    return Column(
      children: [
        _numberField(_hitRate, '命中率（%）', max: 100),
        _numberField(_smallDamage, '17mm 单发伤害'),
        _numberField(_largeDamage, '42mm 单发伤害'),
        for (final role in KillEstimateRobotRole.values)
          _numberField(_health[role], '${role.label}血量上限', integer: true),
      ],
    );
  }

  Widget _numberField(
    TextEditingController? controller,
    String label, {
    double? max,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        validator: (value) => _validate(value, max: max, integer: integer),
      ),
    );
  }

  String? _validate(String? value, {required bool integer, double? max}) {
    final parsed = integer
        ? int.tryParse(value ?? '')
        : double.tryParse(value ?? '');
    if (parsed == null || parsed <= 0) return '请输入大于 0 的数值';
    if (max != null && parsed > max) return '数值不能超过 ${max.toInt()}';
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      KillEstimateConfig(
        hitRate: double.parse(_hitRate.text) / 100,
        smallProjectileDamage: double.parse(_smallDamage.text),
        largeProjectileDamage: double.parse(_largeDamage.text),
        maxHealthByRole: {
          for (final role in KillEstimateRobotRole.values)
            role: int.parse(_health[role]?.text ?? ''),
        },
      ),
    );
  }
}
