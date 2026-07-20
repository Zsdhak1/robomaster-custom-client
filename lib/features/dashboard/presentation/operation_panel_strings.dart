import '../../../core/constants/protocol_constants.dart';
import '../domain/operation_panel_state.dart';

/// 操作面板标题前缀。
const String operationPanelTitlePrefix = '操作';

/// 英雄常规弹丸兑换区标题。
const String operationHeroAmmoTitle = '英雄 · 42mm';

/// 步兵常规弹丸兑换区标题。
const String operationInfantryAmmoTitle = '步兵 · 17mm';

/// 常规兑换数量选择器标题。
const String operationAmmoQuantityLabel = '买弹数量';

/// 远程回血按钮标题。
const String operationRemoteHealLabel = '远程买血';

/// 远程买弹按钮标题。
const String operationRemoteAmmoLabel = '远程买弹';

/// 尚未收到当前机器人动态状态时的禁用原因。
const String operationWaitingTelemetryReason = '等待机器人实时状态';

/// 裁判系统不允许远程回血时的禁用原因。
const String operationRemoteHealUnavailableReason = '裁判系统当前不允许远程回血';

/// 裁判系统不允许远程买弹时的禁用原因。
const String operationRemoteAmmoUnavailableReason = '裁判系统当前不允许远程买弹';

/// 远程操作已可用时的辅助文本。
const String operationAvailableReason = '可立即操作';

/// 尚未收到科技核心状态时的说明。
const String operationTechCoreWaiting = '等待科技核心状态';

/// 科技核心处于初始状态时的说明。
const String operationTechCoreInitial = '科技核心处于初始状态';

/// 科技核心运动中的说明。
const String operationTechCoreMoving = '科技核心运动中';

/// 科技核心已到达的说明。
const String operationTechCoreArrived = '科技核心已到达';

/// 科技核心未知状态的说明。
const String operationTechCoreUnknown = '科技核心状态未知';

/// 工程难度区标题。
const String operationDifficultyTitle = '装配难度';

/// 能量单元已放入。
const String operationPutinDone = '已放入';

/// 等待放入能量单元。
const String operationPutinWaiting = '等待放入';

/// 能量单元已完成平移。
const String operationMoveDone = '已平移';

/// 等待平移能量单元。
const String operationMoveWaiting = '等待平移';

/// 能量单元已完成旋转。
const String operationRotateDone = '已旋转';

/// 等待旋转能量单元。
const String operationRotateWaiting = '等待旋转';

/// 开启自动确认的按钮标题。
const String operationAutoConfirmLabel = '自动确认装配';

/// 停止自动确认的按钮标题。
const String operationStopAutoConfirmLabel = '停止自动确认';

/// 取消装配按钮标题。
const String operationCancelAssemblyLabel = '取消装配';

/// 自动确认行为的准确说明。
const String operationAutoConfirmDescription = '进入兑换流程后持续发送确认装配';

/// 不支持当前机器人时的说明。
const String operationUnsupported = '该兵种暂无可用操作';

/// 返回操作面板完整标题。
String operationPanelTitle(String robotName) {
  return '$operationPanelTitlePrefix · $robotName';
}

/// 返回常规兑换按钮标题。
String operationAmmoButtonLabel(int quantity) => '买弹 × $quantity';

/// 返回数量选择项文字。
String operationQuantityText(int quantity) => '$quantity';

/// 返回难度按钮文字。
String operationDifficultyLabel(int level) => 'Lv.$level';

/// 返回当前最高难度文字。
String operationMaximumDifficultyLabel(int level) => '最高难度 Lv.$level';

/// 返回总剩余时间文字。
String operationTotalTimeLabel(int seconds) => '总剩余 $seconds 秒';

/// 返回步骤剩余时间文字。
String operationStepTimeLabel(int seconds) => '步骤剩余 $seconds 秒';

/// 返回基础运动状态的准确说明。
String operationBasicStateText(int state) {
  return switch (state) {
    techCoreBasicStateInitial => operationTechCoreInitial,
    techCoreBasicStateMoving => operationTechCoreMoving,
    techCoreBasicStateArrived => operationTechCoreArrived,
    _ => operationTechCoreUnknown,
  };
}

/// 返回远程回血按钮当前状态的原因。
String operationRemoteHealReason(OperationPanelState state) {
  if (!state.telemetryKnown) return operationWaitingTelemetryReason;
  return state.remoteHealEnabled
      ? operationAvailableReason
      : operationRemoteHealUnavailableReason;
}

/// 返回远程买弹按钮当前状态的原因。
String operationRemoteAmmoReason(OperationPanelState state) {
  if (!state.telemetryKnown) return operationWaitingTelemetryReason;
  return state.remoteAmmoEnabled
      ? operationAvailableReason
      : operationRemoteAmmoUnavailableReason;
}

/// 将结构化操作反馈转换为用户可读文字。
String operationFeedbackText(OperationFeedback feedback) {
  return switch (feedback.type) {
    OperationFeedbackType.commandSent => '操作指令已发送',
    OperationFeedbackType.autoConfirmArmed => '已开启自动确认，将在进入兑换流程后持续发送确认装配',
    OperationFeedbackType.stopped => '已停止持续发送操作指令',
    OperationFeedbackType.failed => '指令发送失败：${feedback.error ?? '未知错误'}',
  };
}
