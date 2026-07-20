/// 按当前登录机器人身份展示协议驱动的操作面板。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/feedback/feedback_messenger.dart';
import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/state/session_providers.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../domain/operation_panel_state.dart';
import '../../logic/operation_panel_controller.dart';
import '../operation_panel_strings.dart';
import 'operation_panel_sections.dart';

/// 展示当前身份可执行操作和协议状态的副屏面板。
class OperationPanel extends ConsumerWidget {
  /// 创建操作面板。
  const OperationPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final robotId = ref.watch(selectedRobotIdProvider);
    final state = ref.watch(operationPanelControllerProvider);
    final controller = ref.read(operationPanelControllerProvider.notifier);
    ref.listen(operationPanelControllerProvider, (previous, next) {
      _showNewFeedback(context, previous?.feedback, next.feedback);
    });
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: EdgeInsets.all(context.sp(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OperationPanelHeader(robotId: robotId, role: state.role),
            SizedBox(height: context.sp(8)),
            Expanded(
              child: _sectionForRole(state: state, controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionForRole({
  required OperationPanelState state,
  required OperationPanelController controller,
}) {
  return switch (state.role) {
    OperationRobotRole.engineer => EngineerOperationSection(
      state: state,
      onDifficultyPressed: controller.toggleExchange,
      onToggleAutoConfirm: controller.toggleAutoConfirm,
      onCancelAssembly: controller.cancelAssembly,
    ),
    OperationRobotRole.hero ||
    OperationRobotRole.infantry => CombatOperationSection(
      state: state,
      onQuantityChanged: controller.selectAmmoQuantity,
      onExchangeAmmo: controller.exchangeAmmo,
      onRemoteHeal: controller.remoteHeal,
      onRemoteAmmo: controller.remoteAmmo,
    ),
    OperationRobotRole.unsupported => const _UnsupportedOperationSection(),
  };
}

void _showNewFeedback(
  BuildContext context,
  OperationFeedback? previous,
  OperationFeedback? next,
) {
  if (next == null || next.serial == previous?.serial) return;
  final text = operationFeedbackText(next);
  if (next.type == OperationFeedbackType.failed) {
    context.showErrorSnack(text);
  } else {
    context.showSuccessSnack(text);
  }
}

class _OperationPanelHeader extends StatelessWidget {
  const _OperationPanelHeader({required this.robotId, required this.role});

  final int robotId;
  final OperationRobotRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          _roleIcon(role),
          size: context.iconSize(20),
          color: scheme.primary,
        ),
        SizedBox(width: context.sp(8)),
        Text(
          operationPanelTitle(robotDisplayName(robotId)),
          style: context.textTheme.titleSmall,
        ),
      ],
    );
  }
}

IconData _roleIcon(OperationRobotRole role) {
  return switch (role) {
    OperationRobotRole.engineer => Icons.engineering_rounded,
    OperationRobotRole.hero => Icons.person_rounded,
    OperationRobotRole.infantry => Icons.military_tech_rounded,
    OperationRobotRole.unsupported => Icons.info_outline_rounded,
  };
}

class _UnsupportedOperationSection extends StatelessWidget {
  const _UnsupportedOperationSection();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        operationUnsupported,
        style: context.textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
