---
name: topic-receive-scope
description: RoboMaster 2026 MQTT 自定义客户端各 topic 的接收范围（私有 vs 全队广播），多文件合并的判定依据
metadata:
  type: reference
---

通信协议 V1.3.1 + 规则手册 V1.5.0 实测结论。MQTT(port 3333)，clientID = 所连机器人 ID。客户端经图传链路只连「对应那一台」机器人。

**接收范围三类（按数据语义判定，概览表的"发送方/接收方"列对所有 server→client topic 写法相同，不能作为判据）：**

1. **全队共享级**（同阵营任意 id 客户端收到的内容一致，合并时去重取一份即可）：
   - GameStatus（比赛全局，红蓝双方比分都含）— 实际红蓝双方完全一致
   - GlobalUnitStatus（含己方+对方基地/前哨站/所有机器人血量，按己方1/2/3/4/7+对方1/2/3/4/7顺序）
   - GlobalLogisticsStatus（己方经济/科技/加密等级）
   - GlobalSpecialMechanism、Event（全局事件通知）、PenaltyInfo（己方判罚）
   - RadarInfoToClient（雷达全场位置）、TechCoreMotionStateSync、AirSupportStatusSync、RuneStatusSync、DeployModeStatusSync、DartSelectTargetStatusSync

2. **机器人单体私有级**（只有该 id 客户端能收到自己那台的数据，合并时按 robot_id 拼成全场）：
   - RobotInjuryStat、RobotRespawnStatus、RobotStaticStatus、RobotDynamicStatus、RobotModuleStatus、Buff、SentryStatusSync、SentryCtrlResult、RobotPerformanceSelectionSync
   - RobotPosition — 文档明确「仅云台手客户端生效」，最典型私有
   - RobotPathPlanInfo — 哨兵轨迹，仅哨兵客户端
   - **合并价值最高的一类**：每个客户端只有自己 id 的，汇总后才得到全场每台机器人的明细

3. **客户端→服务器/机器人（指令，非记录重点）**：KeyboardMouseControl、CustomControl、CustomByteBlock、MapClickCmd、各种 Command。

**CustomByteBlock**：proto 里方向注释写反了。实际是「机器人→图传链路→自定义客户端，50Hz，对应0x0310」，即机器人上传给对应 id 客户端的私有数据流（最大2.4kbit）。属机器人单体私有级。

**阵营判定**：id 1-11=红，101-111=蓝。1英雄/2工程/3,4,5步兵/6空中/7哨兵/8飞镖/9雷达/10前哨站/11基地。客户端 isBlue = id>=100。

合并主键：robot_id（私有数据归位）+ timestamp（时序对齐）。全队共享数据多文件取并集后按 timestamp 去重。
