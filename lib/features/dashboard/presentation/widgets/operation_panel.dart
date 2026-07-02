/// Operation panel providing robot-type-specific controls.
///
/// - Engineer (工程): Assembly difficulty selection, confirm assembly toggle
/// - Hero (英雄): Buy 42mm ammo, remote health, remote ammo
/// - Infantry (步兵): Buy 17mm ammo, remote health, remote ammo
///
/// All commands are published via MQTT with visual feedback on outcome.
///
/// ## M3 Compliance
/// - Uses `titleSmall`/`bodyMedium`/`labelLarge` type roles
/// - `FilledButton` / `OutlinedButton` per M3 component spec
/// - `surfaceContainerHighest` tonal backgrounds for section headers
/// - Protocol-semantic colors preserved (health, team) per architectural rule
/// - Minimum 48sp touch targets, adequate spacing for readability
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/protocol_constants.dart';
import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/state/session_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../generated/robomaster_custom_client.pb.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../logic/stream_providers.dart';

/// Resolves the current robot type from the selected robot ID.
_RobotType _resolveRobotType(int id) {
  final base = id >= 100 ? id - 100 : id;
  switch (base) {
    case 1:
      return _RobotType.hero;
    case 2:
      return _RobotType.engineer;
    case 3:
    case 4:
      return _RobotType.infantry;
    case 7:
      return _RobotType.sentry;
    default:
      return _RobotType.drone;
  }
}

/// Robot type classification for UI dispatch.
enum _RobotType { engineer, hero, infantry, sentry, drone }

/// Operation panel with role-specific action buttons.
class OperationPanel extends ConsumerStatefulWidget {
  /// Creates an [OperationPanel].
  const OperationPanel({super.key});

  @override
  ConsumerState<OperationPanel> createState() => _OperationPanelState();
}

class _OperationPanelState extends ConsumerState<OperationPanel> {
  String? _lastFeedback;
  bool _lastFeedbackSuccess = false;
  Timer? _feedbackTimer;

  bool _confirmAssemblyActive = false;
  Timer? _confirmAssemblyTimer;

  int? _activeDifficulty;
  Timer? _difficultyTimer;

  bool _coreArrived = false;

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _confirmAssemblyTimer?.cancel();
    _difficultyTimer?.cancel();
    super.dispose();
  }

  void _showFeedback(String message, bool success) {
    _feedbackTimer?.cancel();
    setState(() {
      _lastFeedback = message;
      _lastFeedbackSuccess = success;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 14)),
          backgroundColor: success ? rmSuccessColor : rmHealthLowColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    _feedbackTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _lastFeedback = null);
    });
  }

  void _sendAssemblyCommand(int operation, int difficulty) {
    try {
      ref
          .read(mqttServiceProvider)
          .publish(
            topicAssemblyCommand,
            AssemblyCommand(operation: operation, difficulty: difficulty),
          );
      _showFeedback('✔ 装配指令已发送', true);
    } on Object catch (e) {
      _showFeedback('✘ 发送失败: $e', false);
    }
  }

  void _startDifficultyExchange(int difficulty) {
    _difficultyTimer?.cancel();
    _activeDifficulty = difficulty;
    _coreArrived = false;
    _sendAssemblyCommand(0, difficulty);
    _difficultyTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_coreArrived || !mounted) {
        _difficultyTimer?.cancel();
        if (mounted) setState(() => _activeDifficulty = null);
        return;
      }
      _sendAssemblyCommand(0, difficulty);
    });
  }

  void _stopDifficultyExchange() {
    _difficultyTimer?.cancel();
    setState(() => _activeDifficulty = null);
  }

  void _toggleConfirmAssembly() {
    if (_confirmAssemblyActive) {
      _confirmAssemblyTimer?.cancel();
      setState(() => _confirmAssemblyActive = false);
      _showFeedback('已停止确认装配', true);
    } else {
      setState(() => _confirmAssemblyActive = true);
      _sendAssemblyCommand(1, 0);
      _confirmAssemblyTimer = Timer.periodic(
        const Duration(milliseconds: 300),
        (_) {
          if (!mounted) {
            _confirmAssemblyTimer?.cancel();
            return;
          }
          _sendAssemblyCommand(1, 0);
        },
      );
      _showFeedback('开始持续确认装配', true);
    }
  }

  void _sendCommonCommand(int cmdType, int param, String label) {
    try {
      ref
          .read(mqttServiceProvider)
          .publish(
            topicCommonCommand,
            CommonCommand(cmdType: cmdType, param: param),
          );
      _showFeedback('✔ $label', true);
    } on Object catch (e) {
      _showFeedback('✘ 发送失败: $e', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final robotId = ref.watch(selectedRobotIdProvider);
    final robotType = _resolveRobotType(robotId);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(context.sp(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PanelHeader(
              robotType: robotType,
              robotId: robotId,
              feedback: _lastFeedback,
              feedbackSuccess: _lastFeedbackSuccess,
            ),
            SizedBox(height: context.sp(8)),
            Expanded(
              child: switch (robotType) {
                _RobotType.engineer => _buildEngineerPanel(context),
                _RobotType.hero => _buildHeroPanel(context),
                _RobotType.infantry => _buildInfantryPanel(context),
                _RobotType.sentry ||
                _RobotType.drone => _buildUnsupportedPanel(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // Engineer panel
  // ====================================================================

  Widget _buildEngineerPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAnyActive = _activeDifficulty != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, '装配难度选择'),
          SizedBox(height: context.sp(6)),
          Row(
            children: [
              for (final level in [1, 2, 3, 4]) ...[
                Expanded(
                  child: _DifficultyButton(
                    level: level,
                    isActive: _activeDifficulty == level,
                    onPressed: isAnyActive && _activeDifficulty != level
                        ? null
                        : () {
                            if (_activeDifficulty == level) {
                              _stopDifficultyExchange();
                            } else {
                              _startDifficultyExchange(level);
                            }
                          },
                  ),
                ),
                if (level < 4) SizedBox(width: context.sp(6)),
              ],
            ],
          ),
          SizedBox(height: context.sp(10)),
          Row(
            children: [
              Expanded(
                child: _ToggleButton(
                  label: '确认装配',
                  icon: Icons.check_circle_outline,
                  isActive: _confirmAssemblyActive,
                  onPressed: _toggleConfirmAssembly,
                ),
              ),
              SizedBox(width: context.sp(8)),
              Expanded(
                child: _ActionBtn(
                  label: '取消装配',
                  icon: Icons.cancel_outlined,
                  semanticColor: rmHealthLowColor,
                  onPressed: () {
                    _sendAssemblyCommand(2, 0);
                    _confirmAssemblyTimer?.cancel();
                    setState(() => _confirmAssemblyActive = false);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(10),
              vertical: context.sp(6),
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(context.sp(8)),
            ),
            child: Row(
              children: [
                Icon(
                  _coreArrived ? Icons.check_circle : Icons.hourglass_bottom,
                  size: context.iconSize(16),
                  color: _coreArrived
                      ? rmHealthHighColor
                      : scheme.onSurfaceVariant,
                ),
                SizedBox(width: context.sp(6)),
                Text(
                  _coreArrived ? '科技核心已到达' : '等待科技核心状态…',
                  style: context.textTheme.bodySmall!.copyWith(
                    color: _coreArrived
                        ? rmHealthHighColor
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // Hero / Infantry panels
  // ====================================================================

  Widget _buildHeroPanel(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, '英雄 · 42mm'),
          SizedBox(height: context.sp(6)),
          _buttonRow2(
            context,
            _ActionBtn(
              label: '买弹',
              icon: Icons.wifi_tethering,
              onPressed: () => _sendCommonCommand(1, 10, '兑换42mm发弹量'),
            ),
            _ActionBtn(
              label: '远程买血',
              icon: Icons.favorite,
              semanticColor: rmHealthHighColor,
              onPressed: () => _sendCommonCommand(6, 0, '远程兑换血量'),
            ),
          ),
          SizedBox(height: context.sp(8)),
          _buttonRow2(
            context,
            _ActionBtn(
              label: '远程买弹',
              icon: Icons.shopping_cart,
              onPressed: () => _sendCommonCommand(5, 10, '远程兑换发弹量'),
            ),
            _ActionBtn(
              label: '请求复活',
              icon: Icons.restart_alt,
              semanticColor: rmHealthLowColor,
              onPressed: () => _sendCommonCommand(3, 0, '确认复活'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfantryPanel(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, '步兵 · 17mm'),
          SizedBox(height: context.sp(6)),
          _buttonRow2(
            context,
            _ActionBtn(
              label: '买弹',
              icon: Icons.wifi_tethering,
              onPressed: () => _sendCommonCommand(1, 10, '兑换17mm发弹量'),
            ),
            _ActionBtn(
              label: '远程买血',
              icon: Icons.favorite,
              semanticColor: rmHealthHighColor,
              onPressed: () => _sendCommonCommand(6, 0, '远程兑换血量'),
            ),
          ),
          SizedBox(height: context.sp(8)),
          _buttonRow2(
            context,
            _ActionBtn(
              label: '远程买弹',
              icon: Icons.shopping_cart,
              onPressed: () => _sendCommonCommand(5, 10, '远程兑换发弹量'),
            ),
            _ActionBtn(
              label: '请求复活',
              icon: Icons.restart_alt,
              semanticColor: rmHealthLowColor,
              onPressed: () => _sendCommonCommand(3, 0, '确认复活'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupportedPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: context.iconSize(28),
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(height: context.sp(8)),
          Text(
            '该兵种暂无可用操作',
            style: context.textTheme.bodyMedium!.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttonRow2(BuildContext context, Widget left, Widget right) {
    return Row(
      children: [
        Expanded(child: left),
        SizedBox(width: context.sp(8)),
        Expanded(child: right),
      ],
    );
  }
}

// ====================================================================
// Helper: section label
// ====================================================================

Widget _sectionLabel(BuildContext context, String text) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: context.sp(8),
      vertical: context.sp(4),
    ),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(context.sp(4)),
    ),
    child: Text(
      text,
      style: context.textTheme.labelLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

// ====================================================================
// _PanelHeader
// ====================================================================

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.robotType,
    required this.robotId,
    this.feedback,
    this.feedbackSuccess = false,
  });

  final _RobotType robotType;
  final int robotId;
  final String? feedback;
  final bool feedbackSuccess;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = robotDisplayName(robotId);
    final icon = switch (robotType) {
      _RobotType.engineer => Icons.engineering_rounded,
      _RobotType.hero => Icons.person_rounded,
      _RobotType.infantry => Icons.military_tech_rounded,
      _RobotType.sentry => Icons.security_rounded,
      _RobotType.drone => Icons.flight_rounded,
    };
    return Row(
      children: [
        Icon(icon, size: context.iconSize(20), color: scheme.primary),
        SizedBox(width: context.sp(8)),
        Text(
          '操作 · $name',
          style: context.textTheme.titleSmall!.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (feedback != null)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(6),
              vertical: context.sp(2),
            ),
            decoration: BoxDecoration(
              color: (feedbackSuccess ? rmSuccessColor : rmHealthLowColor)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.sp(4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  feedbackSuccess ? Icons.check_circle : Icons.error,
                  size: context.iconSize(13),
                  color: feedbackSuccess ? rmSuccessColor : rmHealthLowColor,
                ),
                SizedBox(width: context.sp(4)),
                Text(
                  feedback!,
                  style: context.textTheme.labelSmall!.copyWith(
                    color: feedbackSuccess ? rmSuccessColor : rmHealthLowColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ====================================================================
// _DifficultyButton — M3 tonal/outlined level button with active state
// ====================================================================

/// Numbered difficulty level button.
///
/// Uses [FilledButton.tonal] for the active (selected) state and
/// [OutlinedButton] for the inactive state, matching M3 emphasis tiers.
/// All dimensions scale via [context.sp] for proportional fullscreen layout.
class _DifficultyButton extends StatelessWidget {
  const _DifficultyButton({
    required this.level,
    required this.isActive,
    required this.onPressed,
  });

  final int level;
  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = context.sp(20);
    final padding = EdgeInsets.symmetric(horizontal: context.sp(24));

    if (isActive) {
      return SizedBox(
        height: context.sp(48),
        child: FilledButton.tonal(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: Text(
            'Lv.$level',
            style: Theme.of(context).textTheme.labelLarge!.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: context.sp(48),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Text(
          'Lv.$level',
          style: Theme.of(context).textTheme.labelLarge!.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// _ToggleButton — M3 filled-tonal / outlined toggle with active state
// ====================================================================

/// On/off toggle button with active state visualization.
///
/// Active uses [FilledButton.tonalIcon] with semantic green background;
/// inactive uses [OutlinedButton.icon]. All dimensions scale via [context.sp].
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = context.sp(20);
    final iconSize = context.iconSize(18);

    if (isActive) {
      return SizedBox(
        height: context.sp(48),
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(icon, size: iconSize),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: rmHealthHighColor,
            foregroundColor: scheme.onPrimary,
            padding: EdgeInsets.symmetric(horizontal: context.sp(20)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: context.sp(48),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: EdgeInsets.symmetric(horizontal: context.sp(20)),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// _ActionBtn — M3 outlined action button with semantic color
// ====================================================================

/// Standard row action button using [OutlinedButton.icon].
///
/// [semanticColor] tints the foreground and border; defaults to
/// [colorScheme.primary] when null. All dimensions scale via [context.sp].
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticColor,
  });

  final String label;
  final IconData icon;
  final Color? semanticColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fgColor = semanticColor ?? scheme.primary;
    final borderRadius = context.sp(20);
    final iconSize = context.iconSize(18);

    return SizedBox(
      height: context.sp(48),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: fgColor,
          padding: EdgeInsets.symmetric(horizontal: context.sp(20)),
          side: BorderSide(color: fgColor.withValues(alpha: 0.38)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
