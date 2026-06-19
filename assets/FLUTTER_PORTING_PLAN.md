# Doorlock Sniper 解码显示部分 Flutter+Dart 移植计划

## 1. 项目理解摘要

### 1.1 现有架构
- **编码端** (`doorlock_sniper`, C++): 海康相机 → GStreamer (x264enc) → H.264 Annex-B 字节流 → 150B 分包 → ROS2 Topic `/video_stream`
- **解码端** (`doorlock_decoder`, Python): ROS2 订阅 → PyAV (H.264 流式解码) → OpenCV 显示 + 准星叠加
- **核心参数**: 400×400@60fps, 40kbps, 静态区域简化, 运动拖影, 中心保护区

### 1.2 通信协议 (RM2026 V1.3.1)
- **自定义客户端 ↔ 服务器**: MQTT over TCP (`192.168.12.1:3333`), Protobuf v3
- **0x0310 命令** (`CustomByteBlock`): 机器人通过图传链路发送 **300 字节** 自定义数据给自定义客户端，频率上限 50Hz，对应 MQTT Topic `CustomByteBlock`
- **官方图传码流**: UDP `3334` 端口，HEVC 编码，与当前项目无关

### 1.3 移植范围界定
本次移植**仅包含解码显示部分**（原 `doorlock_decoder` 功能），不包含编码器。目标是在 Flutter 自定义客户端中实现：
1. 通过 MQTT 接收 `CustomByteBlock` (300B H.264 数据)
2. 实时解码并显示视频
3. 叠加准星 (Crosshair + 中心圆点)
4. 本地测试能力（无需真实机器人）

---

## 2. 技术选型

| 模块 | 技术方案 | 理由 |
|------|---------|------|
| **MQTT 通信** | `mqtt_client` (Dart) | 纯 Dart 实现，支持 WebSocket/TCP，与现有协议兼容 |
| **Protobuf** | `protobuf` (Dart) + `protoc` | 官方 Dart 支持，协议已定义 |
| **H.264 解码** | 自定义 Flutter Plugin (`doorlock_decoder`) | 原生硬解最优：Android `MediaCodec`, iOS `VideoToolbox`, Windows/macOS `ffmpeg` + OpenGL Texture |
| **视频渲染** | `Texture` Widget | 最高性能，原生解码器直接输出到 GPU Texture |
| **UI/准星** | Flutter `CustomPainter` + `Stack` | 纯 Dart 实现，灵活可调 |
| **状态管理** | `Riverpod` / `Bloc` | 处理异步解码、MQTT 连接、配置状态 |
| **本地测试** | Dart 模拟数据生成器 | 复用现有 H.264 测试文件，UDP/本地 TCP 双路模拟 |

> **为什么不直接用 `video_player`？**  `video_player` 基于 ExoPlayer/AVPlayer，需要封装好的容器格式（MP4/MKV/TS）。本项目是 Annex-B 裸 H.264 流，需要流式解码器（无容器、无时长、实时 feed）。因此必须自定义解码插件。

---

## 3. 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter 自定义客户端 (Dart)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ UI Layer     │  │ Settings Page│  │ Debug Overlay        │  │
│  │ (准星/参数)   │  │ (配置参数)    │  │ (帧率/丢包/延迟)      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                 │                     │              │
│  ┌──────▼─────────────────▼─────────────────────▼───────┐       │
│  │                Business Logic Layer                 │       │
│  │  ┌────────────┐  ┌────────────┐  ┌──────────────┐  │       │
│  │  │ VideoBloc  │  │ MqttBloc   │  │ DecoderBloc  │  │       │
│  │  │ (状态管理)  │  │ (连接管理)  │  │ (解码控制)    │  │       │
│  │  └──────┬─────┘  └──────┬─────┘  └──────┬───────┘  │       │
│  │         │               │               │          │       │
│  │  ┌──────▼───────────────▼───────────────▼──────┐   │       │
│  │  │           Data / Repository Layer           │   │       │
│  │  │  ┌──────────────┐  ┌──────────────────────┐  │   │       │
│  │  │  │ MqttRepository │  │ DoorlockDecoderPlugin│  │   │       │
│  │  │  │ (MQTT + PB)   │  │ (Platform Channel)    │  │   │       │
│  │  │  └──────────────┘  └──────────────────────┘  │   │       │
│  │  └──────────────────────────────────────────────┘   │       │
│  └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Platform Channel
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│              原生解码插件 (Android/iOS/Desktop)                  │
│  ┌──────────────────┐  ┌────────────────────────────────────┐  │
│  │ H.264 Decoder    │  │ Texture / Surface                   │  │
│  │ Android: MediaCodec│  │ Android: SurfaceTexture → Texture   │  │
│  │ iOS: VideoToolbox  │  │ iOS: CVPixelBuffer → FlutterTexture │  │
│  │ Win/mac: ffmpeg    │  │ Desktop: OpenGL Texture            │  │
│  └──────────────────┘  └────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │ UDP 3334 / MQTT CustomByteBlock
                                    │ (本地测试: 模拟服务器)
┌─────────────────────────────────────────────────────────────────┐
│                      机器人 / 本地模拟器                           │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ 机器人端: GStreamer H.264 → 300B 分包 → 图传链路 → 0x0310  │   │
│  │ 本地模拟: 读取 .h264 文件 → 300B 分包 → UDP/MQTT 发送      │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. 详细实施计划

### Phase 0: 准备与环境搭建 (2 天)

**P0.1 创建 Flutter 项目骨架**
```bash
flutter create --org com.doorlock --project-name sniper_client doorlock_sniper_client
```

**P0.2 依赖配置** (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  mqtt_client: ^10.0.0        # MQTT 通信
  protobuf: ^3.1.0            # Protobuf 序列化
  riverpod: ^2.5.0            # 状态管理
  freezed_annotation: ^2.4.0  # 不可变数据类
  path_provider: ^2.1.0       # 文件路径
  shared_preferences: ^2.2.0 # 配置持久化

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^2.4.0
  protoc_plugin: ^21.0.0      # protoc-gen-dart
```

**P0.3 Protobuf 定义**
从通信协议手册提取 `CustomByteBlock` 定义，创建 `proto/doorlock.proto`:
```protobuf
syntax = "proto3";
package doorlock;

message CustomByteBlock {
  bytes data = 1;
}

// 如需要其他指令，可一并定义
message CustomControl {
  bytes data = 1;
}
```
生成 Dart 代码:
```bash
protoc --dart_out=lib/generated proto/doorlock.proto
```

---

### Phase 1: 自定义 H.264 解码插件 (核心难点, 5-7 天)

#### 1.1 插件设计目标
- 统一的 Dart API，跨平台一致
- 接收 Annex-B H.264 裸流数据块（任意大小）
- 输出到 `Texture` widget，供 Flutter 渲染
- 支持动态分辨率（初始 400×400，可配置）
- 低延迟（< 100ms 解码延迟）

#### 1.2 Dart API 定义 (`lib/decoder_plugin.dart`)
```dart
abstract class DoorlockDecoder {
  /// 初始化解码器，返回 Texture ID
  Future<int> initialize(int width, int height);
  
  /// 喂入 H.264 Annex-B 数据（300B 或任意大小）
  Future<void> feedData(Uint8List data);
  
  /// 重置解码器（丢包后调用）
  Future<void> reset();
  
  /// 释放资源
  Future<void> dispose();
  
  /// 解码统计流
  Stream<DecoderStats> get statsStream;
}

class DecoderStats {
  final int decodedFrames;
  final int receivedPackets;
  final int gapCount;
  final double fps;
}
```

#### 1.3 Android 原生实现 (Kotlin/Java)
```kotlin
class DoorlockDecoderPlugin : FlutterPlugin, MethodCallHandler {
    private var codec: MediaCodec? = null
    private var surfaceTexture: SurfaceTexture? = null
    private var textureId: Long = -1
    
    fun initialize(width: Int, height: Int): Long {
        // 1. 创建 SurfaceTexture，注册 Flutter TextureRegistry
        textureId = textureRegistry.createSurfaceTexture().id()
        surfaceTexture = SurfaceTexture(textureId)
        
        // 2. 配置 MediaCodec (H.264, low-latency)
        val format = MediaFormat.createVideoFormat("video/avc", width, height)
        format.setInteger(MediaFormat.KEY_LOW_LATENCY, 1)
        codec = MediaCodec.createDecoderByType("video/avc")
        codec?.configure(format, Surface(surfaceTexture), null, 0)
        codec?.start()
        return textureId
    }
    
    fun feedData(data: ByteArray) {
        // 3. 输入数据到 MediaCodec
        val inputBufferId = codec?.dequeueInputBuffer(0) ?: return
        val inputBuffer = codec?.getInputBuffer(inputBufferId)
        inputBuffer?.clear()
        inputBuffer?.put(data)
        codec?.queueInputBuffer(inputBufferId, 0, data.size, 0, 0)
        
        // 4. 输出到 SurfaceTexture
        val bufferInfo = MediaCodec.BufferInfo()
        var outputBufferId = codec?.dequeueOutputBuffer(bufferInfo, 0)
        while (outputBufferId != null && outputBufferId >= 0) {
            codec?.releaseOutputBuffer(outputBufferId, true)
            outputBufferId = codec?.dequeueOutputBuffer(bufferInfo, 0)
        }
        surfaceTexture?.updateTexImage()
    }
    
    fun reset() {
        codec?.flush()
    }
}
```

#### 1.4 iOS 原生实现 (Swift/Objective-C)
```swift
class DoorlockDecoder: NSObject, FlutterTexture {
    private var decompressionSession: VTDecompressionSession?
    private var textureId: Int64 = -1
    private var pixelBuffer: CVPixelBuffer?
    
    func initialize(width: Int, height: Int) -> Int64 {
        textureId = registry.registerTexture(self)
        
        let decoderSpecification = [
            kVTVideoDecoderSpecification_EnableHardwareAcceleratedVideoDecoder: true
        ] as CFDictionary
        
        var session: VTDecompressionSession?
        VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: formatDescription,  // 从 SPS/PPS 创建
            decoderSpecification: decoderSpecification,
            imageBufferAttributes: nil,
            outputCallback: decompressionOutputCallback,
            decompressionSessionOut: &session
        )
        decompressionSession = session
        return textureId
    }
    
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = pixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }
    
    func feedData(_ data: Data) {
        // 创建 CMSampleBuffer from Annex-B data
        // VTDecompressionSessionDecodeFrame(...)
    }
}
```

> **注**: Desktop (Windows/Linux/macOS) 可用 ffmpeg (libavcodec) + OpenGL/Texture 渲染。作为第二阶段扩展。

---

### Phase 2: MQTT 通信层 (2 天)

#### 2.1 连接管理 (`lib/data/mqtt_repository.dart`)
```dart
class MqttRepository {
  final MqttServerClient _client;
  
  MqttRepository({String ip = '192.168.12.1', int port = 3333}) 
    : _client = MqttServerClient(ip, 'doorlock_client');
  
  Future<void> connect(String robotId) async {
    _client.port = port;
    _client.logging(on: false);
    _client.keepAlivePeriod = 30;
    
    final connMessage = MqttConnectMessage()
        .withClientIdentifier('doorlock_client_$robotId')
        .startClean();
    _client.connectionMessage = connMessage;
    
    await _client.connect();
    
    // 订阅 CustomByteBlock Topic
    _client.subscribe('CustomByteBlock', MqttQos.atMostOnce);
    
    // 监听消息
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final data = recMess.payload.message;
      
      // Protobuf 反序列化
      final byteBlock = CustomByteBlock.fromBuffer(data);
      _onByteBlock.add(byteBlock.data);  // Uint8List (300 bytes)
    });
  }
  
  Stream<Uint8List> get byteBlockStream => _onByteBlock.stream;
  
  // 发送 CustomControl (0x0311)
  void sendCustomControl(Uint8List data) {
    final control = CustomControl(data: data);
    final builder = MqttClientPayloadBuilder();
    builder.add(control.writeToBuffer());
    _client.publishMessage('CustomControl', MqttQos.atMostOnce, builder.payload!);
  }
}
```

#### 2.2 与现有 ROS2 系统的桥接（可选）
在开发/测试阶段，如果机器人端仍使用 ROS2 而非真实图传链路，可以写一个 **Python 桥接节点**:
```python
# bridge_ros2_to_mqtt.py
# 订阅 ROS2 /video_stream (VideoPacket, 150B)
# 合并两个包为 300B（或补零到 300B）
# 通过 MQTT 发送 CustomByteBlock 到本地 Broker
```
这允许在现有硬件环境下测试 Flutter 客户端。

---

### Phase 3: 解码与业务逻辑 (3 天)

#### 3.1 解码 Bloc (`lib/bloc/decoder_bloc.dart`)
完全复现 Python 解码器的逻辑：

```dart
class DecoderBloc extends Bloc<DecoderEvent, DecoderState> {
  final DoorlockDecoder _decoder;
  final MqttRepository _mqttRepo;
  
  int _packetCount = 0;
  int _lastSeq = -1;
  int _gapCount = 0;
  int _frameCount = 0;
  
  DecoderBloc(this._decoder, this._mqttRepo) : super(DecoderInitial()) {
    on<InitializeDecoder>(_onInitialize);
    on<FeedPacket>(_onFeedPacket);
    on<ResetDecoder>(_onReset);
    
    // 订阅 MQTT 数据流
    _mqttRepo.byteBlockStream.listen((data) {
      add(FeedPacket(data));
    });
  }
  
  Future<void> _onInitialize(InitializeDecoder event, Emitter<DecoderState> emit) async {
    final textureId = await _decoder.initialize(event.width, event.height);
    emit(DecoderReady(textureId: textureId));
  }
  
  Future<void> _onFeedPacket(FeedPacket event, Emitter<DecoderState> emit) async {
    _packetCount++;
    
    // TODO: 序列号解析。当前 300B 纯数据无序列号，需设计分包头。
    // 若保持纯 300B 数据，序列号需由机器人端/协议层附加。
    
    // 丢包检测（如果数据中包含序列号）
    // if (lastSeq != null && seq != lastSeq + 1) { reset(); }
    
    await _decoder.feedData(event.data);
    
    emit(DecoderRunning(
      packetCount: _packetCount,
      frameCount: _frameCount,
      gapCount: _gapCount,
    ));
  }
  
  Future<void> _onReset(ResetDecoder event, Emitter<DecoderState> emit) async {
    await _decoder.reset();
    _gapCount++;
  }
}
```

> **关键设计决策：300B 数据的序列号**
> 原 ROS2 `VideoPacket` 包含 `sequence_id` (uint64) 和 `timestamp_ns` (uint64)。但真实 0x0310 协议只有 300 字节纯数据。为了保持丢包检测能力，有两种方案：
> 1. **机器人端修改**：在 300B 数据前附加 2-4 字节序列号头，剩余 296-298B 为 H.264 负载
> 2. **MQTT 层检测**：依赖 MQTT 消息顺序和 QoS，但 MQTT 是可靠传输（TCP），丢包概率低
> 
> **建议采用方案 1**，在 300B 自定义数据中定义：`[2B seq_id][298B h264_payload]`。这与当前 ROS2 的 150B 分包逻辑一致。

#### 3.2 配置管理
所有原 Python 解码器的参数移植为可配置：
| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `topic` | String | `CustomByteBlock` | MQTT Topic |
| `width` | int | 400 | 解码宽度 |
| `height` | int | 400 | 解码高度 |
| `displayScale` | int | 2 | 显示放大倍数 |
| `crosshairOffsetX` | int | 0 | 准心 X 偏移 |
| `crosshairOffsetY` | int | 0 | 准心 Y 偏移 |
| `crosshairWidth` | int | 2 | 准心线宽 |
| `crosshairColor` | Color | 淡紫色 (0xFFE6BEEA) | BGR 映射 |
| `centerColor` | Color | 淡绿色 (0xFFAAFFAA) | 中心圆点 |
| `centerCircleRadius` | int | 24 | 中心圆点半径 |

---

### Phase 4: UI 与准星 (2 天)

#### 4.1 显示页面 (`lib/ui/video_page.dart`)
```dart
class VideoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(decoderBloc);
    
    return Scaffold(
      body: Stack(
        children: [
          // 1. 视频 Texture
          if (state is DecoderReady)
            Texture(textureId: state.textureId),
          
          // 2. 准星叠加 (CustomPainter)
          CustomPaint(
            size: Size.infinite,
            painter: CrosshairPainter(
              offsetX: settings.crosshairOffsetX,
              offsetY: settings.crosshairOffsetY,
              lineWidth: settings.crosshairWidth,
              crosshairColor: settings.crosshairColor,
              centerColor: settings.centerColor,
              radius: settings.centerCircleRadius,
            ),
          ),
          
          // 3. 调试信息覆盖层
          if (settings.debugOverlay)
            DebugOverlay(
              packetCount: state.packetCount,
              frameCount: state.frameCount,
              gapCount: state.gapCount,
              fps: state.fps,
            ),
        ],
      ),
    );
  }
}
```

#### 4.2 准星绘制器 (`lib/ui/painters/crosshair_painter.dart`)
完全复现 Python `_draw_overlay` 逻辑：
```dart
class CrosshairPainter extends CustomPainter {
  final int offsetX, offsetY, lineWidth, radius;
  final Color crosshairColor, centerColor;
  
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // 准心位置（相对中心可调）
    final cx = (w / 2 + offsetX).clamp(0, w - 1);
    final cy = (h / 2 + offsetY).clamp(0, h - 1);
    
    // 淡紫色准心（横竖贯穿全屏）
    final crossPaint = Paint()
      ..color = crosshairColor
      ..strokeWidth = lineWidth.toDouble()
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(0, cy), Offset(w - 1, cy), crossPaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, h - 1), crossPaint);
    
    // 画面正中心固定淡绿色小圆点（不可调）
    final center = Offset(w / 2, h / 2);
    final circlePaint = Paint()
      ..color = centerColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius.toDouble(), circlePaint);
  }
  
  @override
  bool shouldRepaint(covariant CrosshairPainter old) => true;
}
```

---

### Phase 5: 本地测试系统 (3 天)

#### 5.1 测试目标
- 无需真实机器人、无需裁判系统、无需 ROS2
- 在开发 PC/手机上直接验证 Flutter 客户端的完整解码链路

#### 5.2 测试架构
```
┌─────────────────┐      UDP / MQTT      ┌─────────────────┐
│  H.264 模拟器    │  ─────────────────→  │  Flutter 客户端   │
│  (Dart/CLI)     │                      │                 │
└─────────────────┘                      └─────────────────┘
```

#### 5.3 H.264 模拟器 (`tools/h264_simulator/`)

**方案 A: 基于文件的本地测试**
```dart
// test/tools/h264_simulator.dart
class H264Simulator {
  final String filePath;  // 从现有项目 dump 的 H.264 裸流文件
  final int packetSize = 300;  // 模拟 300B 分包
  final Duration interval;     // 发送间隔
  
  Stream<Uint8List> generate() async* {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    
    int seq = 0;
    for (int i = 0; i < bytes.length; i += packetSize) {
      final end = min(i + packetSize, bytes.length);
      final payload = bytes.sublist(i, end);
      
      // 构造 300B 包：2B seq + 298B payload（不足补零）
      final packet = Uint8List(packetSize);
      final seqBytes = ByteData(2)..setUint16(0, seq++, Endian.little);
      packet.setRange(0, 2, seqBytes.buffer.asUint8List());
      packet.setRange(2, 2 + payload.length, payload);
      
      yield packet;
      await Future.delayed(interval);
    }
  }
}
```

**方案 B: 使用现有 ROS2 环境进行桥接测试**
```python
# tools/bridge_ros2_to_mqtt.py
# 1. 启动 ROS2 环境，运行 doorlock_sniper 编码器
# 2. 订阅 /video_stream (VideoPacket, 150B)
# 3. 每两个包合并为一个 300B 包（seq 合并，data 拼接）
# 4. 发送到本地 MQTT Broker (mosquitto)，Topic: CustomByteBlock
# 5. Flutter 客户端连接 localhost:1883 测试
```

**方案 C: 使用 UDP 直接发送（模拟图传链路）**
```dart
// 本地测试时，直接通过 UDP 发送 300B 包到 Flutter 客户端
// Flutter 端监听 UDP 端口，解析后喂给解码器
// 此方案绕过 MQTT/Protobuf，最轻量
```

> **建议**: 本地测试支持三种模式，通过 `Mode` 枚举切换：
> - `Mode.mqtt`: 连接真实/本地 MQTT Broker，接收 CustomByteBlock
> - `Mode.udp`: 监听 UDP 端口，接收裸 300B 包
> - `Mode.file`: 读取本地 H.264 文件，模拟发送

#### 5.4 测试数据生成
使用现有项目的 `debug_dump` 功能，在编码器端保存几帧原始 H.264 流数据：
```bash
# 在 ROS2 环境中启动编码器，并开启 dump
ros2 launch bringup sniper.launch.py
# 从 debug_dump_dir 中提取 encoder/final_*.png 对应的 H.264 时刻
# 或者从 GStreamer appsink 保存原始 buffer 到 .h264 文件
```

---

### Phase 6: 实际机器人对接 (2 天)

#### 6.1 机器人端修改 (适配 300B)
当前编码器 `video_encoder_node.cpp` 限制 `packet_size = 150`:
```cpp
constexpr int kVideoPacketBytes = 150;
// ...
if (param_packet_size_ != kVideoPacketBytes) {
  param_packet_size_ = kVideoPacketBytes;  // 强制 150
}
```

**修改方案**（在 `doorlock_sniper` 仓库中，创建分支 `flutter/300byte`）：
1. 修改 `VideoPacket.msg` 为 `uint8[300]`（或弃用 ROS2 消息，直接通过串口发送）
2. 修改 `kVideoPacketBytes = 300`
3. 在 `pull_stream_and_packetize()` 中，将 300B 数据通过图传链路发送（需配合机器人主控代码）

> **注意**：真实比赛环境中，机器人端代码通常由嵌入式开发团队负责。Flutter 团队需要与他们确认：
> - 300B 数据格式：是否包含序列号？如包含，占用几个字节？在什么位置？
> - 发送频率：是否保持 50Hz？
> - 数据内容：是否纯 H.264 Annex-B？是否包含其他元数据？

#### 6.2 机器人端不改动的替代方案
如果机器人端无法修改，可以在 Flutter 端通过 **MQTT 接收 `CustomByteBlock`**，该消息由机器人主控（或中转节点）发送，机器人主控负责从图传链路提取 0x0310 的 300B 数据并封装为 `CustomByteBlock` 的 `data` 字段。这是协议规定的正常数据流。

```
机器人主控 (STM32/RTOS)
  → 通过裁判系统图传链路发送 0x0310 (300B)
  → 选手端服务器接收并转发
  → 服务器 MQTT Broker (192.168.12.1:3333)
  → Flutter 客户端订阅 CustomByteBlock Topic
  → 提取 data 字段 (300B)
  → 解码器
```

---

### Phase 7: 优化与测试 (3 天)

#### 7.1 性能指标
| 指标 | 目标 | 测试方法 |
|------|------|---------|
| 端到端延迟 | < 200ms | 相机拍摄计时器 → 手机屏幕显示 |
| 解码帧率 | ≥ 60fps | Flutter DevTools Performance |
| 内存占用 | < 150MB | Android Profiler / Xcode Instruments |
| CPU 占用 | < 30% | 同上报表 |
| 丢包恢复 | < 100ms 黑屏 | 模拟丢包 1 个包，测量恢复时间 |
| 带宽 | ~10kB/s | 网络监控 |

#### 7.2 测试矩阵
| 测试项 | 本地文件 | 本地 ROS2+桥接 | 真实机器人 |
|--------|---------|---------------|-----------|
| H.264 解码 | ✅ | ✅ | ✅ |
| 准星显示 | ✅ | ✅ | ✅ |
| 丢包检测 | ✅ | ✅ | ✅ |
| 解码器重置 | ✅ | ✅ | ✅ |
| 参数调整 | ✅ | ✅ | ✅ |
| 长时间稳定性 (10min) | ✅ | ✅ | ✅ |

---

## 5. 项目目录结构

```
doorlock_sniper_client/
├── android/                          # Android 原生代码
│   └── src/main/kotlin/.../DoorlockDecoderPlugin.kt
├── ios/                              # iOS 原生代码
│   └── Classes/DoorlockDecoderPlugin.swift
├── lib/
│   ├── main.dart                     # 入口
│   ├── app.dart                      # MaterialApp 配置
│   ├── generated/                    # Protobuf 生成代码
│   │   └── doorlock.pb.dart
│   ├── data/
│   │   ├── mqtt_repository.dart      # MQTT + Protobuf 通信
│   │   ├── udp_repository.dart       # UDP 测试接收
│   │   └── local_file_source.dart     # 本地文件测试源
│   ├── bloc/
│   │   ├── decoder_bloc.dart         # 解码器状态管理
│   │   ├── mqtt_bloc.dart            # MQTT 连接状态
│   │   └── settings_cubit.dart       # 配置管理
│   ├── models/
│   │   ├── decoder_stats.dart        # 解码统计
│   │   └── app_settings.dart         # 应用配置
│   ├── ui/
│   │   ├── video_page.dart           # 主显示页面
│   │   ├── settings_page.dart        # 参数设置页
│   │   ├── widgets/
│   │   │   ├── debug_overlay.dart    # 调试信息覆盖
│   │   │   └── crosshair_painter.dart # 准星绘制
│   │   └── theme.dart                # 主题配置
│   └── plugin/
│       └── doorlock_decoder.dart     # 解码插件 Dart 封装
├── proto/
│   └── doorlock.proto                # Protobuf 定义
├── test/
│   ├── unit/                         # 单元测试
│   ├── widget/                       # Widget 测试
│   └── integration/                  # 集成测试
├── tools/
│   ├── h264_simulator.dart           # H.264 本地模拟器
│   ├── bridge_ros2_to_mqtt.py      # ROS2→MQTT 桥接
│   └── generate_test_data.py         # 测试数据生成
├── pubspec.yaml
└── README.md                         # 编译运行指南
```

---

## 6. 风险与缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| Flutter 原生 H.264 解码插件开发复杂 | 高 | 高 | 分阶段实现：先 Android (MediaCodec)，再 iOS (VideoToolbox)，Desktop 最后 |
| 300B 数据格式与机器人端不一致 | 中 | 高 | 与机器人团队确认协议头定义；保留 150B 兼容模式 |
| 裁判系统 MQTT 连接不稳定 | 中 | 中 | 实现断线重连、缓冲队列、降级显示 |
| 延迟超过 200ms | 中 | 高 | 使用低延迟解码模式；优化渲染管线；减少缓冲 |
| 跨平台维护成本 | 中 | 中 | 插件接口统一；使用 FFI 替代平台通道（未来优化） |

---

## 7. 里程碑与时间线

| 里程碑 | 预计时间 | 验收标准 |
|--------|---------|---------|
| M1: 项目骨架 + Protobuf | 第 2 天 | `flutter run` 正常，Protobuf 编译通过 |
| M2: Android 解码插件 MVP | 第 7 天 | 能在 Android 真机上解码本地 H.264 文件并显示到 Texture |
| M3: MQTT 通信 + 本地模拟器 | 第 10 天 | 模拟器发送 300B 包 → Flutter 解码 → 显示，延迟 < 200ms |
| M4: UI 完整 + 准星 + 设置 | 第 13 天 | 所有参数可调，准星精确复现 Python 版本视觉效果 |
| M5: iOS 适配 | 第 16 天 | iOS 真机运行，性能与 Android 一致 |
| M6: 真实机器人联调 | 第 19 天 | 连接真实机器人，接收 300B 数据，稳定显示 ≥ 5 分钟 |
| M7: 文档 + 交付 | 第 21 天 | README 完整，代码合并，可独立编译运行 |

---

## 8. 附录：关键代码片段

### A. 合并两个 150B 包为 300B（机器人端 C++ 修改）
```cpp
// 在 video_encoder_node.cpp 的 pull_stream_and_packetize() 中
// 或创建新的 packeting 逻辑

void pull_stream_and_packetize_300b() {
  const size_t small_packet = 150;
  const size_t big_packet = 300;  // 0x0310 要求
  
  // 收集两个 150B 包
  static std::vector<uint8_t> accumulator;
  
  while (stream_buffer_.size() >= small_packet) {
    accumulator.insert(accumulator.end(),
                       stream_buffer_.begin(),
                       stream_buffer_.begin() + small_packet);
    stream_buffer_.erase(stream_buffer_.begin(),
                         stream_buffer_.begin() + small_packet);
    
    if (accumulator.size() >= big_packet) {
      // 发送 300B 包（或添加序列号头）
      doorlock_sniper::msg::VideoPacket pkt;
      pkt.sequence_id = packet_sequence_id_++;
      pkt.data.fill(0);
      memcpy(pkt.data.data(), accumulator.data(), big_packet);
      packet_pub_->publish(pkt);  // 或发送给图传链路
      accumulator.clear();
    }
  }
}
```

### B. Dart 中的 300B 包解析
```dart
class VideoPacketParser {
  static (int seq, Uint8List payload) parse300B(Uint8List packet) {
    assert(packet.length == 300);
    final seq = ByteData.sublistView(packet, 0, 2).getUint16(0, Endian.little);
    final payload = Uint8List.sublistView(packet, 2, 300);  // 298 bytes
    return (seq, payload);
  }
}
```

### C. 本地 MQTT Broker 快速启动（用于测试）
```bash
# Docker
sudo docker run -it -p 1883:1883 -p 9001:9001 eclipse-mosquitto

# 或本地安装
sudo apt install mosquitto
sudo systemctl start mosquitto
```

---

## 9. 总结

本计划将原 `doorlock_decoder` 的全部功能移植到 Flutter+Dart 技术栈，同时严格遵循 RM2026 通信协议手册中 `0x0310` / `CustomByteBlock` 的 300 字节数据规范。通过**自定义原生解码插件**解决 Flutter 实时 H.264 裸流解码的核心难点，通过**三层本地测试体系**（文件模拟 / UDP 模拟 / ROS2 桥接）确保开发阶段的可验证性。

**下一步行动**：
1. 创建 Flutter 项目骨架和 Protobuf 定义（M1）
2. 与机器人团队确认 300B 数据格式（序列号头、负载分配）
3. 启动 Android 原生解码插件开发（M2）
