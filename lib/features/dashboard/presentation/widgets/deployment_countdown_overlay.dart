/// 英雄部署模式自动跳转的 Material 3 倒计时提示。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/responsive_ext.dart';
import '../../logic/deployment_navigation_controller.dart';
import '../../logic/notification_providers.dart';
import '../../logic/notification_runtime_strings.dart';

/// 覆盖在 AppShell 内容区顶部的部署倒计时卡片。
class DeploymentCountdownOverlay extends ConsumerWidget {
  /// 创建倒计时覆盖层。
  const DeploymentCountdownOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deploymentNavigationProvider);
    if (!state.isVisible) return const SizedBox.shrink();
    return Positioned(
      top: context.sp(16),
      left: context.sp(16),
      right: context.sp(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sp(560)),
          child: _CountdownCard(state: state),
        ),
      ),
    );
  }
}

class _CountdownCard extends ConsumerWidget {
  const _CountdownCard({required this.state});

  final DeploymentNavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final failed = state.phase == DeploymentNavigationPhase.failed;
    return Card(
      color: failed ? scheme.errorContainer : scheme.tertiaryContainer,
      elevation: 0,
      child: Padding(
        padding: context.insetAll(16),
        child: Row(
          children: [
            _CountdownIndicator(state: state),
            context.sizedBox(w: 16),
            Expanded(child: _CountdownCopy(state: state)),
            context.sizedBox(w: 12),
            _CountdownActions(state: state),
          ],
        ),
      ),
    );
  }
}

class _CountdownIndicator extends StatelessWidget {
  const _CountdownIndicator({required this.state});

  final DeploymentNavigationState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preparing = state.phase == DeploymentNavigationPhase.preparing;
    return SizedBox.square(
      dimension: context.sp(56),
      child: preparing
          ? CircularProgressIndicator(color: scheme.onTertiaryContainer)
          : Center(
              child: Text(
                '${state.remainingSeconds}',
                style: context.textTheme.headlineLarge?.copyWith(
                  color: state.phase == DeploymentNavigationPhase.failed
                      ? scheme.onErrorContainer
                      : scheme.onTertiaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

class _CountdownCopy extends StatelessWidget {
  const _CountdownCopy({required this.state});

  final DeploymentNavigationState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = state.phase == DeploymentNavigationPhase.failed;
    final foreground = failed
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    final title = failed
        ? deploymentVideoStartFailedTitle
        : deploymentModeEnteredTitle;
    final detail = state.errorMessage ?? deploymentCountdownDetail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
        context.sizedBox(h: 4),
        Text(
          detail,
          style: context.textTheme.bodyMedium?.copyWith(color: foreground),
        ),
      ],
    );
  }
}

class _CountdownActions extends ConsumerWidget {
  const _CountdownActions({required this.state});

  final DeploymentNavigationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(deploymentNavigationProvider.notifier);
    return Wrap(
      spacing: context.sp(8),
      runSpacing: context.sp(8),
      alignment: WrapAlignment.end,
      children: [
        if (state.config.allowCancel)
          TextButton(
            onPressed: controller.cancel,
            child: const Text(deploymentCancelLabel),
          ),
        if (state.config.showEnterNow ||
            state.phase == DeploymentNavigationPhase.failed)
          FilledButton.icon(
            onPressed: controller.enterNow,
            icon: const Icon(Icons.visibility_rounded),
            label: Text(
              state.phase == DeploymentNavigationPhase.failed
                  ? deploymentRetryLabel
                  : deploymentEnterNowLabel,
            ),
          ),
      ],
    );
  }
}
