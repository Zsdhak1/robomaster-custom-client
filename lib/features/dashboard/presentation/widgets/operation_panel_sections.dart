import 'package:flutter/material.dart';

import '../../../../core/constants/protocol_constants.dart';
import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/operation_panel_state.dart';
import '../operation_panel_strings.dart';

const List<int> _ammoQuantityOptions = [10, 20, 30, 50];
const Duration _availabilityPulseDuration = Duration(milliseconds: 700);

/// 英雄和步兵使用的常规及远程操作区。
class CombatOperationSection extends StatelessWidget {
  /// 创建战斗机器人操作区。
  const CombatOperationSection({
    required this.state,
    required this.onQuantityChanged,
    required this.onExchangeAmmo,
    required this.onRemoteHeal,
    required this.onRemoteAmmo,
    super.key,
  });

  /// 当前操作状态。
  final OperationPanelState state;

  /// 用户切换常规兑换数量时调用。
  final ValueChanged<int> onQuantityChanged;

  /// 用户请求常规兑换时调用。
  final VoidCallback onExchangeAmmo;

  /// 用户请求远程回血时调用。
  final VoidCallback onRemoteHeal;

  /// 用户请求远程买弹时调用。
  final VoidCallback onRemoteAmmo;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAmmoHeader(context),
          SizedBox(height: context.sp(6)),
          _buildActionRow(context),
        ],
      ),
    );
  }

  Widget _buildAmmoHeader(BuildContext context) {
    final title = state.role == OperationRobotRole.hero
        ? operationHeroAmmoTitle
        : operationInfantryAmmoTitle;
    return Row(
      children: [
        _SectionLabel(title),
        const Spacer(),
        Text(operationAmmoQuantityLabel, style: context.textTheme.labelMedium),
        SizedBox(width: context.sp(6)),
        _QuantityDropdown(
          value: state.ammoQuantity,
          onChanged: onQuantityChanged,
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ActionColumn(
            button: OperationActionButton(
              label: operationAmmoButtonLabel(state.ammoQuantity),
              icon: Icons.wifi_tethering,
              onPressed: onExchangeAmmo,
            ),
          ),
        ),
        SizedBox(width: context.sp(8)),
        Expanded(child: _buildRemoteHeal()),
        SizedBox(width: context.sp(8)),
        Expanded(child: _buildRemoteAmmo()),
      ],
    );
  }

  Widget _buildRemoteHeal() {
    return _ActionColumn(
      reason: operationRemoteHealReason(state),
      button: AvailabilityPulse(
        key: const ValueKey('remote-heal-pulse'),
        glowKey: const ValueKey('remote-heal-pulse-glow'),
        pulseToken: state.remoteHealPulseToken,
        child: OperationActionButton(
          label: operationRemoteHealLabel,
          icon: Icons.favorite,
          semanticColor: rmHealthHighColor,
          onPressed: state.remoteHealEnabled ? onRemoteHeal : null,
        ),
      ),
    );
  }

  Widget _buildRemoteAmmo() {
    return _ActionColumn(
      reason: operationRemoteAmmoReason(state),
      button: AvailabilityPulse(
        key: const ValueKey('remote-ammo-pulse'),
        glowKey: const ValueKey('remote-ammo-pulse-glow'),
        pulseToken: state.remoteAmmoPulseToken,
        child: OperationActionButton(
          label: operationRemoteAmmoLabel,
          icon: Icons.shopping_cart,
          onPressed: state.remoteAmmoEnabled ? onRemoteAmmo : null,
        ),
      ),
    );
  }
}

/// 工程科技核心状态与装配控制区。
class EngineerOperationSection extends StatelessWidget {
  /// 创建工程操作区。
  const EngineerOperationSection({
    required this.state,
    required this.onDifficultyPressed,
    required this.onToggleAutoConfirm,
    required this.onCancelAssembly,
    super.key,
  });

  /// 当前操作状态。
  final OperationPanelState state;

  /// 点击装配难度时调用。
  final ValueChanged<int> onDifficultyPressed;

  /// 开关自动确认时调用。
  final VoidCallback onToggleAutoConfirm;

  /// 取消装配时调用。
  final VoidCallback onCancelAssembly;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusHeader(context),
          SizedBox(height: context.sp(6)),
          _buildDifficultyRow(context),
          SizedBox(height: context.sp(6)),
          _buildStepRow(context),
          SizedBox(height: context.sp(6)),
          _buildTimeAndControls(context),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    final status = state.techCoreKnown
        ? operationBasicStateText(state.techCore.basicState)
        : operationTechCoreWaiting;
    return Row(
      children: [
        Icon(
          state.techCore.isCompleted
              ? Icons.check_circle_outline
              : Icons.precision_manufacturing_outlined,
          size: context.iconSize(18),
          color: state.techCore.isCompleted
              ? rmHealthHighColor
              : Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: context.sp(6)),
        Text(status, style: context.textTheme.labelLarge),
        const Spacer(),
        if (state.techCoreKnown)
          _SectionLabel(
            operationMaximumDifficultyLabel(state.techCore.maximumDifficulty),
          ),
      ],
    );
  }

  Widget _buildDifficultyRow(BuildContext context) {
    if (!state.techCoreKnown || state.techCore.maximumDifficulty == 0) {
      return const _SectionLabel(operationDifficultyTitle);
    }
    return Row(
      children: [
        for (var level = 1; level <= state.techCore.maximumDifficulty; level++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: level == state.techCore.maximumDifficulty
                    ? 0
                    : context.sp(6),
              ),
              child: _DifficultyButton(
                level: level,
                active: state.activeDifficulty == level,
                enabled: _difficultyEnabled(level),
                onPressed: () => onDifficultyPressed(level),
              ),
            ),
          ),
      ],
    );
  }

  bool _difficultyEnabled(int level) {
    final noConflictingRequest =
        state.activeDifficulty == null || state.activeDifficulty == level;
    return state.techCore.basicState == techCoreBasicStateInitial &&
        noConflictingRequest;
  }

  Widget _buildStepRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepStatus(
            done: state.techCore.putinDone,
            doneText: operationPutinDone,
            waitingText: operationPutinWaiting,
          ),
        ),
        SizedBox(width: context.sp(6)),
        Expanded(
          child: _StepStatus(
            done: state.techCore.moveDone,
            doneText: operationMoveDone,
            waitingText: operationMoveWaiting,
          ),
        ),
        SizedBox(width: context.sp(6)),
        Expanded(
          child: _StepStatus(
            done: state.techCore.rotateDone,
            doneText: operationRotateDone,
            waitingText: operationRotateWaiting,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeAndControls(BuildContext context) {
    return Row(
      children: [
        Text(
          operationTotalTimeLabel(state.techCore.remainingTotalSeconds),
          style: context.textTheme.labelMedium,
        ),
        SizedBox(width: context.sp(10)),
        Text(
          operationStepTimeLabel(state.techCore.remainingStepSeconds),
          style: context.textTheme.labelMedium,
        ),
        const Spacer(),
        Tooltip(
          message: operationAutoConfirmDescription,
          child: FilledButton.tonalIcon(
            onPressed: onToggleAutoConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              state.autoConfirmArmed
                  ? operationStopAutoConfirmLabel
                  : operationAutoConfirmLabel,
            ),
          ),
        ),
        SizedBox(width: context.sp(6)),
        OutlinedButton.icon(
          onPressed: onCancelAssembly,
          icon: const Icon(Icons.cancel_outlined),
          label: const Text(operationCancelAssemblyLabel),
        ),
      ],
    );
  }
}

/// 播放一次低强度外发光的可用状态提示。
class AvailabilityPulse extends StatefulWidget {
  /// 创建由递增 [pulseToken] 触发的单次脉冲。
  const AvailabilityPulse({
    required this.pulseToken,
    required this.glowKey,
    required this.child,
    super.key,
  });

  /// 每次递增时触发一次动画；初始大于零也不会自动播放。
  final int pulseToken;

  /// 标识可检查发光装饰的 Key。
  final Key glowKey;

  /// 被提示的操作按钮。
  final Widget child;

  @override
  State<AvailabilityPulse> createState() => _AvailabilityPulseState();
}

class _AvailabilityPulseState extends State<AvailabilityPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _availabilityPulseDuration,
    );
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 60),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant AvailabilityPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulseToken > oldWidget.pulseToken && widget.pulseToken > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return DecoratedBox(
          key: widget.glowKey,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.sp(22)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22 * _glow.value),
                blurRadius: context.sp(14) * _glow.value,
                spreadRadius: context.sp(2) * _glow.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// 操作面板统一的高强调操作按钮。
class OperationActionButton extends StatelessWidget {
  /// 创建操作按钮。
  const OperationActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticColor,
    super.key,
  });

  /// 按钮标题。
  final String label;

  /// 按钮图标。
  final IconData icon;

  /// 点击回调；为 null 时按钮禁用。
  final VoidCallback? onPressed;

  /// 可选的协议语义背景色。
  final Color? semanticColor;

  @override
  Widget build(BuildContext context) {
    final background = semanticColor ?? Theme.of(context).colorScheme.primary;
    final foreground = _contrastForeground(background);
    return SizedBox(
      height: context.sp(48),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: context.iconSize(18)),
        label: Text(label),
        style: FilledButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          disabledBackgroundColor: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest,
          elevation: onPressed == null ? 0 : 2,
        ),
      ),
    );
  }

  Color _contrastForeground(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

class _ActionColumn extends StatelessWidget {
  const _ActionColumn({required this.button, this.reason});

  final Widget button;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final text = reason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        SizedBox(height: context.sp(2)),
        SizedBox(
          height: context.sp(18),
          child: text == null
              ? null
              : Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.textTheme.labelSmall,
                ),
        ),
      ],
    );
  }
}

class _QuantityDropdown extends StatelessWidget {
  const _QuantityDropdown({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: context.sp(32),
      padding: EdgeInsets.symmetric(horizontal: context.sp(8)),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(context.sp(10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          items: [
            for (final quantity in _ammoQuantityOptions)
              DropdownMenuItem<int>(
                value: quantity,
                child: Text(operationQuantityText(quantity)),
              ),
          ],
          onChanged: (quantity) {
            if (quantity != null) onChanged(quantity);
          },
        ),
      ),
    );
  }
}

class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.level,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });

  final int level;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final callback = enabled ? onPressed : null;
    if (active) {
      return FilledButton.tonal(
        onPressed: callback,
        child: Text(operationDifficultyLabel(level)),
      );
    }
    return OutlinedButton(
      onPressed: callback,
      child: Text(operationDifficultyLabel(level)),
    );
  }
}

class _StepStatus extends StatelessWidget {
  const _StepStatus({
    required this.done,
    required this.doneText,
    required this.waitingText,
  });

  final bool done;
  final String doneText;
  final String waitingText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(vertical: context.sp(4)),
      decoration: BoxDecoration(
        color: done
            ? rmHealthHighColor.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.sp(8)),
      ),
      child: Text(
        done ? doneText : waitingText,
        textAlign: TextAlign.center,
        style: context.textTheme.labelSmall,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(8),
        vertical: context.sp(4),
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(context.sp(6)),
      ),
      child: Text(text, style: context.textTheme.labelLarge),
    );
  }
}
