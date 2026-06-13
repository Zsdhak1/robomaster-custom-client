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

---

### Phase 0: 项目脚手架与环境验证

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

### Phase 1: 核心基础设施（自定义客户端双链路）

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

### Phase 2: 主监控面板（Dashboard）

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

### Phase 3: 数据导出与赛后分析

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

### Phase 4: 设置与辅助页面

| # | Task | 描述 | 产出文件 | 状态 |
|---|------|------|----------|------|
| 4.1 | 设置页面 | 创建设置页面：MQTT 服务器地址/端口/主题前缀、UDP 端口配置、视频流开关、主题切换（亮色/暗色）、Debug 面板开关、数据记录上限。使用 SharedPreferences 持久化。 | `lib/features/settings/presentation/settings_screen.dart` | `[x]` |
| 4.2 | 设置状态管理 | 创建设置相关的 Riverpod Provider，支持设置项的读取、修改和持久化。 | `lib/features/settings/logic/settings_providers.dart` | `[x]` |
| 4.3 | 关于页面 | 创建关于页面：应用名称、版本号、技术栈说明（MQTT + Protobuf + HEVC AnnexB）、开源协议、RoboMaster 2026 自定义客户端协议适配声明。 | `lib/features/about/presentation/about_screen.dart` | `[ ]` |
| 4.4 | 导航与路由 | 常驻 `AppShell` 持有侧边 `NavigationRail` + `IndexedStack`（监控/视频/数据/设置四页），切页只改索引、Rail 与页面状态均存活；Rail 支持展开/收起，顶部 icon 随登录身份切换、3/4 号步兵以数字徽标区分；页面级操作收敛到 `PageFabMenu`。连接页支持「离线模式」直接进入 Shell。 | `lib/core/navigation/app_shell.dart`, `app_navigation_rail.dart`, `page_fab_menu.dart` | `[x]` |

**Phase 4 验收标准：** 所有页面可正常导航，设置项可持久化保存，关于页面信息完整。

---

### Phase 5: 收尾与优化

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

*文档版本：v2.2（更新 — 添加 GitHub 远程同步与多客户端合并完成标记）*
*适配协议：RoboMaster 2026 自定义客户端协议（MQTT 3333 + UDP 3334）*
*参考依据：V1.3.1 第2章 + 自定义客户端 UDP 流问答*
*修正日期：2026-06-13*
