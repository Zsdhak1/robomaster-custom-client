/// 按机器人类型展示专属控件的操作面板。
///
/// - 工程：装配难度选择、确认装配切换
/// - 英雄：购买 42mm 弹药、远程购买血量、远程购买弹药
/// - 步兵：购买 17mm 弹药、远程购买血量、远程购买弹药
///
/// 所有命令都通过 MQTT 发布，并根据发送结果给出视觉反馈。
///
/// ## M3 合规性
/// - 使用 `titleSmall`/`bodyMedium`/`labelLarge` 字体角色
/// - `FilledButton` / `OutlinedButton` 遵循 M3 组件规范
/// - 区段标题使用 `surfaceContainerHighest` 色调背景
/// - 保留血量、队伍等协议语义颜色
/// - 触控目标至少 48sp，并保留可读间距
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/protocol_constants.dart';
import '../../../../core/feedback/feedback_messenger.dart';
import '../../../../core/responsive/responsive_ext.dart';
import '../../../../core/state/session_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../generated/robomaster_custom_client.pb.dart';
import '../../../connection/domain/robot_identity.dart';
import '../../logic/stream_providers.dart';

/// 根据已选择机器人 ID 解析当前机器人类型。
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

/// UI 分派使用的机器人类型分类。
enum _RobotType { engineer, hero, infantry, sentry, drone }

const List<int> _ammoQuantityOptions = [10, 20, 30, 50];

/// 带角色专属操作按钮的操作面板。
class OperationPanel extends ConsumerStatefulWidget {
  /// 创建 [OperationPanel]。
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
  int _ammoQuantity = _ammoQuantityOptions.first;

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
      success
          ? context.showSuccessSnack(message)
          : context.showErrorSnack(message);
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
  // 工程面板
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
  // 英雄 / 步兵面板
  // ====================================================================

  Widget _buildHeroPanel(BuildContext context) {
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Padding(
        padding: context.insetOnly(l: 2, r: 2, b: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _ammoPurchaseHeader(context, '英雄 · 42mm'),
          SizedBox(height: context.sp(6)),
          _buttonRow2(
            context,
            _ActionBtn(
              label: '买弹 × $_ammoQuantity',
              icon: Icons.wifi_tethering,
              onPressed: () => _sendCommonCommand(
                1,
                _ammoQuantity,
                '兑换42mm发弹量 × $_ammoQuantity',
              ),
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
      ),
    );
  }

  Widget _buildInfantryPanel(BuildContext context) {
    return SingleChildScrollView(
      clipBehavior: Clip.none,
      child: Padding(
        padding: context.insetOnly(l: 2, r: 2, b: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _ammoPurchaseHeader(context, '步兵 · 17mm'),
          SizedBox(height: context.sp(6)),
          _buttonRow2(
            context,
            _ActionBtn(
              label: '买弹 × $_ammoQuantity',
              icon: Icons.wifi_tethering,
              onPressed: () => _sendCommonCommand(
                1,
                _ammoQuantity,
                '兑换17mm发弹量 × $_ammoQuantity',
              ),
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

  Widget _ammoPurchaseHeader(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _sectionLabel(context, label),
        const Spacer(),
        Text('买弹数量', style: context.textTheme.labelMedium),
        context.sizedBox(w: 6),
        Container(
          height: context.sp(32),
          padding: context.insetSym(h: 8),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(context.sp(10)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _ammoQuantity,
              isDense: true,
              dropdownColor: scheme.surfaceContainerHigh,
              style: context.textTheme.labelLarge!.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
              items: [
                for (final amount in _ammoQuantityOptions)
                  DropdownMenuItem<int>(value: amount, child: Text('$amount')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _ammoQuantity = value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// 辅助函数：区段标签
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
// _PanelHeader 面板标题
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
// _DifficultyButton - 带当前状态的 M3 tonal/outlined 等级按钮
// ====================================================================

/// 带编号的装配难度等级按钮。
///
/// 当前选中状态使用 [FilledButton.tonal]，未选中状态使用 [OutlinedButton]，
/// 以匹配 M3 强调层级。所有尺寸通过 `context.sp` 等比缩放。
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
// _ToggleButton - 带当前状态的 M3 filled-tonal / outlined 切换按钮
// ====================================================================

/// 带当前状态视觉反馈的开关按钮。
///
/// 激活状态使用 [FilledButton.tonalIcon] 和语义绿色背景；非激活状态使用
/// [OutlinedButton.icon]。所有尺寸通过 `context.sp` 等比缩放。
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
// _ActionBtn - 带语义颜色的 M3 outlined 操作按钮
// ====================================================================

/// 使用 [FilledButton.tonalIcon] 的标准行内操作按钮。
///
/// [semanticColor] 会同时着色前景和边框；为 null 时默认使用 [ColorScheme.primary]。
/// 所有尺寸通过 `context.sp` 等比缩放。
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
    final backgroundColor = semanticColor ?? scheme.primary;
    final foregroundColor = _contrastForeground(backgroundColor);
    final borderRadius = context.sp(20);
    final iconSize = context.iconSize(18);

    return SizedBox(
      height: context.sp(48),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(
          label,
          style: context.textTheme.labelLarge!.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: FilledButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.35),
          padding: EdgeInsets.symmetric(horizontal: context.sp(20)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }

  Color _contrastForeground(Color background) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }
}
