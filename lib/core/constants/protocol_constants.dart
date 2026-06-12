/// Protocol constants for RoboMaster 2026 Custom Client.
///
/// Covers both MQTT 3333 and UDP 3334 link parameters.
/// All values sourced from official protocol V1.3.1.
library;

// ============================================================
// MQTT Link (3333)
// ============================================================

/// Default MQTT broker IP address.
const String defaultMqttBrokerIp = '192.168.12.1';

/// MQTT broker port number.
const int defaultMqttPort = 3333;

/// Default client IP address (as per protocol spec).
const String defaultClientIp = '192.168.12.2';

/// MQTT connection timeout duration.
const Duration mqttConnectionTimeout = Duration(seconds: 5);

/// MQTT keep-alive interval.
const Duration mqttKeepAliveInterval = Duration(seconds: 20);

/// Auto-reconnect initial delay.
const Duration mqttReconnectDelay = Duration(seconds: 3);

/// Auto-reconnect max delay cap.
const Duration mqttMaxReconnectDelay = Duration(seconds: 60);

/// MQTT topic prefix for robot-specific messages.
const String robotTopicPrefix = 'robot';

// ============================================================
// MQTT Topics (from protocol §2.1)
// ============================================================

/// Mouse/keyboard control input topic.
const String topicKeyboardMouseControl = 'KeyboardMouseControl';

/// Custom 30-byte data topic.
const String topicCustomControl = 'CustomControl';

/// Global game status topic.
const String topicGameStatus = 'GameStatus';

// ============================================================
// Game Status Stages (from protocol §2.2.3 current_stage)
// ============================================================

/// Match has not started.
const int stageNotStarted = 0;

/// Preparation phase.
const int stagePreparation = 1;

/// 15-second referee system self-check phase.
const int stageSelfCheck = 2;

/// 5-second countdown.
const int stageCountdown = 3;

/// Match in progress.
const int stageInMatch = 4;

/// Match settlement phase.
const int stageSettlement = 5;

/// Standard match duration plus a settlement buffer.
///
/// Standard RoboMaster matches run 7 minutes; the extra 30 seconds gives the
/// settlement message (stage 5) time to arrive before the disconnect fallback
/// auto-export fires. Measured from the wall-clock "比赛中" (stage 4) anchor.
const Duration matchDurationWithBuffer = Duration(minutes: 7, seconds: 30);

/// Base, outpost and robot status topic.
const String topicGlobalUnitStatus = 'GlobalUnitStatus';

/// Logistics (economy, tech level) topic.
const String topicGlobalLogisticsStatus = 'GlobalLogisticsStatus';

/// Active special mechanisms topic.
const String topicGlobalSpecialMechanism = 'GlobalSpecialMechanism';

/// Global event notifications topic.
const String topicEvent = 'Event';

/// Robot injury statistics topic.
const String topicRobotInjuryStat = 'RobotInjuryStat';

/// Robot respawn status topic.
const String topicRobotRespawnStatus = 'RobotRespawnStatus';

/// Robot static attributes topic.
const String topicRobotStaticStatus = 'RobotStaticStatus';

/// Robot real-time data topic.
const String topicRobotDynamicStatus = 'RobotDynamicStatus';

/// Robot module status topic.
const String topicRobotModuleStatus = 'RobotModuleStatus';

/// Robot position topic.
const String topicRobotPosition = 'RobotPosition';

/// Buff effect topic.
const String topicBuff = 'Buff';

/// Penalty information topic.
const String topicPenaltyInfo = 'PenaltyInfo';

/// Sentry path planning topic.
const String topicRobotPathPlanInfo = 'RobotPathPlanInfo';

/// Map click info sync topic.
const String topicMapClickInfo = 'MapClickInfo';

/// Map click command topic.
const String topicMapClickCmd = 'MapClickCmd';

/// Radar robot position info topic.
const String topicRadarInfoToClient = 'RadarInfoToClient';

/// Custom byte block topic.
const String topicCustomByteBlock = 'CustomByteBlock';

/// Assembly command topic.
const String topicAssemblyCommand = 'AssemblyCommand';

/// Tech core motion state topic.
const String topicTechCoreMotionStateSync = 'TechCoreMotionStateSync';

/// Performance selection command topic.
const String topicRobotPerformanceSelectionCommand =
    'RobotPerformanceSelectionCommand';

/// Performance selection sync topic.
const String topicRobotPerformanceSelectionSync =
    'RobotPerformanceSelectionSync';

/// Common command topic.
const String topicCommonCommand = 'CommonCommand';

/// Hero deploy mode command topic.
const String topicHeroDeployModeEventCommand = 'HeroDeployModeEventCommand';

/// Deploy mode status sync topic.
const String topicDeployModeStatusSync = 'DeployModeStatusSync';

/// Rune activation command topic.
const String topicRuneActivateCommand = 'RuneActivateCommand';

/// Rune status sync topic.
const String topicRuneStatusSync = 'RuneStatusSync';

/// Sentry status sync topic.
const String topicSentryStatusSync = 'SentryStatusSync';

/// Dart control command topic.
const String topicDartCommand = 'DartCommand';

/// Dart target selection sync topic.
const String topicDartSelectTargetStatusSync = 'DartSelectTargetStatusSync';

/// Sentry control command topic.
const String topicSentryCtrlCommand = 'SentryCtrlCommand';

/// Sentry control result topic.
const String topicSentryCtrlResult = 'SentryCtrlResult';

/// Air support command topic.
const String topicAirSupportCommand = 'AirSupportCommand';

/// Air support status sync topic.
const String topicAirSupportStatusSync = 'AirSupportStatusSync';

// ============================================================
// UDP Video Stream (3334)
// ============================================================

/// UDP video stream listen port.
const int defaultUdpVideoPort = 3334;

/// UDP packet header size in bytes.
/// Format: frame_id(2) + packet_id(2) + frame_size(4) = 8 bytes.
const int udpPacketHeaderSize = 8;

/// Offset of frame_id field within UDP header.
const int udpFrameIdOffset = 0;

/// Size of frame_id field in bytes.
const int udpFrameIdSize = 2;

/// Offset of packet_id field within UDP header.
const int udpPacketIdOffset = 2;

/// Size of packet_id field in bytes.
const int udpPacketIdSize = 2;

/// Offset of frame_size field within UDP header.
const int udpFrameSizeOffset = 4;

/// Size of frame_size field in bytes.
const int udpFrameSizeSize = 4;

/// HEVC AnnexB start code prefix (4 bytes).
const List<int> annexbStartCode = [0x00, 0x00, 0x00, 0x01];

/// Alternative AnnexB start code prefix (3 bytes).
const List<int> annexbStartCodeShort = [0x00, 0x00, 0x01];

// ============================================================
// Video Frame Reassembly
// ============================================================

/// Maximum number of frames to cache simultaneously.
///
/// Must be large enough to hold an in-progress keyframe (which can span ~90
/// UDP fragments and arrives interleaved with many small inter-frames) without
/// evicting it. The reference client keeps frames effectively unbounded; 64 is
/// a safe bound that still caps memory.
const int maxCachedFrames = 64;

/// Timeout for incomplete frame reassembly.
///
/// A large keyframe (~128 KB / ~90 fragments) needs time to fully arrive. The
/// previous 200 ms was too tight — the keyframe carrying VPS/SPS/PPS was
/// dropped before completing, so the decoder never received parameter sets and
/// produced no picture. The reference client effectively never times out.
const Duration frameReassemblyTimeout = Duration(milliseconds: 1000);

/// Maximum expected frame size in bytes (HEVC 1080p ~ 4MB).
const int maxFrameSizeBytes = 4 * 1024 * 1024;

/// Maximum UDP payload size.
const int maxUdpPayloadSize = 65507;
