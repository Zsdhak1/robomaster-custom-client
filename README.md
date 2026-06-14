# RoboMaster Monitor · 自定义客户端数据监控

一个面向 **RoboMaster 2026 机甲大师超级对抗赛** 的自定义客户端监控应用。基于 Flutter 构建，对接官方自定义客户端双链路：

- **MQTT 3333** — 控制指令、比赛状态与事件（Protobuf 序列化）
- **UDP 3334** — HEVC(H.265) AnnexB 视频流（自定义字节偏移分片）

支持实时比赛监控、视频流低延迟渲染、赛后 JSON 数据导出/回放、多客户端数据合并，以及基于 GitHub 的远程记录同步。

---

## 功能特性

| 模块 | 能力 |
|------|------|
| **登录与身份** | 红/蓝方机器人身份选择，己方阵营主题色自动切换，支持离线模式直接进入 |
| **实时监控面板** | 比赛阶段、比分、双方血量、经济/发弹量、事件时间轴、实时血量曲线 |
| **视频流监控** | UDP 3334 HEVC 帧重组、本地 TCP 桥接、media_kit / fvp / ffplay 多解码后端 |
| **数据录制与导出** | 自动录制 MQTT 消息，按消息类型分桶，导出 JSON，支持导入本地记录 |
| **赛后回放** | 单记录回放、关键帧缓存、进度拖动、事件时间轴 |
| **多客户端合并** | 选择多个单机器人记录，按时间戳对齐合并为红/蓝方综合记录 |
| **远程同步** | 基于 GitHub Contents API 上传/下载/浏览共享比赛记录 |
| **设置中心** | 导出目录、主题、解码器、硬件解码、开发者模式、Topic 订阅配置 |

---

## 技术栈

- **框架**: Flutter 3.x / Dart 3.x
- **状态管理**: `flutter_riverpod`
- **图表**: `fl_chart`
- **MQTT 客户端**: `mqtt_client`
- **Protobuf**: `protobuf` + `protoc-gen-dart`
- **视频解码**: `media_kit` / `fvp` / `ffplay`
- **文件选择**: `file_selector`
- **持久化**: `shared_preferences` + 本地 JSON

---

## 项目结构

```
robomaster_custom_client_1/
├── android/                 # Android 平台配置
├── lib/
│   ├── core/                # 全局共享能力
│   │   ├── constants/       # 协议常量、字符串、Topic 注册表
│   │   ├── navigation/      # AppShell / NavigationRail / PageFabMenu
│   │   ├── protobuf/        # Protobuf 通用解析器与 Envelope
│   │   ├── state/           # 全局会话级 Providers
│   │   ├── sync/            # 远程同步接口与 GitHub 实现
│   │   ├── theme/           # 主题与队伍配色
│   │   ├── utils/           # ByteData 读取、NALU 检测等纯工具
│   │   └── video/           # HEVC 帧重组器与 VideoFrame 模型
│   ├── features/
│   │   ├── connection/      # 登录页、机器人身份模型
│   │   ├── dashboard/       # 监控面板、游戏状态聚合、图表、事件时间轴
│   │   ├── data_export/     # 记录导出/导入、合并、回放、远程记录
│   │   └── settings/        # 设置页、Topic 配置、解码器选择
│   ├── generated/           # protoc 生成的 Dart 类
│   ├── services/            # MQTT / UDP / TCP 桥接 / ffplay 解码服务
│   ├── app.dart             # MaterialApp 配置
│   └── main.dart            # 应用入口
├── protos/                  # .proto 协议定义
├── test/                    # 单元测试与 Widget 测试
├── test_data/               # 测试用数据文件
├── tool/                    # 辅助脚本
├── .github/workflows/       # GitHub Actions 构建与发布
├── Makefile                 # Protobuf 编译（Linux/macOS）
├── build.ps1                # Protobuf 编译（Windows PowerShell）
├── analysis_options.yaml    # 严格 Lint 规则
├── feature_spec.md          # 功能规格与开发进度
└── AGENTS.md                # AI 开发规范
```

---

## 快速开始

### 环境要求

- Flutter SDK >= 3.44.0 (Dart >= 3.12.1)
- protoc (Protocol Buffers compiler)
- protoc-gen-dart (`dart pub global activate protoc_plugin`)
- Android SDK 或 Linux 桌面构建依赖

### 安装依赖

```bash
flutter pub get
```

### 编译 Protobuf

```bash
# Linux / macOS
make proto

# Windows PowerShell
./build.ps1
```

### 运行应用

```bash
# Android
flutter run

# Linux 桌面
flutter run -d linux

# 指定设备
flutter devices
flutter run -d <device-id>
```

#### Linux 发行包运行依赖

本项目使用 `media_kit` 作为视频解码后端，运行时需要 `libmpv.so.2`。如果你从 Release 下载的 tar.gz 解压后运行报以下错误：

```text
./robomaster_custom_client_1: error while loading shared libraries: libmpv.so.2: cannot open shared object file: No such file or directory
```

说明目标系统缺少 mpv 库。有三种解决方式：

1. **Ubuntu 22.04 用户请下载专用包**

   Release 页面提供两种 Linux 包：

   - `robomaster-custom-client-linux-ubuntu2204.tar.gz` —— 在 **Ubuntu 22.04** 上编译，适合 Ubuntu 22.04 / 兼容的旧系统
   - `robomaster-custom-client-linux.tar.gz` —— 在最新的 `ubuntu-latest`（目前为 Ubuntu 24.04）上编译，适合较新的发行版

   由于 glibc 向前兼容、向后不兼容，**旧系统编译的包通常可以在新系统上运行**，反之则不行。如果你运行在 Ubuntu 22.04 或同类旧发行版，请优先下载带 `-ubuntu2204` 后缀的包。

2. **快速方案：安装系统 mpv 库**

   ```bash
   sudo apt-get update
   sudo apt-get install -y libmpv2   # Debian / Ubuntu
   ```

3. **绿色方案：使用自带依赖库的 Release 包**

   从 `v0.0.2` 起，CI 构建的 Linux 发行包会附带 `libmpv.so.2` 等必要动态库，解压即可直接运行。无需再安装系统 mpv。

   如果仍有其他库缺失，可用 `ldd` 查看：

   ```bash
   ldd ./robomaster_custom_client_1 | grep not
   ```
#### Linux 发行包运行脚本部署
   在发行包根目录下运行终端
   ```bash
  start.sh
   #!/bin/bash
   # RoboMaster Custom Client 启动脚本
   # 自动设置 LD_LIBRARY_PATH 以解决 libmpv.so.1 等间接依赖找不到的问题
   
   SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
   export LD_LIBRARY_PATH="$SCRIPT_DIR/lib:$LD_LIBRARY_PATH"   
   exec "$SCRIPT_DIR/robomaster_custom_client_1" "$@"
   ```


---

## 协议对接说明

### MQTT 3333

- 消息格式为 Protobuf，非 JSON 文本。
- 默认服务器地址 `192.168.12.1:3333`，默认客户端地址 `192.168.12.2`。
- 已注册解析的 Topic 包括：
  - `GameStatus` — 比赛全局状态
  - `GlobalUnitStatus` — 基地、前哨站、机器人血量与发弹量
  - `GlobalLogisticsStatus` — 经济、科技等级
  - `GlobalSpecialMechanism` — 全局特殊机制
  - `Event` — 比赛事件通知
  - 以及机器人控制、判罚、雷达、能量机关、飞镖、空中支援等 Topic
- 未知 Topic 会降级为原始字节日志，不会中断数据流。

### UDP 3334 视频流

- 每个 UDP payload 前缀 8 字节元数据：
  - `frame_id` (2 bytes, BE)
  - `packet_id` (2 bytes, BE)
  - `frame_size` (4 bytes, BE)
- 同一帧的所有分片共享同一个 `frame_id`；`frame_id` 递增标志进入下一帧。
- 接收端按 `frame_id` 缓存分片，收齐后按 `packet_id` 顺序拼接，并补充 AnnexB Start Code `0x00000001`。
- 不完整帧在 1000ms 后丢弃，避免阻塞后续帧；缓存上限 64 帧防止内存泄漏。
- 重组后的完整 HEVC 帧通过本地 TCP 桥接 (`127.0.0.1`) 送入 decoder 播放。

---

## 测试

```bash
# 代码分析（零警告目标）
flutter analyze

# 运行全部测试
flutter test
```

当前覆盖的测试：

- 视频帧重组器 (`test/frame_reassembler_test.dart`)
- AnnexB TCP 桥接 (`test/annexb_tcp_server_test.dart`)
- 游戏状态聚合 (`test/game_state_notifier_test.dart`)
- 记录扫描与解析 (`test/match_record_scanner_test.dart`)
- 多记录合并 (`test/match_merger_test.dart`)
- 远程记录元数据 (`test/remote_record_meta_test.dart`)
- GitHub 同步服务 (`test/github_sync_service_test.dart`)
- 健康图表 Widget (`test/health_chart_test.dart`)
- 记录配置 (`test/record_config_test.dart`)

---

## 构建与发布

项目使用 GitHub Actions 自动构建：

- `push` 到 `master` → 更新名为 `latest` 的滚动预发布
- `push` 标签 `v*` → 发布带版本号的正式 Release
- 手动触发 `workflow_dispatch`

构建产物：

| 平台 | 产物 |
|------|------|
| Android | `robomaster-custom-client-android.apk` |
| Windows | `robomaster-custom-client-windows.zip` |
| Linux | `robomaster-custom-client-linux.tar.gz` |

---

## 配置与自定义

### 导出目录

在「设置 → 数据导出」中选择本地目录，用于保存录制文件、导入文件和合并文件。

### Topic 订阅配置

在「设置 → 数据记录配置」中选择需要订阅并记录的 MQTT Topic，可减少无关流量和文件体积。

### 远程同步

默认共享仓库：

```
Zsdhak1/custom-client-sync
```

可在设置中修改仓库、分支、记录目录和 PAT。内置 PAT 仅用于团队内部开箱即用，**切勿公开发布二进制**。

---

## 截图

> 截图占位：登录页 / 监控面板 / 视频流 / 记录管理 / 回放 / 设置

---

## 参考文档

- `feature_spec.md` — 完整功能规格与开发进度
- `AGENTS.md` — AI 开发规范与自审计清单
- `protos/robomaster_custom_client.proto` — 自定义客户端协议定义
- `RoboMaster 2026 机甲大师高校系列赛通信协议 V1.3.1` — 官方协议手册

---

## 许可

本项目为 RoboMaster 参赛队内部工具，代码按现有开源依赖的许可要求使用。官方通信协议归 RoboMaster 组委会所有。

---

<p align="center">Made with ⚡ for RoboMaster 2026</p>
