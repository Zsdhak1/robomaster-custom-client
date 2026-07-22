/// 记录协议中明确出现的机器人模块状态及其转换。
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/protocol_constants.dart';

/// RoboMaster 协议中的本机模块类型。
enum RobotModuleType {
  powerManager,
  rfid,
  lightStrip,
  smallShooter,
  bigShooter,
  uwb,
  armor,
  videoTransmission,
  capacitor,
  mainController,
  laserDetectionModule,
}

/// 模块的归一化可用性。
enum ModuleAvailability {
  online,
  offline;

  /// 将协议值归一化；只有值 1 表示在线。
  static ModuleAvailability fromProtocolValue(int value) {
    return value == moduleStatusOnline ? online : offline;
  }
}

/// 仅包含本次协议消息中明确存在的模块字段。
class ModuleStatusReading {
  const ModuleStatusReading(this.statuses);

  factory ModuleStatusReading.fromProtocolValues(
    Map<RobotModuleType, int> values,
  ) {
    return ModuleStatusReading(
      Map.unmodifiable({
        for (final entry in values.entries)
          entry.key: ModuleAvailability.fromProtocolValue(entry.value),
      }),
    );
  }

  final Map<RobotModuleType, ModuleAvailability> statuses;
}

/// 一次明确的模块在线或离线变化。
class ModuleStatusTransition {
  const ModuleStatusTransition._({
    required this.module,
    required this.previous,
    required this.current,
  });

  static ModuleStatusTransition? from(
    ModuleAvailability? previous,
    MapEntry<RobotModuleType, ModuleAvailability> entry,
  ) {
    if (!_isTransition(previous, entry.value)) return null;
    return ModuleStatusTransition._(
      module: entry.key,
      previous: previous,
      current: entry.value,
    );
  }

  static bool _isTransition(
    ModuleAvailability? previous,
    ModuleAvailability current,
  ) {
    return (previous == null && current == ModuleAvailability.offline) ||
        (previous == ModuleAvailability.online &&
            current == ModuleAvailability.offline) ||
        (previous == ModuleAvailability.offline &&
            current == ModuleAvailability.online);
  }

  final RobotModuleType module;
  final ModuleAvailability? previous;
  final ModuleAvailability current;

  bool get becameOffline => current == ModuleAvailability.offline;

  bool get becameOnline => current == ModuleAvailability.online;
}

/// 模块状态面板需要的不可变快照。
class ModuleStatusMonitorState {
  const ModuleStatusMonitorState({this.statuses = const {}});

  final Map<RobotModuleType, ModuleAvailability> statuses;

  bool get hasOffline => statuses.values.contains(ModuleAvailability.offline);
}

/// 只保存已在协议中明确出现过的模块字段。
class ModuleStatusMonitorController
    extends StateNotifier<ModuleStatusMonitorState> {
  ModuleStatusMonitorController() : super(const ModuleStatusMonitorState());

  /// 合并当前读取结果，并返回新产生的状态变化。
  List<ModuleStatusTransition> observe(ModuleStatusReading reading) {
    final next = Map<RobotModuleType, ModuleAvailability>.from(state.statuses);
    final transitions = <ModuleStatusTransition>[];
    for (final entry in reading.statuses.entries) {
      final transition = ModuleStatusTransition.from(next[entry.key], entry);
      next[entry.key] = entry.value;
      if (transition != null) transitions.add(transition);
    }
    state = ModuleStatusMonitorState(statuses: Map.unmodifiable(next));
    return transitions;
  }

  /// 清除当前连接会话的全部明确状态。
  void reset() => state = const ModuleStatusMonitorState();
}

/// 供仪表盘模块面板和协议运行时共享的模块状态。
final moduleStatusMonitorProvider =
    StateNotifierProvider<
      ModuleStatusMonitorController,
      ModuleStatusMonitorState
    >((ref) => ModuleStatusMonitorController());

/// 面向通知文案的模块名称。
extension RobotModuleTypeLabel on RobotModuleType {
  String get label => switch (this) {
    RobotModuleType.powerManager => '电源管理',
    RobotModuleType.rfid => 'RFID',
    RobotModuleType.lightStrip => '灯条',
    RobotModuleType.smallShooter => '17mm 发射机构',
    RobotModuleType.bigShooter => '42mm 发射机构',
    RobotModuleType.uwb => '定位',
    RobotModuleType.armor => '装甲',
    RobotModuleType.videoTransmission => '图传',
    RobotModuleType.capacitor => '电容',
    RobotModuleType.mainController => '主控',
    RobotModuleType.laserDetectionModule => '激光检测',
  };
}
