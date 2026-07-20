/// RoboMaster 2026 自定义客户端协议常量。
///
/// 覆盖 MQTT 3333 与 UDP 3334 两条链路的固定参数。
/// 所有取值均来自官方协议 V1.3.1。
library;

// ============================================================
// MQTT 链路 (3333)
// ============================================================

/// 默认 MQTT 代理服务器 IP 地址。
const String defaultMqttBrokerIp = '192.168.12.1';

/// MQTT 代理服务器端口号。
const int defaultMqttPort = 3333;

/// 默认客户端 IP 地址（协议规范约定）。
const String defaultClientIp = '192.168.12.2';

/// MQTT 连接超时时间。
const Duration mqttConnectionTimeout = Duration(seconds: 5);

/// MQTT 保活间隔。
const Duration mqttKeepAliveInterval = Duration(seconds: 20);

/// 自动重连初始延迟。
const Duration mqttReconnectDelay = Duration(seconds: 3);

/// 自动重连最大延迟上限。
const Duration mqttMaxReconnectDelay = Duration(seconds: 60);

/// 机器人专属 MQTT 消息的主题前缀。
const String robotTopicPrefix = 'robot';

// ============================================================
// MQTT 主题（来自协议 §2.1）
// ============================================================

/// 鼠标/键盘控制输入主题。
const String topicKeyboardMouseControl = 'KeyboardMouseControl';

/// 自定义 30 字节数据主题。
const String topicCustomControl = 'CustomControl';

/// 全局比赛状态主题。
const String topicGameStatus = 'GameStatus';

// ============================================================
// 比赛状态阶段（来自协议 §2.2.3 current_stage）
// ============================================================

/// 比赛尚未开始。
const int stageNotStarted = 0;

/// 准备阶段。
const int stagePreparation = 1;

/// 15 秒裁判系统自检阶段。
const int stageSelfCheck = 2;

/// 5 秒倒计时阶段。
const int stageCountdown = 3;

/// 比赛进行中。
const int stageInMatch = 4;

/// 比赛结算阶段。
const int stageSettlement = 5;

/// 标准比赛时长加上结算缓冲。
///
/// 标准 RoboMaster 比赛时长为 7 分钟；额外 30 秒用于在断线降级触发
/// 自动导出前等待结算消息（阶段 5）到达。计时锚点为本地观察到
/// “比赛中”（阶段 4）的墙钟时间。
const Duration matchDurationWithBuffer = Duration(minutes: 7, seconds: 30);

/// 基地、前哨站和机器人状态主题。
const String topicGlobalUnitStatus = 'GlobalUnitStatus';

/// 后勤 (经济，科技等级) 主题。
const String topicGlobalLogisticsStatus = 'GlobalLogisticsStatus';

/// 当前特殊机制主题。
const String topicGlobalSpecialMechanism = 'GlobalSpecialMechanism';

/// 全局事件通知主题。
const String topicEvent = 'Event';

/// 机器人受伤统计主题。
const String topicRobotInjuryStat = 'RobotInjuryStat';

/// 机器人复活状态主题。
const String topicRobotRespawnStatus = 'RobotRespawnStatus';

/// 机器人固定属性主题。
const String topicRobotStaticStatus = 'RobotStaticStatus';

/// 机器人实时数据主题。
const String topicRobotDynamicStatus = 'RobotDynamicStatus';

/// 机器人模块状态主题。
const String topicRobotModuleStatus = 'RobotModuleStatus';

/// 机器人位置主题。
const String topicRobotPosition = 'RobotPosition';

/// 增益效果主题。
const String topicBuff = 'Buff';

/// 判罚信息主题。
const String topicPenaltyInfo = 'PenaltyInfo';

/// 哨兵路径规划主题。
const String topicRobotPathPlanInfo = 'RobotPathPlanInfo';

/// 地图点击信息同步主题。
const String topicMapClickInfo = 'MapClickInfo';

/// 地图点击命令主题。
const String topicMapClickCmd = 'MapClickCmd';

/// 雷达机器人位置信息主题。
const String topicRadarInfoToClient = 'RadarInfoToClient';

/// 自定义字节块主题。
const String topicCustomByteBlock = 'CustomByteBlock';

/// 工程装配命令主题。
const String topicAssemblyCommand = 'AssemblyCommand';

/// 科技核心运动状态主题。
const String topicTechCoreMotionStateSync = 'TechCoreMotionStateSync';

/// 性能体系选择命令主题。
const String topicRobotPerformanceSelectionCommand =
    'RobotPerformanceSelectionCommand';

/// 性能体系选择同步主题。
const String topicRobotPerformanceSelectionSync =
    'RobotPerformanceSelectionSync';

/// 通用命令主题。
const String topicCommonCommand = 'CommonCommand';

// ============================================================
// 操作面板指令参数（来自协议 §2.2.21 / §2.2.25）
// ============================================================

/// 兑换 17mm 弹丸的通用指令类型。
const int commonCommandExchange17mm = 1;

/// 兑换 42mm 弹丸的通用指令类型。
const int commonCommandExchange42mm = 2;

/// 远程兑换弹丸的通用指令类型。
const int commonCommandRemoteAmmo = 5;

/// 远程兑换血量的通用指令类型。
const int commonCommandRemoteHeal = 6;

/// 开始工程兑换流程的装配操作类型。
const int assemblyOperationStartExchange = 0;

/// 确认工程装配的操作类型。
const int assemblyOperationConfirm = 1;

/// 取消工程装配的操作类型。
const int assemblyOperationCancel = 2;

/// 单次远程兑换弹丸请求的发弹量。
const int remoteAmmoExchangeRounds = 100;

/// 英雄部署模式命令主题。
const String topicHeroDeployModeEventCommand = 'HeroDeployModeEventCommand';

/// 部署模式状态同步主题。
const String topicDeployModeStatusSync = 'DeployModeStatusSync';

/// 能量机关激活命令主题。
const String topicRuneActivateCommand = 'RuneActivateCommand';

/// 能量机关状态同步主题。
const String topicRuneStatusSync = 'RuneStatusSync';

/// 哨兵状态同步主题。
const String topicSentryStatusSync = 'SentryStatusSync';

/// 飞镖控制命令主题。
const String topicDartCommand = 'DartCommand';

/// 飞镖目标选择同步主题。
const String topicDartSelectTargetStatusSync = 'DartSelectTargetStatusSync';

/// 哨兵控制命令主题。
const String topicSentryCtrlCommand = 'SentryCtrlCommand';

/// 哨兵控制结果主题。
const String topicSentryCtrlResult = 'SentryCtrlResult';

/// 空中支援命令主题。
const String topicAirSupportCommand = 'AirSupportCommand';

/// 空中支援状态同步主题。
const String topicAirSupportStatusSync = 'AirSupportStatusSync';

/// 通知规则引擎正常工作必须接收的主题。
///
/// 即使用户在记录配置中关闭这些主题，也仍需订阅；记录层可独立决定是否写入文件。
const Set<String> notificationRequiredTopics = {
  topicGameStatus,
  topicGlobalUnitStatus,
  topicEvent,
  topicDeployModeStatusSync,
  topicRobotModuleStatus,
};

// ============================================================
// UDP 视频流 (3334)
// ============================================================

/// UDP 视频流监听端口。
const int defaultUdpVideoPort = 3334;

/// UDP 包头长度，单位为字节。
/// 格式：frame_id(2) + packet_id(2) + frame_size(4) = 8 字节。
const int udpPacketHeaderSize = 8;

/// UDP 包头内 frame_id 字段的偏移。
const int udpFrameIdOffset = 0;

/// frame_id 字段长度，单位为字节。
const int udpFrameIdSize = 2;

/// UDP 包头内 packet_id 字段的偏移。
const int udpPacketIdOffset = 2;

/// packet_id 字段长度，单位为字节。
const int udpPacketIdSize = 2;

/// UDP 包头内 frame_size 字段的偏移。
const int udpFrameSizeOffset = 4;

/// frame_size 字段长度，单位为字节。
const int udpFrameSizeSize = 4;

/// HEVC AnnexB 起始码前缀（4 字节）。
const List<int> annexbStartCode = [0x00, 0x00, 0x00, 0x01];

/// 另一种 AnnexB 起始码前缀（3 字节）。
const List<int> annexbStartCodeShort = [0x00, 0x00, 0x01];

// ============================================================
// 视频帧重组
// ============================================================

/// 同时缓存的最大帧数。
///
/// 该值必须足够容纳正在重组的关键帧。关键帧可能包含约 90 个 UDP 分片，
/// 并与多个较小的帧交错到达，过早淘汰会导致解码器拿不到参数集。
/// 参考客户端近似无限缓存；这里用 64 作为有界但相对安全的内存上限。
const int maxCachedFrames = 64;

/// 未完成帧重组的超时时间。
///
/// 大关键帧（约 128 KB / 90 个分片）需要更长时间才能完整到达。
/// 早先的 200 ms 过紧，携带 VPS/SPS/PPS 的关键帧会在完成前被丢弃，
/// 导致解码器始终拿不到参数集、无法出图。参考客户端实际上不会超时输出。
const Duration frameReassemblyTimeout = Duration(milliseconds: 1000);

/// 预期最大帧大小，单位为字节（HEVC 1080p 约 4MB）。
const int maxFrameSizeBytes = 4 * 1024 * 1024;

/// 最大 UDP 载荷大小。
const int maxUdpPayloadSize = 65507;
