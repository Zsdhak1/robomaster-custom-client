# Feature Spec — WOD Client 自定义客户端数据监控 (RoboMaster 2026 V1.3.1)

## 项目概览

| 属性     | 值                             |
| ------ | ----------------------------- |
| 项目名称   | WOD Client（自定义客户端监控） |
| 技术栈    | Flutter 3.x + Dart 3.x        |
| 目标平台   | Android, Linux Desktop, Windows Desktop |
| 状态管理   | flutter_riverpod              |
| 图表库    | fl_chart                      |
| 当前版本   | 0.1.5（以 `pubspec.yaml` 为准） |

> **架构说明：** 本监控客户端仅对接自定义客户端的两条标准链路：
> 1. **MQTT 3333** — 控制指令、配置、比赛状态与事件（Protobuf 序列化）
> 2. **UDP 3334** — HEVC(H.265) AnnexB 视频流（自定义字节偏移分片，非 RTP FU）
>
> 不涉及裁判系统与机器人间的串口协议（第1章内容）。

---

## 新 Agent 接手摘要

| 项 | 当前结论 |
|---|---|
| 当前版本 | `0.1.5`，通知规则准确性校正已实现、待发布；版本号以 `pubspec.yaml` 为唯一权威。 |
| 当前状态 | `v0.1.5 Phase 1, Task 1` 至 `v0.1.5 Phase 1, Task 8` 已完成；针对性测试 71 项、全量测试 266 项通过，`flutter analyze` 零问题。 |
| 产品定位 | 面向操作手的信息副屏：提供可核对的比赛状态、通知和设备信息，不提供指挥决策；本版本未修改自定义图传或操作面板。 |
| 长期路线 | `v0.1.5` 已从候选路线转为当前开发版本；`v0.1.6` 至 `v0.2.2` 仍为候选，详见 `docs/superpowers/specs/2026-07-19-long-term-development-roadmap-design.md`。 |
| 历史待办 | `v0.0.1 Phase 3, Task 3.5` 是历史遗留未交付项，已纳入候选 `v0.2.0` 赛后分析看板方向；该版本启动时必须先运行 brainstorming，当前不作为默认下一任务。 |
| 主要链路 | 官方线：MQTT 3333 + UDP 3334 HEVC；自定义图传线：MQTT `CustomByteBlock` / `0x0310` + H.264 + 独立 TCP 解码桥。 |
| 设计现状 | v0.1.1 已完成 Typography、Color、Layout、Elevation、Motion 的 MD3 收口；继续 UI 工作时先复用现有 theme/responsive/provider。 |
| 验证命令 | 每次文件写入后运行 `flutter analyze`；改动 Dart 逻辑时补跑最小相关测试，发布前跑 `flutter test`。 |
| 搜索入口 | 代码发现优先用 codebase-memory MCP（若本线程可用），不可用或查文档/配置时用 `rg`。 |

---

## 开发进度表

> **AI 执行指令：** 按 Phase 顺序逐个完成，在每个Phase开始前，必须询问用户这个Phase的具体执行方式，确认用户需求理解无误之后开始具体执行。每完成一个 Task，在状态列标记 `[x]`，运行 `flutter analyze` 确认零警告，执行自审计检查清单，然后自动进入下一个 Task。严禁跳过 Phase。

> **版本化规范：** 开发进度以**版本号为顶层迭代单元**。每个版本（如 `v0.1.0`）是一次独立迭代，其内部 Phase 与 Task 从 `Phase 1, Task 1` 重新编号。在本表登记或更新任务时，**必须在功能描述前标注其所属版本号 + Phase + Task**，格式为 `vX.Y.Z Phase N, Task M`（例：`v0.1.0 Phase 1, Task 1`）。版本号须与 `pubspec.yaml` 的 `version` 字段、附录 E Changelog、git tag 三者一致（见附录 E.1）。**历史版本（v0.0.1 / v0.0.2）保留其原始 Phase 编号以便追溯**，新版本（v0.1.0 起）一律从 Phase 1 Task 1 起编。

---

### v0.1.5 — 通知规则准确性校正（2026-07-22）

> **状态：已实现，待发布。** 本版本在现有通知档案、规则引擎和 Dashboard 基础上，提高操作手信息副屏的通知准确性与状态可见性；不把客户端定位为指挥面板，不修改自定义图传或操作面板。

#### Phase 1: 通知准确性校正与运行时接入

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.5 Phase 1, Task 1 | 正式登记版本与规则默认值 | 登记应用与官方规则版本，并校正敌方复活严重级别和 17mm/42mm 默认伤害 | `pubspec.yaml`, `feature_spec.md`, `lib/features/settings/domain/kill_estimate_config.dart`, `lib/features/settings/domain/notification_rule_profile.dart`, `test/notification_rule_profile_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 2 | Buff 有效状态跟踪 | 按机器人、Buff 类型和协议剩余时间跟踪攻防 Buff，拒绝越界与乱序输入并清理过期项 | `lib/features/dashboard/logic/combat_buff_tracker.dart`, `test/combat_buff_tracker_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 3 | 操作手斩杀线校正 | 按当前操作手武器、敌方目标血量及双方攻防 Buff 估算弹丸或工程撞击需求，并修复零伤害后的重新触发 | `lib/features/dashboard/logic/kill_line_notification_tracker.dart`, `lib/features/dashboard/logic/notification_rule_engine.dart`, `lib/features/dashboard/logic/notification_rule_models.dart`, `test/notification_rule_engine_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 4 | 敌方复活分类 | 将敌方复活区分为普通免费、加速免费、付费和方式不确定；缺少必要数据时安全降级，不把不确定事件误报为付费 | `lib/features/dashboard/logic/notification_rule_engine.dart`, `test/notification_rule_engine_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 5 | 共享模块状态监控 | 仅合并 Protobuf 中明确出现且数值已知的模块字段，生成离线与恢复转换，并由通知运行时共享唯一状态源 | `lib/features/dashboard/logic/module_status_monitor.dart`, `lib/features/dashboard/logic/notification_protocol_tracker.dart`, `lib/features/dashboard/logic/notification_providers.dart`, `test/module_status_monitor_test.dart`, `test/notification_runtime_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 6 | 模块持久显示面板 | 任一已知模块离线时在 Dashboard 侧栏持续显示模块状态，全部恢复后切回事件时间轴；通知开关不影响面板，事件仍继续记录 | `lib/features/dashboard/presentation/module_status_strings.dart`, `lib/features/dashboard/presentation/widgets/module_status_panel.dart`, `lib/features/dashboard/presentation/widgets/dashboard_side_panel.dart`, `test/dashboard_side_panel_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 7 | 实时协议与重置边界接入 | 接入 Buff Topic、模块字段和共享状态；在 MQTT 断开、新小局、离开比赛阶段（含异常结束兜底）及操作身份变化时清理比赛临时状态 | `lib/features/dashboard/logic/notification_providers.dart`, `test/notification_runtime_test.dart`, `test/notification_runtime_widget_test.dart` | `[x]` |
| v0.1.5 Phase 1, Task 8 | 回归、自审与文档收口 | 运行格式检查、针对性/全量回归与静态分析，完成发布前自审、验收记录和版本文档 | `feature_spec.md`, `.superpowers/sdd/task-8-report.md` | `[x]` |

**v0.1.5 验收标准：** 官方通知规则档案与 17mm/42mm 伤害基线准确；斩杀线结合当前操作手武器、目标血量和攻防 Buff；敌方复活可区分普通免费、加速免费、付费和方式不确定；任一明确离线模块在侧栏持续可见；比赛临时状态在断线、新小局、离开比赛阶段和身份变化时完整清理；自定义图传与操作面板保持不变。

**v0.1.5 验收结果（2026-07-22）：** 官方规则版本更新为 `2.0.0`，敌方普通复活为 INFO、付费复活为 CRITICAL，17mm/42mm 默认伤害为 20/200；斩杀线按操作手身份选择 17mm、42mm 或工程撞击并计算攻防 Buff；敌方复活按普通免费、基地低血量、补给区或原因不确定的加速免费、付费和方式不确定分类，并遵循不确定事件的抑制设置；Buff、比赛倒计时和敌方基地血量仅在 Protobuf 必要字段明确出现时参与判定；模块状态面板在任一明确离线模块存在时持续显示，全部恢复后切回事件时间轴；恢复事件会先关闭持续告警，比赛重置会清理可见通知、冷却和 UDP 采样基线但保留历史；MQTT 断开、新小局、离开比赛阶段（包括未收到正常结算的异常结束兜底）和身份变化均清理比赛临时状态，连接会话 fence 会拒绝断线期间和旧 generation 的迟到消息。敌方详情模式已移除最低血量选敌算法和指挥性集火建议，仅保留中性状态展示；本版本未修改自定义图传或操作面板。针对性测试 71 项通过，`flutter analyze` 零问题，全量测试 266 项通过。

---

### v0.1.4 — 操作面板规则校正与协议状态接入（2026-07-20）

> **状态：已实现，待发布。** 本版本校正常规/远程兑换指令，移除副屏复活确认，使用机器人动态状态控制远程操作，并用科技核心状态驱动工程兑换/装配流程。详细执行清单见 `docs/superpowers/plans/2026-07-20-v014-operation-panel.md`。

#### Phase 1: 指令边界与协议常量

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.4 Phase 1, Task 1 | 操作指令常量 | 为 17mm/42mm、远程回血/买弹和工程开始/确认/取消提取命名协议常量，明确远程买弹最小单位 100 发 | `lib/core/constants/protocol_constants.dart` | `[x]` |
| v0.1.4 Phase 1, Task 2 | MQTT 操作指令服务 | 将 `CommonCommand` / `AssemblyCommand` 构建和发布移出 Widget，提供可注入发布函数和角色明确的方法 | `lib/features/dashboard/data/operation_command_service.dart` | `[x]` |
| v0.1.4 Phase 1, Task 3 | 指令服务测试 | 验证每个方法的 Topic、Protobuf 类型、`cmd_type`、`operation`、难度和数量参数 | `test/operation_command_service_test.dart` | `[x]` |

**Phase 1 验收标准：** Widget 不再直接构建或发布操作 Protobuf；英雄 42mm 使用命令类型 2，远程买弹使用参数 100；指令服务测试覆盖全部保留操作。

---

#### Phase 2: 操作状态控制器与协议同步

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.4 Phase 2, Task 1 | 操作面板状态模型 | 定义身份类别、远程操作可用状态、单次脉冲序号、科技核心步骤、自动确认状态和结构化反馈模型 | `lib/features/dashboard/domain/operation_panel_state.dart` | `[x]` |
| v0.1.4 Phase 2, Task 2 | 状态与重发控制器 | 监听 `RobotDynamicStatus`、`TechCoreMotionStateSync`、登录身份和 MQTT 连接；管理开始兑换/确认装配重发，并在完成、取消、流程复位、断线、身份切换或释放时停止 | `lib/features/dashboard/logic/operation_panel_controller.dart` | `[x]` |
| v0.1.4 Phase 2, Task 3 | 控制器测试 | 覆盖首帧不脉冲、false→true 单次脉冲、身份重置、最高难度、流程进入/完成/复位及所有定时任务停止条件 | `test/operation_panel_controller_test.dart` | `[x]` |

**Phase 2 验收标准：** 操作状态完全由真实协议消息和显式用户操作驱动；定时发送不依赖 Widget 生命周期变量；首次状态快照不误触发脉冲；未知状态安全禁用操作。

---

#### Phase 3: 操作面板界面接入

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.4 Phase 3, Task 1 | 文案与组件拆分 | 集中操作面板 UI 文案，拆分通用按钮、脉冲外框、英雄/步兵区和工程状态区，保证单函数不超过 50 行 | `lib/features/dashboard/presentation/operation_panel_strings.dart`, `lib/features/dashboard/presentation/widgets/operation_panel_sections.dart` | `[x]` |
| v0.1.4 Phase 3, Task 2 | 英雄/步兵操作接入 | 复用控制器发送常规兑换、远程回血/买弹；移除复活按钮；未知/不可用状态禁用并显示准确原因；可用转换播放一次低强度脉冲 | `lib/features/dashboard/presentation/widgets/operation_panel.dart` | `[x]` |
| v0.1.4 Phase 3, Task 3 | 工程状态界面 | 展示最高难度、基础运动状态、放入/平移/旋转步骤及总/步骤剩余时间；接入开始兑换、自动确认和取消操作 | `lib/features/dashboard/presentation/widgets/operation_panel.dart`, `operation_panel_sections.dart` | `[x]` |
| v0.1.4 Phase 3, Task 4 | 组件测试 | 覆盖英雄/步兵无复活按钮、远程按钮禁用/启用、单次脉冲、工程步骤和窄高度无溢出 | `test/operation_panel_test.dart` | `[x]` |

**Phase 3 验收标准：** 操作面板只通过 Controller 修改状态；所有登录身份显示正确控件；远程操作和工程流程均由协议状态驱动；现有 Material 3 触控、hover、focus、pressed、disabled 反馈保持有效。

---

#### Phase 4: 回归、自审与文档收口

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.4 Phase 4, Task 1 | 相关回归 | 运行操作指令、控制器、操作面板、比赛状态和通知运行时相关测试，修复回归 | `test/operation_*_test.dart`, `test/game_state_notifier_test.dart`, `test/notification_runtime_test.dart` | `[x]` |
| v0.1.4 Phase 4, Task 2 | 全量验证与自审 | 运行格式化、`flutter analyze` 和全量 `flutter test`；检查函数长度、状态分层、字符串常量、异步错误和平台兼容 | 验证结果 | `[x]` |
| v0.1.4 Phase 4, Task 3 | 版本文档收口 | 更新接手摘要、任务状态、验收结果、文档版本和附录 E Changelog；保持 pubspec、进度表和发布版本一致 | `feature_spec.md` | `[x]` |

**v0.1.4 验收标准：** 所有保留操作使用正确协议参数；副屏不提供复活确认；远程回血/买弹由协议字段控制并在首次变为可用时仅脉冲一次；工程界面展示真实科技核心状态且重发任务在全部终止条件下停止；`flutter analyze` 零问题且全量测试通过。

**v0.1.4 验收结果（2026-07-21）：** 英雄 42mm 常规兑换使用 `cmd_type = 2`，远程买弹使用参数 100；副屏已移除复活确认；远程回血/买弹由 `can_remote_heal` / `can_remote_ammo` 控制，首次从不可用变为可用时播放一次 700ms 低强度脉冲；工程界面展示最高难度、基础运动状态、放入/平移/旋转和两类剩余时间，开始兑换与自动确认重发会在完成、取消、流程复位、剩余时间归零、断线、身份切换和 Provider 释放时停止。聚焦回归 26 项通过，`flutter analyze` 零问题，全量测试 197 项通过。

---

### v0.1.3 — 通知与比赛规则可配置化（2026-07-13）

> **状态：已实现，待发布。** 本版本已把通知实验台升级为可长期维护的通知系统：具备版本化规则档案、JSON 导入导出、持久化设置、Material 3 设置与手动测试入口、全局通知运行时、战术规则、部署模式自动跳转、连接质量与模块状态通知。

#### Phase 1: 通知设置与规则配置基础

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 1, Task 1 | 通知与比赛规则模型 | 定义通知总览、事件开关、斩杀线、复活判定、部署自动跳转、连接质量和版本化规则档案；全部模型实现 `toJson/fromJson`、默认值、范围钳制和不可变复制 | `lib/features/settings/domain/notification_*.dart` | `[x]` |
| v0.1.3 Phase 1, Task 2 | 配置档案持久化 | 使用 SharedPreferences 保存官方只读档案、自定义档案与当前激活档案；支持复制、切换、更新、恢复默认和删除 | `lib/features/settings/logic/notification_profile_provider.dart` | `[x]` |
| v0.1.3 Phase 1, Task 3 | JSON 导入导出 | 使用 file_selector 导入/导出带 `schema_version`、协议版本和规则版本的 JSON 档案，非法档案显示用户可见错误 | `lib/features/settings/data/notification_profile_file_service.dart` | `[x]` |
| v0.1.3 Phase 1, Task 4 | Material 3 设置入口 | 在设置 Master–Detail 分类中新增“通知与规则”，提供档案管理、通知总览、斩杀线、敌方复活、部署跳转和连接质量基础表单 | `lib/features/settings/presentation/notification_rules_settings_screen.dart`, `settings_screen.dart` | `[x]` |
| v0.1.3 Phase 1, Task 5 | 配置测试与验证 | 覆盖 JSON 往返、非法值钳制、官方档案保护、复制/导入和设置页基础渲染；运行 analyze 与相关测试 | `test/notification_rule_profile_test.dart`, `test/notification_profile_provider_test.dart`, `test/notification_rules_settings_screen_test.dart` | `[x]` |

**Phase 1 验收标准：** 用户可在设置页查看官方规则档案、复制为自定义档案、切换当前档案、修改常用通知与规则参数、恢复默认，并通过 JSON 文件导入/导出；官方档案不可直接修改；所有配置可持久化且异常输入安全降级；本阶段不改变实时通知触发逻辑。

---

#### Phase 2: 通知运行时、分级展示与历史

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 2, Task 1 | 通知运行时模型 | 将通知类型、严重级别、展示位置、自动关闭策略、去重键和历史记录整合为不可变运行时模型 | `lib/features/dashboard/logic/dashboard_notification_models.dart` | `[x]` |
| v0.1.3 Phase 2, Task 2 | 规则化通知控制器 | 按激活档案执行事件开关、冷却、INFO 最大可见数、CRITICAL 确认/恢复关闭和历史上限；保留开发者预览入口 | `lib/features/dashboard/logic/dashboard_notification_controller.dart` | `[x]` |
| v0.1.3 Phase 2, Task 3 | 全局通知宿主 | 将通知覆盖层提升到 AppShell 内容区，使监控、视频、数据和设置页面均能实时看到通知；INFO/CRITICAL 可分别使用设置中的展示位置 | `lib/core/navigation/app_shell.dart`, `dashboard_notification_overlay.dart` | `[x]` |
| v0.1.3 Phase 2, Task 4 | 通知历史与反馈 | 提供本次运行内的通知历史、清空操作，并按设置触发系统提示音及 Android 震动 | `lib/features/dashboard/presentation/widgets/notification_history_sheet.dart` | `[x]` |

**Phase 2 验收标准：** 激活档案实时决定通知是否显示、严重级别、位置、持续时间、确认方式与冷却；不同级别可同时出现在不同位置；历史数量受配置限制；关闭通知不影响历史记录。

---

#### Phase 3: 英雄部署模式自动进入自定义图传

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 3, Task 1 | 可编程顶层导航 | 将 AppShell 当前目标页改为 Riverpod 状态，使通知运行时可安全切换到自定义图传页，同时保留 IndexedStack 页面状态 | `lib/core/navigation/app_shell.dart`, `app_navigation_rail.dart` | `[x]` |
| v0.1.3 Phase 3, Task 2 | 部署倒计时控制器 | 仅在登录身份为英雄且 `DeployModeStatusSync.status` 从 0 变为 1 时启动配置秒数倒计时；支持取消、立即进入、本场抑制和新比赛重置 | `lib/features/dashboard/logic/deployment_navigation_controller.dart` | `[x]` |
| v0.1.3 Phase 3, Task 3 | 图传预启动与失败降级 | 按档案配置在倒计时期间预启动自定义图传；启动失败时显示错误，并按策略留在当前页或继续跳转 | `lib/features/dashboard/logic/notification_providers.dart` | `[x]` |
| v0.1.3 Phase 3, Task 4 | Material 3 倒计时提示 | 使用高显著度 MD3 色调卡片显示剩余秒数、取消和立即进入操作，并覆盖桌面与紧凑布局 | `lib/features/dashboard/presentation/widgets/deployment_countdown_overlay.dart` | `[x]` |

**Phase 3 验收标准：** 非英雄身份、首次收到已部署状态和重复状态均不触发；英雄 0→1 后默认倒数 3 秒进入自定义图传，用户可取消或立即进入；失败降级和本场抑制遵循当前档案。

---

#### Phase 4: 斩杀线、复活/买活与比赛事件判定

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 4, Task 1 | 敌方斩杀线引擎 | 按预计弹丸、血量比例或固定血量模式检测敌方英雄/工程/步兵/哨兵进入斩杀线，并执行再武装差值和冷却 | `lib/features/dashboard/logic/notification_rule_engine.dart` | `[x]` |
| v0.1.3 Phase 4, Task 2 | 敌方复活与买活判定 | 记录敌方血量清零时间，按比赛剩余时间、历史买活次数、基地低血量加速和容差计算免费复活最早时刻；提前恢复判为买活 | `lib/features/dashboard/logic/notification_rule_engine.dart` | `[x]` |
| v0.1.3 Phase 4, Task 3 | 己方复活与装配事件 | 检测己方机器人 0→正血量、装配成功事件和敌方申请四级装配事件，并映射为配置中的 INFO/CRITICAL 通知 | `lib/features/dashboard/logic/notification_rule_engine.dart`, `dashboard_notification_factory.dart` | `[x]` |
| v0.1.3 Phase 4, Task 4 | 战术规则测试 | 覆盖三种斩杀线、冷却/再武装、正常复活、买活、疑似买活、己方复活和协议事件映射 | `test/notification_rule_engine_test.dart` | `[x]` |

**Phase 4 验收标准：** 血量变化不会重复刷屏；敌方在免费复活最早时刻前恢复时产生买活通知，到时或之后恢复时产生普通复活通知；缺失关键比赛信息时遵循“抑制/疑似”配置。

---

#### Phase 5: MQTT、连接质量与模块状态通知

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 5, Task 1 | MQTT 断开与重连 | 忽略应用启动时的初始未连接状态，仅在曾连接后断开时通知，并在随后恢复连接时通知重连成功 | `lib/features/dashboard/logic/notification_providers.dart` | `[x]` |
| v0.1.3 Phase 5, Task 2 | 连接质量评估器 | 依据 MQTT 消息停滞、UDP 窗口丢包率、自定义图传块停滞和关键帧/解码停滞计算 good/warning/critical；执行防抖和稳定恢复 | `lib/features/dashboard/logic/connection_quality_evaluator.dart` | `[x]` |
| v0.1.3 Phase 5, Task 3 | 模块断联与恢复 | 对 `RobotModuleStatus` 建立首帧基线，检测每个模块在线→离线和离线→恢复，断联使用 CRITICAL、恢复使用 INFO | `lib/features/dashboard/logic/notification_rule_engine.dart` | `[x]` |
| v0.1.3 Phase 5, Task 4 | 设置表单补全 | 补齐通知位置、CRITICAL 关闭方式、事件级别/声音/冷却、复活公式、部署失败策略和全部连接质量阈值的可视化配置 | `lib/features/settings/presentation/widgets/notification_*.dart` | `[x]` |
| v0.1.3 Phase 5, Task 5 | 连接与模块测试 | 覆盖初始连接、断开/重连、质量降级/恢复、防抖、模块断联/恢复和设置页交互 | `test/connection_quality_evaluator_test.dart`, `test/notification_runtime_test.dart` | `[x]` |

**Phase 5 验收标准：** 图片中列出的 MQTT 断开、MQTT 重连、连接质量、模块断联通知均由真实运行状态驱动；质量波动受防抖和恢复稳定时间约束；首次状态快照不产生误报。

---

#### Phase 6: 完整回归与交付

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 6, Task 1 | 场景级组件测试 | 覆盖全局通知宿主、INFO/CRITICAL 分位显示、历史、部署倒计时取消/立即进入和图传失败反馈 | `test/notification_runtime_widget_test.dart` | `[x]` |
| v0.1.3 Phase 6, Task 2 | 自审与全量验证 | 已完成格式化、函数/文件长度、空安全、异步错误、MD3 与跨平台自审；`flutter analyze` 零问题，173 项全量测试通过 | 验证结果 | `[x]` |
| v0.1.3 Phase 6, Task 3 | 文档收口 | 更新新 Agent 接手摘要、v0.1.3 状态、任务完成标记和 Changelog，使规格、版本号与实现一致 | `feature_spec.md` | `[x]` |

**v0.1.3 验收标准：** 图片中的 INFO/CRITICAL 通知均有真实数据触发链路；英雄部署自动跳转可取消；斩杀线和买活逻辑由档案配置驱动；规则变化可通过设置或 JSON 档案适配；所有通知具备冷却、历史和错误降级；`flutter analyze` 零问题且全量测试通过。

---

#### Phase 7: 设置页手动通知测试

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 7, Task 1 | Material 3 通知测试卡片 | 在“通知与规则”设置页增加通知测试卡片，提供 INFO、CRITICAL 和全部事件类型的手动触发入口 | `lib/features/settings/presentation/widgets/notification_test_section.dart` | `[x]` |
| v0.1.3 Phase 7, Task 2 | 全局预览调度 | 通过设置 Feature 内的请求接口和 AppShell 组合层连接全局通知控制器；测试通知使用当前档案的位置、时长、关闭、声音与震动设置，但绕过事件开关和冷却 | `lib/features/settings/logic/notification_test_provider.dart`, `lib/core/navigation/app_shell.dart` | `[x]` |
| v0.1.3 Phase 7, Task 3 | 测试与回归 | 覆盖设置页手动触发、INFO/CRITICAL 级别覆盖、事件档案设置应用和全局覆盖层显示；`flutter analyze` 零问题，173 项全量测试通过 | `test/notification_rules_settings_screen_test.dart`, `test/dashboard_notification_controller_test.dart`, `test/notification_runtime_widget_test.dart` | `[x]` |

**Phase 7 验收标准：** 用户可在设置页直接触发 INFO、CRITICAL 或任意已定义事件的测试通知；测试不受全局/事件启用开关和冷却阻挡，但准确使用当前档案的展示位置、持续时间、确认策略、历史、声音与 Android 震动配置。

---

#### Phase 8: 通知设置逐项作用说明

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 8, Task 1 | 辅助文本组件与集中式文案 | 为滑杆和自定义选择器增加统一的 MD3 辅助文本样式，并集中定义所有通知设置作用说明 | `notification_settings_components.dart`, `notification_settings_strings.dart` | `[x]` |
| v0.1.3 Phase 8, Task 2 | 全设置说明补全 | 为通知总览、事件级设置、斩杀线、复活公式、部署跳转、连接质量和档案选择中的每个设置补充具体作用描述 | `lib/features/settings/presentation/widgets/notification_*.dart` | `[x]` |
| v0.1.3 Phase 8, Task 3 | 描述渲染测试与回归 | 验证关键设置说明在页面中可见；`flutter analyze` 零问题，173 项全量测试通过 | `test/notification_rules_settings_screen_test.dart` | `[x]` |

**Phase 8 验收标准：** “通知与规则”页面的每个可配置项均具有紧邻控件的具体作用说明；说明使用 `bodySmall` 与 `onSurfaceVariant` 语义色，不依赖悬停才能阅读，并在紧凑与桌面布局中保持可访问性。

---

#### Phase 9: 通知设置二级页面整理

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 9, Task 1 | 设置目录信息架构 | 将原长列表整理为“通知管理”和“比赛与链路规则”两组 Material 3 列表入口，集中展示六个二级页面的名称、图标与用途摘要 | `notification_rules_settings_screen.dart`, `notification_settings_strings.dart` | `[x]` |
| v0.1.3 Phase 9, Task 2 | 六个二级配置页面 | 拆分规则档案、通知展示与测试、事件通知、斩杀线与复活、英雄部署跳转、连接质量页面；复用现有 Provider、文件导入导出和设置组件，并兼容紧凑全屏与宽屏嵌套 Navigator | `notification_profile_settings_screen.dart`, `notification_settings_subpages.dart`, `settings_screen.dart` | `[x]` |
| v0.1.3 Phase 9, Task 3 | 导航测试与完整回归 | 验证六个入口、页面标题、关键设置说明、档案复制、手动通知测试和返回目录行为；已完成格式化，`flutter analyze` 零问题，175 项全量测试通过 | `test/notification_rules_settings_screen_test.dart` | `[x]` |

**Phase 9 验收标准：** “通知与规则”首页只承担目录导航，不再显示完整设置表单；六个入口的名称与目标内容一致，桌面宽屏在详情区内完成二级跳转，紧凑布局使用标准全屏返回导航；现有设置、档案管理和手动通知测试行为保持不变。

---

#### Phase 10: 桌面设置导航交互修复

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 10, Task 1 | 返回按钮命中区修复 | 避免 Windows 顶部拖动区域覆盖设置详情返回按钮中心，保持至少 48dp 可点击目标与正常窗口拖动能力 | `settings_screen.dart`, `notification_rules_settings_screen_test.dart` | `[x]` |
| v0.1.3 Phase 10, Task 2 | 二级页面过渡表面修复 | 为宽屏嵌入式通知二级页面绘制完整不透明的 MD3 `surface`，防止路由进入动画期间新旧内容透叠 | `notification_settings_subpages.dart` | `[x]` |
| v0.1.3 Phase 10, Task 3 | 交互回归验证 | 覆盖 Windows 窗口框架下返回按钮点击、过渡中页面表面尺寸与原有通知导航；已完成格式化，`flutter analyze` 零问题，178 项全量测试通过 | `notification_rules_settings_screen_test.dart`, `desktop_window_frame_test.dart` | `[x]` |

**Phase 10 验收标准：** Windows 桌面端返回按钮整个中心区域均可点击，点击后优先退出通知二级页面；进入任一通知二级页面时不再出现目录文字和新页面内容透叠；紧凑布局、窗口拖动和窗口控制按钮行为不受影响。

---

#### Phase 11: 全局 MiSans 字体统一

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 11, Task 1 | MiSans 字体资源与主题接入 | 从官方字体包接入 Regular、Medium、Semibold、Bold、Heavy 字重，在 Flutter 字体清单、全局主题和响应式文本主题中统一使用 MiSans | `assets/fonts/`, `pubspec.yaml`, `lib/core/theme/text_theme.dart`, `lib/core/theme/app_theme.dart` | `[x]` |
| v0.1.3 Phase 11, Task 2 | 字体配置验证 | 验证全局主题与响应式文本主题均解析为 MiSans，并运行 `flutter analyze` | `test/app_theme_font_test.dart` | `[x]` |

**Phase 11 验收标准：** 普通界面文字在 Android、Linux 和 Windows 上统一使用随应用打包的 MiSans；400、500、600、700、900 字重均有明确字体资源映射；调试数据中显式声明的等宽字体保持不变；`flutter analyze` 零问题且字体主题测试通过。

---

#### Phase 12: Windows 发布构建修复

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.3 Phase 12, Task 1 | fvp 符号链接解压兼容 | 将 fvp 升级到包含真实路径解压修复的 0.37.3，解决新版 CMake 拒绝在 Flutter 插件符号链接目录中解压 MDK SDK，恢复 GitHub Actions Windows release 构建 | `pubspec.lock`, `feature_spec.md` | `[x]` |

**Phase 12 验收标准：** `flutter analyze` 零问题；GitHub Actions 的 Build Windows 作业可完成 MDK SDK 下载、解压、编译与产物上传，不再出现 `Cannot extract through symlink`。

---

### v0.1.2 — 仪表盘血量可视化、击杀估算与桌面等比缩放（2026-07-11）

> **状态：已实现，待发布。** 本版本把仪表盘调整为固定设计画布上的实时比赛 HUD：机器人行直接承载血量进度与低血量告警，底部集中展示比赛、操作、录制和连接状态；Windows/Linux 桌面端整体等比缩放，保证全屏与不同窗口尺寸下布局比例一致。

#### Phase 1: 击杀估算参数模型与设置

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.2 Phase 1, Task 1 | 击杀估算配置模型 | 定义命中率、17mm/42mm 单发伤害、英雄/工程/步兵3/步兵4/哨兵血量上限；实现 `toJson/fromJson`、输入钳制、默认值和预计弹丸纯函数 | `lib/features/settings/domain/kill_estimate_config.dart` | `[x]` |
| v0.1.2 Phase 1, Task 2 | 配置持久化 Provider | 使用 SharedPreferences 持久化击杀估算配置，支持逐项更新与恢复默认值 | `lib/features/settings/logic/kill_estimate_provider.dart` | `[x]` |
| v0.1.2 Phase 1, Task 3 | 仪表盘设置入口 | 在仪表盘设置页新增“击杀估算参数”区段，提供命中率、弹丸伤害和各机器人血量上限的校验输入 | `lib/features/settings/presentation/dashboard_settings_screen.dart` | `[x]` |

#### Phase 2: 机器人血量卡片与预计击杀弹丸量

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.2 Phase 2, Task 1 | 整行血量卡片 | 将机器人普通列表行改为整行血量卡片；彩色填充宽度等于当前血量/配置血量上限，损失部分使用 surface 色；头像/文字与预计弹丸覆盖层使用半透明亚克力材质透出连续血条 | `lib/features/dashboard/presentation/widgets/robot_status_list.dart` | `[x]` |
| v0.1.2 Phase 2, Task 2 | 血量节点语义色 | 正常血量使用阵营色；低于 60% 切换橙色，低于 30% 切换红色，低于 25% 增加轻微脉冲告警；宽度和颜色变化使用平滑动画 | `lib/features/dashboard/presentation/widgets/robot_status_list.dart` | `[x]` |
| v0.1.2 Phase 2, Task 3 | 预计弹丸显示 | 右侧区域显示 `ceil(当前血量 / (单发伤害 × 命中率))`；英雄使用大弹丸，步兵/哨兵使用小弹丸，无射击能力身份显示不适用；无人机继续显示反制进度 | `lib/features/dashboard/presentation/widgets/robot_status_list.dart` | `[x]` |
| v0.1.2 Phase 2, Task 4 | 无数据扫描光晕 | 普通机器人尚未获取血量遥测时，在整行血量显示层循环播放从左到右的阵营色渐变光晕，提示该区域为血条；收到数据后立即停止并复位，无人机反制进度不播放该动画 | `lib/features/dashboard/presentation/widgets/robot_status_list.dart` | `[x]` |

#### Phase 3: 底部状态面板与 MD3 操作按钮

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.2 Phase 3, Task 1 | 比赛状态纵向卡片 | 比赛状态卡片占满底部栏高度，并展示阶段、局数、比分、剩余/已过时间、暂停、经济、科技、加密和特殊机制；缺失数据不伪造为 0 | `lib/features/dashboard/presentation/widgets/game_status_card.dart` | `[x]` |
| v0.1.2 Phase 3, Task 2 | 录制状态卡片 | 新增录制状态面板，展示录制中/停止、消息数、起止时间、持续时间和容量；只局部刷新运行时长 | `lib/features/dashboard/presentation/widgets/recording_status_panel.dart` | `[x]` |
| v0.1.2 Phase 3, Task 3 | 四面板底部布局 | 移除空白占位，正确排列比赛状态、操作、录制状态与连接质量，保证连接信息不裁切 | `lib/features/dashboard/presentation/dashboard_screen.dart` | `[x]` |
| v0.1.2 Phase 3, Task 4 | MD3 原生操作按钮 | 四个英雄/步兵操作统一使用 `FilledButton.tonalIcon`，共享高度、图标、文字、间距和状态样式，保留 hover/focus/pressed/disabled 反馈 | `lib/features/dashboard/presentation/widgets/operation_panel.dart` | `[x]` |
| v0.1.2 Phase 3, Task 5 | 面板安全边距统一 | Dashboard 底部四面板统一使用相同的窗口边距、面板间距和零 Card 外边距，避免操作/连接面板贴住窗口边框；底部栏增加内容安全高度，连接质量改为固定可见的紧凑摘要 | `lib/features/dashboard/presentation/dashboard_screen.dart`, `game_status_card.dart`, `recording_status_panel.dart`, `connection_quality_panel.dart` | `[x]` |
| v0.1.2 Phase 3, Task 6 | 操作按钮对比度与买弹数量 | 操作按钮改用有静止阴影的高对比度 MD3 Filled 按钮；英雄/步兵普通买弹支持选择 10/20/30/50 发，并把所选数量写入 CommonCommand.param；滚动视口为按钮阴影保留底部安全区 | `lib/features/dashboard/presentation/widgets/operation_panel.dart` | `[x]` |

#### Phase 4: 桌面固定设计画布整体缩放

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.2 Phase 4, Task 1 | 桌面设计画布 | Windows/Linux 以 1280×720 固定画布排版，使用单一 `min(widthRatio, heightRatio)` 对应用外壳整体缩放，避免组件尺寸缩放后布局继续拉伸 | `lib/core/responsive/desktop_design_canvas.dart`, `lib/core/navigation/app_shell.dart` | `[x]` |
| v0.1.2 Phase 4, Task 2 | 比例不匹配降级 | 非 16:9 窗口使用 contain 策略居中留边，不变形、不裁切；Android 保留紧凑/自适应导航布局 | `lib/core/responsive/desktop_design_canvas.dart` | `[x]` |
| v0.1.2 Phase 4, Task 3 | 高分辨率全屏放大修复 | 强制桌面 `FittedBox` 占满窗口约束，修复窗口大于 1280×720 时画布只保持原始尺寸而不继续放大的问题；Windows/Linux 共用逻辑像素 contain 策略，Android 明确绕过固定画布 | `lib/core/responsive/desktop_design_canvas.dart`, `test/desktop_design_canvas_test.dart` | `[x]` |
| v0.1.2 Phase 4, Task 4 | 3:2～16:9 可变设计画布 | 桌面窗口处于允许比例范围时，以 720 为设计高度、按实时宽高比生成 1080～1280 的可变设计宽度；主内容与底部面板通过 Flex 同步分配宽度，避免固定 16:9 画布产生留白；超出范围时才使用 contain 降级 | `lib/core/responsive/desktop_design_canvas.dart`, `lib/core/responsive/responsive_ext.dart` | `[x]` |
| v0.1.2 Phase 4, Task 5 | Windows 页面内窗口控件 | 移除 Windows 原生标题栏，不再新增独立应用标题行；仅把透明拖动区和最小化、最大化/还原、关闭按钮叠加到现有页面顶部，Dashboard 状态栏为按钮组预留空间；Linux 保留 GTK HeaderBar，Android 不显示桌面窗口控件 | `lib/core/window/`, `lib/main.dart`, `windows/runner/` | `[x]` |
| v0.1.2 Phase 4, Task 6 | 桌面缩放比例限位 | Windows 在 `WM_SIZING` 中、Linux 在 GTK geometry hints 中把用户拖动缩放限制到 3:2～16:9；使用逻辑尺寸和 DPI 感知计算，不绑定具体 PC 分辨率 | `windows/runner/win32_window.cpp`, `linux/runner/my_application.cc` | `[x]` |

#### Phase 5: 验证与回归

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.2 Phase 5, Task 1 | 单元与组件测试 | 覆盖配置 JSON、击杀弹丸计算、无数据扫描光晕、零血/满血、比赛信息展示和桌面画布放大/缩小；组件测试额外守卫窄高度溢出，并确认 Windows/Linux 使用固定画布、Android 保留自适应布局 | `test/kill_estimate_config_test.dart`, `test/dashboard_v012_test.dart`, `test/desktop_design_canvas_test.dart` | `[x]` |
| v0.1.2 Phase 5, Task 2 | 多尺寸与 Windows 验证 | 完成常规桌面窗口固定画布目检；运行格式化、`flutter analyze`、全量 `flutter test`、`flutter run -d windows`，并修复共享 FAB 默认 Hero tag 冲突 | 构建与测试结果 | `[x]` |

**v0.1.2 验收标准：** 血量卡片比例来自实时血量与可配置上限；未获取血量时显示从左到右的扫描光晕，收到数据后停止；低血量节点颜色清晰；预计弹丸随设置实时更新；底部四面板无空白占位或裁切；四个操作按钮为一致的 MD3 原生按钮；Windows 全屏与不同尺寸下保持同一布局比例；`flutter analyze` 零问题且相关测试通过。

---

### v0.0.1 — 首个正式版本 (2026-06-14)

> 双链路监控基线：MQTT 3333 / UDP 3334、实时面板、数据导出与回放、多客户端合并、GitHub 远程同步。
> 历史版本保留原始 Phase 0–5 编号，不重新编号。

#### Phase 0: 项目脚手架与环境验证

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 0.1 | 创建 Flutter 项目 | `flutter create --platforms=android,linux mecha_monitor` | 项目根目录 | `[x]` |
| 0.2 | 添加依赖 | 在 pubspec.yaml 中添加: flutter_riverpod, fl_chart, path_provider, file_selector, shared_preferences, mqtt_client, protobuf, fixnum | pubspec.yaml | `[x]` |
| 0.3 | 配置 Protobuf 编译 | 在 `build.yaml` / `Makefile` 中配置 `protoc` 生成 Dart 代码的命令；将 `.proto` 文件放入 `protos/` 目录 | `protos/`, `Makefile` | `[x]` |
| 0.4 | 配置 Lint 规则 | 创建 analysis_options.yaml，启用所有推荐规则 + 自定义严格规则（禁止隐式 dynamic） | analysis_options.yaml | `[x]` |
| 0.5 | 配置项目级 AGENTS.md | 将 AGENTS.md 写入项目根目录，明确限定仅对接 MQTT 3333 + UDP 3334 | AGENTS.md | `[x]` |
| 0.6 | 验证环境 | 运行 `flutter analyze` 和 `flutter test`，确保零错误零警告；验证 `protoc` 可生成 Dart 文件 | - | `[x]` |

**Phase 0 验收标准：** `flutter analyze` 零警告，`flutter test` 通过，项目可在 Android 模拟器和 Linux 桌面运行，`protoc` 生成无报错。

---

#### Phase 1: 核心基础设施（自定义客户端双链路）

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 1.1 | MQTT Service 封装 | 创建 MQTT 客户端封装类，连接服务器 3333 端口，支持订阅/发布 Protobuf 主题。使用 StreamController 将收到的 Protobuf 消息广播为 Dart Stream。自动重连与心跳保持。 | `lib/services/mqtt_service.dart` | `[x]` |
| 1.2 | UDP 视频流 Service | 创建 RawSocket 封装类，绑定 3334 端口。实现 HEVC AnnexB 视频帧重组：按 `frame_id` + `packet_id` + `frame_size` 缓存分片，重组含 `0x00000001` Start Code 的完整帧后输出 Stream。超时未收齐分片则丢弃该帧。 | `lib/services/video_stream_service.dart` | `[x]` |
| 1.3 | Protobuf 定义与生成 | 将官方提供的自定义客户端 `.proto` 文件放入 `protos/` 并生成 Dart 类。若官方未提供，则先定义占位消息（如 `GameStatus`, `ClientConfig`, `CustomEvent`），待后续替换。 | `protos/*.proto`, `lib/generated/*.dart` | `[x]` |
| 1.4 | Protobuf 通用解析器 | 实现 MQTT 消息的通用分发器：根据 topic / message type 将 `Uint8List` 反序列化为对应的 `GeneratedMessage` 子类。无法识别类型时降级为原始字节日志。 | `lib/core/protobuf/protobuf_parser.dart` | `[x]` |
| 1.5 | 视频帧重组器 | 实现分片缓存表（以 `frame_id` 为 key），接收 UDP packet 后提取元数据（`frame_id`, `packet_id`, `frame_size`, `payload_offset`），按偏移写入缓冲区，收齐后输出 `VideoFrame`。 | `lib/core/video/frame_reassembler.dart` | `[x]` |
| 1.6 | ByteData 工具类 | 创建二进制数据解析工具：小端序读取 uint8/uint16/uint32/float32；HEVC NALU 前缀检测（`0x00000001` / `0x000001`）；位域提取辅助方法。 | `lib/core/utils/byte_data_reader.dart` | `[x]` |
| 1.7 | 协议常量定义 | 定义 MQTT 主题常量、UDP 端口、视频流分片元数据偏移量（根据实际抓包确认）、AnnexB Start Code 常量、最大帧缓存数。 | `lib/core/constants/protocol_constants.dart` | `[x]` |
| 1.8 | Riverpod Provider 设置 | 创建全局 Provider：`mqttMessageProvider`（StreamProvider<ProtobufEnvelope>）、`videoFrameProvider`（StreamProvider<VideoFrame>）、`gameStateProvider`（StateNotifierProvider，聚合 MQTT 下发的最新状态）。 | `lib/features/dashboard/logic/stream_providers.dart` | `[x]` |

**Phase 1 验收标准：**
- MQTT Service 可独立运行并打印接收到的 Protobuf 消息摘要；
- UDP 3334 Service 可接收分片并输出完整 AnnexB 帧（日志打印帧大小、frame_id 连续性、重组耗时）；
- 视频帧重组器通过单元测试：模拟 3-5 个分片组成一帧，验证重组后 AnnexB 前缀正确；模拟丢包验证超时丢弃逻辑。

---

#### Phase 2: 主监控面板（Dashboard）

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 2.1 | Dashboard 页面框架 | 创建 Dashboard 主页面，包含顶部状态栏（MQTT 连接状态、UDP 视频流状态、帧计数、重组丢帧率）、主内容区域。 | `lib/features/dashboard/presentation/dashboard_screen.dart` | `[x]` |
| 2.2 | 关键数据显示 | 实现核心数据卡片组件：比赛剩余时间、双方血量、经济/发弹量、能量机关状态。数据从 `gameStateProvider` 读取（由 MQTT Protobuf 消息驱动）。 | `lib/features/dashboard/presentation/widgets/robot_status_list.dart`, `game_status_card.dart` | `[x]` |
| 2.3 | 实时状态图表 | 使用 fl_chart 绘制：己方总血量变化曲线、金币/发弹量实时柱状图。数据源为 `gameStateProvider` 的历史缓存（最近 120 秒）。 | `lib/features/dashboard/presentation/widgets/health_chart.dart` | `[x]` |
| 2.4 | 关键事件列表 | 实现事件列表组件，监听 MQTT 下发的比赛事件消息（击杀、摧毁、占领、判罚等），按时间倒序显示，限制最近 50 条。 | `lib/features/dashboard/presentation/widgets/event_timeline_panel.dart` | `[x]` |
| 2.5 | 实时操作面板 | 实现辅助信息区域：飞镖发射倒计时、空中支援状态、哨兵决策状态。数据来自 MQTT 状态消息。 | `lib/features/dashboard/presentation/widgets/operation_panel.dart` | `[x]` |
| 2.6 | 视频流显示（可选） | 实现视频面板 Widget，接收 `videoFrameProvider` 的 AnnexB 帧，通过平台 View 或外部播放器渲染 HEVC 流。提供"显示/隐藏视频"开关。 | `lib/features/dashboard/presentation/widgets/video_panel.dart` | `[x]` |
| 2.7 | 数据流连接控制 | 添加连接/断开按钮，控制 MQTT Service 与 UDP Service 的启动和停止。连接状态实时显示。连接/断开操作收敛至 Dashboard 页面级 `PageFabMenu`（已连接显示「断开连接」、未连接显示「重新连接」并跳转登录页）；顶部状态栏实时显示连接状态点与登录身份。 | `lib/core/navigation/page_fab_menu.dart`, `connection_screen.dart`, `dashboard_screen.dart` | `[x]` |
| 2.8 | Debug 面板 | 实现原始数据查看面板：MQTT 消息十六进制 + Protobuf 解析后字段树；UDP 分片重组统计（帧ID、分片数、丢包数）。可通过设置开关显示/隐藏。 | `lib/features/dashboard/presentation/widgets/debug_panel.dart` | `[x]` |

**Phase 2 验收标准：** Dashboard 页面可完整运行，能显示模拟/真实 MQTT 状态数据与视频流，UI 响应流畅无卡顿，视频流（若开启）无花屏或丢帧感知。

---

#### Phase 3: 数据导出与赛后分析

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 3.1 | 数据记录服务 | 创建 DataRecorder 类，在接收 MQTT Protobuf 消息时自动记录到内存列表（按消息类型分桶），提供 `startRecording/stopRecording` 控制。限制内存中最大消息数（默认 10000 条），超限自动滚动。 | `lib/features/data_export/domain/data_recorder.dart` | `[x]` |
| 3.2 | JSON 导出功能 | 实现导出为 JSON 文件：选择保存路径（Android 使用 SAF，Linux 使用 file_selector），写入 schema_version + 元数据 + 按消息类型分桶的 Protobuf 转 JSON 数组。 | `lib/features/data_export/data/json_exporter.dart` | `[x]` |
| 3.3 | JSON 导入功能 | 实现从 JSON 文件导入数据：选择文件、验证 schema_version、解析数据数组、反序列化为 Protobuf 消息、加载到 `gameStateProvider` 历史缓存。 | `lib/features/data_export/data/json_importer.dart` | `[x]` |
| 3.4 | 导出/导入 UI | 创建数据管理页面，显示记录统计信息（各消息类型数量、总时长），提供导出/导入/清空按钮。 | `lib/features/data_export/presentation/data_export_screen.dart` | `[x]` |
| 3.5 | 赛后数据看板 | 创建赛后分析页面，使用 fl_chart 绘制：击杀/摧毁时间线、经济变化曲线、事件分布饼图、血量变化曲线。 | `lib/features/post_match_analysis/presentation/analysis_screen.dart` | `[ ]` |
| 3.6 | 多客户端数据汇总 | 实现多文件数据合并功能：导入多个 JSON 文件，按 MQTT 消息时间戳对齐合并，生成汇总统计。 | `lib/features/post_match_analysis/domain/data_merger.dart` | `[x]` |
| 3.7 | GitHub 远程记录同步 | 实现基于 GitHub Contents API 的远程记录同步：默认共享仓库 `Zsdhak1/custom-client-sync`，默认分支 `main`，内置默认 PAT；支持上传本地记录、浏览远程记录、下载远程记录到本地；云端记录列表以日期/红蓝方/机器人编号展示，并支持按日期、阵营、机器人编号筛选。 | `lib/core/sync/github_sync_service.dart`, `lib/core/sync/remote_sync_service.dart`, `lib/features/settings/logic/github_sync_provider.dart`, `lib/features/data_export/presentation/remote_records_screen.dart`, `lib/features/data_export/domain/remote_record_meta.dart` | `[x]` |

> **历史遗留说明：** Task 3.5 未交付，后续已通过 v0.1.0 调试/回放能力覆盖主要现场排障需求。新 agent 不应把它当作默认当前任务，除非用户明确要求补齐赛后分析看板。


**Phase 3 验收标准：** 可完整录制 MQTT 数据、导出 JSON、导入 JSON、绘制赛后分析图表。多文件合并结果时间戳对齐误差 < 1 秒。GitHub 远程同步在无凭证或空仓库配置时优雅降级，不触发网络请求。

---

#### Phase 4: 设置与辅助页面

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 4.1 | 设置页面 | 创建设置页面：MQTT 服务器地址/端口/主题前缀、UDP 端口配置、视频流开关、主题切换（亮色/暗色）、Debug 面板开关、数据记录上限。使用 SharedPreferences 持久化。 | `lib/features/settings/presentation/settings_screen.dart` | `[x]` |
| 4.2 | 设置状态管理 | 创建设置相关的 Riverpod Provider，支持设置项的读取、修改和持久化。 | `lib/features/settings/logic/settings_providers.dart` | `[x]` |
| 4.3 | 关于页面 | 创建关于页面：应用名称、版本号、技术栈说明（MQTT + Protobuf + HEVC AnnexB）、开源协议、RoboMaster 2026 自定义客户端协议适配声明。 | `lib/features/settings/presentation/about_screen.dart` | `[x]`（v0.0.2 交付） |
| 4.4 | 导航与路由 | 常驻 `AppShell` 持有侧边 `NavigationRail` + `IndexedStack`（监控/视频/数据/设置四页），切页只改索引、Rail 与页面状态均存活；Rail 支持展开/收起，顶部 icon 随登录身份切换、3/4 号步兵以数字徽标区分；页面级操作收敛到 `PageFabMenu`。连接页支持「离线模式」直接进入 Shell。 | `lib/core/navigation/app_shell.dart`, `app_navigation_rail.dart`, `page_fab_menu.dart` | `[x]` |

**Phase 4 验收标准：** 所有页面可正常导航，设置项可持久化保存，关于页面信息完整。

---

#### Phase 5: 收尾与优化

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 5.1 | 主题与样式统一 | 确保所有页面使用统一的颜色、字体、间距。支持亮色/暗色主题切换。 | `lib/core/theme/app_theme.dart` | `[x]` |
| 5.2 | 错误处理与反馈 | 所有异步操作添加错误处理：MQTT 连接失败、UDP 绑定失败、Protobuf 解析异常、视频帧重组超时、文件读写错误。使用 SnackBar 提示用户。 | 全局 | `[x]` |
| 5.3 | 性能优化 | 大数据量场景优化：事件列表使用 `ListView.builder`，图表数据采样（每 1 秒取一个点），内存中消息数量限制，视频帧缓存上限（避免内存泄漏）。 | 全局 | `[x]` |
| 5.4 | 多平台适配 | 验证 Android 和 Linux 桌面端的 UI 适配：字体大小、触摸目标、文件选择器、MQTT/UDP 网络权限。 | 全局 | `[x]` |
| 5.5 | 最终代码审计 | 执行完整自审计：函数长度、重复代码、命名规范、导入顺序、空安全、错误处理、无 `dynamic` 隐式使用。 | - | `[x]` |
| 5.6 | 运行全部测试 | 运行 `flutter analyze`、`flutter test`，确保零警告、所有测试通过。 | - | `[x]` |

**Phase 5 验收标准：** 应用在两平台运行正常，零 Lint 警告，所有功能完整可用，视频流（若开启）稳定。

---

### v0.0.2 — WOD Client 更名与更新检查 (2026-06-15)

> 对外名称更名为 **WOD Client**，新增关于页面、应用内更新检查与 Linux 启动脚本。本版本增量原不在 Phase/Task 表中，按版本化规范补登为 Phase 1。

#### Phase 1: 发布完善

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 1.1 | 关于页面 | 完善关于页面（应用名称、版本号、协议适配声明）；移除技术栈展示 | `lib/features/settings/presentation/about_screen.dart` | `[x]` |
| 1.2 | 应用内更新检查 | 启动 / 手动触发的版本更新检查（对比 GitHub Release，弹窗提示更新） | `lib/core/update/data/update_checker_service.dart`, `lib/core/update/data/version_comparator.dart`, `lib/core/update/domain/github_release.dart`, `lib/core/update/logic/update_providers.dart`, `lib/core/update/presentation/update_checker_listener.dart`, `lib/core/update/presentation/update_dialog.dart` | `[x]` |
| 1.3 | Linux 启动脚本 | 默认启动脚本 `wod_client.sh`（自动加载自带依赖库） | `wod_client.sh` | `[x]` |
| 1.4 | 对外更名 | 应用对外名称更名为 **WOD Client**（保留 package 名与仓库链接） | （多平台配置） | `[x]` |

**v0.0.2 验收标准：** 应用对外显示为 WOD Client，关于页面信息完整，更新检查可用，Linux 端可经 `wod_client.sh` 启动并正确加载依赖。

---

### v0.0.3 — 自定义数据图传线（0x0310 / H.264）

> 目标：在现有 WOD Client 中新增第二条图传线，用于接收机器人通过 `0x0310` 指令上传的 `CustomByteBlock` 数据，并在 Flutter 端实时解码显示、叠加准星。
>
> 设计原则：
> 1. **与官方 UDP 3334 / HEVC 图传线完全独立**：独立 TCP 桥、独立 provider、独立 NAL 门控、独立 UI 入口。
> 2. **复用已验证的解码桥模式**：`CustomByteBlock.data` → 顺序拼接 Annex-B H.264 → 独立 `AnnexbTcpServer` → media_kit/fvp 解码。
> 3. **真实链路无序列号**：`0x0310` 的 300B 负载为纯 H.264 字节，MQTT QoS1/TCP 已保序；reset 逻辑由解码器错误/断流触发，不依赖 `sequence_id`。
> 4. **本地测试补齐 Windows 编码端**：用 FFmpeg/x264 把本地视频/摄像头编码为 H.264 Annex-B，切 300B 包后发本地 MQTT `CustomByteBlock`，无需真实机器人/ROS2。

#### Phase 1: 数据层与 H.264 门控

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.0.3 Phase 1, Task 1 | `CustomByteBlock` 数据源 | 订阅 `topicCustomByteBlock`，经 `ProtobufParser` 取 `data` 字段，暴露 `Stream<Uint8List>`；空/超长（>2.4kbit）包防御并降级日志 | `lib/features/custom_video/data/custom_byte_block_source.dart` | `[x]` |
| v0.0.3 Phase 1, Task 2 | H.264 关键帧门控 | 实现 H.264 SPS(7)/PPS(8) 检测纯函数，与现有 HEVC 门控物理隔离；附单元测试 | `lib/core/video/h264_annexb_gate.dart`, `test/h264_annexb_gate_test.dart` | `[x]` |
| v0.0.3 Phase 1, Task 3 | 独立 TCP 桥与 provider | 为自定义图传线新建 `AnnexbTcpServer` 实例，顺序拼流、H.264 门控放行后写桥；用 Riverpod StreamProvider 暴露视频帧 | `lib/features/custom_video/logic/custom_video_providers.dart`, `custom_video_stream_service.dart` | `[x]` |

**Phase 1 验收标准：**
- 能订阅本地 MQTT Broker 的 `CustomByteBlock`，正确提取 `data` 字节；
- H.264 门控单元测试覆盖 SPS/PPS 检测、非关键帧丢弃、HEVC 帧不误判为 H.264 关键帧；
- TCP 桥只在收到含 SPS/PPS 的帧后才向 decoder 输出，模拟器发送时能正常接到 `tcp://` 流。

---

#### Phase 2: UI 与解码

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.0.3 Phase 2, Task 1 | 自定义图传解码面板 | 复用 media_kit/fvp，配置 `demuxer-lavf-format=h264`，使用 Phase 1 的独立 TCP 桥；带状态灯与重连按钮 | `lib/features/custom_video/presentation/widgets/custom_video_panel.dart` | `[x]` |
| v0.0.3 Phase 2, Task 2 | 准星叠加 | `CustomPainter` 复现 Python 版 `_draw_overlay`：淡紫色横竖准星 + 淡绿色中心圆点；参数可配并持久化 | `lib/features/custom_video/presentation/widgets/crosshair_painter.dart` | `[x]` |
| v0.0.3 Phase 2, Task 3 | 解码统计覆盖层 | 显示：收包数、解码帧数、门控等待/已放行、桥转发字节、最后错误 | `lib/features/custom_video/presentation/widgets/custom_video_overlay.dart` | `[x]` |
| v0.0.3 Phase 2, Task 4 | 导航入口与页面 | 在 `AppShell`/`NavigationRail` 新增「自定义图传」入口；新建 `CustomVideoScreen` 承载面板+准星+覆盖层 | `lib/features/custom_video/presentation/custom_video_screen.dart`, 导航文件 | `[x]` |

**Phase 2 验收标准：**
- 页面能在 Android/Linux/Windows 正常打开；
- 本地模拟器发送 H.264 后 2 秒内出图（普通 GOP）或最长 8 秒内出图（低码率 GOP）并显示准星；
- 与官方 UDP 3334 图传线同时运行时互不抢占端口、互不污染解码状态。

---

#### Phase 3: Windows 本地测试编码端（完整复刻原编码端特性）

> 目标：在 Windows 开发机上，无需 ROS2、无需真实机器人，即可完整复刻原仓库编码端的预处理与发送逻辑，向本地 MQTT Broker 发送 `CustomByteBlock`。
>
> 实现方式：一个独立的 Python 3 脚本，复用与原仓库相同的技术栈（OpenCV 预处理、PyAV H.264 编码、paho-mqtt 发送），配置项与 `sniper.launch.py` 一一对应。

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.0.3 Phase 3, Task 1 | Windows 编码模拟器 CLI | 基于 Python 3 + OpenCV + PyAV + paho-mqtt，读取本地视频文件或摄像头；复刻原编码端预处理：中心裁剪、resize 到 400×400、静态区域简化、运动拖影、中心保护区、强制灰度 | `tool/custom_byte_block_simulator/encoder_simulator.py` | `[x]` |
| v0.0.3 Phase 3, Task 2 | H.264 Annex-B 编码 | 用 PyAV `h264` 编码器输出 Annex-B 字节流，支持 `target_bitrate`、`x264_preset`、`key_int`、低码率长 GOP / 普通 zerolatency 两种模式、AUD 输出 | 同上 | `[x]` |
| v0.0.3 Phase 3, Task 3 | 带宽限速与 backlog 裁剪 | 复刻 2 秒滑动窗口硬限速 + 超限时裁剪到下一个 Annex-B 起始码；保证发送硬上限不超标 | 同上 | `[x]` |
| v0.0.3 Phase 3, Task 4 | 300B 打包与 MQTT 发送 | 将 H.264 流切 300B 包，按 50Hz 经本地 MQTT Broker 发送到 `CustomByteBlock` Topic；包内无 sequence_id（匹配真实 0x0310） | 同上 | `[x]` |
| v0.0.3 Phase 3, Task 5 | 编码端调试显示 | 复刻 Raw / ROI / Static / Final 四个 OpenCV 调试窗口（可选开启） | 同上 | `[x]` |
| v0.0.3 Phase 3, Task 6 | 编码端调试 dump | 每 N 帧保存 Raw/ROI/Static/Final PNG 到本地目录（可选开启） | 同上 | `[x]` |
| v0.0.3 Phase 3, Task 7 | 一键测试脚本 | PowerShell 脚本：启动 mosquitto → 启动编码模拟器 → 可选启动 Flutter 客户端；支持循环文件/摄像头切换 | `tool/run_custom_video_test.ps1` | `[x]` |
| v0.0.3 Phase 3, Task 8 | 依赖与文档 | 在脚本目录提供 `requirements.txt` 与 README，说明 Python 3.11+、OpenCV、PyAV、paho-mqtt、mosquitto 安装 | `tool/custom_byte_block_simulator/README.md`, `requirements.txt` | `[x]` |

**Phase 3 验收标准：**
- Windows 开发机上仅运行 `run_custom_video_test.ps1` 即可端到端验证；
- 编码模拟器发送的流能被 Flutter 端正确解码出图并显示准星；
- 预处理效果（静态简化、运动拖影、中心保护区）与原仓库肉眼一致；
- 带宽限速与 backlog 裁剪行为与原仓库日志一致；
- 不依赖 ROS2、不依赖 Linux、不依赖真实机器人。

---

### v0.0.4 — MPEG-TS 封装与后端切换 (2026-06-19)

> 目标：解决自定义图传线（0x0310 / H.264）在 Windows 上的解码问题。media_kit 缺裸 H.264 解封装（`Unknown lavf format h264`），fvp 在 Windows 渲染异常（D3D11 纹理白屏）。
> 方案：新增「封装为 MPEG-TS」开关 + 自定义图传独立后端选择器，让用户在 Windows 上走 media_kit + TS（TS demuxer 在 libmpv 中普遍内置），Linux 上走 fvp + 裸流，与官方线平台策略对齐。
> 同步修复：桥端 `AnnexbTcpServer` 缓存关键帧 AU，后连接的解码器不再因连接竞态白屏。

#### Phase 1: MPEG-TS 封装与后端切换

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.0.4 Phase 1, Task 1 | MPEG-TS muxer（纯 Dart） | 实现 `MpegTsMuxer`：NAL 切分 → AU 分组（`first_mb_in_slice==0` 顶位判定，多 slice IDR 归为一个 AU）→ 每 AU 一个 PES + 90kHz PTS；关键帧前发 PAT/PMT 使流可中途接入；ffprobe/ffmpeg 验证真实 _dump.h264 转 TS 后完整 150 帧解码零错误 | `lib/core/video/mpegts_muxer.dart` | `[x]` |
| v0.0.4 Phase 1, Task 2 | muxer 单元测试 | 结构单测：188 对齐 + sync byte 0x47；PAT/PMT 存在性；多 slice IDR 不拆分 AU；tsHasPat 门控检测 | `test/mpegts_muxer_test.dart` | `[x]` |
| v0.0.4 Phase 1, Task 3 | 自定义图传后端选择器 | 独立持久化 `customVideoBackendProvider`（默认 fvp），与官方线 `videoDecoderBackendProvider` 隔离；设置页新增「自定义图传解码器 (0x0310)」选择区 | `lib/features/settings/logic/settings_providers.dart`, `lib/features/settings/presentation/settings_screen.dart` | `[x]` |
| v0.0.4 Phase 1, Task 4 | MPEG-TS 开关与集成 | 新增 `customVideoTsWrapProvider`；service 开/关时选择原始 H.264 门控或 TS PAT 门控；controller 启动时传递 TS 标志给 service | `lib/features/custom_video/logic/custom_video_stream_service.dart`, `custom_video_providers.dart` | `[x]` |
| v0.0.4 Phase 1, Task 5 | media_kit 播放器 | 新增 `CustomMediaKitPlayer`：强制 `demuxer-lavf-format=mpegts`（TS 模式）或 `h264`（裸流），低延迟缓存配置 | `lib/features/custom_video/presentation/widgets/custom_mediakit_player.dart` | `[x]` |
| v0.0.4 Phase 1, Task 6 | ffplay 验证面板 | 新增 `CustomFfplayLauncher` + `CustomFfplayPanel`：启动外部 `ffplay -f mpegts/h264 -i tcp://...`，状态面板显示连接信息与错误 | `lib/features/custom_video/logic/custom_ffplay_launcher.dart`, `lib/features/custom_video/presentation/widgets/custom_ffplay_panel.dart` | `[x]` |
| v0.0.4 Phase 1, Task 7 | 桥关键帧缓存补发 | `AnnexbTcpServer` 缓存打开门控的关键帧 AU；新客户端连接时 `_replayKeyframe()` 优先补发，解码器一启动就拿到 SPS+IDR | `lib/services/annexb_tcp_server.dart` | `[x]` |
| v0.0.4 Phase 1, Task 8 | fvp 播放器低延迟对齐 | 直连 `mdk.Player` 完整复刻官方线 low-latency 配置：`+nobuffer`、`setBufferRange(min:0)`、硬解优先 `MFT:d3d=11`、`shader_resource=0` 等 | `lib/features/custom_video/presentation/widgets/custom_video_panel.dart` | `[x]` |
| v0.0.4 Phase 1, Task 9 | 面板分发集成 | `custom_video_panel.dart` 按后端 + TS 标志分发到 fvp/media_kit/ffplay；设置页切换自动重启接收 | `lib/features/custom_video/presentation/widgets/custom_video_panel.dart` | `[x]` |

**Phase 1 验收标准：**
- 设置页「自定义图传解码器」三端可选（fvp / media_kit / ffplay），独立持久化互不干扰；
- 「封装为 MPEG-TS」开关打开后，桥服务的字节流被 ffmpeg 验证为合法可解码的 MPEG-TS；
- Windows 上 media_kit + TS 出图正常（libmpv 必含 mpegts demuxer）；
- Linux 上 fvp + 裸流保持不变（降零回归风险）；
- 桥关键帧缓存补发通过单元测试验证；
- 31 个自定义图传相关测试全部通过，`flutter analyze` 零问题。

---

### v0.1.0 — 调试基础设施：NAL 诊断、丢包检测、拼包切片、H.264 导出 (2026-06-21)

> 目标：为自定义图传线（0x0310 / H.264）构建完整的调试基础设施，使黑屏/花屏的根因定位从"猜"变为"看数据"。
>
> 关键发现：抓包分析发现机器人固件在每个 `CustomByteBlock.data` 前插入了 8 字节 uint64 LE 序列号（丢包检测用），
> 且 H.264 负载包裹了 `0x0A <varint>` 长度前缀。旧的 verbatim 转发模式会把前缀注入码流，
> 导致几乎所有跨包边界的 NAL 被破坏。
>
> 解决方案：
> 1. **可实时切换的拼包模式** — stripPrefix（自动剥离前缀，推荐）、verbatim（原样转发基线）、fixed（手动调参）；
> 2. **序列号丢包检测** — 8 字节包头开关，实时统计丢包率、乱序数；
> 3. **NAL 类型计数器** — `_scanNalUnits()` 跨 chunk 边界统计 H.264 NAL type 1/5/7/8，直观判断关键帧是否到达；
> 4. **调试面板** — 流水线红绿灯（MQTT→门控→解码器→出图），每阶段详情与码率；
> 5. **解码器诊断** — fvp/media_kit 实时上报分辨率、编解码、fps、错误、滚动日志；
> 6. **20 秒 H.264 流导出** — 将原始码流保存为 `.h264` 文件，供 ffprobe/ffplay 离线分析；
> 7. **准星点击移动** — crosshair 改为 `aimCenter` 参数，点击画面可以把准星移到点击位置；
> 8. **Proto 字段更新** — `CustomByteBlock` 新增 `is_frame_start` 字段（固件端标记帧首包，当前接收端未依赖此标记分帧）。

#### Phase 1: 调试基础设施

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.0 Phase 1, Task 1 | 自定义图传拼包切片器 | 实现 `SliceResult` 与三种切片模式：`stripVarintPrefix`（自动识别 0x0A+varint，取声明负载，丢弃前缀与尾部补齐）、`sliceFixed`（手动指定 header+payload）、verbatim（原样转发，基线对照）；附带单元测试 | `lib/features/custom_video/data/custom_packet_slicer.dart`, `test/custom_packet_slicer_test.dart` | `[x]` |
| v0.1.0 Phase 1, Task 2 | uint64 LE 序列号丢包检测器 | 实现 `PacketSequenceTracker`：解析每包前 8 字节 uint64 LE 序列号，检测间隙（gap→丢包）、乱序/重复（regression）、大幅回跳（重启后重设基线）；附带单元测试 | `lib/features/custom_video/data/packet_sequence_tracker.dart`, `test/packet_sequence_tracker_test.dart` | `[x]` |
| v0.1.0 Phase 1, Task 3 | CustomByteBlockSource 重构 | 构造方法新增 `sliceMode` / `headerBytes` / `payloadBytes` / `seqHeaderEnabled` 四个 live callback；集成 `PacketSequenceTracker`；暴露出诊断 getter（`packetsReceived`, `packetsWithPrefix`, `packetsTruncated`, `packetsLost`, `lossRate`、`lastSequence` 等）；支持设置项实时生效无需重启 | `lib/features/custom_video/data/custom_byte_block_source.dart` | `[x]` |
| v0.1.0 Phase 1, Task 4 | 设置项：拼包模式、序列号开关、负载字节数 | 新增 `CustomVideoSliceMode` 枚举（verbatim / stripPrefix / fixed 带中文描述）；新增 `customVideoSliceModeProvider`、`customVideoSeqHeaderProvider`、`customVideoPayloadBytesProvider` 三个持久化 StateNotifier；设置页新增对应的 RadioListTile、Switch、Slider 控件 | `lib/features/settings/logic/settings_providers.dart`, `lib/features/settings/presentation/settings_screen.dart` | `[x]` |
| v0.1.0 Phase 1, Task 5 | H.264 NAL 类型跨块扫描 | 在 `CustomVideoStreamService._onChunk()` 中调用 `_scanNalUnits()`：识别 3/4 字节 AnnexB Start Code，统计 NAL type 1/5/6/7/8/9 频次；跨 chunk 边界携带 3 字节尾部避免 Start Code 跨块漏计 | `lib/features/custom_video/logic/custom_video_stream_service.dart` | `[x]` |
| v0.1.0 Phase 1, Task 6 | CustomVideoStats 扩充与吞吐率计算 | 新增字段：`tsWrap`、`gateBufferBytes`、`pendingFrames`、`millisSinceLastChunk`、`keyframesSeen`、`spsSeen`、`nonIdrSeen`、`millisSinceLastKeyframe`、序列号丢包统计、`chunksPerSec`/`bytesInPerSec`/`framesPerSec`/`bytesOutPerSec` 吞吐率（每秒 tick 增量计算）；`customVideoStatsProvider` 从 source+service 联合读取 | `lib/features/custom_video/logic/custom_video_providers.dart` | `[x]` |
| v0.1.0 Phase 1, Task 7 | 解码器诊断信息模型 | 创建 `CustomVideoDecoderInfo` / `CustomVideoDecoderInfoNotifier`：记录 backend 名称、打开次数、resolution、codec、pixelFormat、fps、bitRate、profile、lastError、滚动日志（最多 60 条）；暴露为 `customVideoDecoderInfoProvider`；附带单元测试 | `lib/features/custom_video/logic/custom_video_decoder_info.dart`, `test/custom_video_decoder_info_test.dart` | `[x]` |
| v0.1.0 Phase 1, Task 8 | 全面调试面板 | 创建 `CustomVideoDebugPanel`：流水线红绿灯（MQTT 接收→关键帧门控→解码器连接→出图）、MQTT 接收详情（chunk 频率、入站码率、距上一包时间、门控缓冲）、丢包统计（序列号、丢包数/率、乱序数）、关键帧诊断（IDR/SPS/non-IDR 计数、距上一关键帧时间）、TCP 桥转发（地址、封装模式、连接数、转发帧率/码率）、解码器详情（状态、分辨率、编解码、fps、错误）、解码器日志（带时间戳与颜色等级的滚动记录） | `lib/features/custom_video/presentation/widgets/custom_video_debug_panel.dart` | `[x]` |
| v0.1.0 Phase 1, Task 9 | 面板分发集成：门控后连接播放器 | `custom_video_panel.dart` 改为等待 `gateOpen==true` 后才创建播放器（避免播放器连接空 socket 后永不重试）；开发者模式下用 `CustomVideoDebugPanel` 替换紧凑型 stats card；`_PreviewPlaceholder` 增加"等待关键帧…"动画提示 | `lib/features/custom_video/presentation/widgets/custom_video_panel.dart` | `[x]` |
| v0.1.0 Phase 1, Task 10 | fvp 播放器诊断集成 | fvp `_FvpPlayer` 改为 `ConsumerStatefulWidget`；`_attachDiagnostics()` 推送 `mdk.Player` 状态（event/state/mediaStatus）到 `customVideoDecoderInfoProvider`；`_open()` 成功后上报 resolution/codec/fps/profile；支持点击画面移动准星 | `lib/features/custom_video/presentation/widgets/custom_video_panel.dart` | `[x]` |
| v0.1.0 Phase 1, Task 11 | media_kit 播放器诊断集成 | `CustomMediaKitPlayer` 改为 `ConsumerStatefulWidget`；监听 `player.stream.error/playing/buffering/width/height` 推送到 `customVideoDecoderInfoProvider`；支持点击画面移动准星 | `lib/features/custom_video/presentation/widgets/custom_mediakit_player.dart` | `[x]` |
| v0.1.0 Phase 1, Task 12 | 准星点击移动 | `CrosshairPainter` 重构：将 `offsetX`/`offsetY` 替换为 `aimCenter`（`Offset?`，null=画布中心）；两个播放器包裹 `GestureDetector`，`onTapDown` 更新 crosshair 位置 | `lib/features/custom_video/presentation/widgets/crosshair_painter.dart`, `custom_video_panel.dart`, `custom_mediakit_player.dart` | `[x]` |
| v0.1.0 Phase 1, Task 13 | CustomVideoScreen FAB 保存 20 秒流 | 新增"保存前 20 秒"FAB 动作：调用 `CustomVideoController.startDump()` 录制 20 秒原始码流；完成后弹出平台文件保存对话框（`file_selector`）；录制中按钮禁用并显示"正在录制 20s…" | `lib/features/custom_video/presentation/custom_video_screen.dart` | `[x]` |
| v0.1.0 Phase 1, Task 14 | 20 秒 H.264 流导出服务 | 在 `CustomVideoStreamService` 中实现 `startDump()` / `stopDump()`：20 秒内逐 chunk 累积到内存缓存；超时后写入 `getApplicationDocumentsDirectory()` 下时间戳命名 `.h264` 文件；服务停止或取消写入时优雅错误处理 | `lib/features/custom_video/logic/custom_video_stream_service.dart` | `[x]` |
| v0.1.0 Phase 1, Task 15 | Proto 更新：CustomByteBlock 加 is_frame_start | 在 `CustomByteBlock` message 中新增 `uint32 is_frame_start = 2`；更新注释说明 150B 固定分包与 0x00 补齐规则；重新生成 Dart protobuf 代码 | `protos/robomaster_custom_client.proto`, `lib/generated/robomaster_custom_client.pb.dart` | `[x]` |
| v0.1.0 Phase 1, Task 16 | 官方图传缓存参数微调 | 将官方 media_kit 播放器的 `demuxer-readahead-secs` 和 `cache-secs` 从 1.0 降至 0.3，降低首帧延迟 | `lib/features/dashboard/presentation/widgets/video_panel.dart` | `[x]` |

**Phase 1 验收标准：**
- 设置页拼包模式三种可选，实时生效无需重启接收（切换后下一个包即用新模式）；
- 序列号开关打开后调试面板显示实时丢包率、乱序计数；
- `CustomVideoDebugPanel` 在开发者模式下替换紧凑 stats 卡，显示流水线红绿灯、NAL 计数、码率；
- 点击视频画面可将准星移动到点击位置；
- 官方图传与自定义图传各自独立运行，互不干扰；
- CustomVideoScreen 的"保存前 20 秒"可导出可在线 ffprobe 验证的 `.h264` 文件；
- 所有单元测试通过：`flutter test` 124 项 0 失败，`flutter analyze` 零问题。

---

#### Phase 2: 主监控通知实验

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.0 Phase 2, Task 1 | 监控页通知样式实验台 | 为 Dashboard 增加多种可切换的事件通知覆盖样式（自动响应 `Event` Topic，并支持手动触发样例通知预览）；通知需足够醒目但尽量避让关键监控区域；监控页内提供样式切换、预览面板开关与样例事件触发按钮，便于现场比较后决定最终方案 | `lib/features/dashboard/logic/dashboard_notification*.dart`, `lib/features/dashboard/presentation/dashboard_screen.dart`, `lib/features/settings/logic/settings_providers.dart` | `[x]` |

**Phase 2 验收标准：**
- Dashboard 页面可在不离开监控视图的情况下切换通知样式；
- 至少 3 种通知样式可手动触发预览，并在数秒后自动收起；
- 实时收到 `Event` Topic 时可自动弹出通知，不影响现有事件时间轴；
- `flutter analyze` 零新增问题。

##### Phase 2 补充规格：Dashboard 通知模板参数基线（供后续开发）

> 本节记录当前通知实验台已经落地的数据模型、样式枚举、堆叠与动画基线，并约束后续“通知模板编辑器 / 样式配置面板”的参数来源。后续继续开发通知系统时，以本节为单一规格来源，避免在 `models`、`factory`、`provider`、`overlay`、`settings` 中出现分叉定义。

**1. 当前通知内容模板（`DashboardNotificationContent`）**

| 字段 | 类型 | 当前用途 | 后续开发建议 |
|------|------|----------|--------------|
| `headline` | `String` | 主标题，承担第一注意力焦点 | 保持单行高显著展示；后续可增加基于优先级的文案规范 |
| `detail` | `String` | 描述信息，补充持续时间、增益、返场等细节 | 后续可拆分为“关键数值片段 + 普通描述片段”以支持差异化字号/颜色 |
| `badge` | `String` | 标签/类别名，如“高优先级”“战场告警” | 后续建议改为枚举 + 文案映射，避免自由文本不一致 |
| `icon` | `IconData` | 事件识别图标 | 后续可改为按事件类别自动映射，模板层只存类别 |
| `accentColor` | `Color` | 主色，驱动背景、边框、光晕、阴影 | 后续可细分为 `baseColor` / `glowColor` / `textAccentColor` |
| `duration` | `Duration` | 自动消失时长 | 后续可按优先级分层设置最短/最长显示时间 |

**2. 当前预览模板（`DashboardNotificationPreset`）**

| 字段 | 类型 | 当前用途 | 后续开发建议 |
|------|------|----------|--------------|
| `label` | `String` | 实验面板中的预览按钮文字 | 保持短文本；后续可支持按分类分组显示 |
| `content` | `DashboardNotificationContent` | 点击按钮后触发的通知内容模板 | 作为人工验样、动画对比、现场挑选样式的样本来源 |

**3. 当前通知样式枚举（`DashboardNotificationStyle`）**

| 枚举值 | 布局定位 | 当前意图 |
|--------|----------|----------|
| `topBanner` | 顶部居中横幅 | 最高显著性，适合极高优先级事件 |
| `rightCorner` | 右上悬浮卡片 | 信息完整、对主监控区遮挡较小 |
| `sideBeacon` | 左侧信标卡片 | 方向感强，适合连续事件扫视 |

**4. 当前显示与堆叠基线**

- 通知支持同时显示多条，按“最新在上”进行竖向堆叠。
- 当前最大同时显示数为 `4`；超过上限时，新通知进入，最旧通知被移出。
- 每条通知独立计时并自动消失，也可手动关闭。
- 新通知出现时，既有通知仅执行位置下移补位，不应重新播放进入动画。
- 退场时应保持“向后堆叠缩小并淡出”的观感，同时释放纵向占位供其余通知补位。

**5. 当前动画基线**

- 进入动画：淡入 + 定向滑入 + 放大过冲回弹 + 短时增强外发光。
- 常驻状态：通知外缘存在弱脉冲动态光晕，用于维持可见性。
- 退出动画：轻微后撤、缩小、淡出，最后压缩高度完成堆叠补位。
- 任何裁剪、重建或 key 复用问题都不应破坏上述三类动画语义。

**6. 后续建议开放为可编辑配置的参数**

| 参数组 | 建议字段 |
|--------|----------|
| 文案层 | `headline` 字号、`detail` 字号、关键片段高亮规则、最大行数 |
| 颜色层 | 主色、边框色、光晕色、文字色、渐变强度 |
| 布局层 | 横幅/卡片宽度、顶部偏移、左右边距、堆叠间距、图标尺寸、圆角、内边距 |
| 行为层 | 自动消失时长、最大同时显示数、手动关闭开关、不同优先级的覆盖策略 |
| 动画层 | 进入/退出时长、滑入偏移、放大过冲幅度、回弹强度、光晕脉冲周期、退场后撤幅度 |

**7. 未来参数化开发约束**

- 数据模板参数与渲染样式参数分离：`DashboardNotificationContent` 只描述“通知是什么”，样式配置只描述“通知怎么显示”。
- 自动事件映射（`Event -> NotificationContent`）与手动预览模板必须共用同一内容模型，避免两套字段体系。
- 若后续引入可持久化模板配置，优先落在 Dashboard / Settings 对应 Provider 中，并保证默认值可完全复现当前实验台效果。
- 若后续新增第 4 种及以上样式，必须同步补充本节第 3、4、5、6 小节，确保规格与实现一致。

---

### v0.1.1 — Material 3 合规优化：排版令牌化、颜色收口、自适应布局、Elevation 色调化、M3 动效（2026-06-28）

> **状态：已发布。** 本版本不引入新业务功能，目标是把 UI 层从"能跑"提升到"符合 Material 3 设计系统"，为后续视觉迭代与多端适配打底。
>
> **审计基线（2026-06-23，源码静态分析，总分 52/100）：**
> | 维度 | 当前 | 目标 | 核心证据 |
> |------|------|------|----------|
> | Typography 排版 | 3/10 | ≥8 | `TextStyle(fontSize:)` 写死字号 **139 处**，`textTheme.*` 角色仅 1 处 |
> | Color 颜色令牌 | 5/10 | ≥8 | `Colors.white/black/grey` 硬编码 **117 处**，业务层 `Color(0x..)` **23 处** |
> | Shape 形状 | 6/10 | ≥8 | `BorderRadius.circular()` 魔法数 **47 处** |
> | Layout 布局 | 5/10 | ≥8 | `MediaQuery/LayoutBuilder` 仅 4 处，无窗口尺寸类自适应 |
> | Accessibility 无障碍 | 5/10 | ≥8 | `Semantics/tooltip` 仅 **12 处**，灰字未校验对比度 |
> | Elevation 高程 | 3/10 | ≥8 | `CardThemeData(elevation: 2)` 使用阴影传达层级而非色调表面；卡片同时叠加阴影+边框；无 `surfaceContainer*` 变体使用 |
> | Motion 动效 | 0/10 | ≥7 | 无 spring 物理动画、无自定义页面过渡、无 M3 emphasized/standard 曲线、无组件交互动效 |
>
> **保留项（已达标，本版本不动）：** Theming 9/10（`fromSeed` + light/dark/team 三态）、Navigation 8/10（`NavigationRail` + `IndexedStack` 正确使用）、Components 7/10（全原生 M3，视频面板手动布局可后续再迭代）。
>
> **设计底线：** 承载协议语义的固定色（红/蓝方、血量红绿、连接状态）跨明暗主题必须保持不变，仅做"集中化"而非"令牌化"，避免动态换肤误改比赛语义。

#### Phase 1: 排版令牌化（Typography 3/10 → ≥8）

> 抓手：让 `MaterialTheme.textTheme` 成为字号单一事实源，缩放在 `TextTheme` 上统一乘一次，业务侧改用 type scale 角色，消化散落 139 处的裸 `fontSize`。

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.1 Phase 1, Task 1 | 缩放型 TextTheme 注入 | 在 `_buildThemeWithAccent` 中基于 MD3 五档 type scale（Display/Headline/Title/Body/Label）构建 `TextTheme`，并提供 `scaledTextTheme(BuildContext)` 使其随 `context.scale` 等比缩放；保持与 `responsive_ext` 缩放因子一致 | `lib/core/theme/app_theme.dart` | `[x]` |
| v0.1.1 Phase 1, Task 2 | type scale 角色映射约定 + 迁移样板 | 在 `responsive_ext.dart` 增补 `context.textTheme` getter；将违规最多的 `data_export_screen.dart`（14 处）迁移为 `textTheme.titleMedium/bodyMedium` 等角色 + `.copyWith()`，作为后续迁移的范式样板 | `lib/core/responsive/responsive_ext.dart`, `lib/features/data_export/presentation/data_export_screen.dart` | `[x]` |
| v0.1.1 Phase 1, Task 3 | 视频/调试面板排版迁移 | 迁移 `video_panel.dart`（11）、`custom_video_debug_panel.dart`（9）、`video_debug_panel.dart`（8）、`robot_status_list.dart`（8）、`debug_panel.dart`（8）中的裸 `fontSize` 为 type scale 角色 | 上述 5 个文件 | `[x]` |
| v0.1.1 Phase 1, Task 4 | 设置页与对话框排版迁移 | 迁移 `video_settings_screen.dart`（9）、`record_config_screen.dart`（9）、`update_dialog.dart`（9）、`replay_screen.dart`（5）及剩余文件的裸 `fontSize` | 上述文件及其余 `fontSize` 残留点 | `[x]` |
| v0.1.1 Phase 1, Task 5 | 排版收尾与守卫 | 全库复扫 `TextStyle(fontSize:)` 降至仅保留必要特例（如 `_NumberBadge` 微型徽标）；在 `analysis_options.yaml` 评估加入自定义 lint 注释约定防回潮；`flutter analyze` 零新增问题 | `analysis_options.yaml`, 收尾文件 | `[x]` |

**Phase 1 验收标准：**
- `grep -rn "fontSize:" lib --include="*.dart" | grep -v generated` 从 139 降至 < 15（仅保留徽标/画布等特例并注释说明）；
- `textTheme.*` 角色用法显著上升，文本样式统一从主题派生；
- 字体随窗口缩放行为与改造前一致，无视觉回归；
- `flutter analyze` 零新增问题，`flutter test` 全通过。

#### Phase 2: 颜色令牌双轨收口（Color 5/10 → ≥8）

> 双轨：① 协议语义色 → 集中为 `app_theme.dart` 具名常量（保持固定）；② 装饰/中性色 → 改用 `colorScheme` 角色（随主题变化）。

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.1 Phase 2, Task 1 | 协议语义色集中化 | 将散落的协议色（`robot_status_list.dart` 血量渐变 `0xFFEF4444`/`0xFFF59E0B`/`0xFF22C55E`、`feedback_messenger.dart:48` 成功绿、准星色等）抽到 `app_theme.dart` 具名常量，统一命名风格（参照现有 `rmHealthBarColor`）；业务侧引用常量而非裸十六进制 | `lib/core/theme/app_theme.dart`, `robot_status_list.dart`, `feedback_messenger.dart`, `crosshair_painter.dart` | `[x]` |
| v0.1.1 Phase 2, Task 2 | 视频深色底改用 surface 令牌 | 将 `video_panel.dart`（4 处）、`custom_video_panel.dart`（4 处）、`custom_ffplay_panel.dart`、`debug_panel.dart:142` 中的 `Color(0xFF101418)`/`0xFF303030` 改为 `colorScheme.surfaceContainerLowest` 或 `surfaceContainerHigh`，使播放器底色随明暗主题适配 | 上述文件 | `[x]` |
| v0.1.1 Phase 2, Task 3 | 中性色迁移 colorScheme 角色 | 迁移 `Colors.white/black/grey` 高发文件（`video_panel.dart` 25、`custom_video_panel.dart` 13、`debug_panel.dart` 12、`video_debug_panel.dart` 7）为 `onSurface/onSurfaceVariant/surface` 等角色；导航徽标 `app_navigation_rail.dart:209` 的 `Colors.white` 边框改 `colorScheme.surface` | 上述文件 | `[x]` |
| v0.1.1 Phase 2, Task 4 | 颜色收尾审查 | 全库复扫剩余 `Colors.white/black/grey` 与裸 `Color(0x..)`，确认仅协议语义常量保留；明暗双主题下逐页目检对比度无异常 | 收尾文件 | `[x]` |

**Phase 2 验收标准：**
- `Colors.white/black/grey` 从 117 降至 < 20（仅协议语义/特例并注释）；
- 业务层 `Color(0x..)` 仅保留 `app_theme.dart` 集中定义的协议常量；
- 暗色主题下播放器底、调试面板、状态行均正确适配，无突兀亮块；
- `flutter analyze` 零新增问题。

#### Phase 3: 自适应布局（Layout 5/10 → ≥8）

> 在保留现有等比缩放方案的前提下，叠加 MD3 窗口尺寸类（compact/medium/expanded）以切换导航形态。导航（Navigation）已达标 8/10（`NavigationRail` + `IndexedStack` 正确使用），自适应降级作为布局增强纳入本 Phase。
> **说明：** 宽屏内容宽度约束已移除——等比例缩放（`context.sp()`）是预期行为，窗口拉宽时字体与间距同步放大，无需人工 `ConstrainedBox` 限宽。

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.1 Phase 3, Task 1 | 窗口尺寸类工具 | 在 `core/responsive` 新增 `WindowSizeClass`（compact <600 / medium 600–839 / expanded ≥840）与 `context.windowSizeClass` getter，统一断点判定来源 | `lib/core/responsive/window_size_class.dart`, `responsive_ext.dart` | `[x]` |
| v0.1.1 Phase 3, Task 2 | AppShell 自适应导航 | `app_shell.dart` 按尺寸类切换：compact → 底部 `NavigationBar`、medium → 收起 `NavigationRail`、expanded → 可展开 `NavigationRail`；保持 `IndexedStack` 页面状态不丢失 | `lib/core/navigation/app_shell.dart`, `app_navigation_rail.dart` | `[x]` |
| v0.1.1 Phase 3, Task 3 | 多窗口尺寸验证 | 在 Windows 桌面调整窗口至 <600 / 600–839 / ≥840 三档，确认导航形态切换正确、页面状态保留、无溢出告警 | （验证任务，无新增文件） | `[x]` |

**Phase 3 验收标准：**
- 窄窗（<600）显示底部导航栏，宽窗显示侧边 rail，切换无状态丢失；
- 无 `RenderFlex overflow` 告警；
- `flutter analyze` 零新增问题。

#### Phase 4: Elevation 色调表面化（Elevation 3/10 → ≥8）

> MD3 使用 **色调表面颜色**（tonal surface color）而非阴影来传达高程层级。当前代码 `CardThemeData(elevation: 2)` + 卡片边框是 MD2 遗风，与 MD3 设计准则冲突。本 Phase 将阴影 + 边框替换为 `surfaceContainer*` 色调表面链，使 UI 层级感知随明暗主题正确适配。
>
> **色调表面层级映射（MD3 规范）：**
> | 层级 | Token | 用途 |
> |------|-------|------|
> | 最低 | `surfaceContainerLowest` | 播放器深色底、模态背景 |
> | 低 | `surfaceContainerLow` | 默认卡片背景 |
> | 中 | `surfaceContainer` | 导航区域、侧栏背景 |
> | 高 | `surfaceContainerHigh` | 悬浮面板、弹出菜单 |
> | 最高 | `surfaceContainerHighest` | 搜索栏、输入框填充 |

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.1 Phase 4, Task 1 | 卡片色调表面化 | 移除 `CardThemeData(elevation: 2)`，改为 `CardThemeData(color: colorScheme.surfaceContainerLow)`；移除卡片边框 `BorderSide(color: rmCardBorder/rmCardBorderDark)`，MD3 filled card 无边框，outlined card 应使用 `colorScheme.outlineVariant` | `lib/core/theme/app_theme.dart` | `[x]` |
| v0.1.1 Phase 4, Task 2 | 视频面板深色底 surface 化 | 将 `video_panel.dart` / `custom_video_panel.dart` / `custom_ffplay_panel.dart` 中的 `Color(0xFF101418)` 硬编码改为 `colorScheme.surfaceContainerLowest`；`debug_panel.dart` 的 `0xFF303030` 改为 `colorScheme.surfaceContainerHigh` | 上述文件 | `[x]` |
| v0.1.1 Phase 4, Task 3 | 覆盖层色调表面化 | 将视频覆盖层（`Colors.black.withValues(alpha: 0.55)`）改为 `colorScheme.scrim.withValues(alpha: 0.55)`，使覆盖层在明暗主题下均有合理对比 | `custom_mediakit_player.dart`, `mqtt_login_badge.dart` | `[x]` |
| v0.1.1 Phase 4, Task 4 | 导航/侧栏色调表面化 | 确认 `NavigationRail` 的 `backgroundColor: scheme.surface` 已正确 — 无需改动 | `app_navigation_rail.dart` | `[x]` |
| v0.1.1 Phase 4, Task 5 | Elevation 收尾审查 | 全库复扫 `elevation:` 关键字：`debug_panel.dart` 浮窗 `elevation:8` 保留（浮动面板需阴影），`settings_screen.dart` 卡片 `elevation:2` 改为 `0` | 全库 | `[x]` |

**Phase 4 验收标准：**
- `CardThemeData` 中 `elevation` 已移除，卡片无阴影，背景使用 `surfaceContainerLow`；
- 视频播放器底色随明暗主题切换正确适配（暗色≈`0xFF101418`，亮色≈白色系）；
- 覆盖层使用 `scrim` 语义，在明暗主题下均有可比对的视觉降噪效果；
- 无 `elevation:` 残留在非必要位置；
- `flutter analyze` 零新增问题。

> **编号说明：** v0.1.1 没有独立 Phase 5；Accessibility 在 Phase 1-4 的排版、颜色、布局、surface 收口中合并处理，随后直接进入 Phase 6 Motion。

#### Phase 6: M3 动效系统（Motion 0/10 → ≥7）

> MD3 Expressive（2025年5月）引入了基于弹簧的物理运动（spring-based motion physics）取代传统的缓动/持续时间系统。本 Phase 为关键导航与组件交互注入 M3 动效，包括页面过渡、组件交互动画与加载反馈。
>
> **动效系统架构：**
> | 层级 | 类型 | MD3 规范 | 适用场景 |
> |------|------|----------|----------|
> | 导航过渡 | 进入/退出/共享轴 | Emphasized 500ms / Decelerate 400ms / Accelerate 200ms | 页面切换、Tab 切换 |
> | 组件交互 | 按压/悬停/展开 | Spring 物理（stiffness=300-500, damping=20-30） | 按钮按下、卡片展开、FAB 弹出 |
> | 反馈动效 | 加载/成功/错误 | Standard 300ms + 透明度/缩放 | 连接状态变化、数据刷新、操作确认 |
> | 容器变换 | 列表/面板 | Shared axis Z/X/Y | 列表项展开、面板折叠 |

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| v0.1.1 Phase 6, Task 1 | M3 页面过渡动画 | 在 `MaterialApp` 配置 `theme.pageTransitionsTheme`，注册 `M3PageTransitionsBuilder`（自定义实现：使用 MD3 emphasized 曲线 `cubic-bezier(0.2, 0, 0, 1)` + 500ms slide+fade） | `lib/core/theme/app_theme.dart` | `[x]` |
| v0.1.1 Phase 6, Task 2 | NavigationRail 交互动画 | 为 NavigationRail 的展开/收起添加容器宽度动画（`AnimatedContainer` + `Curves.fastOutSlowIn`，300ms） | `lib/core/navigation/app_shell.dart` | `[x]` |
| v0.1.1 Phase 6, Task 3 | 卡片/面板进入动效 | 为 Dashboard 数据卡片添加入场动画（`TweenAnimationBuilder` + fade+slide，MD3 emphasized 曲线 400ms） | `robot_status_list.dart`, `event_timeline_panel.dart`, `health_chart.dart` | `[x]` |
| v0.1.1 Phase 6, Task 4 | 连接状态动画 | MQTT 连接状态指示点使用弹簧动画切换颜色（`AnimatedContainer` + `Curves.fastOutSlowIn`）；登录徽标图标使用 `AnimatedSwitcher` 过渡 | `mqtt_login_badge.dart`, `dashboard_screen.dart` | `[x]` |
| v0.1.1 Phase 6, Task 5 | FAB 菜单动效 | `PageFabMenu` 展开/收起使用 `AnimationController` + `Curves.fastOutSlowIn` 旋转动画（90°）+ `SingleTickerProviderStateMixin` | `lib/core/navigation/page_fab_menu.dart` | `[x]` |
| v0.1.1 Phase 6, Task 6 | 加载反馈动效 | 视频流"等待关键帧"使用 M3 `CircularProgressIndicator`；数据导出加载使用 `CircularProgressIndicator`（均为 M3 原生动效组件） | `custom_video_panel.dart`, `data_export_screen.dart` | `[x]` |
| v0.1.1 Phase 6, Task 7 | Motion 收尾与审计 | 全库确认：页面过渡 M3 emphasized 500ms；Rail 展开 300ms；卡片入场 400ms；连接状态 350ms；FAB 旋转 350ms；`flutter analyze` 零问题，`flutter test` 124/124 通过 | 全库 | `[x]` |

**Phase 6 验收标准：**
- 页面切换使用 MD3 强调曲线，过渡时长 ≥ 200ms ≤ 500ms；
- NavigationRail 展开/收起有弹簧动画，不突兀；
- 列表条目入场有交错淡入滑动效果；
- 连接状态切换有平滑颜色过渡而非瞬间跳变；
- `PageFabMenu` 展开/收起有扇形动画；
- 所有动画在 `flutter run --release` 下满 60fps（无 jank）；
- `flutter analyze` 零新增问题。

**v0.1.1 整体验收标准：** MD3 合规审计总分从 52 提升至 ≥ 80；Typography/Color/Shape/Layout/ Elevation/Accessibility/Motion 七维均达目标分（≥8 或 ≥7）；全程不破坏现有业务功能（双图传线、数据导出、回放、同步），`flutter test` 全通过，`flutter analyze` 零问题。

---

## 附录 A: 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  fl_chart: ^0.70.0
  path: ^1.9.0
  path_provider: ^2.1.5
  file_selector: ^1.1.0
  shared_preferences: ^2.5.0
  mqtt_client: ^10.0.0        # MQTT 3333 链路
  protobuf: ^6.0.0           # Protobuf 序列化/反序列化
  fixnum: ^1.1.0             # Protobuf int64/uint64 支持
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0
  typed_data: ^1.4.0
  package_info_plus: ^8.0.0
  url_launcher: ^6.3.0
  media_kit: ^1.2.0
  media_kit_video: ^2.0.0
  media_kit_libs_video: ^1.0.4
  video_player: ^2.11.0
  fvp: ^0.37.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.4.0
  freezed: ^3.0.0
  json_serializable: ^6.9.0
```

> **说明：** 依赖清单是阅读摘要，准确版本以 `pubspec.yaml` 为准。开发环境需安装 `protoc` (Protocol Buffers Compiler) 以从 `.proto` 文件生成 Dart 代码。

---

## 附录 B: 数据模型设计

### B.1 MQTT 消息包装模型（链路 A）

```dart
class ProtobufEnvelope {
  final String topic;                    // MQTT 主题名称
  final String messageType;              // Protobuf 消息类型标识
  final GeneratedMessage? protobufMessage; // protoc 生成的 Dart 实例（可能为 null 若类型未注册）
  final Uint8List rawBytes;              // 原始 Protobuf 字节（降级/调试用）
  final DateTime timestamp;
}
```

### B.2 视频帧模型（链路 B：HEVC 视频流）

```dart
class VideoFrame {
  final int frameId;              // 帧 ID（同一帧的所有分片共享）
  final int packetCount;          // 该帧包含的 UDP 分片总数
  final Uint8List annexbData;     // 含 0x00000001 Start Code 的完整 HEVC 帧
  final DateTime timestamp;       // 重组完成时间
  final Duration reassemblyTime;  // 从首分片到重组完成的耗时
}
```

### B.3 导出文件结构

```json
{
  "schema_version": "2.0",
  "export_time": "2026-06-06T12:00:00Z",
  "app_version": "1.0.0",
  "metadata": {
    "mqtt_broker": "192.168.1.2:3333",
    "udp_port": 3334,
    "duration_seconds": 180,
    "message_count": 4500,
    "video_frame_count": 5400
  },
  "messages": [
    {
      "timestamp": "2026-06-06T12:00:01.123Z",
      "topic": "game/status",
      "type": "GameStatus",
      "payload": { /* Protobuf 转 JSON 后的字段 */ }
    }
  ]
}
```

### B.4 远程记录文件名约定

远程记录仓库中的文件遵循导出/合并命名约定，用于在不下载文件的情况下解析出日期、阵营、机器人编号：

- 单机导出：`rm_export_{robotId}_{yyyyMMdd_HHmmss}.json`
  - `robotId < 100` 为红方，`robotId >= 100` 为蓝方。
- 多机合并：`rm_merged_{red|blue}_{yyyyMMdd_HHmmss}.json`

云端记录管理页面基于这些元数据显示，并支持按日期、阵营、机器人编号筛选。

---

## 附录 C: 自定义客户端链路约束

### C.1 MQTT 3333 约束（链路 A）

- **消息格式：** 采用 Protobuf 序列化，非纯文本 JSON。
- **主题设计：** 根据官方自定义客户端协议第2章定义订阅主题（如 `robot/{id}/status`、`game/state`、`client/config` 等）。
- **心跳机制：** 客户端需按 MQTT 标准发送 PINGREQ，保持连接。
- **解析降级：** 若收到未在 `protos/` 中注册的 Protobuf 类型，保留原始 `Uint8List` 并写入 Debug 日志，不抛异常中断。

### C.2 UDP 3334 视频流约束（链路 B）

- **分片机制：** 不保证 NALU 边界对齐。每个 UDP payload 前缀包含 `frame_id` + `packet_id` + `frame_size` 等元数据，接收端必须重组。
- **同一帧的所有 UDP 分片共享同一个 `frame_id`，`frame_id` 递增严格等于进入下一帧。**
- **参数集内嵌：** VPS/SPS/PPS 在 3334 内周期性内嵌，周期由编码器 GOP 决定（约 1-2 秒），每个 I 帧前携带。不需要从特定时刻抓包，等待下一个 I 帧即可获取。
- **重组后的完整帧包含 AnnexB Start Code `0x00000001`，可直接送入 HEVC 解码器。**
- **分片格式：** 不是 RTP FU 格式，而是自定义的字节偏移分片。
- **丢包处理：** 若某帧分片丢失超过超时阈值（如 200ms），应丢弃该帧缓存，避免阻塞后续帧。
- **首分片特征：** 从实际抓包观察，首分片 payload 前缀长期为 `00000001 02...`，需据此识别并验证。

---

## 附录 D: GitHub 远程同步说明

### D.1 默认配置

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| 仓库 | `Zsdhak1/custom-client-sync` | 团队共享仓库 |
| 分支 | `main` | 默认目标分支 |
| 记录目录 | `records` | 远程仓库中存放比赛记录的目录 |
| 配置路径 | `record_config.json` | 团队共享记录配置的远程路径 |
| PAT | 内置默认值 | 程序内置默认 token，开箱即用 |

### D.2 安全提示

内置 PAT 仅用于团队内部 convenience，任何拿到二进制的人都可以提取该 token。若 token 泄露，应立即在 GitHub 上撤销并轮换。生产环境建议改为让用户在「数据记录配置」页面输入自己的 PAT。

### D.3 功能列表

- **上传记录：** 在数据导出页面选择本地记录后点击上传按钮，将本地 `MatchRecord` 序列化后通过 GitHub Contents API PUT 到远程 `records/` 目录。
- **浏览远程记录：** 在「云端记录」页面列出远程 `records/` 目录下的文件，显示为日期/阵营/机器人编号/文件大小，而非原始文件名。
- **下载远程记录：** 点击单条记录右侧下载按钮，将文件拉取到本地导出目录，并刷新本地记录列表。
- **共享配置同步：** 支持拉取/推送 `record_config.json`（团队统一的记录配置）。
- **无凭证降级：** 当仓库为空字符串或 token 被显式清空时，所有同步方法直接返回失败/空结果，不会发起网络请求。

---

## 附录 E: 版本更新日志（Changelog）

> **维护规则：** 本节记录每个发布版本的变更。版本号遵循 `pubspec.yaml` 中的 `version` 字段（语义化版本 `MAJOR.MINOR.PATCH+BUILD`）。
> - 每次发布新版本前，在表格**顶部**新增一行（最新版本在最上）。
> - 变更分类使用：`新增` / `修复` / `优化` / `重构` / `文档`。一行可包含多项，用 `；` 分隔。
> - 发布日期使用绝对日期 `YYYY-MM-DD`，不要使用“今天/昨天”等相对表述。
> - 版本号需与 `pubspec.yaml`、git tag 保持一致。
> - 详细的逐版本说明可在表格下方按需展开为小节。

| 版本 | 日期 | 变更摘要 |
|------|------|----------|
| 0.1.5 | 2026-07-22 | 新增 Dashboard 模块状态持续显示面板，并接入 Buff 与模块实时协议状态；修复 Protobuf 必要字段 presence、复活基地证据三态、不确定事件抑制、恢复告警关闭顺序、运行时重置与 MQTT 会话隔离；优化 官方规则版本、复活严重级别、17mm/42mm 默认伤害及断线/新小局/离场/身份变化状态清理；移除 敌方最低血量选敌算法和指挥性集火建议，仅保留中性状态展示；文档 完成 71 项针对性测试、266 项全量测试和零问题静态分析的发布收口 |
| 0.1.4 | 2026-07-21 | 修复 英雄 42mm 常规兑换指令类型为 2、远程买弹参数为 100，并移除副屏复活确认；新增 `RobotDynamicStatus` 驱动的远程回血/买弹许可与单次脉冲提示；新增 `TechCoreMotionStateSync` 驱动的工程难度、运动步骤、剩余时间和自动确认控制；重构 操作 Protobuf 构建、MQTT 发布与重发定时任务到数据层和控制器，覆盖完成、取消、复位、剩余时间归零、断线、身份切换及释放清理；优化 操作面板文案、窄高度滚动布局与 197 项全量回归 |
| 0.1.3 | 2026-07-13 | 新增 可跨页面显示的 INFO/CRITICAL 通知运行时、独立位置与关闭策略、会话历史、系统声音和 Android 震动；新增 设置页 INFO、CRITICAL 与全部事件类型的手动通知测试入口，测试使用当前档案反馈和展示策略但绕过开关与冷却；新增 通知总览、事件级设置、斩杀线、复活公式、部署跳转、连接质量与档案选择的逐项作用说明，统一使用 MD3 辅助文本层级；新增 英雄部署模式 0→1 三秒倒计时、取消/立即进入、本场抑制、自定义图传预启动与失败降级；新增 三种敌方斩杀线、免费复活公式、买活/普通复活/己方复活与装配事件判定；新增 MQTT 断开/重连、连接质量防抖恢复和机器人模块断联/恢复通知；新增 通知与比赛规则版本化配置档案、JSON 导入导出、持久化设置与完整 Material 3 配置表单；修复 AppShell 非默认初始页面的 Riverpod 构建期写入、部署准备期间取消后的异步竞态和导航失败反馈；修复 AppShell 宽屏内容区因未纵向拉伸而折叠为零高度的启动空白；修复 设置详情区内嵌 Navigator 在当前 Flutter 页面 API 下缺少移除回调的断言；修复 Windows 顶部拖动层覆盖设置返回按钮中心以及通知二级页进入动画新旧内容透叠；优化 通知设置由单页长列表重构为两组目录和六个二级页面，兼容紧凑全屏与桌面详情区导航；优化 通知规则引擎拆分、必需主题订阅与 178 项全量回归；优化 全局普通界面文字统一使用随应用打包的 MiSans，覆盖 400、500、600、700、900 字重并保留调试数据等宽字体；修复 Dashboard 机器人列表、连接质量与操作面板裁切；修复 最大化工作区轻微超宽时画布产生左右白边、视频页侧栏血量列表越界；优化 Windows 窗口控件为页面内悬浮叠加，不再占用独立标题栏高度；修复 GitHub Actions Windows 构建因 fvp 0.37.2 在插件符号链接目录解压 MDK SDK 被新版 CMake 拒绝，升级至 fvp 0.37.3 使用真实路径解压 |
| 0.1.2 | 2026-07-12 | 新增 仪表盘整行血量卡片、亚克力信息层、预计击杀弹丸量及可配置命中率/弹丸伤害/机器人血量上限；新增 比赛详情与录制状态面板；优化 无血量遥测时使用从左到右的扫描光晕提示血条区域；优化 底部四面板布局与 MD3 原生操作按钮；优化 Windows/Linux 固定设计画布整体等比缩放；修复 高分辨率全屏时固定画布不放大及多页面共享 FAB 默认 Hero tag 冲突 |
| 0.1.1 | 2026-07-03 | 修复 稳定性审查问题：MQTT 自动重连保留用户实际 broker/port，手动断开后再次连接恢复自动重连，并忽略旧客户端迟到回调；修复 UDP/自定义图传启动失败后的资源回滚与迟到数据保护；优化 Android 安装包下载超时与打开链接异常兜底 |
| 0.1.1 | 2026-06-28 | 优化 Material 3 合规（审计基线 52/100 → 目标 ≥80）：排版令牌化（消化 139 处裸 fontSize，改用 type scale 角色）；颜色双轨收口（协议语义色集中、中性色改 colorScheme 角色，消化 117+23 处硬编码）；自适应布局（窗口尺寸类 + compact 降级 NavigationBar，宽屏适配移除——等比例缩放为预期行为）；Elevation 色调表面化（移除全局卡片阴影+边框，改用 surfaceContainer* 链，settings_screen 卡片 elevation 修复）；M3 动效系统（页面过渡 emphasized curve 500ms + slide+fade、NavigationRail 展开/收起 `AnimatedContainer` 300ms、Dashboard 三面板入场动画 400ms、连接状态 `AnimatedSwitcher` 350ms、FAB 菜单旋转动画 350ms）。无新增业务功能 |
| 0.1.0 | 2026-06-21 | 新增 调试基础设施：三种可实时切换的拼包模式（verbatim/stripPrefix/fixed）、uint64 LE 序列号丢包检测与统计；新增 全面调试面板（CustomVideoDebugPanel）显示流水线红绿灯、NAL 类型计数、实时码率与丢包率；新增 解码器诊断信息模型（fvp/media_kit 上报 resolution/codec/fps/error 到滚动日志）；新增 20 秒 H.264 原始码流导出（保存 .h264 供 ffprobe 离线分析）；新增 准星点击移动交互；新增 Dashboard 事件通知样式实验台（监控页内切换多种高显著通知样式并手动预览）；更新 Proto CustomByteBlock 新增 is_frame_start 字段 |
| 0.0.4 | 2026-06-19 | 新增 自定义图传后端切换（fvp/media_kit/ffplay）；新增 MPEG-TS 封装模式（media_kit 缺裸 H.264 解封装，包 TS 后可正常播放）；新增 桥端关键帧缓存与后连接客户端补发机制（修复解码器连接竞态白屏）；新增 自定义图传设置页独立后端选择与 TS 开关；新增 Windows 端 ffplay 验证面板；新增 pure-Dart MPEG-TS muxer（ffprobe/ffmpeg 验证可完整解码） |
| 0.0.3 | 2026-06-18 | 新增 自定义数据图传线（0x0310 / CustomByteBlock / H.264）监控页面；新增 Windows 端本地模拟器（H.264 编码 + MQTT 发送）；复用现有 media_kit/fvp 解码桥，与官方 UDP 3334 图传线并存；新增 准星叠加与解码统计覆盖层 |
| 0.0.2 | 2026-06-15 | 新增 应用内更新检查与 Linux 启动脚本；优化 对外名称更名为 WOD Client；文档 关于页面信息收口 |
| 0.0.1 | 2026-06-14 | 新增 RoboMaster Monitor 首个正式版本：MQTT 3333 / UDP 3334 双链路监控、实时面板、数据导出与回放、多客户端合并、GitHub 远程同步 |

### E.1 版本号与发布流程

- 修改 `pubspec.yaml` 的 `version` 字段后，必须同步在本节表格新增对应行。
- 进度表（开发进度表）的版本块标题、`pubspec.yaml` 的 `version`、本节 Changelog 行、git tag 名四者必须一致；新增版本时四处同步更新。
- `push` 标签 `v*`（如 `v0.1.0`）触发正式 Release；标签名应与本节版本号一致。
- `push` 到 `master` 会更新名为 `latest` 的滚动预发布，不要求在本节登记，但建议在合入显著功能时补充摘要。

---

## 附录 F: 设置页面 Master–Detail 布局规范（v0.1.1+）

### F.1 布局结构

设置页面采用三层自适应布局：

```
┌─────────────────────────────────────────────────────────┐
│   NavigationRail (AppShell 持有)                        │
├──────────┬──────────────────────────────────────────────┤
│  Master  │  Detail                                      │
│  (360dp) │  ┌─ [← 返回] [标题] ─────────────────────┐  │
│          │  ├────────────────────────────────────────┤  │
│  卡片列表 │  │  Nested Navigator                     │  │
│  选中态   │  │  (子页面 + 二级子页面)                │  │
│  primary  │  │                                        │  │
│  Container│  │  sub‑sub‑screen pushed via              │  │
│          │  │  Navigator.of(context).push()            │  │
│          │  │  → 局限在此区域内                        │  │
│          │  └────────────────────────────────────────┘  │
└──────────┴──────────────────────────────────────────────┘
```

### F.2 关键实现决策

| 决策 | 实现 |
|------|------|
| 外层路由 | `Navigator.push`（窄屏 <600dp）/ 本地 State（宽屏 ≥600dp） |
| 二级路由 | 嵌套 `Navigator` widget + `pages` API，局限在 Detail 区域 |
| 三级路由 | 从子页面 `push(MaterialPageRoute)` 自动进入嵌套 Navigator |
| 返回行为 | 先 pop 嵌套 Navigator（三级→二级），再关闭 Detail 面板（二级→一级） |
| 入场动画 | `SlideTransition` + `Curves.easeInOutCubicEmphasized`，350ms |
| 退场动画 | 无——旧页面被 `ValueKey<int>` 驱动的 widget 生命周期直接卸载 |
| 子页面 AppBar | 通过 `embedded` 参数跳过（只渲染 body） |

### F.3 文件清单

| 角色 | 文件 |
|------|------|
| Master–Detail 容器 | `lib/features/settings/presentation/settings_screen.dart` |
| 入场动画 wrapper | `_AnimatedDetailPage`（stateful, AnimationController） |
| 接收 `embedded` 的子页面 | `GeneralSettingsScreen`, `DashboardSettingsScreen`, `VideoSettingsScreen`, `PlaybackSettingsScreen`, `DeveloperSettingsScreen`, `AboutScreen` |

### F.4 添加新子页面的规范

1. 子页面必须接受 `embedded` 参数（`const XxxScreen({super.key, this.embedded = false})`）
2. 当 `embedded=true` 时，只返回 body 内容，不渲染 `Scaffold` + `AppBar`
3. 当 `embedded=false` 时，渲染完整 `Scaffold` + `AppBar`（窄屏 fallback 用）
4. 在 `_categories` 中分别注册 `screenBuilder`（full）和 `bodyBuilder`（embedded）

---

*文档版本：v2.20（完成 v0.1.5 最终整分支审查修复）*
*适配协议：RoboMaster 2026 自定义客户端协议（MQTT 3333 + UDP 3334）*
*参考依据：V1.3.1 第2章 + 自定义客户端 UDP 流问答 + 0x0310 抓包分析 + MD3 合规审计（2026-06-23）*
*修正日期：2026-07-22*
