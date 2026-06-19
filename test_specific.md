# 测试明细 — WOD Client v0.0.3

> 本文件记录每个单元测试到底验证了什么，作为 `feature_spec.md` 的测试补充。
> 每次新增或修改测试后，必须在此更新对应条目。

---

## v0.0.3 Phase 1: 数据层与 H.264 门控

### `test/custom_byte_block_source_test.dart`

| 测试名 | 验证内容 |
|--------|---------|
| `emits H.264 chunks from CustomByteBlock messages` | `CustomByteBlockSource` 订阅 `topicCustomByteBlock` 后，收到合法的 `CustomByteBlock` 消息时，能从 `data` 字段提取字节并通过 `chunkStream` 发出。 |
| `ignores messages on other topics` | 非 `CustomByteBlock` Topic 的消息被过滤，不会进入 `chunkStream`。 |
| `ignores empty data payloads` | `data` 字段为空时不会发出空 chunk。 |
| `ignores payloads larger than 300 bytes` | 超过 300 字节的异常 `data` 被丢弃（协议上限 2.4 kbit）。 |
| `unsubscribes on stop` | 调用 `stop()` 后取消对 `topicCustomByteBlock` 的订阅。 |

### `test/h264_annexb_gate_test.dart`

| 测试名 | 验证内容 |
|--------|---------|
| `detects an SPS (type 7)` | 4 字节 AnnexB start code 后接 nal_type=7 的 NALU 被识别为含 SPS。 |
| `detects a PPS (type 8)` | 4 字节 AnnexB start code 后接 nal_type=8 的 NALU 被识别为含 PPS。 |
| `detects SPS with a 3-byte short start code` | 3 字节短 start code (`00 00 01`) 场景下也能识别 SPS。 |
| `an IDR slice (type 5) alone is NOT a parameter set` | IDR slice 不触发门控。 |
| `a non-IDR slice (type 1) is NOT a parameter set` | 普通 P slice 不触发门控。 |
| `an AUD (type 9) is NOT a parameter set` | AUD NALU 不触发门控。 |
| `finds SPS when it follows an AUD in the same buffer` | 同一 buffer 内 AUD 后紧跟 SPS 时，SPS 被正确识别。 |
| `HEVC VPS (32) does NOT trip the H.264 gate` | HEVC 关键帧（VPS=32）不会被 H.264 门控误判。 |
| `HEVC SPS (33) does NOT trip the H.264 gate` | HEVC 关键帧（SPS=33）不会被 H.264 门控误判。 |
| `HEVC PPS (34) does NOT trip the H.264 gate` | HEVC 关键帧（PPS=34）不会被 H.264 门控误判。 |
| `empty data returns false` | 空 buffer 不触发门控。 |
| `data with no start code returns false` | 无 AnnexB start code 的 buffer 不触发门控。 |

### `test/custom_video_stream_service_test.dart`

| 测试名 | 验证内容 |
|--------|---------|
| `stays closed on pre-keyframe junk, opens on SPS` | 收到非关键帧数据时门控关闭；收到 SPS 后门控打开。 |
| `detects an SPS split across two chunks` | SPS 的 AnnexB start code 跨两个 `CustomByteBlock`（300B 分包边界）时，服务层累积扫描仍能正确识别并开门。 |
| `stop resets gate state` | 调用 `stop()` 后门控状态重置为关闭，下次 `start()` 重新等待关键帧。 |

---

## v0.0.3 Phase 3: Windows 本地测试编码端

### `tool/custom_byte_block_simulator/encoder_simulator.py`

| 模块 | 测试/验证方式 | 验证内容 |
|------|--------------|---------|
| `VideoReader` | 手动运行 + Python 语法编译 | 能打开本地视频文件或 DirectShow 摄像头，并按目标帧率抽帧。 |
| `ImagePreprocessor.process` | 手动运行 + OpenCV 窗口观察 | 复刻原编码端预处理：中心裁剪 800×800 → resize 到 400×400；静态区域简化；运动拖影；中心保护区；强制灰度模式。 |
| `H264Encoder` | 手动运行 + 输出文件/MQTT 抓包 | PyAV x264 输出 Annex-B byte-stream H.264；码率、 preset、GOP、B 帧参数与原仓库对齐。 |
| `MqttPacketizer` | 手动运行 + MQTT 订阅抓包 | 每 300B 切包；以 50Hz 频率发送 `CustomByteBlock`；2 秒滑动窗口带宽限速；超限时裁剪到下一个 Annex-B start code。 |
| `DisplayLoop` | 手动运行 | 显示 Raw / ROI / Static / Final 四个调试窗口；可选按 N 帧 dump PNG。 |
| 端到端 | `run_custom_video_test.ps1` | Mosquitto + 模拟器 + Flutter 客户端一键联调，验证客户端能解码出图并显示准星。 |

### `tool/run_custom_video_test.ps1`

| 功能 | 验证内容 |
|------|---------|
| 自动启动 mosquitto | 检查 1883 端口，未占用则启动，已占用则复用。 |
| 检查 Python 依赖 | 自动检测 `cv2`/`av`/`paho`/`protobuf`，缺失时 `pip install -r requirements.txt`。 |
| 生成 protobuf 绑定 | 首次运行时自动调用 `protoc` 生成 `robomaster_custom_client_pb2.py`。 |
| 启动编码模拟器 | 传入用户指定的输入、broker、端口。 |
| 启动 Flutter 客户端 | 默认启动 `flutter run`，可用 `-NoFlutter` 跳过。 |

### `tool/custom_byte_block_simulator/mini_mqtt_broker.py`

| 功能 | 验证内容 |
|------|---------|
| 零依赖 MQTT broker | 仅用 Python 标准库实现 MQTT 3.1.1 子集，监听指定端口。 |
| 端到端联调（已实测） | 在本地 `127.0.0.1:3333` 实测：发布 5 包 → 订阅收 5 包，protobuf 往返字节一致；编码模拟器发出 24 包 300B，首包即含 H.264 SPS（`00 00 00 01 67 42 ...`），格式正确。 |

> **联调实测记录（2026-06-18）**：合成视频 → OpenCV 预处理 → PyAV H.264 编码 → 300B 切包 → MQTT 发布 → mini broker 转发 → 订阅者接收，全链路无报错。修复了 3 个模拟器真实 bug：PyAV `time_base`/`framerate` 需 `Fraction`；cv2 `erode`/`dilate` 需 `iterations=` 关键字；cv2 Python 无 `Mat.copyTo`，改用布尔掩码。

---

## v0.0.3 Phase 2: UI 与解码

### `test/custom_video_ui_test.dart`

| 测试名 | 验证内容 |
|--------|---------|
| `CrosshairPainter default constructor uses zero offset and line width 1` | 准星默认参数：偏移为 0，线宽为 1（对齐原 Python 版默认值）。 |
| `CrosshairPainter shouldRepaint returns true when parameters change` | 偏移 X/Y 或线宽任一变化时触发重绘。 |
| `CrosshairPainter shouldRepaint returns false for identical parameters` | 参数完全相同时不重绘。 |
| `CrosshairPainter crosshair paints without error in a widget` | 准星 `CustomPainter` 在 widget 树中正常绘制，不抛异常。 |
| `CustomVideoScreen renders app bar and custom video panel` | 自定义图传页面正确渲染 AppBar 标题与面板。 |

---

## 待补充

（暂无）
