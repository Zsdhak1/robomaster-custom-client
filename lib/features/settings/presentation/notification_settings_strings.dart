/// “通知与规则”设置页使用的集中式 UI 文案。
library;

import '../domain/combat_notification_rules.dart';
import '../domain/notification_preferences.dart';

const notificationSettingsTitle = '通知与比赛规则';
const notificationSettingsCategoryTitle = '通知与规则';
const notificationSettingsCategorySubtitle = '通知偏好、战术判定与规则档案';
const notificationDirectoryTitle = '选择要配置的部分';
const notificationDirectorySubtitle = '设置已按用途分类；进入二级页面后可查看每项参数的具体作用。';
const notificationManagementGroupTitle = '通知管理';
const notificationRulesGroupTitle = '比赛与链路规则';
const notificationProfilePageTitle = '规则档案';
const notificationProfilePageSubtitle = '选择、复制、导入、导出、恢复或删除规则档案';
const notificationDisplayTestPageTitle = '通知展示与测试';
const notificationDisplayTestPageSubtitle =
    '配置全局展示与反馈，并手动测试 INFO 或 CRITICAL 通知';
const notificationEventsPageTitle = '事件通知';
const notificationEventsPageSubtitle = '分别配置 12 类事件的开关、级别、声音、确认和冷却';
const notificationCombatRulesPageTitle = '斩杀线与复活';
const notificationCombatRulesPageSubtitle = '配置敌方斩杀线、免费复活公式和买活判断';
const notificationDeploymentPageTitle = '英雄部署跳转';
const notificationDeploymentPageSubtitle = '配置部署倒计时、取消、预启动和失败处理';
const notificationConnectionPageTitle = '连接质量';
const notificationConnectionPageSubtitle = '配置 MQTT、UDP、自定义图传和解码链路阈值';
const notificationProfileSectionTitle = '规则配置档案';
const notificationProfileSectionSubtitle = '选择比赛规则基线；当前档案决定本页全部通知与判定参数';
const notificationProfilePickerDescription = '切换后立即使用该档案，官方档案只读，自定义档案可编辑和导出';
const notificationProfileReadOnly = '官方只读';
const notificationProfileEditable = '自定义';
const notificationProfileCopy = '复制后编辑';
const notificationProfileImport = '导入';
const notificationProfileExport = '导出';
const notificationProfileReset = '恢复默认';
const notificationProfileDelete = '删除档案';
const notificationProfileProtocol = '通信协议';
const notificationProfileRule = '比赛规则';
const notificationProfileCopied = '已创建并切换到自定义档案';
const notificationProfileImported = '规则档案已导入并启用';
const notificationProfileImportFailed = '规则档案导入失败';
const notificationProfileExported = '规则档案已导出';
const notificationProfileExportFailed = '规则档案导出失败';
const notificationProfileSaveFailed = '规则设置保存失败';
const notificationProfileResetDone = '已恢复官方默认参数';
const notificationProfileDeleted = '自定义档案已删除';
const notificationProfileDeleteTitle = '删除当前规则档案？';
const notificationProfileDeleteBody = '删除后无法恢复，当前配置将切换回官方档案。';
const notificationCancel = '取消';
const notificationDelete = '删除';
const notificationOfficialHint = '官方档案用于保存规则基线。复制为自定义档案后才能修改参数。';
const notificationOverviewTitle = '通知总览';
const notificationOverviewSubtitle = '控制所有通知共用的展示、反馈、历史与关闭策略';
const notificationEnabled = '启用通知';
const notificationEnabledDescription = '关闭后停止真实事件通知；设置页中的手动测试仍可使用';
const notificationSensitivityTitle = '通知敏感度';
const notificationSensitivityDescription =
    '调整同类事件冷却和连接质量判定速度；敏感模式更快提醒，保守模式减少重复';
const notificationSoundEnabled = '声音提示';
const notificationSoundEnabledDescription = '允许事件在自身声音开关开启时播放系统提示音';
const notificationVibrationEnabled = 'Android 震动提示';
const notificationVibrationEnabledDescription = '在 Android 设备收到通知时调用系统震动反馈';
const notificationKeepHistory = '保存通知历史';
const notificationKeepHistoryDescription = '把本次应用运行中的通知保留在通知历史列表中';
const notificationMuteWhenPaused = '比赛暂停时静音通知';
const notificationMuteWhenPausedDescription = '比赛暂停期间仍显示通知，但不产生声音或震动反馈';
const notificationInfoDuration = 'INFO 显示时长';
const notificationInfoDurationDescription = '决定普通信息通知自动关闭前保持可见的时间';
const notificationCriticalDuration = 'CRITICAL 定时显示时长';
const notificationCriticalDurationDescription =
    '仅在 CRITICAL 关闭方式选择“定时关闭”时决定自动关闭时间';
const notificationInfoPlacement = 'INFO 展示位置';
const notificationInfoPlacementDescription = '选择普通信息通知在所有页面上的覆盖位置';
const notificationCriticalPlacement = 'CRITICAL 展示位置';
const notificationCriticalPlacementDescription = '选择严重告警在所有页面上的覆盖位置';
const notificationCriticalDismiss = 'CRITICAL 关闭方式';
const notificationCriticalDismissDescription = '决定严重告警由定时器、用户确认或对应状态恢复来关闭';
const notificationMaxVisibleInfo = '同时显示的 INFO 数量';
const notificationMaxVisibleInfoDescription = '限制屏幕上同时保留的普通通知数量，超出时优先保留最新通知';
const notificationHistoryLimit = '通知历史上限';
const notificationHistoryLimitDescription = '限制本次运行中保留的历史通知条数，防止列表无限增长';
const notificationSecondsUnit = '秒';
const notificationEventSectionTitle = '通知事件';
const notificationEventSectionSubtitle = '为每一类事件单独开启或关闭提醒';
const notificationEventToggleDescription = '左侧开关控制此类事件是否产生通知';
const notificationEventSound = '播放事件提示音';
const notificationEventSoundDescription = '仅控制这一类事件是否播放声音，还需同时开启全局声音提示';
const notificationEventAcknowledgement = '要求用户确认';
const notificationEventAcknowledgementDescription = '开启后通知不会自动消失，需要用户手动关闭';
const notificationEventCooldown = '同类事件冷却';
const notificationEventCooldownDescription = '同一事件在该时间内只提醒一次，避免连续数据重复刷屏';
const notificationEventSeverityDescription =
    'INFO 适合一般状态变化，CRITICAL 适合需要立即关注的告警';
const notificationTestTitle = '通知测试';
const notificationTestSubtitle = '按当前档案测试位置、时长、关闭方式、声音和震动；测试不受开关与冷却限制';
const notificationTestInfo = '测试 INFO';
const notificationTestCritical = '测试 CRITICAL';
const notificationTestEventTitle = '按事件类型测试';
const notificationTestDetail = '这是手动触发的通知测试，不代表真实比赛事件。';
const notificationTestUnavailable = '通知测试运行时尚未就绪';
const notificationKillLineTitle = '敌方斩杀线';
const notificationKillLineSubtitle = '根据敌方血量或预计所需弹丸判断是否进入可击杀范围';
const notificationKillLineEnabled = '启用斩杀线提醒';
const notificationKillLineEnabledDescription = '比赛进行中持续检查敌方机器人，并在首次进入阈值时通知';
const notificationKillLineMode = '判定方式';
const notificationKillLineModeDescription = '选择按预计弹丸数、当前血量比例或固定血量阈值判定';
const notificationHealthPercentThreshold = '血量比例阈值';
const notificationHealthPercentThresholdDescription = '敌方当前血量占配置血量上限不高于该比例时触发';
const notificationFixedHealthThreshold = '固定血量阈值';
const notificationFixedHealthThresholdDescription = '敌方当前血量不高于该 HP 数值时触发';
const notificationHeroThreshold = '英雄阈值';
const notificationHeroThresholdDescription = '预计击杀敌方英雄所需弹丸数不高于该值时触发';
const notificationInfantryThreshold = '步兵阈值';
const notificationInfantryThresholdDescription = '预计击杀敌方步兵或工程所需弹丸数不高于该值时触发';
const notificationSentryThreshold = '哨兵阈值';
const notificationSentryThresholdDescription = '预计击杀敌方哨兵所需弹丸数不高于该值时触发';
const notificationKillLineCooldown = '斩杀线重复提醒冷却';
const notificationKillLineCooldownDescription = '同一敌方机器人再次进入斩杀线前至少等待的时间';
const notificationKillLineRearm = '重新布防差值';
const notificationKillLineRearmDescription = '敌方状态需先高出原阈值该差值，之后再次下降才会重新提醒';
const notificationProjectileUnit = '发';
const notificationHealthUnit = 'HP';
const notificationRespawnTitle = '敌方复活与买活';
const notificationRespawnSubtitle = '根据血量清零后的恢复时间区分免费复活、买活与疑似买活';
const notificationRespawnEnabled = '启用敌方复活判断';
const notificationRespawnEnabledDescription = '记录敌方血量从零恢复的时刻，并产生复活类通知';
const notificationBuybackEnabled = '启用买活判断';
const notificationBuybackEnabledDescription = '比较实际恢复时刻和规则计算的免费复活最早时刻，识别提前买活';
const notificationUncertainBehavior = '无法确定时';
const notificationUncertainBehaviorDescription = '缺少比赛时间等关键数据时，选择不通知或显示“疑似买活”';
const notificationTolerance = '时间误差容限';
const notificationToleranceDescription = '给遥测延迟和采样误差预留缓冲，避免临界时刻误判买活';
const notificationRespawnBaseProgress = '基础复活进度';
const notificationRespawnBaseProgressDescription = '免费复活所需进度的固定起始值，对整场比赛都生效';
const notificationMatchDuration = '比赛总时长';
const notificationMatchDurationDescription = '用于将剩余时间换算为比赛已进行时间；规则变化时按新赛制调整';
const notificationTimeDivisor = '比赛时间进度除数';
const notificationTimeDivisorDescription = '控制比赛进行时间对复活所需进度的增长幅度，数值越小增长越快';
const notificationBuybackPenalty = '每次买活追加进度';
const notificationBuybackPenaltyDescription = '敌方每发生一次买活，后续免费复活所需进度增加的数值';
const notificationNormalProgressRate = '普通复活进度速度';
const notificationNormalProgressRateDescription = '基地未进入低血量状态时，每秒增长的免费复活进度';
const notificationAcceleratedProgressRate = '基地低血量加速速度';
const notificationAcceleratedProgressRateDescription =
    '基地血量达到加速条件后，每秒增长的免费复活进度';
const notificationLowBaseThreshold = '基地低血量阈值';
const notificationLowBaseThresholdDescription = '己方基地血量不高于该值时，复活公式改用加速进度速度';
const notificationDeploymentTitle = '英雄部署自动跳转';
const notificationDeploymentSubtitle = '英雄进入部署模式时倒计时进入自定义图传页面';
const notificationDeploymentEnabled = '部署时自动进入自定义图传';
const notificationDeploymentEnabledDescription = '仅英雄身份检测到部署状态从 0 变为 1 时启动自动跳转';
const notificationDeploymentCountdown = '跳转倒计时';
const notificationDeploymentCountdownDescription =
    '部署触发后等待多少秒进入自定义图传；设为 0 表示立即进入';
const notificationDeploymentAllowCancel = '允许取消本次跳转';
const notificationDeploymentAllowCancelDescription = '在倒计时卡片中显示取消操作，允许留在当前页面';
const notificationDeploymentEnterNow = '显示“立即进入”操作';
const notificationDeploymentEnterNowDescription = '允许用户跳过剩余倒计时，立即打开自定义图传';
const notificationDeploymentPrestart = '倒计时期间预启动图传';
const notificationDeploymentPrestartDescription = '提前建立自定义图传接收与解码链路，减少进入页面后的等待';
const notificationDeploymentCancelForMatch = '取消后本场不再自动跳转';
const notificationDeploymentCancelForMatchDescription =
    '用户取消一次后抑制本场后续部署触发，新比赛开始时自动恢复';
const notificationDeploymentStayOnFailure = '图传启动失败时留在当前页面';
const notificationDeploymentStayOnFailureDescription =
    '预启动失败时显示错误并停止跳转；关闭后仍会进入图传页面';
const notificationQualityTitle = '连接质量阈值';
const notificationQualitySubtitle = '综合 MQTT、UDP、自定义图传与解码链路判断连接质量';
const notificationMqttWarning = 'MQTT 无消息警告';
const notificationMqttWarningDescription = '已连接但连续未收到 MQTT 消息达到该时间后进入警告状态';
const notificationMqttCritical = 'MQTT 严重告警';
const notificationMqttCriticalDescription = 'MQTT 消息停滞达到该时间后进入严重状态，不能低于警告阈值';
const notificationUdpWarning = 'UDP 丢包率警告';
const notificationUdpWarningDescription = '统计窗口内 UDP 视频分片丢包率达到该比例后进入警告状态';
const notificationUdpCritical = 'UDP 丢包率严重告警';
const notificationUdpCriticalDescription = '统计窗口内 UDP 视频分片丢包率达到该比例后进入严重状态';
const notificationUdpWindow = 'UDP 统计窗口';
const notificationUdpWindowDescription = '使用最近这段时间的收包数据计算 UDP 丢包率，窗口越长越平稳';
const notificationCustomVideoStale = '自定义图传无数据告警';
const notificationCustomVideoStaleDescription = '自定义图传运行中连续未收到数据块达到该时间后判定链路异常';
const notificationDecoderStale = '解码链路无关键帧告警';
const notificationDecoderStaleDescription = '存在解码客户端但长时间没有关键帧时判定解码链路异常';
const notificationRecoveryStable = '质量恢复稳定时间';
const notificationRecoveryStableDescription = '异常指标恢复后持续稳定达到该时间，才通知连接质量恢复';
const notificationQualityDebounce = '质量变化防抖';
const notificationQualityDebounceDescription = '质量等级变化需持续达到该时间才生效，用于过滤瞬时网络波动';
const notificationPercentUnit = '%';
const notificationCountUnit = '条';
const notificationProgressUnit = '进度';

String notificationSensitivityLabel(NotificationSensitivity value) =>
    switch (value) {
      NotificationSensitivity.conservative => '保守',
      NotificationSensitivity.standard => '标准',
      NotificationSensitivity.sensitive => '敏感',
    };

String killLineModeLabel(KillLineMode value) => switch (value) {
  KillLineMode.expectedProjectiles => '预计弹丸',
  KillLineMode.healthPercent => '血量比例',
  KillLineMode.fixedHealth => '固定血量',
};

String uncertainBuybackLabel(UncertainBuybackBehavior value) => switch (value) {
  UncertainBuybackBehavior.suppress => '不通知',
  UncertainBuybackBehavior.suspected => '显示疑似买活',
};

String notificationSeverityLabel(NotificationSeverity value) =>
    value == NotificationSeverity.critical ? 'CRITICAL' : 'INFO';

String notificationPlacementLabel(NotificationPlacement value) =>
    switch (value) {
      NotificationPlacement.topBanner => '顶部横幅',
      NotificationPlacement.rightCorner => '右上卡片',
      NotificationPlacement.sideBeacon => '侧边信标',
    };

String criticalDismissModeLabel(CriticalDismissMode value) => switch (value) {
  CriticalDismissMode.timed => '定时关闭',
  CriticalDismissMode.acknowledgement => '用户确认',
  CriticalDismissMode.recovery => '状态恢复',
};

String notificationEventLabel(NotificationEventType type) => switch (type) {
  NotificationEventType.mqttDisconnected => 'MQTT 断开',
  NotificationEventType.mqttReconnected => 'MQTT 自动重连',
  NotificationEventType.connectionQualityChanged => '连接质量变化',
  NotificationEventType.allyAssemblyCompleted => '己方装配完成',
  NotificationEventType.allyRespawned => '己方复活',
  NotificationEventType.heroDeployAutoNavigation => '英雄部署自动跳转',
  NotificationEventType.enemyRespawned => '敌方复活',
  NotificationEventType.enemyBoughtRespawn => '敌方买活',
  NotificationEventType.enemyKillLine => '敌方进入斩杀线',
  NotificationEventType.enemyRequestedLevelFour => '敌方申请四级装配',
  NotificationEventType.moduleDisconnected => '模块断联',
  NotificationEventType.moduleRecovered => '模块恢复',
};

String notificationEventDescription(NotificationEventType type) =>
    switch (type) {
      NotificationEventType.mqttDisconnected => '客户端曾成功连接后与 MQTT 服务器断开时触发',
      NotificationEventType.mqttReconnected => 'MQTT 断开后自动恢复连接时触发',
      NotificationEventType.connectionQualityChanged => '综合网络和视频链路质量降级或恢复时触发',
      NotificationEventType.allyAssemblyCompleted => '协议上报己方机器人装配完成时触发',
      NotificationEventType.allyRespawned => '己方机器人血量从零恢复为正值时触发',
      NotificationEventType.heroDeployAutoNavigation => '英雄进入部署模式并启动自动跳转倒计时时触发',
      NotificationEventType.enemyRespawned => '敌方机器人完成普通免费、加速免费或方式不确定的复活时触发',
      NotificationEventType.enemyBoughtRespawn =>
        '敌方机器人恢复时间早于免费复活阈值并推断为付费复活时触发',
      NotificationEventType.enemyKillLine => '敌方机器人首次进入当前斩杀线阈值时触发',
      NotificationEventType.enemyRequestedLevelFour => '协议上报敌方申请四级装配时触发',
      NotificationEventType.moduleDisconnected => '机器人模块首次明确上报离线，或状态从在线变为离线时触发',
      NotificationEventType.moduleRecovered => '离线模块重新恢复在线时触发',
    };

String notificationTestHeadline(
  NotificationEventType type,
  NotificationSeverity? severity,
) {
  if (severity == NotificationSeverity.info) return 'INFO 通知测试';
  if (severity == NotificationSeverity.critical) return 'CRITICAL 通知测试';
  return '${notificationEventLabel(type)}通知测试';
}
