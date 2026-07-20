import '../../../core/constants/protocol_constants.dart';

/// 操作面板支持区分的机器人职责。
enum OperationRobotRole {
  /// 英雄机器人。
  hero,

  /// 工程机器人。
  engineer,

  /// 步兵机器人。
  infantry,

  /// 当前面板不提供操作的机器人。
  unsupported,
}

/// 将协议机器人 ID 转换为操作面板职责。
OperationRobotRole operationRobotRoleForId(int robotId) {
  final baseId = robotId >= 100 ? robotId - 100 : robotId;
  return switch (baseId) {
    1 => OperationRobotRole.hero,
    2 => OperationRobotRole.engineer,
    3 || 4 => OperationRobotRole.infantry,
    _ => OperationRobotRole.unsupported,
  };
}

/// 科技核心协议状态在操作面板中的不可变表示。
class TechCorePanelState {
  /// 创建已知的科技核心状态。
  const TechCorePanelState({
    required this.maximumDifficulty,
    required this.basicState,
    required this.putinDone,
    required this.moveDone,
    required this.rotateDone,
    required this.remainingTotalSeconds,
    required this.remainingStepSeconds,
  });

  /// 创建尚未收到协议消息时的占位状态。
  const TechCorePanelState.unknown()
    : maximumDifficulty = 0,
      basicState = 0,
      putinDone = false,
      moveDone = false,
      rotateDone = false,
      remainingTotalSeconds = 0,
      remainingStepSeconds = 0;

  /// 当前允许选择的最高装配难度。
  final int maximumDifficulty;

  /// 科技核心基础运动状态。
  final int basicState;

  /// 能量单元是否已经放入。
  final bool putinDone;

  /// 能量单元是否已经完成平移。
  final bool moveDone;

  /// 能量单元是否已经完成旋转。
  final bool rotateDone;

  /// 当前装配流程总剩余秒数。
  final int remainingTotalSeconds;

  /// 当前装配步骤剩余秒数。
  final int remainingStepSeconds;

  /// 三个装配步骤是否全部完成。
  bool get isCompleted => putinDone && moveDone && rotateDone;

  /// 是否处于需要持续确认装配的流程阶段。
  bool get isFlowActive {
    return !isCompleted &&
        (basicState == techCoreBasicStateMoving ||
            basicState == techCoreBasicStateArrived);
  }
}

/// 操作结果反馈的类别。
enum OperationFeedbackType {
  /// 单次操作指令已经发送。
  commandSent,

  /// 自动确认已开启，等待或跟随兑换流程。
  autoConfirmArmed,

  /// 持续发送已经停止。
  stopped,

  /// 指令发布失败。
  failed,
}

/// 可由界面按序号消费一次的结构化操作反馈。
class OperationFeedback {
  /// 创建序号为 [serial] 的反馈。
  const OperationFeedback(this.serial, this.type, [this.error]);

  /// 单调递增的反馈序号。
  final int serial;

  /// 反馈类别。
  final OperationFeedbackType type;

  /// 发布失败时的原始错误。
  final Object? error;
}

const Object _keepOperationValue = Object();

/// 操作面板的完整不可变状态。
class OperationPanelState {
  /// 创建操作面板状态。
  const OperationPanelState({
    this.role = OperationRobotRole.unsupported,
    this.telemetryKnown = false,
    this.remoteHealEnabled = false,
    this.remoteAmmoEnabled = false,
    this.remoteHealPulseToken = 0,
    this.remoteAmmoPulseToken = 0,
    this.ammoQuantity = 10,
    this.autoConfirmArmed = false,
    this.activeDifficulty,
    this.techCoreKnown = false,
    this.techCore = const TechCorePanelState.unknown(),
    this.feedback,
  });

  /// 当前登录身份对应的机器人职责。
  final OperationRobotRole role;

  /// 是否已经收到当前身份的机器人动态状态。
  final bool telemetryKnown;

  /// 裁判系统当前是否允许远程回血。
  final bool remoteHealEnabled;

  /// 裁判系统当前是否允许远程买弹。
  final bool remoteAmmoEnabled;

  /// 远程回血从不可用变为可用的次数。
  final int remoteHealPulseToken;

  /// 远程买弹从不可用变为可用的次数。
  final int remoteAmmoPulseToken;

  /// 常规兑换选择的弹丸数量。
  final int ammoQuantity;

  /// 是否已经开启自动确认装配。
  final bool autoConfirmArmed;

  /// 正在持续发送开始兑换的难度。
  final int? activeDifficulty;

  /// 是否已经收到科技核心状态。
  final bool techCoreKnown;

  /// 最新科技核心基本类型状态。
  final TechCorePanelState techCore;

  /// 最近一次需要界面展示的操作反馈。
  final OperationFeedback? feedback;

  /// 返回替换指定字段后的新状态。
  OperationPanelState copyWith({
    OperationRobotRole? role,
    bool? telemetryKnown,
    bool? remoteHealEnabled,
    bool? remoteAmmoEnabled,
    int? remoteHealPulseToken,
    int? remoteAmmoPulseToken,
    int? ammoQuantity,
    bool? autoConfirmArmed,
    Object? activeDifficulty = _keepOperationValue,
    bool? techCoreKnown,
    TechCorePanelState? techCore,
    Object? feedback = _keepOperationValue,
  }) {
    return OperationPanelState(
      role: role ?? this.role,
      telemetryKnown: telemetryKnown ?? this.telemetryKnown,
      remoteHealEnabled: remoteHealEnabled ?? this.remoteHealEnabled,
      remoteAmmoEnabled: remoteAmmoEnabled ?? this.remoteAmmoEnabled,
      remoteHealPulseToken: remoteHealPulseToken ?? this.remoteHealPulseToken,
      remoteAmmoPulseToken: remoteAmmoPulseToken ?? this.remoteAmmoPulseToken,
      ammoQuantity: ammoQuantity ?? this.ammoQuantity,
      autoConfirmArmed: autoConfirmArmed ?? this.autoConfirmArmed,
      activeDifficulty: identical(activeDifficulty, _keepOperationValue)
          ? this.activeDifficulty
          : activeDifficulty as int?,
      techCoreKnown: techCoreKnown ?? this.techCoreKnown,
      techCore: techCore ?? this.techCore,
      feedback: identical(feedback, _keepOperationValue)
          ? this.feedback
          : feedback as OperationFeedback?,
    );
  }
}
