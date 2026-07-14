# AGENTS.md — 自定义客户端数据监控 (RoboMaster 2026 V1.3.1)

## 1. 项目核心语境

**当前应用名：** WOD Client。版本号以 `pubspec.yaml` 的 `version` 为唯一权威；接手时先读 `feature_spec.md` 顶部「新 Agent 接手摘要」。

**技术栈：** Flutter 3.x + Dart 3.x，Android + Linux/Windows 桌面多平台。状态管理使用 Riverpod（flutter_riverpod）。图表使用 fl_chart。JSON 数据持久化使用 dart:convert + path_provider。

**网络层：**
- **MQTT 3333** — 控制指令、配置、比赛状态与事件（Protobuf 序列化），使用 `mqtt_client` 包。
- **UDP 3334** — HEVC(H.265) AnnexB 视频流（自定义字节偏移分片，非 RTP），使用 `dart:io` RawSocket。
- **CustomByteBlock / 0x0310** — MQTT 承载 H.264 字节块，经独立 TCP 解码桥进入 fvp/media_kit/ffplay 后端。

**架构模式：** Feature-First 分层架构。每个 Feature 包含 `{presentation, domain, data}` 三层，但千行级项目允许适度简化——不强制要求 Repository 接口抽象，但数据与 UI 必须物理分离。

**核心目标：** 构建一个对接 RoboMaster 自定义客户端链路（MQTT 3333 + UDP 3334 + 0x0310 自定义图传）的监控客户端，实时解析并可视化展示比赛状态，支持数据导出、回放、调试与多客户端数据汇总分析。

---

## 2. 非 negotiable 规则

| 规则 | 强制执行方式 |
|------|------------|
| 单函数不超过 50 行 | analysis_options.yaml (metrics) + 代码审查 hook |
| 先定义数据模型，再写 UI | feature_spec.md 强制要求 + Stop hook 验证 |
| 严禁在 Widget 中直接调用 RawSocket 或 MQTT 客户端 | 必须通过 Data 层的 Service 类封装 |
| 所有协议常量使用命名常量 | Lint: prefer_const_declarations |
| JSON 导出/导入的数据结构必须有 fromJson/toJson | 编译时检查 |
| UI 字符串全部放入常量文件 | analysis_options.yaml: avoid_hardcoded_strings |
| 每次文件写入后必须运行 `flutter analyze` | PostToolUse hook 自动执行 |
| 发布新版本前必须更新 feature_spec.md 的更新日志 | 见第 6.3 节 + 自审计清单 |
| 进度表任务必须标注所属版本号（`vX.Y.Z Phase N, Task M`） | feature_spec.md 开发进度表 + 见 6.4 节 |

---

## 3. 语言与风格

- **命名：** 类名 UpperCamelCase，文件/变量/函数 lowerCamelCase，常量 lowerCamelCase。Feature 文件夹使用 snake_case。
- **导入排序：** dart: 内置 → package: 第三方 → 相对路径，每组空行分隔。
- **空安全：** 全程启用 null safety，禁止显式 `!` 操作符（除非有注释说明理由）。
- **异步：** 优先使用 `Future`/`async-await`，仅在数据流场景使用 `Stream`（MQTT 消息流、UDP 视频帧流）。
- **注释：** 仅对复杂算法和协议解析逻辑写注释，禁止无意义的 `// 设置颜色` 类注释。

---

## 4. 架构约束

### 4.1 文件组织

```
lib/
├── main.dart                    # 入口，ProviderScope 包裹
├── app.dart                     # MaterialApp + 路由
├── core/                        # 全局共享
│   ├── constants/               # 字符串、颜色、数值常量、协议常量
│   ├── theme/                   # ThemeData + 样式
│   ├── utils/                   # 纯函数工具类（禁止放状态）
│   ├── extensions/              # Dart/Flutter 扩展方法
│   └── protobuf/                # Protobuf 通用解析与降级处理
├── features/                    # 按功能模块组织
│   ├── dashboard/               # 主监控面板
│   ├── custom_video/            # 0x0310 / H.264 自定义图传
│   ├── data_export/             # JSON 导入导出
│   ├── post_match_analysis/     # 赛后复盘分析
│   ├── settings/                # 设置页面
│   └── about/                   # 关于页面
└── services/                    # 全局服务
    ├── mqtt_service.dart        # MQTT 3333 客户端（Protobuf 消息收发）
    ├── video_stream_service.dart # UDP 3334 HEVC 视频流接收与帧重组
    └── udp_service.dart         # 通用 UDP 辅助（如端口绑定工具）
```

### 4.2 层间依赖方向

- `presentation` → `domain` → `data` → 外部（MQTT 客户端、RawSocket、文件系统）
- 禁止反向依赖。禁止跨 Feature 直接引用。
- `core/` 可以被任何层引用，但 `core/` 不能引用任何 Feature。

### 4.3 状态管理规范

- 使用 `StateNotifier` + `StateNotifierProvider` 管理复杂状态。
- 简单状态使用 `StateProvider`。
- 异步数据流使用 `StreamProvider`：
  - `mqttMessageProvider` — MQTT Protobuf 消息流
  - `videoFrameProvider` — UDP 3334 重组后的 HEVC 视频帧流
- Widget 中读取状态使用 `ref.watch()`，修改状态使用 `ref.read()`。

---

## 5. 协议与数据规范

### 5.1 MQTT 3333 — Protobuf 消息解析

- 所有 MQTT 消息解析逻辑集中在 `services/mqtt_service.dart` 和 `core/protobuf/protobuf_parser.dart`。
- 消息体为 Protobuf 序列化字节，**非 JSON 文本**。
- 解析器根据 topic / message type 将 `Uint8List` 反序列化为对应的 `GeneratedMessage` 子类。
- 无法识别类型时**降级为原始字节日志**，禁止抛异常中断数据流。
- `.proto` 定义文件存放于 `protos/` 目录，通过 `protoc` 生成 Dart 类到 `lib/generated/`。

### 5.2 UDP 3334 — HEVC AnnexB 视频流重组

- 视频流处理逻辑集中在 `services/video_stream_service.dart` 和 `core/video/frame_reassembler.dart`。
- 每个 UDP payload 包含分片元数据（`frame_id`, `packet_id`, `frame_size` 等），**不保证 NALU 边界对齐**。
- 接收端必须按 `frame_id` 缓存分片，按 `packet_id` / 偏移重组完整帧。
- 同一帧的所有分片共享同一个 `frame_id`；`frame_id` 递增标志进入下一帧。
- 重组后的完整帧必须包含 AnnexB Start Code `0x00000001`，可直接送入 HEVC 解码器。
- 若某帧分片丢失超过超时阈值（默认 200ms），**丢弃该帧缓存**，避免阻塞后续帧。
- VPS/SPS/PPS 随 I 帧周期性内嵌（周期约 1-2 秒），无需主动请求。

### 5.3 JSON 数据结构

- 所有可导出/导入的数据模型必须实现：
  - `Map<String, dynamic> toJson()`
  - `factory ModelName.fromJson(Map<String, dynamic> json)`
- JSON Schema 版本号写入每个导出文件的 `schema_version` 字段。

---

## 6. 开发流程协议

### 6.1 任务启动流程

1. **读取 feature_spec.md** — 先看顶部「新 Agent 接手摘要」，确认当前**版本号**与要实现的 Task，记下 `vX.Y.Z Phase N, Task M`。
2. **Codebase 搜索** — 优先使用 codebase-memory MCP（`search_graph` / `trace_path` / `get_code_snippet`）；若本线程未暴露 MCP 工具，或查找文档/配置/字符串，再用 `rg` 检查是否存在重复逻辑。
3. **编写/更新 Spec** — 如需调整计划，先更新 feature_spec.md 再编码。
4. **编码实现** — 遵循本文件所有规则。
5. **运行 flutter analyze** — 确保零警告。
6. **自审计** — 执行代码审查检查清单（见第7节）。
7. **提交** — 写入 git commit，标记 feature_spec.md 中对应 Task 为完成；若涉及版本发布，按 6.3 节更新附录 E 更新日志。

### 6.2 多平台兼容性

- 使用 `Platform.isAndroid` / `Platform.isLinux` 区分平台逻辑。
- 文件路径使用 `path_provider` 获取，禁止硬编码绝对路径。
- Linux 桌面端使用 GTK 文件选择器对话框（`file_selector` 包）。

### 6.3 版本更新日志维护

更新日志记录在 **feature_spec.md 的「附录 E: 版本更新日志（Changelog）」**，接手的 agent 必须按以下规则维护，确保日志与代码、git tag 一致：

1. **何时更新：** 凡是修改 `pubspec.yaml` 的 `version` 字段、准备打 `v*` tag 发布、或合入显著功能/修复时，必须在附录 E 表格**顶部**新增一行（最新版本在最上）。
2. **版本号来源：** 以 `pubspec.yaml` 的 `version`（`MAJOR.MINOR.PATCH+BUILD`）为唯一权威，表格版本号、git tag 名三者必须一致。
3. **变更分类：** 使用 `新增` / `修复` / `优化` / `重构` / `文档` 前缀，一行可含多项，用 `；` 分隔。
4. **日期格式：** 使用绝对日期 `YYYY-MM-DD`，禁止“今天/昨天/本周”等相对表述。
5. **不登记滚动预发布：** `push` 到 `master` 的 `latest` 预发布不强制登记，但合入显著功能时建议补充摘要。
6. **完成后验证：** 更新日志属文档变更，但本项目仍要求文件写入后运行 `flutter analyze`；若环境无法运行，必须在回复中说明。

### 6.4 版本化进度规范

开发进度以**版本号为顶层迭代单元**，与 6.3 节更新日志规范配套使用（见 6.3），确保进度表、版本号、Changelog、git tag 口径一致：

1. **顶层单元：** feature_spec.md「开发进度表」以 `### vX.Y.Z` 版本块为顶层，每个版本是一次独立迭代。
2. **重新编号：** 新版本（v0.1.0 起）内部 Phase 与 Task 一律从 `Phase 1, Task 1` 起编；历史版本（v0.0.1 / v0.0.2）保留其原始 Phase 编号以便追溯，不回填重排。
3. **任务标注：** 在进度表登记或更新任务、以及在交流中引用任务时，必须前置标注所属版本号 + Phase + Task，格式 `vX.Y.Z Phase N, Task M`（例：`v0.1.0 Phase 1, Task 1`）。
4. **四处一致：** 版本号在 `pubspec.yaml` 的 `version`、进度表版本块标题、附录 E Changelog 行、git tag 名四处必须一致；新增版本时四处同步更新。
5. **唯一权威：** 版本号以 `pubspec.yaml` 的 `version` 为唯一权威来源。

---

## 7. AI 自审计检查清单

每次完成一个 Task 后，AI 必须按以下清单自行审查代码，发现问题立即修复：

- [ ] **函数长度：** 所有函数不超过 50 行？超过则拆分。
- [ ] **重复代码：** 是否存在与已有代码功能重复的函数/类？
- [ ] **状态位置：** 状态是否放在正确的层？Widget 中是否存在业务逻辑？
- [ ] **命名一致性：** 命名是否符合第3节规范？是否存在中文拼音命名？
- [ ] **导入顺序：** 导入是否按第3节规范分组排序？
- [ ] **空安全：** 是否存在未处理的 null？是否存在不必要的 `!`？
- [ ] **常量提取：** 魔法数字/字符串是否已提取为命名常量？
- [ ] **错误处理：** 所有 async 函数是否有 try-catch？错误是否有用户反馈？
- [ ] **平台兼容：** 平台特定代码是否有条件分支？
- [ ] **文档注释：** 公共 API 是否有 dartdoc 注释？
- [ ] **协议降级：** MQTT 收到未知 Protobuf 类型时是否降级为原始字节，而非抛异常？
- [ ] **视频流防泄漏：** UDP 分片缓存表是否有最大容量限制和超时清理机制？
- [ ] **更新日志：** 若本次改动涉及版本号变更或显著功能/修复，是否已在 feature_spec.md 附录 E 顶部新增对应版本行（版本号与 pubspec.yaml 一致）？
- [ ] **版本标注：** 本次改动涉及的进度表任务是否已按 `vX.Y.Z Phase N, Task M` 标注，且版本号与 pubspec.yaml 一致？

---

## 8. 沟通规范

- **语言：** 所有变量命名使用英文。代码注释、文档、AI 与用户交互使用中文。
- **输出风格：** 简洁，直接给出可执行结论。禁止在工具调用前写长段解释。
- **代码块：** 使用 Dart 语法高亮标记。```dart

---

## 9. 原则

1. **简单优先** — 千行级项目拒绝过度设计。能用简单方案就不用复杂模式。
2. **显式优于隐式** — 字节序、编码格式、数据单位、协议链路（MQTT/UDP）必须显式声明。
3. **防御性编程** — 网络输入不可信（MQTT 消息、UDP 分片）。所有解析操作必须验证长度、范围、CRC/超时。
4. **可测试性** — 所有业务逻辑必须是纯函数或可注入依赖的类。
5. **平台无关核心** — 核心协议解析逻辑（Protobuf 反序列化、视频帧重组）必须是纯 Dart，与平台无关。

---

## 10. 进化记录

- 2026-06-06: 初始版本创建，适配千行级 Flutter 项目。
- 2026-06-06: **修正** — 将项目范围从"通用 UDP 数据包监控"精确限定为"自定义客户端双链路监控（MQTT 3333 + UDP 3334 HEVC）"；同步更新文件组织、协议规范、非 negotiable 规则与自审计清单。
- 2026-06-15: **新增** — 引入版本更新日志维护规范（6.3 节）；在 feature_spec.md 新增「附录 E: 版本更新日志」；非 negotiable 规则与自审计清单同步加入更新日志检查项。
- 2026-06-17: **新增** — 引入进度表版本化规范（6.4 节）：开发进度以版本号为顶层迭代单元，任务标注 `vX.Y.Z Phase N, Task M`；feature_spec.md 进度表回溯归档为 v0.0.1 / v0.0.2 版本块。
