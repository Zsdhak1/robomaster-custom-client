// This is a generated file - do not edit.
//
// Generated from robomaster_custom_client.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// ============================================================
/// 2.2.1 KeyboardMouseControl
/// 用途：传输鼠标键盘输入
/// Topic: KeyboardMouseControl
/// 方向：自定义客户端 → 图传链路 → 机器人
/// ============================================================
class KeyboardMouseControl extends $pb.GeneratedMessage {
  factory KeyboardMouseControl({
    $core.int? mouseX,
    $core.int? mouseY,
    $core.int? mouseZ,
    $core.bool? leftButtonDown,
    $core.bool? rightButtonDown,
    $core.int? keyboardValue,
    $core.bool? midButtonDown,
  }) {
    final result = create();
    if (mouseX != null) result.mouseX = mouseX;
    if (mouseY != null) result.mouseY = mouseY;
    if (mouseZ != null) result.mouseZ = mouseZ;
    if (leftButtonDown != null) result.leftButtonDown = leftButtonDown;
    if (rightButtonDown != null) result.rightButtonDown = rightButtonDown;
    if (keyboardValue != null) result.keyboardValue = keyboardValue;
    if (midButtonDown != null) result.midButtonDown = midButtonDown;
    return result;
  }

  KeyboardMouseControl._();

  factory KeyboardMouseControl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory KeyboardMouseControl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'KeyboardMouseControl',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'mouseX')
    ..aI(2, _omitFieldNames ? '' : 'mouseY')
    ..aI(3, _omitFieldNames ? '' : 'mouseZ')
    ..aOB(4, _omitFieldNames ? '' : 'leftButtonDown')
    ..aOB(5, _omitFieldNames ? '' : 'rightButtonDown')
    ..aI(6, _omitFieldNames ? '' : 'keyboardValue',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(7, _omitFieldNames ? '' : 'midButtonDown')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyboardMouseControl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  KeyboardMouseControl copyWith(void Function(KeyboardMouseControl) updates) =>
      super.copyWith((message) => updates(message as KeyboardMouseControl))
          as KeyboardMouseControl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static KeyboardMouseControl create() => KeyboardMouseControl._();
  @$core.override
  KeyboardMouseControl createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static KeyboardMouseControl getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<KeyboardMouseControl>(create);
  static KeyboardMouseControl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get mouseX => $_getIZ(0);
  @$pb.TagNumber(1)
  set mouseX($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMouseX() => $_has(0);
  @$pb.TagNumber(1)
  void clearMouseX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get mouseY => $_getIZ(1);
  @$pb.TagNumber(2)
  set mouseY($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMouseY() => $_has(1);
  @$pb.TagNumber(2)
  void clearMouseY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get mouseZ => $_getIZ(2);
  @$pb.TagNumber(3)
  set mouseZ($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMouseZ() => $_has(2);
  @$pb.TagNumber(3)
  void clearMouseZ() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get leftButtonDown => $_getBF(3);
  @$pb.TagNumber(4)
  set leftButtonDown($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLeftButtonDown() => $_has(3);
  @$pb.TagNumber(4)
  void clearLeftButtonDown() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get rightButtonDown => $_getBF(4);
  @$pb.TagNumber(5)
  set rightButtonDown($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRightButtonDown() => $_has(4);
  @$pb.TagNumber(5)
  void clearRightButtonDown() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get keyboardValue => $_getIZ(5);
  @$pb.TagNumber(6)
  set keyboardValue($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasKeyboardValue() => $_has(5);
  @$pb.TagNumber(6)
  void clearKeyboardValue() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get midButtonDown => $_getBF(6);
  @$pb.TagNumber(7)
  set midButtonDown($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMidButtonDown() => $_has(6);
  @$pb.TagNumber(7)
  void clearMidButtonDown() => $_clearField(7);
}

/// ============================================================
/// 2.2.2 CustomControl
/// 用途：最大30字节的自定义数据
/// Topic: CustomControl
/// 方向：自定义客户端 → 图传链路 → 机器人
/// ============================================================
class CustomControl extends $pb.GeneratedMessage {
  factory CustomControl({
    $core.List<$core.int>? data,
  }) {
    final result = create();
    if (data != null) result.data = data;
    return result;
  }

  CustomControl._();

  factory CustomControl.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomControl.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomControl',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomControl clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomControl copyWith(void Function(CustomControl) updates) =>
      super.copyWith((message) => updates(message as CustomControl))
          as CustomControl;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomControl create() => CustomControl._();
  @$core.override
  CustomControl createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomControl getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomControl>(create);
  static CustomControl? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);
}

/// ============================================================
/// 2.2.3 GameStatus
/// 用途：同步比赛全局状态信息
/// Topic: GameStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class GameStatus extends $pb.GeneratedMessage {
  factory GameStatus({
    $core.int? currentRound,
    $core.int? totalRounds,
    $core.int? redScore,
    $core.int? blueScore,
    $core.int? currentStage,
    $core.int? stageCountdownSec,
    $core.int? stageElapsedSec,
    $core.bool? isPaused,
  }) {
    final result = create();
    if (currentRound != null) result.currentRound = currentRound;
    if (totalRounds != null) result.totalRounds = totalRounds;
    if (redScore != null) result.redScore = redScore;
    if (blueScore != null) result.blueScore = blueScore;
    if (currentStage != null) result.currentStage = currentStage;
    if (stageCountdownSec != null) result.stageCountdownSec = stageCountdownSec;
    if (stageElapsedSec != null) result.stageElapsedSec = stageElapsedSec;
    if (isPaused != null) result.isPaused = isPaused;
    return result;
  }

  GameStatus._();

  factory GameStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GameStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GameStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'currentRound',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'totalRounds',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'redScore', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'blueScore', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'currentStage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'stageCountdownSec')
    ..aI(7, _omitFieldNames ? '' : 'stageElapsedSec')
    ..aOB(8, _omitFieldNames ? '' : 'isPaused')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GameStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GameStatus copyWith(void Function(GameStatus) updates) =>
      super.copyWith((message) => updates(message as GameStatus)) as GameStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GameStatus create() => GameStatus._();
  @$core.override
  GameStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GameStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GameStatus>(create);
  static GameStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get currentRound => $_getIZ(0);
  @$pb.TagNumber(1)
  set currentRound($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrentRound() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrentRound() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalRounds => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalRounds($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalRounds() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalRounds() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get redScore => $_getIZ(2);
  @$pb.TagNumber(3)
  set redScore($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRedScore() => $_has(2);
  @$pb.TagNumber(3)
  void clearRedScore() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get blueScore => $_getIZ(3);
  @$pb.TagNumber(4)
  set blueScore($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBlueScore() => $_has(3);
  @$pb.TagNumber(4)
  void clearBlueScore() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get currentStage => $_getIZ(4);
  @$pb.TagNumber(5)
  set currentStage($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrentStage() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrentStage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get stageCountdownSec => $_getIZ(5);
  @$pb.TagNumber(6)
  set stageCountdownSec($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStageCountdownSec() => $_has(5);
  @$pb.TagNumber(6)
  void clearStageCountdownSec() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get stageElapsedSec => $_getIZ(6);
  @$pb.TagNumber(7)
  set stageElapsedSec($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasStageElapsedSec() => $_has(6);
  @$pb.TagNumber(7)
  void clearStageElapsedSec() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isPaused => $_getBF(7);
  @$pb.TagNumber(8)
  set isPaused($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsPaused() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsPaused() => $_clearField(8);
}

/// ============================================================
/// 2.2.4 GlobalUnitStatus
/// 用途：同步基地、前哨站和所有机器人状态
/// Topic: GlobalUnitStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class GlobalUnitStatus extends $pb.GeneratedMessage {
  factory GlobalUnitStatus({
    $core.int? baseHealth,
    $core.int? baseStatus,
    $core.int? baseShield,
    $core.int? outpostHealth,
    $core.int? outpostStatus,
    $core.int? enemyBaseHealth,
    $core.int? enemyBaseStatus,
    $core.int? enemyBaseShield,
    $core.int? enemyOutpostHealth,
    $core.int? enemyOutpostStatus,
    $core.Iterable<$core.int>? robotHealth,
    $core.Iterable<$core.int>? robotBullets,
    $core.int? totalDamageAlly,
    $core.int? totalDamageEnemy,
  }) {
    final result = create();
    if (baseHealth != null) result.baseHealth = baseHealth;
    if (baseStatus != null) result.baseStatus = baseStatus;
    if (baseShield != null) result.baseShield = baseShield;
    if (outpostHealth != null) result.outpostHealth = outpostHealth;
    if (outpostStatus != null) result.outpostStatus = outpostStatus;
    if (enemyBaseHealth != null) result.enemyBaseHealth = enemyBaseHealth;
    if (enemyBaseStatus != null) result.enemyBaseStatus = enemyBaseStatus;
    if (enemyBaseShield != null) result.enemyBaseShield = enemyBaseShield;
    if (enemyOutpostHealth != null)
      result.enemyOutpostHealth = enemyOutpostHealth;
    if (enemyOutpostStatus != null)
      result.enemyOutpostStatus = enemyOutpostStatus;
    if (robotHealth != null) result.robotHealth.addAll(robotHealth);
    if (robotBullets != null) result.robotBullets.addAll(robotBullets);
    if (totalDamageAlly != null) result.totalDamageAlly = totalDamageAlly;
    if (totalDamageEnemy != null) result.totalDamageEnemy = totalDamageEnemy;
    return result;
  }

  GlobalUnitStatus._();

  factory GlobalUnitStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GlobalUnitStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GlobalUnitStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'baseHealth', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'baseStatus', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'baseShield', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'outpostHealth',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'outpostStatus',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'enemyBaseHealth',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'enemyBaseStatus',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'enemyBaseShield',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'enemyOutpostHealth',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'enemyOutpostStatus',
        fieldType: $pb.PbFieldType.OU3)
    ..p<$core.int>(
        11, _omitFieldNames ? '' : 'robotHealth', $pb.PbFieldType.KU3)
    ..p<$core.int>(
        12, _omitFieldNames ? '' : 'robotBullets', $pb.PbFieldType.K3)
    ..aI(13, _omitFieldNames ? '' : 'totalDamageAlly',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(14, _omitFieldNames ? '' : 'totalDamageEnemy',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GlobalUnitStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GlobalUnitStatus copyWith(void Function(GlobalUnitStatus) updates) =>
      super.copyWith((message) => updates(message as GlobalUnitStatus))
          as GlobalUnitStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GlobalUnitStatus create() => GlobalUnitStatus._();
  @$core.override
  GlobalUnitStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GlobalUnitStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GlobalUnitStatus>(create);
  static GlobalUnitStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get baseHealth => $_getIZ(0);
  @$pb.TagNumber(1)
  set baseHealth($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBaseHealth() => $_has(0);
  @$pb.TagNumber(1)
  void clearBaseHealth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get baseStatus => $_getIZ(1);
  @$pb.TagNumber(2)
  set baseStatus($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBaseStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearBaseStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get baseShield => $_getIZ(2);
  @$pb.TagNumber(3)
  set baseShield($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBaseShield() => $_has(2);
  @$pb.TagNumber(3)
  void clearBaseShield() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get outpostHealth => $_getIZ(3);
  @$pb.TagNumber(4)
  set outpostHealth($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOutpostHealth() => $_has(3);
  @$pb.TagNumber(4)
  void clearOutpostHealth() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get outpostStatus => $_getIZ(4);
  @$pb.TagNumber(5)
  set outpostStatus($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOutpostStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearOutpostStatus() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get enemyBaseHealth => $_getIZ(5);
  @$pb.TagNumber(6)
  set enemyBaseHealth($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnemyBaseHealth() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnemyBaseHealth() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get enemyBaseStatus => $_getIZ(6);
  @$pb.TagNumber(7)
  set enemyBaseStatus($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEnemyBaseStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearEnemyBaseStatus() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get enemyBaseShield => $_getIZ(7);
  @$pb.TagNumber(8)
  set enemyBaseShield($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasEnemyBaseShield() => $_has(7);
  @$pb.TagNumber(8)
  void clearEnemyBaseShield() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get enemyOutpostHealth => $_getIZ(8);
  @$pb.TagNumber(9)
  set enemyOutpostHealth($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasEnemyOutpostHealth() => $_has(8);
  @$pb.TagNumber(9)
  void clearEnemyOutpostHealth() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get enemyOutpostStatus => $_getIZ(9);
  @$pb.TagNumber(10)
  set enemyOutpostStatus($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEnemyOutpostStatus() => $_has(9);
  @$pb.TagNumber(10)
  void clearEnemyOutpostStatus() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.int> get robotHealth => $_getList(10);

  @$pb.TagNumber(12)
  $pb.PbList<$core.int> get robotBullets => $_getList(11);

  @$pb.TagNumber(13)
  $core.int get totalDamageAlly => $_getIZ(12);
  @$pb.TagNumber(13)
  set totalDamageAlly($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasTotalDamageAlly() => $_has(12);
  @$pb.TagNumber(13)
  void clearTotalDamageAlly() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get totalDamageEnemy => $_getIZ(13);
  @$pb.TagNumber(14)
  set totalDamageEnemy($core.int value) => $_setUnsignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasTotalDamageEnemy() => $_has(13);
  @$pb.TagNumber(14)
  void clearTotalDamageEnemy() => $_clearField(14);
}

/// ============================================================
/// 2.2.5 GlobalLogisticsStatus
/// 用途：同步全局后勤信息
/// Topic: GlobalLogisticsStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class GlobalLogisticsStatus extends $pb.GeneratedMessage {
  factory GlobalLogisticsStatus({
    $core.int? remainingEconomy,
    $fixnum.Int64? totalEconomyObtained,
    $core.int? techLevel,
    $core.int? encryptionLevel,
  }) {
    final result = create();
    if (remainingEconomy != null) result.remainingEconomy = remainingEconomy;
    if (totalEconomyObtained != null)
      result.totalEconomyObtained = totalEconomyObtained;
    if (techLevel != null) result.techLevel = techLevel;
    if (encryptionLevel != null) result.encryptionLevel = encryptionLevel;
    return result;
  }

  GlobalLogisticsStatus._();

  factory GlobalLogisticsStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GlobalLogisticsStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GlobalLogisticsStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'remainingEconomy',
        fieldType: $pb.PbFieldType.OU3)
    ..a<$fixnum.Int64>(
        2, _omitFieldNames ? '' : 'totalEconomyObtained', $pb.PbFieldType.OU6,
        defaultOrMaker: $fixnum.Int64.ZERO)
    ..aI(3, _omitFieldNames ? '' : 'techLevel', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'encryptionLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GlobalLogisticsStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GlobalLogisticsStatus copyWith(
          void Function(GlobalLogisticsStatus) updates) =>
      super.copyWith((message) => updates(message as GlobalLogisticsStatus))
          as GlobalLogisticsStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GlobalLogisticsStatus create() => GlobalLogisticsStatus._();
  @$core.override
  GlobalLogisticsStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GlobalLogisticsStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GlobalLogisticsStatus>(create);
  static GlobalLogisticsStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get remainingEconomy => $_getIZ(0);
  @$pb.TagNumber(1)
  set remainingEconomy($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRemainingEconomy() => $_has(0);
  @$pb.TagNumber(1)
  void clearRemainingEconomy() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalEconomyObtained => $_getI64(1);
  @$pb.TagNumber(2)
  set totalEconomyObtained($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalEconomyObtained() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalEconomyObtained() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get techLevel => $_getIZ(2);
  @$pb.TagNumber(3)
  set techLevel($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTechLevel() => $_has(2);
  @$pb.TagNumber(3)
  void clearTechLevel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get encryptionLevel => $_getIZ(3);
  @$pb.TagNumber(4)
  set encryptionLevel($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEncryptionLevel() => $_has(3);
  @$pb.TagNumber(4)
  void clearEncryptionLevel() => $_clearField(4);
}

/// ============================================================
/// 2.2.6 GlobalSpecialMechanism
/// 用途：同步正在生效的全局特殊机制
/// Topic: GlobalSpecialMechanism
/// 方向：服务器 → 自定义客户端
/// ============================================================
class GlobalSpecialMechanism extends $pb.GeneratedMessage {
  factory GlobalSpecialMechanism({
    $core.Iterable<$core.int>? mechanismId,
    $core.Iterable<$core.int>? mechanismTimeSec,
  }) {
    final result = create();
    if (mechanismId != null) result.mechanismId.addAll(mechanismId);
    if (mechanismTimeSec != null)
      result.mechanismTimeSec.addAll(mechanismTimeSec);
    return result;
  }

  GlobalSpecialMechanism._();

  factory GlobalSpecialMechanism.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GlobalSpecialMechanism.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GlobalSpecialMechanism',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'mechanismId', $pb.PbFieldType.KU3)
    ..p<$core.int>(
        2, _omitFieldNames ? '' : 'mechanismTimeSec', $pb.PbFieldType.K3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GlobalSpecialMechanism clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GlobalSpecialMechanism copyWith(
          void Function(GlobalSpecialMechanism) updates) =>
      super.copyWith((message) => updates(message as GlobalSpecialMechanism))
          as GlobalSpecialMechanism;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GlobalSpecialMechanism create() => GlobalSpecialMechanism._();
  @$core.override
  GlobalSpecialMechanism createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GlobalSpecialMechanism getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GlobalSpecialMechanism>(create);
  static GlobalSpecialMechanism? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get mechanismId => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get mechanismTimeSec => $_getList(1);
}

/// ============================================================
/// 2.2.7 Event
/// 用途：全局事件通知
/// Topic: Event
/// 方向：服务器 → 自定义客户端
/// ============================================================
class Event extends $pb.GeneratedMessage {
  factory Event({
    $core.int? eventId,
    $core.String? param,
  }) {
    final result = create();
    if (eventId != null) result.eventId = eventId;
    if (param != null) result.param = param;
    return result;
  }

  Event._();

  factory Event.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Event.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'eventId')
    ..aOS(2, _omitFieldNames ? '' : 'param')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event copyWith(void Function(Event) updates) =>
      super.copyWith((message) => updates(message as Event)) as Event;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Event create() => Event._();
  @$core.override
  Event createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Event getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Event>(create);
  static Event? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get eventId => $_getIZ(0);
  @$pb.TagNumber(1)
  set eventId($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEventId() => $_has(0);
  @$pb.TagNumber(1)
  void clearEventId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get param => $_getSZ(1);
  @$pb.TagNumber(2)
  set param($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParam() => $_has(1);
  @$pb.TagNumber(2)
  void clearParam() => $_clearField(2);
}

/// ============================================================
/// 2.2.8 RobotInjuryStat
/// 用途：机器人一次存活期间累计受伤统计
/// Topic: RobotInjuryStat
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotInjuryStat extends $pb.GeneratedMessage {
  factory RobotInjuryStat({
    $core.int? totalDamage,
    $core.int? collisionDamage,
    $core.int? smallProjectileDamage,
    $core.int? largeProjectileDamage,
    $core.int? dartSplashDamage,
    $core.int? moduleOfflineDamage,
    $core.int? offlineDamage,
    $core.int? penaltyDamage,
    $core.int? serverKillDamage,
    $core.int? killerId,
  }) {
    final result = create();
    if (totalDamage != null) result.totalDamage = totalDamage;
    if (collisionDamage != null) result.collisionDamage = collisionDamage;
    if (smallProjectileDamage != null)
      result.smallProjectileDamage = smallProjectileDamage;
    if (largeProjectileDamage != null)
      result.largeProjectileDamage = largeProjectileDamage;
    if (dartSplashDamage != null) result.dartSplashDamage = dartSplashDamage;
    if (moduleOfflineDamage != null)
      result.moduleOfflineDamage = moduleOfflineDamage;
    if (offlineDamage != null) result.offlineDamage = offlineDamage;
    if (penaltyDamage != null) result.penaltyDamage = penaltyDamage;
    if (serverKillDamage != null) result.serverKillDamage = serverKillDamage;
    if (killerId != null) result.killerId = killerId;
    return result;
  }

  RobotInjuryStat._();

  factory RobotInjuryStat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotInjuryStat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotInjuryStat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'totalDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'collisionDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'smallProjectileDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'largeProjectileDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'dartSplashDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'moduleOfflineDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'offlineDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'penaltyDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'serverKillDamage',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'killerId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotInjuryStat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotInjuryStat copyWith(void Function(RobotInjuryStat) updates) =>
      super.copyWith((message) => updates(message as RobotInjuryStat))
          as RobotInjuryStat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotInjuryStat create() => RobotInjuryStat._();
  @$core.override
  RobotInjuryStat createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotInjuryStat getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotInjuryStat>(create);
  static RobotInjuryStat? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get totalDamage => $_getIZ(0);
  @$pb.TagNumber(1)
  set totalDamage($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalDamage() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalDamage() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get collisionDamage => $_getIZ(1);
  @$pb.TagNumber(2)
  set collisionDamage($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCollisionDamage() => $_has(1);
  @$pb.TagNumber(2)
  void clearCollisionDamage() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get smallProjectileDamage => $_getIZ(2);
  @$pb.TagNumber(3)
  set smallProjectileDamage($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSmallProjectileDamage() => $_has(2);
  @$pb.TagNumber(3)
  void clearSmallProjectileDamage() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get largeProjectileDamage => $_getIZ(3);
  @$pb.TagNumber(4)
  set largeProjectileDamage($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLargeProjectileDamage() => $_has(3);
  @$pb.TagNumber(4)
  void clearLargeProjectileDamage() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get dartSplashDamage => $_getIZ(4);
  @$pb.TagNumber(5)
  set dartSplashDamage($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDartSplashDamage() => $_has(4);
  @$pb.TagNumber(5)
  void clearDartSplashDamage() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get moduleOfflineDamage => $_getIZ(5);
  @$pb.TagNumber(6)
  set moduleOfflineDamage($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasModuleOfflineDamage() => $_has(5);
  @$pb.TagNumber(6)
  void clearModuleOfflineDamage() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get offlineDamage => $_getIZ(6);
  @$pb.TagNumber(7)
  set offlineDamage($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOfflineDamage() => $_has(6);
  @$pb.TagNumber(7)
  void clearOfflineDamage() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get penaltyDamage => $_getIZ(7);
  @$pb.TagNumber(8)
  set penaltyDamage($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPenaltyDamage() => $_has(7);
  @$pb.TagNumber(8)
  void clearPenaltyDamage() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get serverKillDamage => $_getIZ(8);
  @$pb.TagNumber(9)
  set serverKillDamage($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasServerKillDamage() => $_has(8);
  @$pb.TagNumber(9)
  void clearServerKillDamage() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get killerId => $_getIZ(9);
  @$pb.TagNumber(10)
  set killerId($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasKillerId() => $_has(9);
  @$pb.TagNumber(10)
  void clearKillerId() => $_clearField(10);
}

/// ============================================================
/// 2.2.9 RobotRespawnStatus
/// 用途：机器人复活状态同步
/// Topic: RobotRespawnStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotRespawnStatus extends $pb.GeneratedMessage {
  factory RobotRespawnStatus({
    $core.bool? isPendingRespawn,
    $core.int? totalRespawnProgress,
    $core.int? currentRespawnProgress,
    $core.bool? canFreeRespawn,
    $core.int? goldCostForRespawn,
    $core.bool? canPayForRespawn,
  }) {
    final result = create();
    if (isPendingRespawn != null) result.isPendingRespawn = isPendingRespawn;
    if (totalRespawnProgress != null)
      result.totalRespawnProgress = totalRespawnProgress;
    if (currentRespawnProgress != null)
      result.currentRespawnProgress = currentRespawnProgress;
    if (canFreeRespawn != null) result.canFreeRespawn = canFreeRespawn;
    if (goldCostForRespawn != null)
      result.goldCostForRespawn = goldCostForRespawn;
    if (canPayForRespawn != null) result.canPayForRespawn = canPayForRespawn;
    return result;
  }

  RobotRespawnStatus._();

  factory RobotRespawnStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotRespawnStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotRespawnStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'isPendingRespawn')
    ..aI(2, _omitFieldNames ? '' : 'totalRespawnProgress',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'currentRespawnProgress',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'canFreeRespawn')
    ..aI(5, _omitFieldNames ? '' : 'goldCostForRespawn',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(6, _omitFieldNames ? '' : 'canPayForRespawn')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotRespawnStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotRespawnStatus copyWith(void Function(RobotRespawnStatus) updates) =>
      super.copyWith((message) => updates(message as RobotRespawnStatus))
          as RobotRespawnStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotRespawnStatus create() => RobotRespawnStatus._();
  @$core.override
  RobotRespawnStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotRespawnStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotRespawnStatus>(create);
  static RobotRespawnStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get isPendingRespawn => $_getBF(0);
  @$pb.TagNumber(1)
  set isPendingRespawn($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsPendingRespawn() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsPendingRespawn() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get totalRespawnProgress => $_getIZ(1);
  @$pb.TagNumber(2)
  set totalRespawnProgress($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalRespawnProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalRespawnProgress() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get currentRespawnProgress => $_getIZ(2);
  @$pb.TagNumber(3)
  set currentRespawnProgress($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrentRespawnProgress() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrentRespawnProgress() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get canFreeRespawn => $_getBF(3);
  @$pb.TagNumber(4)
  set canFreeRespawn($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCanFreeRespawn() => $_has(3);
  @$pb.TagNumber(4)
  void clearCanFreeRespawn() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get goldCostForRespawn => $_getIZ(4);
  @$pb.TagNumber(5)
  set goldCostForRespawn($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGoldCostForRespawn() => $_has(4);
  @$pb.TagNumber(5)
  void clearGoldCostForRespawn() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get canPayForRespawn => $_getBF(5);
  @$pb.TagNumber(6)
  set canPayForRespawn($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCanPayForRespawn() => $_has(5);
  @$pb.TagNumber(6)
  void clearCanPayForRespawn() => $_clearField(6);
}

/// ============================================================
/// 2.2.10 RobotStaticStatus
/// 用途：机器人固定属性和配置
/// Topic: RobotStaticStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotStaticStatus extends $pb.GeneratedMessage {
  factory RobotStaticStatus({
    $core.int? connectionState,
    $core.int? fieldState,
    $core.int? aliveState,
    $core.int? robotId,
    $core.int? robotType,
    $core.int? performanceSystemShooter,
    $core.int? performanceSystemChassis,
    $core.int? level,
    $core.int? maxHealth,
    $core.int? maxHeat,
    $core.double? heatCooldownRate,
    $core.int? maxPower,
    $core.int? maxBufferEnergy,
    $core.int? maxChassisEnergy,
  }) {
    final result = create();
    if (connectionState != null) result.connectionState = connectionState;
    if (fieldState != null) result.fieldState = fieldState;
    if (aliveState != null) result.aliveState = aliveState;
    if (robotId != null) result.robotId = robotId;
    if (robotType != null) result.robotType = robotType;
    if (performanceSystemShooter != null)
      result.performanceSystemShooter = performanceSystemShooter;
    if (performanceSystemChassis != null)
      result.performanceSystemChassis = performanceSystemChassis;
    if (level != null) result.level = level;
    if (maxHealth != null) result.maxHealth = maxHealth;
    if (maxHeat != null) result.maxHeat = maxHeat;
    if (heatCooldownRate != null) result.heatCooldownRate = heatCooldownRate;
    if (maxPower != null) result.maxPower = maxPower;
    if (maxBufferEnergy != null) result.maxBufferEnergy = maxBufferEnergy;
    if (maxChassisEnergy != null) result.maxChassisEnergy = maxChassisEnergy;
    return result;
  }

  RobotStaticStatus._();

  factory RobotStaticStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotStaticStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotStaticStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'connectionState',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'fieldState', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'aliveState', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'robotId', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'robotType', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'performanceSystemShooter',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'performanceSystemChassis',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'level', fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'maxHealth', fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'maxHeat', fieldType: $pb.PbFieldType.OU3)
    ..aD(11, _omitFieldNames ? '' : 'heatCooldownRate',
        fieldType: $pb.PbFieldType.OF)
    ..aI(12, _omitFieldNames ? '' : 'maxPower', fieldType: $pb.PbFieldType.OU3)
    ..aI(13, _omitFieldNames ? '' : 'maxBufferEnergy',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(14, _omitFieldNames ? '' : 'maxChassisEnergy',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotStaticStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotStaticStatus copyWith(void Function(RobotStaticStatus) updates) =>
      super.copyWith((message) => updates(message as RobotStaticStatus))
          as RobotStaticStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotStaticStatus create() => RobotStaticStatus._();
  @$core.override
  RobotStaticStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotStaticStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotStaticStatus>(create);
  static RobotStaticStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get connectionState => $_getIZ(0);
  @$pb.TagNumber(1)
  set connectionState($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConnectionState() => $_has(0);
  @$pb.TagNumber(1)
  void clearConnectionState() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get fieldState => $_getIZ(1);
  @$pb.TagNumber(2)
  set fieldState($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFieldState() => $_has(1);
  @$pb.TagNumber(2)
  void clearFieldState() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get aliveState => $_getIZ(2);
  @$pb.TagNumber(3)
  set aliveState($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAliveState() => $_has(2);
  @$pb.TagNumber(3)
  void clearAliveState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get robotId => $_getIZ(3);
  @$pb.TagNumber(4)
  set robotId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRobotId() => $_has(3);
  @$pb.TagNumber(4)
  void clearRobotId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get robotType => $_getIZ(4);
  @$pb.TagNumber(5)
  set robotType($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRobotType() => $_has(4);
  @$pb.TagNumber(5)
  void clearRobotType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get performanceSystemShooter => $_getIZ(5);
  @$pb.TagNumber(6)
  set performanceSystemShooter($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPerformanceSystemShooter() => $_has(5);
  @$pb.TagNumber(6)
  void clearPerformanceSystemShooter() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get performanceSystemChassis => $_getIZ(6);
  @$pb.TagNumber(7)
  set performanceSystemChassis($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPerformanceSystemChassis() => $_has(6);
  @$pb.TagNumber(7)
  void clearPerformanceSystemChassis() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get level => $_getIZ(7);
  @$pb.TagNumber(8)
  set level($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLevel() => $_has(7);
  @$pb.TagNumber(8)
  void clearLevel() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get maxHealth => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxHealth($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxHealth() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxHealth() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get maxHeat => $_getIZ(9);
  @$pb.TagNumber(10)
  set maxHeat($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMaxHeat() => $_has(9);
  @$pb.TagNumber(10)
  void clearMaxHeat() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.double get heatCooldownRate => $_getN(10);
  @$pb.TagNumber(11)
  set heatCooldownRate($core.double value) => $_setFloat(10, value);
  @$pb.TagNumber(11)
  $core.bool hasHeatCooldownRate() => $_has(10);
  @$pb.TagNumber(11)
  void clearHeatCooldownRate() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get maxPower => $_getIZ(11);
  @$pb.TagNumber(12)
  set maxPower($core.int value) => $_setUnsignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasMaxPower() => $_has(11);
  @$pb.TagNumber(12)
  void clearMaxPower() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get maxBufferEnergy => $_getIZ(12);
  @$pb.TagNumber(13)
  set maxBufferEnergy($core.int value) => $_setUnsignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasMaxBufferEnergy() => $_has(12);
  @$pb.TagNumber(13)
  void clearMaxBufferEnergy() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get maxChassisEnergy => $_getIZ(13);
  @$pb.TagNumber(14)
  set maxChassisEnergy($core.int value) => $_setUnsignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasMaxChassisEnergy() => $_has(13);
  @$pb.TagNumber(14)
  void clearMaxChassisEnergy() => $_clearField(14);
}

/// ============================================================
/// 2.2.11 RobotDynamicStatus
/// 用途：机器人实时数据
/// Topic: RobotDynamicStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotDynamicStatus extends $pb.GeneratedMessage {
  factory RobotDynamicStatus({
    $core.int? currentHealth,
    $core.double? currentHeat,
    $core.double? lastProjectileFireRate,
    $core.int? currentChassisEnergy,
    $core.int? currentBufferEnergy,
    $core.int? currentExperience,
    $core.int? experienceForUpgrade,
    $core.int? totalProjectilesFired,
    $core.int? remainingAmmo,
    $core.bool? isOutOfCombat,
    $core.int? outOfCombatCountdown,
    $core.bool? canRemoteHeal,
    $core.bool? canRemoteAmmo,
  }) {
    final result = create();
    if (currentHealth != null) result.currentHealth = currentHealth;
    if (currentHeat != null) result.currentHeat = currentHeat;
    if (lastProjectileFireRate != null)
      result.lastProjectileFireRate = lastProjectileFireRate;
    if (currentChassisEnergy != null)
      result.currentChassisEnergy = currentChassisEnergy;
    if (currentBufferEnergy != null)
      result.currentBufferEnergy = currentBufferEnergy;
    if (currentExperience != null) result.currentExperience = currentExperience;
    if (experienceForUpgrade != null)
      result.experienceForUpgrade = experienceForUpgrade;
    if (totalProjectilesFired != null)
      result.totalProjectilesFired = totalProjectilesFired;
    if (remainingAmmo != null) result.remainingAmmo = remainingAmmo;
    if (isOutOfCombat != null) result.isOutOfCombat = isOutOfCombat;
    if (outOfCombatCountdown != null)
      result.outOfCombatCountdown = outOfCombatCountdown;
    if (canRemoteHeal != null) result.canRemoteHeal = canRemoteHeal;
    if (canRemoteAmmo != null) result.canRemoteAmmo = canRemoteAmmo;
    return result;
  }

  RobotDynamicStatus._();

  factory RobotDynamicStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotDynamicStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotDynamicStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'currentHealth',
        fieldType: $pb.PbFieldType.OU3)
    ..aD(2, _omitFieldNames ? '' : 'currentHeat', fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'lastProjectileFireRate',
        fieldType: $pb.PbFieldType.OF)
    ..aI(4, _omitFieldNames ? '' : 'currentChassisEnergy',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'currentBufferEnergy',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'currentExperience',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'experienceForUpgrade',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'totalProjectilesFired',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'remainingAmmo',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(10, _omitFieldNames ? '' : 'isOutOfCombat')
    ..aI(11, _omitFieldNames ? '' : 'outOfCombatCountdown',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(12, _omitFieldNames ? '' : 'canRemoteHeal')
    ..aOB(13, _omitFieldNames ? '' : 'canRemoteAmmo')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotDynamicStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotDynamicStatus copyWith(void Function(RobotDynamicStatus) updates) =>
      super.copyWith((message) => updates(message as RobotDynamicStatus))
          as RobotDynamicStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotDynamicStatus create() => RobotDynamicStatus._();
  @$core.override
  RobotDynamicStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotDynamicStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotDynamicStatus>(create);
  static RobotDynamicStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get currentHealth => $_getIZ(0);
  @$pb.TagNumber(1)
  set currentHealth($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrentHealth() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrentHealth() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get currentHeat => $_getN(1);
  @$pb.TagNumber(2)
  set currentHeat($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCurrentHeat() => $_has(1);
  @$pb.TagNumber(2)
  void clearCurrentHeat() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get lastProjectileFireRate => $_getN(2);
  @$pb.TagNumber(3)
  set lastProjectileFireRate($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastProjectileFireRate() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastProjectileFireRate() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get currentChassisEnergy => $_getIZ(3);
  @$pb.TagNumber(4)
  set currentChassisEnergy($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrentChassisEnergy() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrentChassisEnergy() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get currentBufferEnergy => $_getIZ(4);
  @$pb.TagNumber(5)
  set currentBufferEnergy($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrentBufferEnergy() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrentBufferEnergy() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get currentExperience => $_getIZ(5);
  @$pb.TagNumber(6)
  set currentExperience($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrentExperience() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrentExperience() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get experienceForUpgrade => $_getIZ(6);
  @$pb.TagNumber(7)
  set experienceForUpgrade($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExperienceForUpgrade() => $_has(6);
  @$pb.TagNumber(7)
  void clearExperienceForUpgrade() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get totalProjectilesFired => $_getIZ(7);
  @$pb.TagNumber(8)
  set totalProjectilesFired($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTotalProjectilesFired() => $_has(7);
  @$pb.TagNumber(8)
  void clearTotalProjectilesFired() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get remainingAmmo => $_getIZ(8);
  @$pb.TagNumber(9)
  set remainingAmmo($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasRemainingAmmo() => $_has(8);
  @$pb.TagNumber(9)
  void clearRemainingAmmo() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isOutOfCombat => $_getBF(9);
  @$pb.TagNumber(10)
  set isOutOfCombat($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsOutOfCombat() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsOutOfCombat() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get outOfCombatCountdown => $_getIZ(10);
  @$pb.TagNumber(11)
  set outOfCombatCountdown($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasOutOfCombatCountdown() => $_has(10);
  @$pb.TagNumber(11)
  void clearOutOfCombatCountdown() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get canRemoteHeal => $_getBF(11);
  @$pb.TagNumber(12)
  set canRemoteHeal($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCanRemoteHeal() => $_has(11);
  @$pb.TagNumber(12)
  void clearCanRemoteHeal() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get canRemoteAmmo => $_getBF(12);
  @$pb.TagNumber(13)
  set canRemoteAmmo($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCanRemoteAmmo() => $_has(12);
  @$pb.TagNumber(13)
  void clearCanRemoteAmmo() => $_clearField(13);
}

/// ============================================================
/// 2.2.12 RobotModuleStatus
/// 用途：机器人各模块运行状态
/// Topic: RobotModuleStatus
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotModuleStatus extends $pb.GeneratedMessage {
  factory RobotModuleStatus({
    $core.int? powerManager,
    $core.int? rfid,
    $core.int? lightStrip,
    $core.int? smallShooter,
    $core.int? bigShooter,
    $core.int? uwb,
    $core.int? armor,
    $core.int? videoTransmission,
    $core.int? capacitor,
    $core.int? mainController,
    $core.int? laserDetectionModule,
  }) {
    final result = create();
    if (powerManager != null) result.powerManager = powerManager;
    if (rfid != null) result.rfid = rfid;
    if (lightStrip != null) result.lightStrip = lightStrip;
    if (smallShooter != null) result.smallShooter = smallShooter;
    if (bigShooter != null) result.bigShooter = bigShooter;
    if (uwb != null) result.uwb = uwb;
    if (armor != null) result.armor = armor;
    if (videoTransmission != null) result.videoTransmission = videoTransmission;
    if (capacitor != null) result.capacitor = capacitor;
    if (mainController != null) result.mainController = mainController;
    if (laserDetectionModule != null)
      result.laserDetectionModule = laserDetectionModule;
    return result;
  }

  RobotModuleStatus._();

  factory RobotModuleStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotModuleStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotModuleStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'powerManager',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'rfid', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'lightStrip', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'smallShooter',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'bigShooter', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'uwb', fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'armor', fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'videoTransmission',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(9, _omitFieldNames ? '' : 'capacitor', fieldType: $pb.PbFieldType.OU3)
    ..aI(10, _omitFieldNames ? '' : 'mainController',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(11, _omitFieldNames ? '' : 'laserDetectionModule',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotModuleStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotModuleStatus copyWith(void Function(RobotModuleStatus) updates) =>
      super.copyWith((message) => updates(message as RobotModuleStatus))
          as RobotModuleStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotModuleStatus create() => RobotModuleStatus._();
  @$core.override
  RobotModuleStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotModuleStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotModuleStatus>(create);
  static RobotModuleStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get powerManager => $_getIZ(0);
  @$pb.TagNumber(1)
  set powerManager($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPowerManager() => $_has(0);
  @$pb.TagNumber(1)
  void clearPowerManager() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rfid => $_getIZ(1);
  @$pb.TagNumber(2)
  set rfid($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRfid() => $_has(1);
  @$pb.TagNumber(2)
  void clearRfid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get lightStrip => $_getIZ(2);
  @$pb.TagNumber(3)
  set lightStrip($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLightStrip() => $_has(2);
  @$pb.TagNumber(3)
  void clearLightStrip() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get smallShooter => $_getIZ(3);
  @$pb.TagNumber(4)
  set smallShooter($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSmallShooter() => $_has(3);
  @$pb.TagNumber(4)
  void clearSmallShooter() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get bigShooter => $_getIZ(4);
  @$pb.TagNumber(5)
  set bigShooter($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBigShooter() => $_has(4);
  @$pb.TagNumber(5)
  void clearBigShooter() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get uwb => $_getIZ(5);
  @$pb.TagNumber(6)
  set uwb($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUwb() => $_has(5);
  @$pb.TagNumber(6)
  void clearUwb() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get armor => $_getIZ(6);
  @$pb.TagNumber(7)
  set armor($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasArmor() => $_has(6);
  @$pb.TagNumber(7)
  void clearArmor() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get videoTransmission => $_getIZ(7);
  @$pb.TagNumber(8)
  set videoTransmission($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVideoTransmission() => $_has(7);
  @$pb.TagNumber(8)
  void clearVideoTransmission() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get capacitor => $_getIZ(8);
  @$pb.TagNumber(9)
  set capacitor($core.int value) => $_setUnsignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCapacitor() => $_has(8);
  @$pb.TagNumber(9)
  void clearCapacitor() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get mainController => $_getIZ(9);
  @$pb.TagNumber(10)
  set mainController($core.int value) => $_setUnsignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMainController() => $_has(9);
  @$pb.TagNumber(10)
  void clearMainController() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get laserDetectionModule => $_getIZ(10);
  @$pb.TagNumber(11)
  set laserDetectionModule($core.int value) => $_setUnsignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasLaserDetectionModule() => $_has(10);
  @$pb.TagNumber(11)
  void clearLaserDetectionModule() => $_clearField(11);
}

/// ============================================================
/// 2.2.13 RobotPosition
/// 用途：机器人空间坐标和朝向
/// Topic: RobotPosition
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotPosition extends $pb.GeneratedMessage {
  factory RobotPosition({
    $core.double? x,
    $core.double? y,
    $core.double? z,
    $core.double? yaw,
    $core.int? robotId,
  }) {
    final result = create();
    if (x != null) result.x = x;
    if (y != null) result.y = y;
    if (z != null) result.z = z;
    if (yaw != null) result.yaw = yaw;
    if (robotId != null) result.robotId = robotId;
    return result;
  }

  RobotPosition._();

  factory RobotPosition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotPosition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotPosition',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'x', fieldType: $pb.PbFieldType.OF)
    ..aD(2, _omitFieldNames ? '' : 'y', fieldType: $pb.PbFieldType.OF)
    ..aD(3, _omitFieldNames ? '' : 'z', fieldType: $pb.PbFieldType.OF)
    ..aD(4, _omitFieldNames ? '' : 'yaw', fieldType: $pb.PbFieldType.OF)
    ..aI(5, _omitFieldNames ? '' : 'robotId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPosition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPosition copyWith(void Function(RobotPosition) updates) =>
      super.copyWith((message) => updates(message as RobotPosition))
          as RobotPosition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotPosition create() => RobotPosition._();
  @$core.override
  RobotPosition createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotPosition getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotPosition>(create);
  static RobotPosition? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get x => $_getN(0);
  @$pb.TagNumber(1)
  set x($core.double value) => $_setFloat(0, value);
  @$pb.TagNumber(1)
  $core.bool hasX() => $_has(0);
  @$pb.TagNumber(1)
  void clearX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get y => $_getN(1);
  @$pb.TagNumber(2)
  set y($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasY() => $_has(1);
  @$pb.TagNumber(2)
  void clearY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get z => $_getN(2);
  @$pb.TagNumber(3)
  set z($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasZ() => $_has(2);
  @$pb.TagNumber(3)
  void clearZ() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get yaw => $_getN(3);
  @$pb.TagNumber(4)
  set yaw($core.double value) => $_setFloat(3, value);
  @$pb.TagNumber(4)
  $core.bool hasYaw() => $_has(3);
  @$pb.TagNumber(4)
  void clearYaw() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get robotId => $_getIZ(4);
  @$pb.TagNumber(5)
  set robotId($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRobotId() => $_has(4);
  @$pb.TagNumber(5)
  void clearRobotId() => $_clearField(5);
}

/// ============================================================
/// 2.2.14 Buff
/// 用途：Buff效果信息
/// Topic: Buff
/// 方向：服务器 → 自定义客户端
/// ============================================================
class Buff extends $pb.GeneratedMessage {
  factory Buff({
    $core.int? robotId,
    $core.int? buffType,
    $core.int? buffLevel,
    $core.int? buffMaxTime,
    $core.int? buffLeftTime,
  }) {
    final result = create();
    if (robotId != null) result.robotId = robotId;
    if (buffType != null) result.buffType = buffType;
    if (buffLevel != null) result.buffLevel = buffLevel;
    if (buffMaxTime != null) result.buffMaxTime = buffMaxTime;
    if (buffLeftTime != null) result.buffLeftTime = buffLeftTime;
    return result;
  }

  Buff._();

  factory Buff.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Buff.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Buff',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'robotId', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'buffType', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'buffLevel')
    ..aI(4, _omitFieldNames ? '' : 'buffMaxTime',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'buffLeftTime',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Buff clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Buff copyWith(void Function(Buff) updates) =>
      super.copyWith((message) => updates(message as Buff)) as Buff;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Buff create() => Buff._();
  @$core.override
  Buff createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Buff getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Buff>(create);
  static Buff? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get robotId => $_getIZ(0);
  @$pb.TagNumber(1)
  set robotId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRobotId() => $_has(0);
  @$pb.TagNumber(1)
  void clearRobotId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get buffType => $_getIZ(1);
  @$pb.TagNumber(2)
  set buffType($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBuffType() => $_has(1);
  @$pb.TagNumber(2)
  void clearBuffType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get buffLevel => $_getIZ(2);
  @$pb.TagNumber(3)
  set buffLevel($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBuffLevel() => $_has(2);
  @$pb.TagNumber(3)
  void clearBuffLevel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get buffMaxTime => $_getIZ(3);
  @$pb.TagNumber(4)
  set buffMaxTime($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBuffMaxTime() => $_has(3);
  @$pb.TagNumber(4)
  void clearBuffMaxTime() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get buffLeftTime => $_getIZ(4);
  @$pb.TagNumber(5)
  set buffLeftTime($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBuffLeftTime() => $_has(4);
  @$pb.TagNumber(5)
  void clearBuffLeftTime() => $_clearField(5);
}

/// ============================================================
/// 2.2.15 PenaltyInfo
/// 用途：判罚信息同步
/// Topic: PenaltyInfo
/// 方向：服务器 → 自定义客户端
/// ============================================================
class PenaltyInfo extends $pb.GeneratedMessage {
  factory PenaltyInfo({
    $core.int? penaltyType,
    $core.int? penaltyEffectSec,
    $core.int? totalPenaltyNum,
  }) {
    final result = create();
    if (penaltyType != null) result.penaltyType = penaltyType;
    if (penaltyEffectSec != null) result.penaltyEffectSec = penaltyEffectSec;
    if (totalPenaltyNum != null) result.totalPenaltyNum = totalPenaltyNum;
    return result;
  }

  PenaltyInfo._();

  factory PenaltyInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PenaltyInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PenaltyInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'penaltyType',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'penaltyEffectSec',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'totalPenaltyNum',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PenaltyInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PenaltyInfo copyWith(void Function(PenaltyInfo) updates) =>
      super.copyWith((message) => updates(message as PenaltyInfo))
          as PenaltyInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PenaltyInfo create() => PenaltyInfo._();
  @$core.override
  PenaltyInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PenaltyInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PenaltyInfo>(create);
  static PenaltyInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get penaltyType => $_getIZ(0);
  @$pb.TagNumber(1)
  set penaltyType($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPenaltyType() => $_has(0);
  @$pb.TagNumber(1)
  void clearPenaltyType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get penaltyEffectSec => $_getIZ(1);
  @$pb.TagNumber(2)
  set penaltyEffectSec($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPenaltyEffectSec() => $_has(1);
  @$pb.TagNumber(2)
  void clearPenaltyEffectSec() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get totalPenaltyNum => $_getIZ(2);
  @$pb.TagNumber(3)
  set totalPenaltyNum($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalPenaltyNum() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalPenaltyNum() => $_clearField(3);
}

/// ============================================================
/// 2.2.16 RobotPathPlanInfo
/// 用途：哨兵轨迹规划信息
/// Topic: RobotPathPlanInfo
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotPathPlanInfo extends $pb.GeneratedMessage {
  factory RobotPathPlanInfo({
    $core.int? intention,
    $core.int? startPosX,
    $core.int? startPosY,
    $core.Iterable<$core.int>? offsetX,
    $core.Iterable<$core.int>? offsetY,
    $core.int? senderId,
  }) {
    final result = create();
    if (intention != null) result.intention = intention;
    if (startPosX != null) result.startPosX = startPosX;
    if (startPosY != null) result.startPosY = startPosY;
    if (offsetX != null) result.offsetX.addAll(offsetX);
    if (offsetY != null) result.offsetY.addAll(offsetY);
    if (senderId != null) result.senderId = senderId;
    return result;
  }

  RobotPathPlanInfo._();

  factory RobotPathPlanInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotPathPlanInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotPathPlanInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'intention', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'startPosX', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'startPosY', fieldType: $pb.PbFieldType.OU3)
    ..p<$core.int>(4, _omitFieldNames ? '' : 'offsetX', $pb.PbFieldType.K3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'offsetY', $pb.PbFieldType.K3)
    ..aI(6, _omitFieldNames ? '' : 'senderId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPathPlanInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPathPlanInfo copyWith(void Function(RobotPathPlanInfo) updates) =>
      super.copyWith((message) => updates(message as RobotPathPlanInfo))
          as RobotPathPlanInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotPathPlanInfo create() => RobotPathPlanInfo._();
  @$core.override
  RobotPathPlanInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotPathPlanInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotPathPlanInfo>(create);
  static RobotPathPlanInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get intention => $_getIZ(0);
  @$pb.TagNumber(1)
  set intention($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIntention() => $_has(0);
  @$pb.TagNumber(1)
  void clearIntention() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get startPosX => $_getIZ(1);
  @$pb.TagNumber(2)
  set startPosX($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartPosX() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartPosX() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get startPosY => $_getIZ(2);
  @$pb.TagNumber(3)
  set startPosY($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStartPosY() => $_has(2);
  @$pb.TagNumber(3)
  void clearStartPosY() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get offsetX => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get offsetY => $_getList(4);

  @$pb.TagNumber(6)
  $core.int get senderId => $_getIZ(5);
  @$pb.TagNumber(6)
  set senderId($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSenderId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSenderId() => $_clearField(6);
}

/// ============================================================
/// 2.2.17 MapClickInfo
/// 用途：地图点击标记信息同步
/// Topic: MapClickInfo
/// 方向：服务器 → 自定义客户端
/// ============================================================
class MapClickInfo extends $pb.GeneratedMessage {
  factory MapClickInfo({
    $core.int? isSendAll,
    $core.List<$core.int>? robotId,
    $core.int? mode,
    $core.int? enemyId,
    $core.int? ascii,
    $core.int? type,
    $core.double? mapX,
    $core.double? mapY,
  }) {
    final result = create();
    if (isSendAll != null) result.isSendAll = isSendAll;
    if (robotId != null) result.robotId = robotId;
    if (mode != null) result.mode = mode;
    if (enemyId != null) result.enemyId = enemyId;
    if (ascii != null) result.ascii = ascii;
    if (type != null) result.type = type;
    if (mapX != null) result.mapX = mapX;
    if (mapY != null) result.mapY = mapY;
    return result;
  }

  MapClickInfo._();

  factory MapClickInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MapClickInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MapClickInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'isSendAll', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'robotId', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'mode', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'enemyId', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'ascii', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'type', fieldType: $pb.PbFieldType.OU3)
    ..aD(7, _omitFieldNames ? '' : 'mapX', fieldType: $pb.PbFieldType.OF)
    ..aD(8, _omitFieldNames ? '' : 'mapY', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapClickInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapClickInfo copyWith(void Function(MapClickInfo) updates) =>
      super.copyWith((message) => updates(message as MapClickInfo))
          as MapClickInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MapClickInfo create() => MapClickInfo._();
  @$core.override
  MapClickInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MapClickInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MapClickInfo>(create);
  static MapClickInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get isSendAll => $_getIZ(0);
  @$pb.TagNumber(1)
  set isSendAll($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsSendAll() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsSendAll() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get robotId => $_getN(1);
  @$pb.TagNumber(2)
  set robotId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRobotId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRobotId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get mode => $_getIZ(2);
  @$pb.TagNumber(3)
  set mode($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get enemyId => $_getIZ(3);
  @$pb.TagNumber(4)
  set enemyId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnemyId() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnemyId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get ascii => $_getIZ(4);
  @$pb.TagNumber(5)
  set ascii($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAscii() => $_has(4);
  @$pb.TagNumber(5)
  void clearAscii() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get type => $_getIZ(5);
  @$pb.TagNumber(6)
  set type($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasType() => $_has(5);
  @$pb.TagNumber(6)
  void clearType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get mapX => $_getN(6);
  @$pb.TagNumber(7)
  set mapX($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMapX() => $_has(6);
  @$pb.TagNumber(7)
  void clearMapX() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get mapY => $_getN(7);
  @$pb.TagNumber(8)
  set mapY($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMapY() => $_has(7);
  @$pb.TagNumber(8)
  void clearMapY() => $_clearField(8);
}

/// ============================================================
/// 2.2.18 MapClickCmd
/// 用途：地图点击标记指令
/// Topic: MapClickCmd
/// 方向：自定义客户端 → 服务器
/// ============================================================
class MapClickCmd extends $pb.GeneratedMessage {
  factory MapClickCmd({
    $core.int? isSendAll,
    $core.List<$core.int>? robotId,
    $core.int? mode,
    $core.int? enemyId,
    $core.int? ascii,
    $core.int? type,
    $core.double? mapX,
    $core.double? mapY,
  }) {
    final result = create();
    if (isSendAll != null) result.isSendAll = isSendAll;
    if (robotId != null) result.robotId = robotId;
    if (mode != null) result.mode = mode;
    if (enemyId != null) result.enemyId = enemyId;
    if (ascii != null) result.ascii = ascii;
    if (type != null) result.type = type;
    if (mapX != null) result.mapX = mapX;
    if (mapY != null) result.mapY = mapY;
    return result;
  }

  MapClickCmd._();

  factory MapClickCmd.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MapClickCmd.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MapClickCmd',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'isSendAll', fieldType: $pb.PbFieldType.OU3)
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'robotId', $pb.PbFieldType.OY)
    ..aI(3, _omitFieldNames ? '' : 'mode', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'enemyId', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'ascii', fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'type', fieldType: $pb.PbFieldType.OU3)
    ..aD(7, _omitFieldNames ? '' : 'mapX', fieldType: $pb.PbFieldType.OF)
    ..aD(8, _omitFieldNames ? '' : 'mapY', fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapClickCmd clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MapClickCmd copyWith(void Function(MapClickCmd) updates) =>
      super.copyWith((message) => updates(message as MapClickCmd))
          as MapClickCmd;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MapClickCmd create() => MapClickCmd._();
  @$core.override
  MapClickCmd createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MapClickCmd getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MapClickCmd>(create);
  static MapClickCmd? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get isSendAll => $_getIZ(0);
  @$pb.TagNumber(1)
  set isSendAll($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIsSendAll() => $_has(0);
  @$pb.TagNumber(1)
  void clearIsSendAll() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get robotId => $_getN(1);
  @$pb.TagNumber(2)
  set robotId($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRobotId() => $_has(1);
  @$pb.TagNumber(2)
  void clearRobotId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get mode => $_getIZ(2);
  @$pb.TagNumber(3)
  set mode($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get enemyId => $_getIZ(3);
  @$pb.TagNumber(4)
  set enemyId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnemyId() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnemyId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get ascii => $_getIZ(4);
  @$pb.TagNumber(5)
  set ascii($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAscii() => $_has(4);
  @$pb.TagNumber(5)
  void clearAscii() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get type => $_getIZ(5);
  @$pb.TagNumber(6)
  set type($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasType() => $_has(5);
  @$pb.TagNumber(6)
  void clearType() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get mapX => $_getN(6);
  @$pb.TagNumber(7)
  set mapX($core.double value) => $_setFloat(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMapX() => $_has(6);
  @$pb.TagNumber(7)
  void clearMapX() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.double get mapY => $_getN(7);
  @$pb.TagNumber(8)
  set mapY($core.double value) => $_setFloat(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMapY() => $_has(7);
  @$pb.TagNumber(8)
  void clearMapY() => $_clearField(8);
}

/// ============================================================
/// 2.2.19 RadarInfoToClient
/// 用途：雷达发送的机器人位置信息
/// Topic: RadarInfoToClient
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RadarSingleRobotInfo extends $pb.GeneratedMessage {
  factory RadarSingleRobotInfo({
    $core.int? targetPosX,
    $core.int? targetPosY,
    $core.int? isHighLight,
  }) {
    final result = create();
    if (targetPosX != null) result.targetPosX = targetPosX;
    if (targetPosY != null) result.targetPosY = targetPosY;
    if (isHighLight != null) result.isHighLight = isHighLight;
    return result;
  }

  RadarSingleRobotInfo._();

  factory RadarSingleRobotInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RadarSingleRobotInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RadarSingleRobotInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'targetPosX', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'targetPosY', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'isHighLight',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadarSingleRobotInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadarSingleRobotInfo copyWith(void Function(RadarSingleRobotInfo) updates) =>
      super.copyWith((message) => updates(message as RadarSingleRobotInfo))
          as RadarSingleRobotInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RadarSingleRobotInfo create() => RadarSingleRobotInfo._();
  @$core.override
  RadarSingleRobotInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RadarSingleRobotInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RadarSingleRobotInfo>(create);
  static RadarSingleRobotInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get targetPosX => $_getIZ(0);
  @$pb.TagNumber(1)
  set targetPosX($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetPosX() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetPosX() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get targetPosY => $_getIZ(1);
  @$pb.TagNumber(2)
  set targetPosY($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetPosY() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetPosY() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get isHighLight => $_getIZ(2);
  @$pb.TagNumber(3)
  set isHighLight($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIsHighLight() => $_has(2);
  @$pb.TagNumber(3)
  void clearIsHighLight() => $_clearField(3);
}

class RadarInfoToClient extends $pb.GeneratedMessage {
  factory RadarInfoToClient({
    $core.Iterable<RadarSingleRobotInfo>? radarInfo,
  }) {
    final result = create();
    if (radarInfo != null) result.radarInfo.addAll(radarInfo);
    return result;
  }

  RadarInfoToClient._();

  factory RadarInfoToClient.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RadarInfoToClient.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RadarInfoToClient',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..pPM<RadarSingleRobotInfo>(1, _omitFieldNames ? '' : 'radarInfo',
        subBuilder: RadarSingleRobotInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadarInfoToClient clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RadarInfoToClient copyWith(void Function(RadarInfoToClient) updates) =>
      super.copyWith((message) => updates(message as RadarInfoToClient))
          as RadarInfoToClient;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RadarInfoToClient create() => RadarInfoToClient._();
  @$core.override
  RadarInfoToClient createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RadarInfoToClient getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RadarInfoToClient>(create);
  static RadarInfoToClient? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RadarSingleRobotInfo> get radarInfo => $_getList(0);
}

/// ============================================================
/// 2.2.20 CustomByteBlock
/// 用途：自定义数据流
/// Topic: CustomByteBlock
/// 方向：自定义客户端 → 图传链路 → 机器人
/// ============================================================
class CustomByteBlock extends $pb.GeneratedMessage {
  factory CustomByteBlock({
    $core.List<$core.int>? data,
    $core.int? isFrameStart,
  }) {
    final result = create();
    if (data != null) result.data = data;
    if (isFrameStart != null) result.isFrameStart = isFrameStart;
    return result;
  }

  CustomByteBlock._();

  factory CustomByteBlock.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CustomByteBlock.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CustomByteBlock',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aI(2, _omitFieldNames ? '' : 'isFrameStart',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomByteBlock clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CustomByteBlock copyWith(void Function(CustomByteBlock) updates) =>
      super.copyWith((message) => updates(message as CustomByteBlock))
          as CustomByteBlock;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CustomByteBlock create() => CustomByteBlock._();
  @$core.override
  CustomByteBlock createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CustomByteBlock getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CustomByteBlock>(create);
  static CustomByteBlock? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get isFrameStart => $_getIZ(1);
  @$pb.TagNumber(2)
  set isFrameStart($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsFrameStart() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsFrameStart() => $_clearField(2);
}

/// ============================================================
/// 2.2.21 AssemblyCommand
/// 用途：工程装配指令
/// Topic: AssemblyCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class AssemblyCommand extends $pb.GeneratedMessage {
  factory AssemblyCommand({
    $core.int? operation,
    $core.int? difficulty,
  }) {
    final result = create();
    if (operation != null) result.operation = operation;
    if (difficulty != null) result.difficulty = difficulty;
    return result;
  }

  AssemblyCommand._();

  factory AssemblyCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AssemblyCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AssemblyCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'operation', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'difficulty', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssemblyCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AssemblyCommand copyWith(void Function(AssemblyCommand) updates) =>
      super.copyWith((message) => updates(message as AssemblyCommand))
          as AssemblyCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AssemblyCommand create() => AssemblyCommand._();
  @$core.override
  AssemblyCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AssemblyCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AssemblyCommand>(create);
  static AssemblyCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get operation => $_getIZ(0);
  @$pb.TagNumber(1)
  set operation($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOperation() => $_has(0);
  @$pb.TagNumber(1)
  void clearOperation() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get difficulty => $_getIZ(1);
  @$pb.TagNumber(2)
  set difficulty($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDifficulty() => $_has(1);
  @$pb.TagNumber(2)
  void clearDifficulty() => $_clearField(2);
}

/// ============================================================
/// 2.2.22 TechCoreMotionStateSync
/// 用途：科技核心运动状态同步
/// Topic: TechCoreMotionStateSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class TechCoreMotionStateSync extends $pb.GeneratedMessage {
  factory TechCoreMotionStateSync({
    $core.int? maximumDifficultyLevel,
    $core.int? basicState,
    $core.int? putinState,
    $core.int? moveState,
    $core.int? rotateState,
    $core.int? enemyCoreStatus,
    $core.int? remainTimeAll,
    $core.int? remainTimeStep,
  }) {
    final result = create();
    if (maximumDifficultyLevel != null)
      result.maximumDifficultyLevel = maximumDifficultyLevel;
    if (basicState != null) result.basicState = basicState;
    if (putinState != null) result.putinState = putinState;
    if (moveState != null) result.moveState = moveState;
    if (rotateState != null) result.rotateState = rotateState;
    if (enemyCoreStatus != null) result.enemyCoreStatus = enemyCoreStatus;
    if (remainTimeAll != null) result.remainTimeAll = remainTimeAll;
    if (remainTimeStep != null) result.remainTimeStep = remainTimeStep;
    return result;
  }

  TechCoreMotionStateSync._();

  factory TechCoreMotionStateSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TechCoreMotionStateSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TechCoreMotionStateSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'maximumDifficultyLevel',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'basicState', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'putinState', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'moveState', fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'rotateState',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(6, _omitFieldNames ? '' : 'enemyCoreStatus',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(7, _omitFieldNames ? '' : 'remainTimeAll',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(8, _omitFieldNames ? '' : 'remainTimeStep',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TechCoreMotionStateSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TechCoreMotionStateSync copyWith(
          void Function(TechCoreMotionStateSync) updates) =>
      super.copyWith((message) => updates(message as TechCoreMotionStateSync))
          as TechCoreMotionStateSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TechCoreMotionStateSync create() => TechCoreMotionStateSync._();
  @$core.override
  TechCoreMotionStateSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TechCoreMotionStateSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TechCoreMotionStateSync>(create);
  static TechCoreMotionStateSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get maximumDifficultyLevel => $_getIZ(0);
  @$pb.TagNumber(1)
  set maximumDifficultyLevel($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMaximumDifficultyLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearMaximumDifficultyLevel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get basicState => $_getIZ(1);
  @$pb.TagNumber(2)
  set basicState($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBasicState() => $_has(1);
  @$pb.TagNumber(2)
  void clearBasicState() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get putinState => $_getIZ(2);
  @$pb.TagNumber(3)
  set putinState($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPutinState() => $_has(2);
  @$pb.TagNumber(3)
  void clearPutinState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get moveState => $_getIZ(3);
  @$pb.TagNumber(4)
  set moveState($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMoveState() => $_has(3);
  @$pb.TagNumber(4)
  void clearMoveState() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get rotateState => $_getIZ(4);
  @$pb.TagNumber(5)
  set rotateState($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRotateState() => $_has(4);
  @$pb.TagNumber(5)
  void clearRotateState() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get enemyCoreStatus => $_getIZ(5);
  @$pb.TagNumber(6)
  set enemyCoreStatus($core.int value) => $_setUnsignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnemyCoreStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnemyCoreStatus() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get remainTimeAll => $_getIZ(6);
  @$pb.TagNumber(7)
  set remainTimeAll($core.int value) => $_setUnsignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRemainTimeAll() => $_has(6);
  @$pb.TagNumber(7)
  void clearRemainTimeAll() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get remainTimeStep => $_getIZ(7);
  @$pb.TagNumber(8)
  set remainTimeStep($core.int value) => $_setUnsignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRemainTimeStep() => $_has(7);
  @$pb.TagNumber(8)
  void clearRemainTimeStep() => $_clearField(8);
}

/// ============================================================
/// 2.2.23 RobotPerformanceSelectionCommand
/// 用途：地面机器人选择性能体系或控制方式
/// Topic: RobotPerformanceSelectionCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class RobotPerformanceSelectionCommand extends $pb.GeneratedMessage {
  factory RobotPerformanceSelectionCommand({
    $core.int? shooter,
    $core.int? chassis,
    $core.int? sentryControl,
  }) {
    final result = create();
    if (shooter != null) result.shooter = shooter;
    if (chassis != null) result.chassis = chassis;
    if (sentryControl != null) result.sentryControl = sentryControl;
    return result;
  }

  RobotPerformanceSelectionCommand._();

  factory RobotPerformanceSelectionCommand.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotPerformanceSelectionCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotPerformanceSelectionCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'shooter', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'chassis', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'sentryControl',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPerformanceSelectionCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPerformanceSelectionCommand copyWith(
          void Function(RobotPerformanceSelectionCommand) updates) =>
      super.copyWith(
              (message) => updates(message as RobotPerformanceSelectionCommand))
          as RobotPerformanceSelectionCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotPerformanceSelectionCommand create() =>
      RobotPerformanceSelectionCommand._();
  @$core.override
  RobotPerformanceSelectionCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotPerformanceSelectionCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotPerformanceSelectionCommand>(
          create);
  static RobotPerformanceSelectionCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get shooter => $_getIZ(0);
  @$pb.TagNumber(1)
  set shooter($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShooter() => $_has(0);
  @$pb.TagNumber(1)
  void clearShooter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get chassis => $_getIZ(1);
  @$pb.TagNumber(2)
  set chassis($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChassis() => $_has(1);
  @$pb.TagNumber(2)
  void clearChassis() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get sentryControl => $_getIZ(2);
  @$pb.TagNumber(3)
  set sentryControl($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSentryControl() => $_has(2);
  @$pb.TagNumber(3)
  void clearSentryControl() => $_clearField(3);
}

/// ============================================================
/// 2.2.24 RobotPerformanceSelectionSync
/// 用途：步兵/英雄性能体系状态同步
/// Topic: RobotPerformanceSelectionSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RobotPerformanceSelectionSync extends $pb.GeneratedMessage {
  factory RobotPerformanceSelectionSync({
    $core.int? shooter,
    $core.int? chassis,
    $core.int? sentryControl,
  }) {
    final result = create();
    if (shooter != null) result.shooter = shooter;
    if (chassis != null) result.chassis = chassis;
    if (sentryControl != null) result.sentryControl = sentryControl;
    return result;
  }

  RobotPerformanceSelectionSync._();

  factory RobotPerformanceSelectionSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RobotPerformanceSelectionSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RobotPerformanceSelectionSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'shooter', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'chassis', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'sentryControl',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPerformanceSelectionSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RobotPerformanceSelectionSync copyWith(
          void Function(RobotPerformanceSelectionSync) updates) =>
      super.copyWith(
              (message) => updates(message as RobotPerformanceSelectionSync))
          as RobotPerformanceSelectionSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RobotPerformanceSelectionSync create() =>
      RobotPerformanceSelectionSync._();
  @$core.override
  RobotPerformanceSelectionSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RobotPerformanceSelectionSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RobotPerformanceSelectionSync>(create);
  static RobotPerformanceSelectionSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get shooter => $_getIZ(0);
  @$pb.TagNumber(1)
  set shooter($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShooter() => $_has(0);
  @$pb.TagNumber(1)
  void clearShooter() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get chassis => $_getIZ(1);
  @$pb.TagNumber(2)
  set chassis($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChassis() => $_has(1);
  @$pb.TagNumber(2)
  void clearChassis() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get sentryControl => $_getIZ(2);
  @$pb.TagNumber(3)
  set sentryControl($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSentryControl() => $_has(2);
  @$pb.TagNumber(3)
  void clearSentryControl() => $_clearField(3);
}

/// ============================================================
/// 2.2.25 CommonCommand
/// 用途：机器人多种常用指令
/// Topic: CommonCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class CommonCommand extends $pb.GeneratedMessage {
  factory CommonCommand({
    $core.int? cmdType,
    $core.int? param,
  }) {
    final result = create();
    if (cmdType != null) result.cmdType = cmdType;
    if (param != null) result.param = param;
    return result;
  }

  CommonCommand._();

  factory CommonCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommonCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommonCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'cmdType', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'param', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommonCommand copyWith(void Function(CommonCommand) updates) =>
      super.copyWith((message) => updates(message as CommonCommand))
          as CommonCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommonCommand create() => CommonCommand._();
  @$core.override
  CommonCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommonCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommonCommand>(create);
  static CommonCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get cmdType => $_getIZ(0);
  @$pb.TagNumber(1)
  set cmdType($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCmdType() => $_has(0);
  @$pb.TagNumber(1)
  void clearCmdType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get param => $_getIZ(1);
  @$pb.TagNumber(2)
  set param($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParam() => $_has(1);
  @$pb.TagNumber(2)
  void clearParam() => $_clearField(2);
}

/// ============================================================
/// 2.2.26 HeroDeployModeEventCommand
/// 用途：英雄部署模式指令
/// Topic: HeroDeployModeEventCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class HeroDeployModeEventCommand extends $pb.GeneratedMessage {
  factory HeroDeployModeEventCommand({
    $core.int? mode,
  }) {
    final result = create();
    if (mode != null) result.mode = mode;
    return result;
  }

  HeroDeployModeEventCommand._();

  factory HeroDeployModeEventCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HeroDeployModeEventCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HeroDeployModeEventCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'mode', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeroDeployModeEventCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HeroDeployModeEventCommand copyWith(
          void Function(HeroDeployModeEventCommand) updates) =>
      super.copyWith(
              (message) => updates(message as HeroDeployModeEventCommand))
          as HeroDeployModeEventCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HeroDeployModeEventCommand create() => HeroDeployModeEventCommand._();
  @$core.override
  HeroDeployModeEventCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HeroDeployModeEventCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HeroDeployModeEventCommand>(create);
  static HeroDeployModeEventCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get mode => $_getIZ(0);
  @$pb.TagNumber(1)
  set mode($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMode() => $_has(0);
  @$pb.TagNumber(1)
  void clearMode() => $_clearField(1);
}

/// ============================================================
/// 2.2.27 DeployModeStatusSync
/// 用途：英雄部署模式状态同步
/// Topic: DeployModeStatusSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class DeployModeStatusSync extends $pb.GeneratedMessage {
  factory DeployModeStatusSync({
    $core.int? status,
  }) {
    final result = create();
    if (status != null) result.status = status;
    return result;
  }

  DeployModeStatusSync._();

  factory DeployModeStatusSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeployModeStatusSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeployModeStatusSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'status', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeployModeStatusSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeployModeStatusSync copyWith(void Function(DeployModeStatusSync) updates) =>
      super.copyWith((message) => updates(message as DeployModeStatusSync))
          as DeployModeStatusSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeployModeStatusSync create() => DeployModeStatusSync._();
  @$core.override
  DeployModeStatusSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeployModeStatusSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeployModeStatusSync>(create);
  static DeployModeStatusSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get status => $_getIZ(0);
  @$pb.TagNumber(1)
  set status($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearStatus() => $_clearField(1);
}

/// ============================================================
/// 2.2.28 RuneActivateCommand
/// 用途：能量机关激活指令
/// Topic: RuneActivateCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class RuneActivateCommand extends $pb.GeneratedMessage {
  factory RuneActivateCommand({
    $core.int? activate,
  }) {
    final result = create();
    if (activate != null) result.activate = activate;
    return result;
  }

  RuneActivateCommand._();

  factory RuneActivateCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RuneActivateCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RuneActivateCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'activate', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RuneActivateCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RuneActivateCommand copyWith(void Function(RuneActivateCommand) updates) =>
      super.copyWith((message) => updates(message as RuneActivateCommand))
          as RuneActivateCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RuneActivateCommand create() => RuneActivateCommand._();
  @$core.override
  RuneActivateCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RuneActivateCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RuneActivateCommand>(create);
  static RuneActivateCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get activate => $_getIZ(0);
  @$pb.TagNumber(1)
  set activate($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActivate() => $_has(0);
  @$pb.TagNumber(1)
  void clearActivate() => $_clearField(1);
}

/// ============================================================
/// 2.2.29 RuneStatusSync
/// 用途：能量机关状态同步
/// Topic: RuneStatusSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class RuneStatusSync extends $pb.GeneratedMessage {
  factory RuneStatusSync({
    $core.int? runeStatus,
    $core.int? activatedArms,
    $core.double? averageRings,
  }) {
    final result = create();
    if (runeStatus != null) result.runeStatus = runeStatus;
    if (activatedArms != null) result.activatedArms = activatedArms;
    if (averageRings != null) result.averageRings = averageRings;
    return result;
  }

  RuneStatusSync._();

  factory RuneStatusSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RuneStatusSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RuneStatusSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'runeStatus', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'activatedArms',
        fieldType: $pb.PbFieldType.OU3)
    ..aD(3, _omitFieldNames ? '' : 'averageRings',
        fieldType: $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RuneStatusSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RuneStatusSync copyWith(void Function(RuneStatusSync) updates) =>
      super.copyWith((message) => updates(message as RuneStatusSync))
          as RuneStatusSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RuneStatusSync create() => RuneStatusSync._();
  @$core.override
  RuneStatusSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RuneStatusSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RuneStatusSync>(create);
  static RuneStatusSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get runeStatus => $_getIZ(0);
  @$pb.TagNumber(1)
  set runeStatus($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRuneStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearRuneStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get activatedArms => $_getIZ(1);
  @$pb.TagNumber(2)
  set activatedArms($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActivatedArms() => $_has(1);
  @$pb.TagNumber(2)
  void clearActivatedArms() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get averageRings => $_getN(2);
  @$pb.TagNumber(3)
  set averageRings($core.double value) => $_setFloat(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAverageRings() => $_has(2);
  @$pb.TagNumber(3)
  void clearAverageRings() => $_clearField(3);
}

/// ============================================================
/// 2.2.30 SentryStatusSync
/// 用途：哨兵姿态和弱化状态
/// Topic: SentryStatusSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class SentryStatusSync extends $pb.GeneratedMessage {
  factory SentryStatusSync({
    $core.int? postureId,
    $core.bool? isWeakened,
  }) {
    final result = create();
    if (postureId != null) result.postureId = postureId;
    if (isWeakened != null) result.isWeakened = isWeakened;
    return result;
  }

  SentryStatusSync._();

  factory SentryStatusSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SentryStatusSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SentryStatusSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'postureId', fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'isWeakened')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SentryStatusSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SentryStatusSync copyWith(void Function(SentryStatusSync) updates) =>
      super.copyWith((message) => updates(message as SentryStatusSync))
          as SentryStatusSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SentryStatusSync create() => SentryStatusSync._();
  @$core.override
  SentryStatusSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SentryStatusSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SentryStatusSync>(create);
  static SentryStatusSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get postureId => $_getIZ(0);
  @$pb.TagNumber(1)
  set postureId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPostureId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPostureId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get isWeakened => $_getBF(1);
  @$pb.TagNumber(2)
  set isWeakened($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIsWeakened() => $_has(1);
  @$pb.TagNumber(2)
  void clearIsWeakened() => $_clearField(2);
}

/// ============================================================
/// 2.2.31 DartCommand
/// 用途：飞镖控制指令
/// Topic: DartCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class DartCommand extends $pb.GeneratedMessage {
  factory DartCommand({
    $core.int? targetId,
    $core.bool? open,
    $core.bool? launchConfirm,
  }) {
    final result = create();
    if (targetId != null) result.targetId = targetId;
    if (open != null) result.open = open;
    if (launchConfirm != null) result.launchConfirm = launchConfirm;
    return result;
  }

  DartCommand._();

  factory DartCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DartCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DartCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'targetId', fieldType: $pb.PbFieldType.OU3)
    ..aOB(2, _omitFieldNames ? '' : 'open')
    ..aOB(3, _omitFieldNames ? '' : 'launchConfirm')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DartCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DartCommand copyWith(void Function(DartCommand) updates) =>
      super.copyWith((message) => updates(message as DartCommand))
          as DartCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DartCommand create() => DartCommand._();
  @$core.override
  DartCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DartCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DartCommand>(create);
  static DartCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get targetId => $_getIZ(0);
  @$pb.TagNumber(1)
  set targetId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get open => $_getBF(1);
  @$pb.TagNumber(2)
  set open($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOpen() => $_has(1);
  @$pb.TagNumber(2)
  void clearOpen() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get launchConfirm => $_getBF(2);
  @$pb.TagNumber(3)
  set launchConfirm($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLaunchConfirm() => $_has(2);
  @$pb.TagNumber(3)
  void clearLaunchConfirm() => $_clearField(3);
}

/// ============================================================
/// 2.2.32 DartSelectTargetStatusSync
/// 用途：飞镖目标选择状态同步
/// Topic: DartSelectTargetStatusSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class DartSelectTargetStatusSync extends $pb.GeneratedMessage {
  factory DartSelectTargetStatusSync({
    $core.int? targetId,
    $core.int? open,
  }) {
    final result = create();
    if (targetId != null) result.targetId = targetId;
    if (open != null) result.open = open;
    return result;
  }

  DartSelectTargetStatusSync._();

  factory DartSelectTargetStatusSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DartSelectTargetStatusSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DartSelectTargetStatusSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'targetId', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'open', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DartSelectTargetStatusSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DartSelectTargetStatusSync copyWith(
          void Function(DartSelectTargetStatusSync) updates) =>
      super.copyWith(
              (message) => updates(message as DartSelectTargetStatusSync))
          as DartSelectTargetStatusSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DartSelectTargetStatusSync create() => DartSelectTargetStatusSync._();
  @$core.override
  DartSelectTargetStatusSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DartSelectTargetStatusSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DartSelectTargetStatusSync>(create);
  static DartSelectTargetStatusSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get targetId => $_getIZ(0);
  @$pb.TagNumber(1)
  set targetId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTargetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTargetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get open => $_getIZ(1);
  @$pb.TagNumber(2)
  set open($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOpen() => $_has(1);
  @$pb.TagNumber(2)
  void clearOpen() => $_clearField(2);
}

/// ============================================================
/// 2.2.33 SentryCtrlCommand
/// 用途：哨兵控制指令请求
/// Topic: SentryCtrlCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class SentryCtrlCommand extends $pb.GeneratedMessage {
  factory SentryCtrlCommand({
    $core.int? commandId,
  }) {
    final result = create();
    if (commandId != null) result.commandId = commandId;
    return result;
  }

  SentryCtrlCommand._();

  factory SentryCtrlCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SentryCtrlCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SentryCtrlCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'commandId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SentryCtrlCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SentryCtrlCommand copyWith(void Function(SentryCtrlCommand) updates) =>
      super.copyWith((message) => updates(message as SentryCtrlCommand))
          as SentryCtrlCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SentryCtrlCommand create() => SentryCtrlCommand._();
  @$core.override
  SentryCtrlCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SentryCtrlCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SentryCtrlCommand>(create);
  static SentryCtrlCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get commandId => $_getIZ(0);
  @$pb.TagNumber(1)
  set commandId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommandId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommandId() => $_clearField(1);
}

/// ============================================================
/// 2.2.34 SentryCtrlResult
/// 用途：哨兵控制指令结果反馈
/// Topic: SentryCtrlResult
/// 方向：服务器 → 自定义客户端
/// ============================================================
class SentryCtrlResult extends $pb.GeneratedMessage {
  factory SentryCtrlResult({
    $core.int? commandId,
    $core.int? resultCode,
  }) {
    final result = create();
    if (commandId != null) result.commandId = commandId;
    if (resultCode != null) result.resultCode = resultCode;
    return result;
  }

  SentryCtrlResult._();

  factory SentryCtrlResult.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SentryCtrlResult.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SentryCtrlResult',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'commandId', fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'resultCode', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SentryCtrlResult clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SentryCtrlResult copyWith(void Function(SentryCtrlResult) updates) =>
      super.copyWith((message) => updates(message as SentryCtrlResult))
          as SentryCtrlResult;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SentryCtrlResult create() => SentryCtrlResult._();
  @$core.override
  SentryCtrlResult createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SentryCtrlResult getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SentryCtrlResult>(create);
  static SentryCtrlResult? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get commandId => $_getIZ(0);
  @$pb.TagNumber(1)
  set commandId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommandId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommandId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get resultCode => $_getIZ(1);
  @$pb.TagNumber(2)
  set resultCode($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResultCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearResultCode() => $_clearField(2);
}

/// ============================================================
/// 2.2.35 AirSupportCommand
/// 用途：空中支援指令
/// Topic: AirSupportCommand
/// 方向：自定义客户端 → 服务器
/// ============================================================
class AirSupportCommand extends $pb.GeneratedMessage {
  factory AirSupportCommand({
    $core.int? commandId,
  }) {
    final result = create();
    if (commandId != null) result.commandId = commandId;
    return result;
  }

  AirSupportCommand._();

  factory AirSupportCommand.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AirSupportCommand.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AirSupportCommand',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'commandId', fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AirSupportCommand clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AirSupportCommand copyWith(void Function(AirSupportCommand) updates) =>
      super.copyWith((message) => updates(message as AirSupportCommand))
          as AirSupportCommand;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AirSupportCommand create() => AirSupportCommand._();
  @$core.override
  AirSupportCommand createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AirSupportCommand getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AirSupportCommand>(create);
  static AirSupportCommand? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get commandId => $_getIZ(0);
  @$pb.TagNumber(1)
  set commandId($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCommandId() => $_has(0);
  @$pb.TagNumber(1)
  void clearCommandId() => $_clearField(1);
}

/// ============================================================
/// 2.2.36 AirSupportStatusSync
/// 用途：空中支援状态反馈
/// Topic: AirSupportStatusSync
/// 方向：服务器 → 自定义客户端
/// ============================================================
class AirSupportStatusSync extends $pb.GeneratedMessage {
  factory AirSupportStatusSync({
    $core.int? airsupportStatus,
    $core.int? leftTime,
    $core.int? costCoins,
    $core.int? isBeingTargeted,
    $core.int? shooterStatus,
  }) {
    final result = create();
    if (airsupportStatus != null) result.airsupportStatus = airsupportStatus;
    if (leftTime != null) result.leftTime = leftTime;
    if (costCoins != null) result.costCoins = costCoins;
    if (isBeingTargeted != null) result.isBeingTargeted = isBeingTargeted;
    if (shooterStatus != null) result.shooterStatus = shooterStatus;
    return result;
  }

  AirSupportStatusSync._();

  factory AirSupportStatusSync.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AirSupportStatusSync.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AirSupportStatusSync',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'robomaster'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'airsupportStatus',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(2, _omitFieldNames ? '' : 'leftTime', fieldType: $pb.PbFieldType.OU3)
    ..aI(3, _omitFieldNames ? '' : 'costCoins', fieldType: $pb.PbFieldType.OU3)
    ..aI(4, _omitFieldNames ? '' : 'isBeingTargeted',
        fieldType: $pb.PbFieldType.OU3)
    ..aI(5, _omitFieldNames ? '' : 'shooterStatus',
        fieldType: $pb.PbFieldType.OU3)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AirSupportStatusSync clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AirSupportStatusSync copyWith(void Function(AirSupportStatusSync) updates) =>
      super.copyWith((message) => updates(message as AirSupportStatusSync))
          as AirSupportStatusSync;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AirSupportStatusSync create() => AirSupportStatusSync._();
  @$core.override
  AirSupportStatusSync createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AirSupportStatusSync getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AirSupportStatusSync>(create);
  static AirSupportStatusSync? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get airsupportStatus => $_getIZ(0);
  @$pb.TagNumber(1)
  set airsupportStatus($core.int value) => $_setUnsignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAirsupportStatus() => $_has(0);
  @$pb.TagNumber(1)
  void clearAirsupportStatus() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get leftTime => $_getIZ(1);
  @$pb.TagNumber(2)
  set leftTime($core.int value) => $_setUnsignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLeftTime() => $_has(1);
  @$pb.TagNumber(2)
  void clearLeftTime() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get costCoins => $_getIZ(2);
  @$pb.TagNumber(3)
  set costCoins($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCostCoins() => $_has(2);
  @$pb.TagNumber(3)
  void clearCostCoins() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get isBeingTargeted => $_getIZ(3);
  @$pb.TagNumber(4)
  set isBeingTargeted($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIsBeingTargeted() => $_has(3);
  @$pb.TagNumber(4)
  void clearIsBeingTargeted() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get shooterStatus => $_getIZ(4);
  @$pb.TagNumber(5)
  set shooterStatus($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasShooterStatus() => $_has(4);
  @$pb.TagNumber(5)
  void clearShooterStatus() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
