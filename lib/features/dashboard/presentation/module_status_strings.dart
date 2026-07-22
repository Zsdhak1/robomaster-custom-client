/// 主仪表盘模块状态面板的集中式文案。
library;

import '../logic/module_status_monitor.dart';

/// 模块状态面板标题。
const String moduleStatusPanelTitle = '模块状态';

/// 模块在线状态文案。
const String moduleStatusOnline = '在线';

/// 模块离线状态文案。
const String moduleStatusOffline = '离线';

/// 返回模块面板使用的模块名称。
String moduleStatusModuleLabel(RobotModuleType type) {
  return switch (type) {
    RobotModuleType.powerManager => '电源管理模块',
    RobotModuleType.rfid => 'RFID 模块',
    RobotModuleType.lightStrip => '灯条模块',
    RobotModuleType.smallShooter => '17mm 发射模块',
    RobotModuleType.bigShooter => '42mm 发射模块',
    RobotModuleType.uwb => '定位模块',
    RobotModuleType.armor => '装甲模块',
    RobotModuleType.videoTransmission => '图传模块',
    RobotModuleType.capacitor => '电容模块',
    RobotModuleType.mainController => '主控模块',
    RobotModuleType.laserDetectionModule => '激光检测模块',
  };
}

/// 返回模块面板使用的可用性文案。
String moduleStatusAvailabilityLabel(ModuleAvailability availability) {
  return availability == ModuleAvailability.offline
      ? moduleStatusOffline
      : moduleStatusOnline;
}
