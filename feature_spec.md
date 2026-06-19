# Feature Spec — 自定义客户端数据监控 (RoboMaster 2026 V1.3.1)

## 项目概览

| 属性     | 值                             |
| ------ | ----------------------------- |
| 项目名称   | RoboMaster_monitor（自定义客户端监控） |
| 技术栈    | Flutter 3.x + Dart 3.x        |
| 目标平台   | Android, Linux Desktop        |
| 状态管理   | flutter_riverpod              |
| 图表库    | fl_chart                      |
| 目标代码规模 | ~1800 行 Dart 代码               |

> **架构说明：** 本监控客户端仅对接自定义客户端的两条标准链路：
> 1. **MQTT 3333** — 控制指令、配置、比赛状态与事件（Protobuf 序列化）
> 2. **UDP 3334** — HEVC(H.265) AnnexB 视频流（自定义字节偏移分片，非 RTP FU）
>
> 不涉及裁判系统与机器人间的串口协议（第1章内容）。

---

## 开发进度表

> **AI 执行指令：** 按 Phase 顺序逐个完成，在每个Phase开始前，必须询问用户这个Phase的具体执行方式，确认用户需求理解无误之后开始具体执行。每完成一个 Task，在状态列标记 `[x]`，运行 `flutter analyze` 确认零警告，执行自审计检查清单，然后自动进入下一个 Task。严禁跳过 Phase。

> **版本化规范：** 开发进度以**版本号为顶层迭代单元**。每个版本（如 `v0.1.0`）是一次独立迭代，其内部 Phase 与 Task 从 `Phase 1, Task 1` 重新编号。在本表登记或更新任务时，**必须在功能描述前标注其所属版本号 + Phase + Task**，格式为 `vX.Y.Z Phase N, Task M`（例：`v0.1.0 Phase 1, Task 1`）。版本号须与 `pubspec.yaml` 的 `version` 字段、附录 E Changelog、git tag 三者一致（见附录 E.1）。**历史版本（v0.0.1 / v0.0.2）保留其原始 Phase 编号以便追溯**，新版本（v0.1.0 起）一律从 Phase 1 Task 1 起编。

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
| 2.5 | 实时操作面板 | 实现辅助信息区域：飞镖发射倒计时、空中支援状态、哨兵决策状态。数据来自 MQTT 状态消息。 | `lib/features/dashboard/presentation/widgets/operation_panel.dart` | `[ ]` |
| 2.6 | 视频流显示（可选） | 实现视频面板 Widget，接收 `videoFrameProvider` 的 AnnexB 帧，通过平台 View 或外部播放器渲染 HEVC 流。提供"显示/隐藏视频"开关。 | `lib/features/dashboard/presentation/widgets/video_panel.dart` | `[ ]` |
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
| 5.6 | 运行全部测试 | 运行 `flutter analyze`、`flutter test`，确保零警告、所有测试通过。 | - | `[ ]` |

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

## 附录 A: 依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  fl_chart: ^0.70.0
  path_provider: ^2.1.5
  file_selector: ^1.1.0
  shared_preferences: ^2.5.0
  mqtt_client: ^10.0.0        # MQTT 3333 链路
  protobuf: ^3.1.0           # Protobuf 序列化/反序列化
  fixnum: ^1.1.0             # Protobuf int64/uint64 支持
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.0
  freezed: ^3.0.0
  json_serializable: ^6.9.0
```

> **外部工具依赖：** 开发环境需安装 `protoc` (Protocol Buffers Compiler) 以从 `.proto` 文件生成 Dart 代码。

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
| 0.0.4 | 2026-06-19 | 新增 自定义图传后端切换（fvp/media_kit/ffplay）；新增 MPEG-TS 封装模式（media_kit 缺裸 H.264 解封装，包 TS 后可正常播放）；新增 桥端关键帧缓存与后连接客户端补发机制（修复解码器连接竞态白屏）；新增 自定义图传设置页独立后端选择与 TS 开关；新增 Windows 端 ffplay 验证面板；新增 pure-Dart MPEG-TS muxer（ffprobe/ffmpeg 验证可完整解码） |
| 0.0.3 | 2026-06-18 | 新增 自定义数据图传线（0x0310 / CustomByteBlock / H.264）监控页面；新增 Windows 端本地模拟器（H.264 编码 + MQTT 发送）；复用现有 media_kit/fvp 解码桥，与官方 UDP 3334 图传线并存；新增 准星叠加与解码统计覆盖层 |
| 0.0.1 | 2026-06-14 | 新增 RoboMaster Monitor 首个正式版本：MQTT 3333 / UDP 3334 双链路监控、实时面板、数据导出与回放、多客户端合并、GitHub 远程同步 |

### E.1 版本号与发布流程

- 修改 `pubspec.yaml` 的 `version` 字段后，必须同步在本节表格新增对应行。
- 进度表（开发进度表）的版本块标题、`pubspec.yaml` 的 `version`、本节 Changelog 行、git tag 名四者必须一致；新增版本时四处同步更新。
- `push` 标签 `v*`（如 `v0.1.0`）触发正式 Release；标签名应与本节版本号一致。
- `push` 到 `master` 会更新名为 `latest` 的滚动预发布，不要求在本节登记，但建议在合入显著功能时补充摘要。

---

*文档版本：v2.4（新增 v0.0.4 MPEG-TS 封装与后端切换）*
*适配协议：RoboMaster 2026 自定义客户端协议（MQTT 3333 + UDP 3334）*
*参考依据：V1.3.1 第2章 + 自定义客户端 UDP 流问答*
*修正日期：2026-06-17*
